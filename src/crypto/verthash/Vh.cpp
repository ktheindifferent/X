/* X Miner
 * Copyright (c) 2024 X Project
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

#include "crypto/verthash/Vh.h"
#include "crypto/verthash/VerthashConfig.h"
#include "crypto/verthash/VerthashWrapper.h"
#include "base/io/log/Log.h"
#include "base/io/log/Tags.h"
#include "base/tools/Chrono.h"

namespace xmrig {

static const char *kDefaultDataFile = "verthash.dat";

bool Vh::init(const VerthashConfig &config)
{
    // Check if we need to generate the data file first
    if (!config.genDataFile().isEmpty()) {
        LOG_INFO("%s " YELLOW("Generating Verthash data file: %s"), Tags::cpu(), config.genDataFile().data());
        LOG_INFO("%s " YELLOW("This may take 30-60 minutes..."), Tags::cpu());

        const uint64_t startTime = Chrono::steadyMSecs();
        int result = Verthash::generateDataFile(config.genDataFile().data());

        if (result != 0) {
            LOG_ERR("%s " RED("Failed to generate Verthash data file!"), Tags::cpu());
            return false;
        }

        LOG_INFO("%s " GREEN("Verthash data file generated successfully in %" PRIu64 " seconds"),
                 Tags::cpu(), (Chrono::steadyMSecs() - startTime) / 1000);

        // If no data file was specified, use the generated one
        if (config.dataFile().isEmpty()) {
            return Verthash::instance().init(config.genDataFile().data());
        }
    }

    // Determine which data file to load
    const char *dataFile = config.dataFile().isEmpty() ? kDefaultDataFile : config.dataFile().data();

    LOG_INFO("%s " YELLOW("Loading Verthash data file: %s"), Tags::cpu(), dataFile);

    const uint64_t startTime = Chrono::steadyMSecs();

    if (!Verthash::instance().init(dataFile)) {
        LOG_ERR("%s " RED("Failed to load Verthash data file: %s"), Tags::cpu(), dataFile);
        LOG_ERR("%s " RED("Use --gen-verthash-data=verthash.dat to generate it, or download from:"), Tags::cpu());
        LOG_ERR("%s " RED("  https://github.com/nicehash/VerthashMiner/releases"), Tags::cpu());
        return false;
    }

    LOG_INFO("%s " GREEN("Verthash data file loaded: %zu MB (%" PRIu64 "ms)"),
             Tags::cpu(),
             Verthash::instance().dataSize() / (1024 * 1024),
             Chrono::steadyMSecs() - startTime);

    return true;
}

void Vh::destroy()
{
    Verthash::instance().release();
}

bool Vh::isReady()
{
    return Verthash::instance().isValid();
}

const char *Vh::dataFile()
{
    return Verthash::instance().filePath();
}

} // namespace xmrig
