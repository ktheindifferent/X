/* XMRig
 * Copyright (c) 2018-2020 SChernykh   <https://github.com/SChernykh>
 * Copyright (c) 2016-2020 XMRig       <https://github.com/xmrig>, <support@xmrig.com>
 *
 *   This program is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU General Public License as published by
 *   the Free Software Foundation, either version 3 of the License, or
 *   (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *   GNU General Public License for more details.
 *
 *   You should have received a copy of the GNU General Public License
 *   along with this program. If not, see <http://www.gnu.org/licenses/>.
 */


#include "base/net/stratum/strategies/FailoverStrategy.h"
#include "3rdparty/rapidjson/document.h"
#include "base/kernel/interfaces/IClient.h"
#include "base/kernel/interfaces/IStrategyListener.h"
#include "base/kernel/Platform.h"
#include "base/io/log/Log.h"


xmrig::FailoverStrategy::FailoverStrategy(const std::vector<Pool> &pools, int retryPause, int retries, IStrategyListener *listener, bool quiet) :
    m_quiet(quiet),
    m_retries(retries),
    m_retryPause(retryPause),
    m_listener(listener)
{
    for (const Pool &pool : pools) {
        add(pool);
    }
}


xmrig::FailoverStrategy::FailoverStrategy(int retryPause, int retries, IStrategyListener *listener, bool quiet) :
    m_quiet(quiet),
    m_retries(retries),
    m_retryPause(retryPause),
    m_listener(listener)
{
}


xmrig::FailoverStrategy::~FailoverStrategy()
{
    for (IClient *client : m_pools) {
        client->deleteLater();
    }
}


void xmrig::FailoverStrategy::add(const Pool &pool)
{
    IClient *client = pool.createClient(static_cast<int>(m_pools.size()), this);

    client->setRetries(m_retries);
    client->setRetryPause(m_retryPause * 1000);
    client->setQuiet(m_quiet);

    m_pools.push_back(client);
}


int64_t xmrig::FailoverStrategy::submit(const JobResult &result)
{
    if (!isActive()) {
        return -1;
    }

    return active()->submit(result);
}


void xmrig::FailoverStrategy::connect()
{
    m_pools[m_index]->connect();
}


void xmrig::FailoverStrategy::resume()
{
    if (!isActive()) {
        return;
    }

    m_listener->onJob(this, active(), active()->job(), rapidjson::Value(rapidjson::kNullType));
}


void xmrig::FailoverStrategy::setAlgo(const Algorithm &algo)
{
    for (IClient *client : m_pools) {
        client->setAlgo(algo);
    }
}


void xmrig::FailoverStrategy::setProxy(const ProxyUrl &proxy)
{
    for (IClient *client : m_pools) {
        client->setProxy(proxy);
    }
}


void xmrig::FailoverStrategy::stop()
{
    for (auto &pool : m_pools) {
        pool->disconnect();
    }

    m_index  = 0;
    m_active = -1;

    m_listener->onPause(this);
}


void xmrig::FailoverStrategy::tick(uint64_t now)
{
    for (IClient *client : m_pools) {
        client->tick(now);
    }

    // Process any pending connection from deferred failover (retries=0 mode)
    connectNext();
}


void xmrig::FailoverStrategy::onClose(IClient *client, int failures)
{
    LOG_INFO("FAILOVER onClose: client=%d failures=%d m_index=%zu m_active=%d m_minAcceptableIndex=%zu m_pendingConnect=%d",
              client->id(), failures, m_index, m_active, m_minAcceptableIndex, m_pendingConnect ? 1 : 0);

    if (failures == -1) {
        LOG_INFO("FAILOVER onClose: ignoring explicit disconnect (failures=-1)");
        return;
    }

    if (m_active == client->id()) {
        m_active = -1;
        m_listener->onPause(this);
    }

    // With 0 retries configured, immediately failover to next pool on first error.
    // We defer the connect() call to tick() to prevent re-entrancy issues that can
    // cause crashes when DNS resolution fails synchronously for multiple pools.
    if (m_retries == 0) {
        // Ignore onClose from lower-indexed pools when we're already progressing
        // to a higher pool. Check against m_minAcceptableIndex which persists even
        // after connectNext() clears m_pendingConnect.
        if (static_cast<size_t>(client->id()) < m_minAcceptableIndex) {
            // Re-disconnect to reset its reconnect timer
            client->disconnect();
            return;
        }

        // Only advance to next pool if this is the current pool
        if (m_index == static_cast<size_t>(client->id())) {
            // Stop ALL pools up to and including this one from auto-reconnecting.
            // This is critical because lower-indexed pools may have reconnect timers
            // that would fire and interfere with us progressing to the next pool.
            for (size_t i = 0; i <= m_index; ++i) {
                m_pools[i]->disconnect();
            }

            if ((m_pools.size() - m_index) > 1) {
                // More pools available, schedule connection to the next one
                m_pendingIndex = m_index + 1;
                // Set minimum acceptable index - we won't accept any pool below this
                m_minAcceptableIndex = m_pendingIndex;
            } else {
                // All pools exhausted, wrap around to pool #0
                m_pendingIndex = 0;
                // Reset minimum acceptable index since we're starting over
                m_minAcceptableIndex = 0;
            }
            m_pendingConnect = true;
        }
        return;
    }

    if (m_index == 0 && failures < m_retries) {
        return;
    }

    if (m_index == static_cast<size_t>(client->id()) && (m_pools.size() - m_index) > 1) {
        m_pools[++m_index]->connect();
    }
}


void xmrig::FailoverStrategy::connectNext()
{
    if (!m_pendingConnect || m_pendingIndex >= m_pools.size()) {
        return;
    }

    LOG_INFO("FAILOVER connectNext: connecting to pool %zu (pools.size=%zu)", m_pendingIndex, m_pools.size());

    m_pendingConnect = false;
    m_index = m_pendingIndex;
    m_pools[m_index]->connect();
}


void xmrig::FailoverStrategy::onLogin(IClient *client, rapidjson::Document &doc, rapidjson::Value &params)
{
    m_listener->onLogin(this, client, doc, params);
}


void xmrig::FailoverStrategy::onJobReceived(IClient *client, const Job &job, const rapidjson::Value &params)
{
    if (m_active == client->id()) {
        m_listener->onJob(this, client, job, params);
    }
}


void xmrig::FailoverStrategy::onLoginSuccess(IClient *client)
{
    int active = m_active;

    // In retries=0 mode, if we're in the process of failing over to a higher pool,
    // ignore login success from lower-indexed pools. This prevents the primary pool
    // from "stealing" the connection when we're trying to progress through the failover chain.
    // Use m_minAcceptableIndex which persists even after connectNext() clears m_pendingConnect.
    if (m_retries == 0 && static_cast<size_t>(client->id()) < m_minAcceptableIndex) {
        // Lower pool reconnected while we're trying to connect to a higher one - disconnect it
        client->disconnect();
        return;
    }

    // Cancel any pending connection since we now have an active pool
    m_pendingConnect = false;

    // Reset minimum acceptable index since we successfully connected to an acceptable pool
    m_minAcceptableIndex = 0;

    if (client->id() == 0 || !isActive()) {
        active = client->id();
    }

    // Disconnect ALL other pools, including pool #0 when a backup pool becomes active.
    // This is critical for retries=0 mode to prevent the primary pool from interfering.
    for (size_t i = 0; i < m_pools.size(); ++i) {
        if (active != static_cast<int>(i)) {
            m_pools[i]->disconnect();
        }
    }

    if (active >= 0 && active != m_active) {
        m_index = m_active = active;
        m_listener->onActive(this, client);
    }
}


void xmrig::FailoverStrategy::onResultAccepted(IClient *client, const SubmitResult &result, const char *error)
{
    m_listener->onResultAccepted(this, client, result, error);
}


void xmrig::FailoverStrategy::onVerifyAlgorithm(const IClient *client, const Algorithm &algorithm, bool *ok)
{
    m_listener->onVerifyAlgorithm(this, client, algorithm, ok);
}
