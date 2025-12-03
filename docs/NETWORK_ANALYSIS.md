# Network and Stratum Protocol Analysis

## Overview

This document provides a comprehensive analysis of X's network layer implementation, focusing on the Stratum protocol client, pool connection management, job distribution, and result submission systems. The network layer is responsible for all communication with mining pools, job propagation to workers, and submission of successful mining results.

**Key Components:**
- **Network** - Main network coordinator orchestrating all network activity
- **Client** - Stratum protocol implementation for pool communication
- **Strategy Pattern** - Pool management strategies (failover, donation)
- **Job Distribution** - Job propagation from pools to workers
- **Result Submission** - Mining result collection and submission

**Documentation Version:** 2025-12-02
**Based on:** X v6.24.0 (forked from XMRig)

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Network Class - Main Coordinator](#network-class---main-coordinator)
3. [Client Hierarchy](#client-hierarchy)
4. [Pool Configuration](#pool-configuration)
5. [Strategy Pattern](#strategy-pattern)
6. [Job Structure and Lifecycle](#job-structure-and-lifecycle)
7. [Result Submission System](#result-submission-system)
8. [Stratum Protocol Implementation](#stratum-protocol-implementation)
9. [Connection Management](#connection-management)
10. [Network State Tracking](#network-state-tracking)
11. [Optimization Opportunities](#optimization-opportunities)
12. [Code References](#code-references)

---

## Architecture Overview

### Component Hierarchy

```
Network (src/net/Network.h/cpp)
├── IStrategy (strategy pattern for pool management)
│   ├── FailoverStrategy (pool failover logic)
│   ├── DonateStrategy (donation mining)
│   └── SinglePoolStrategy (single pool)
├── NetworkState (statistics tracking)
├── IClient (pool connection interface)
│   ├── BaseClient (common client logic)
│   └── Client (Stratum implementation)
│       ├── DNS resolution
│       ├── TLS support
│       └── SOCKS5 proxy
└── JobResults (static result submission)
    └── JobResultsPrivate (async result handling)
```

### Data Flow

```
1. Job Reception:
   Pool → Client (Stratum) → Strategy → Network → Workers

2. Result Submission:
   Workers → JobResults → Network → Strategy → Client → Pool

3. Connection Management:
   Network → Strategy → Client → DNS/TLS/Socket → Pool
```

---

## Network Class - Main Coordinator

### Purpose

The `Network` class (`src/net/Network.h`) is the main coordinator for all network activity. It:
- Manages pool connection strategies
- Handles job distribution to miners
- Processes result submissions from workers
- Coordinates donation mining periods
- Tracks network statistics

### Class Structure

```cpp
class Network : public IJobResultListener,
                public IStrategyListener,
                public IBaseListener,
                public ITimerListener,
                public IApiListener
{
public:
    Network(Controller *controller);
    ~Network() override;

    inline IStrategy *strategy() const { return m_strategy; }

    void connect();
    void execCommand(char command);

protected:
    // Strategy listener callbacks
    void onActive(IStrategy *strategy, IClient *client) override;
    void onJob(IStrategy *strategy, IClient *client, const Job &job, const rapidjson::Value &params) override;
    void onResultAccepted(IStrategy *strategy, IClient *client, const SubmitResult &result, const char *error) override;

    // Job result listener callback
    void onJobResult(const JobResult &result) override;

private:
    constexpr static int kTickInterval = 1 * 1000;  // 1 second

    Controller *m_controller;
    IStrategy *m_donate     = nullptr;  // Donation strategy
    IStrategy *m_strategy   = nullptr;  // Main pool strategy
    NetworkState *m_state   = nullptr;  // Statistics tracker
    Timer *m_timer          = nullptr;  // Periodic tick timer
};
```

**File:** `src/net/Network.h`, `src/net/Network.cpp`

### Initialization

```cpp
xmrig::Network::Network(Controller *controller) :
    m_controller(controller)
{
    // Register as job result listener
    JobResults::setListener(this, controller->config()->cpu().isHwAES());

    // Create network state tracker
    m_state = new NetworkState(this);

    // Create main pool strategy from configuration
    const Pools &pools = controller->config()->pools();
    m_strategy = pools.createStrategy(m_state);

    // Create donation strategy if donation level > 0
    if (pools.donateLevel() > 0) {
        m_donate = new DonateStrategy(controller, this);
    }

    // Start periodic timer (1 second interval)
    m_timer = new Timer(this, kTickInterval, kTickInterval);
}
```

**File:** `src/net/Network.cpp:59-79`

### Job Distribution

When a new job arrives from the pool, the Network class distributes it to workers:

```cpp
void xmrig::Network::onJob(IStrategy *strategy, IClient *client, const Job &job, const rapidjson::Value &)
{
    // Ignore jobs from inactive donation strategy
    if (m_donate && m_donate->isActive() && m_donate != strategy) {
        return;
    }

    setJob(client, job, m_donate == strategy);
}
```

The `setJob` method updates the global job that workers mine on and triggers job propagation through the backend system.

**File:** `src/net/Network.cpp:165-172`

### Result Handling

When workers find valid shares, results flow back through the Network:

```cpp
void xmrig::Network::onJobResult(const JobResult &result)
{
    // Route donation results to donation strategy
    if (result.index == 1 && m_donate) {
        m_donate->submit(result);
        return;
    }

    // Route regular results to main strategy
    m_strategy->submit(result);
}
```

**File:** `src/net/Network.cpp:175-183`

---

## Client Hierarchy

### Interface: IClient

The `IClient` interface (`src/base/kernel/interfaces/IClient.h`) defines the contract for all pool clients:

```cpp
class IClient
{
public:
    enum Extension {
        EXT_ALGO,       // Algorithm extension support
        EXT_NICEHASH,   // NiceHash protocol support
        EXT_CONNECT,    // Connect extension
        EXT_TLS,        // TLS support
        EXT_KEEPALIVE,  // Keep-alive support
        EXT_MAX
    };

    using Callback = std::function<void(const rapidjson::Value &result, bool success, uint64_t elapsed)>;

    virtual bool disconnect() = 0;
    virtual bool hasExtension(Extension extension) const noexcept = 0;
    virtual const Job &job() const = 0;
    virtual const Pool &pool() const = 0;
    virtual int64_t submit(const JobResult &result) = 0;
    virtual void connect() = 0;
    virtual void tick(uint64_t now) = 0;
    // ... more methods
};
```

**File:** `src/base/kernel/interfaces/IClient.h`

### BaseClient - Common Logic

`BaseClient` (`src/base/net/stratum/BaseClient.h`) provides common functionality:

```cpp
class BaseClient : public IClient
{
protected:
    enum SocketState {
        UnconnectedState,
        HostLookupState,
        ConnectingState,
        ConnectedState,
        ClosingState,
        ReconnectingState
    };

    struct SendResult {
        inline SendResult(Callback &&callback) : callback(callback), ts(Chrono::steadyMSecs()) {}
        Callback callback;
        const uint64_t ts;  // Timestamp for timeout tracking
    };

    IClientListener *m_listener;
    Job m_job;                              // Current job
    Pool m_pool;                            // Pool configuration
    SocketState m_state;
    std::map<int64_t, SendResult> m_callbacks;     // RPC callbacks
    std::map<int64_t, SubmitResult> m_results;     // Pending results
    int64_t m_failures = 0;                        // Connection failure count
    int m_retries = 5;                             // Max retries
    uint64_t m_retryPause = 5000;                  // Retry pause (ms)
};
```

**File:** `src/base/net/stratum/BaseClient.h`

### Client - Stratum Protocol Implementation

The `Client` class (`src/base/net/stratum/Client.h`) implements the Stratum protocol:

```cpp
class Client : public BaseClient, public IDnsListener, public ILineListener
{
public:
    constexpr static uint64_t kConnectTimeout  = 20 * 1000;  // 20 seconds
    constexpr static uint64_t kResponseTimeout = 20 * 1000;  // 20 seconds
    constexpr static size_t kMaxSendBufferSize = 1024 * 16;  // 16 KB

    Client(int id, const char *agent, IClientListener *listener);

    // Connection management
    void connect() override;
    void connect(const Pool &pool) override;
    bool disconnect() override;
    void tick(uint64_t now) override;

    // Communication
    int64_t send(const rapidjson::Value &obj, Callback callback) override;
    int64_t send(const rapidjson::Value &obj) override;
    int64_t submit(const JobResult &result) override;

    // TLS support
    bool isTLS() const override;
    const char *tlsFingerprint() const override;
    const char *tlsVersion() const override;

private:
    void connect(const sockaddr *addr);
    void handshake();
    void login();
    void parse(char *line, size_t len);
    void parseResponse(int64_t id, const rapidjson::Value &result, const rapidjson::Value &error);
    void ping();
    void reconnect();

    const char *m_agent;                    // User agent string
    LineReader m_reader;                    // Line-based protocol reader
    Socks5 *m_socks5 = nullptr;            // SOCKS5 proxy support
    std::bitset<EXT_MAX> m_extensions;     // Supported extensions
    std::shared_ptr<DnsRequest> m_dns;      // DNS resolution
    std::vector<char> m_sendBuf;           // Send buffer
    Tls *m_tls = nullptr;                  // TLS context
    uint64_t m_expire = 0;                 // Connection timeout
    uint64_t m_jobs = 0;                   // Job counter
    uint64_t m_keepAlive = 0;              // Keep-alive timestamp
    uv_tcp_t *m_socket = nullptr;          // TCP socket
};
```

**File:** `src/base/net/stratum/Client.h`, `src/base/net/stratum/Client.cpp`

### Connection Flow

1. **DNS Resolution**
   ```cpp
   int Client::resolve(const String &host)
   {
       setState(HostLookupState);
       m_dns = Dns::resolve(host, this);
       return 0;
   }
   ```

2. **TCP Connection**
   ```cpp
   void Client::connect(const sockaddr *addr)
   {
       setState(ConnectingState);
       uv_tcp_connect(&req, m_socket, addr, onConnect);
   }
   ```

3. **TLS Handshake** (if enabled)
   ```cpp
   void Client::handshake()
   {
       m_tls = new Tls(m_pool);
       m_tls->handshake();
   }
   ```

4. **Login** (Stratum authentication)
   ```cpp
   void Client::login()
   {
       using namespace rapidjson;
       Document doc(kObjectType);
       // Build login JSON-RPC request
       send(doc);
   }
   ```

**File:** `src/base/net/stratum/Client.cpp`

---

## Pool Configuration

### Pool Class

The `Pool` class (`src/base/net/stratum/Pool.h`) encapsulates all pool connection parameters:

```cpp
class Pool
{
public:
    enum Mode {
        MODE_POOL,          // Standard pool
        MODE_DAEMON,        // Solo mining to daemon
        MODE_SELF_SELECT,   // Self-select (e.g., P2Pool)
        MODE_AUTO_ETH,      // Auto-detect Ethereum pool
        MODE_BENCHMARK      // Benchmark mode
    };

    constexpr static int kKeepAliveTimeout         = 60;      // seconds
    constexpr static uint16_t kDefaultPort         = 3333;
    constexpr static uint64_t kDefaultPollInterval = 1000;    // ms
    constexpr static uint64_t kDefaultJobTimeout   = 15000;   // ms

    Pool(const char *host, uint16_t port, const char *user, const char *password,
         const char* spendSecretKey, int keepAlive, bool nicehash, bool tls, Mode mode);

    inline bool isNicehash() const      { return m_flags.test(FLAG_NICEHASH); }
    inline bool isTLS() const           { return m_flags.test(FLAG_TLS) || m_url.isTLS(); }
    inline const String &host() const   { return m_url.host(); }
    inline const String &user() const   { return !m_user.isNull() ? m_user : kDefaultUser; }
    inline uint16_t port() const        { return m_url.port(); }
    inline Mode mode() const            { return m_mode; }

private:
    Algorithm m_algorithm;              // Algorithm override
    Coin m_coin;                        // Coin type
    Mode m_mode = MODE_POOL;
    ProxyUrl m_proxy;                   // SOCKS5 proxy
    std::bitset<FLAG_MAX> m_flags;
    String m_fingerprint;               // TLS fingerprint
    String m_password;
    String m_rigId;                     // Worker/rig identifier
    String m_user;                      // Wallet address
    Url m_url;                          // Pool URL
    int m_keepAlive = 0;               // Keep-alive interval (seconds)
    int m_zmqPort = -1;                // ZMQ port (for daemon mode)
    uint64_t m_pollInterval = kDefaultPollInterval;
    uint64_t m_jobTimeout = kDefaultJobTimeout;
};
```

**File:** `src/base/net/stratum/Pool.h`

### Pools Collection

The `Pools` class manages multiple pool configurations:

```cpp
class Pools
{
public:
    enum ProxyDonate {
        PROXY_DONATE_NONE,      // No proxy for donations
        PROXY_DONATE_AUTO,      // Auto-detect
        PROXY_DONATE_ALWAYS     // Always use proxy
    };

    Pools();

    inline const std::vector<Pool> &data() const { return m_data; }
    inline int retries() const                   { return m_retries; }
    inline int retryPause() const                { return m_retryPause; }

    int donateLevel() const;                     // Returns donation percentage (0-100)
    IStrategy *createStrategy(IStrategyListener *listener) const;
    size_t active() const;                       // Number of enabled pools

private:
    int m_donateLevel;                          // Default 1%
    int m_retries = 5;                          // Max connection retries
    int m_retryPause = 5;                       // Retry pause (seconds)
    ProxyDonate m_proxyDonate = PROXY_DONATE_AUTO;
    std::vector<Pool> m_data;                   // Pool configurations
};
```

**File:** `src/base/net/stratum/Pools.h`

---

## Strategy Pattern

### IStrategy Interface

The `IStrategy` interface (`src/base/kernel/interfaces/IStrategy.h`) defines pool management strategies:

```cpp
class IStrategy
{
public:
    virtual ~IStrategy() = default;

    virtual bool isActive() const                   = 0;
    virtual IClient *client() const                 = 0;
    virtual int64_t submit(const JobResult &result) = 0;
    virtual void connect()                          = 0;
    virtual void resume()                           = 0;
    virtual void setAlgo(const Algorithm &algo)     = 0;
    virtual void stop()                             = 0;
    virtual void tick(uint64_t now)                 = 0;
};
```

### FailoverStrategy

The `FailoverStrategy` (`src/base/net/stratum/strategies/FailoverStrategy.h`) implements pool failover:

```cpp
class FailoverStrategy : public IStrategy, public IClientListener
{
public:
    FailoverStrategy(const std::vector<Pool> &pool, int retryPause, int retries,
                     IStrategyListener *listener, bool quiet = false);

    void add(const Pool &pool);

protected:
    inline bool isActive() const override    { return m_active >= 0; }
    inline IClient *client() const override  { return isActive() ? active() : m_pools[m_index]; }

    void connect() override;
    void onClose(IClient *client, int failures) override;
    void onJobReceived(IClient *client, const Job &job, const rapidjson::Value &params) override;
    void onLoginSuccess(IClient *client) override;

private:
    inline IClient *active() const { return m_pools[static_cast<size_t>(m_active)]; }

    const bool m_quiet;
    const int m_retries;                    // Max retries per pool
    const int m_retryPause;                 // Retry pause (seconds)
    int m_active = -1;                      // Active client index (-1 = none)
    IStrategyListener *m_listener;
    size_t m_index = 0;                     // Current pool index
    std::vector<IClient*> m_pools;          // Pool clients
};
```

**Failover Logic:**
1. Try to connect to pools in order
2. On connection failure, move to next pool after retry pause
3. On successful connection, set as active
4. If active pool disconnects, try to reconnect or failover
5. If all pools fail after retries, start over

**File:** `src/base/net/stratum/strategies/FailoverStrategy.h`

### DonateStrategy

The `DonateStrategy` (`src/net/strategies/DonateStrategy.h`) manages donation mining periods:

```cpp
class DonateStrategy : public IStrategy, public IStrategyListener,
                       public ITimerListener, public IClientListener
{
public:
    DonateStrategy(Controller *controller, IStrategyListener *listener);

    void update(IClient *client, const Job &job);

protected:
    int64_t submit(const JobResult &result) override;
    void connect() override;
    void tick(uint64_t now) override;

private:
    enum State {
        STATE_NEW,          // Initial state
        STATE_IDLE,         // Waiting for next donation period
        STATE_CONNECT,      // Connecting to donation pool
        STATE_ACTIVE,       // Actively mining for donation
        STATE_WAIT          // Waiting to return to user pool
    };

    void idle(double min, double max);              // Schedule next donation
    void setState(State state);

    State m_state = STATE_NEW;
    const uint64_t m_donateTime;                   // Donation duration
    const uint64_t m_idleTime;                     // Idle duration
    IClient *m_proxy = nullptr;                    // Donation client
    IStrategy *m_strategy = nullptr;               // Donation strategy
    IStrategyListener *m_listener;
    Timer *m_timer = nullptr;
    uint64_t m_timestamp = 0;                      // State change timestamp
};
```

**Donation Logic:**
1. Calculate idle time based on donation level (e.g., 1% = 99 minutes idle)
2. After idle period, connect to donation pool
3. Mine for donation period (e.g., 1 minute for 1%)
4. Disconnect and return to user pools
5. Repeat

**File:** `src/net/strategies/DonateStrategy.h`

---

## Job Structure and Lifecycle

### Job Class

The `Job` class (`src/base/net/stratum/Job.h`) represents a mining job:

```cpp
class Job
{
public:
    // Max blob size is 408 bytes (rounded up for efficient Keccak)
    static constexpr const size_t kMaxBlobSize = 408;
    static constexpr const size_t kMaxSeedSize = 32;

    Job() = default;
    Job(bool nicehash, const Algorithm &algorithm, const String &clientId);

    // Job validation and comparison
    bool isEqual(const Job &other) const;
    bool isValid() const { return (m_size > 0 && m_diff > 0) || !m_poolWallet.isEmpty(); }

    // Blob and target management
    bool setBlob(const char *blob);
    bool setTarget(const char *target);
    bool setSeedHash(const char *hash);

    // Accessors
    inline const Algorithm &algorithm() const    { return m_algorithm; }
    inline const String &id() const              { return m_id; }
    inline const String &clientId() const        { return m_clientId; }
    inline uint64_t diff() const                 { return m_diff; }
    inline uint64_t target() const               { return m_target; }
    inline uint64_t height() const               { return m_height; }
    inline size_t size() const                   { return m_size; }
    inline const uint8_t *blob() const           { return m_blob; }
    inline uint32_t *nonce()                     { return reinterpret_cast<uint32_t*>(m_blob + nonceOffset()); }
    inline size_t nonceSize() const              { return (algorithm().family() == Algorithm::KAWPOW) ? 8 : 4; }
    inline uint64_t nonceMask() const {
        return isNicehash() ? 0xFFFFFFULL :
               (nonceSize() == 8 ? (static_cast<uint64_t>(-1LL) >> (extraNonce().size() * 4)) : 0xFFFFFFFFULL);
    }

    static inline uint64_t toDiff(uint64_t target) { return target ? (0xFFFFFFFFFFFFFFFFULL / target) : 0; }

private:
    Algorithm m_algorithm;
    bool m_nicehash = false;
    Buffer m_seed;                              // RandomX seed hash
    size_t m_size = 0;                          // Blob size
    String m_clientId;                          // Client ID for result routing
    String m_extraNonce;                        // Extra nonce (for NiceHash)
    String m_id;                                // Job ID
    String m_poolWallet;                        // Pool wallet address
    uint32_t m_backend = 0;                     // Backend type flag
    uint64_t m_diff = 0;                        // Difficulty
    uint64_t m_height = 0;                      // Block height
    uint64_t m_target = 0;                      // Target hash value
    uint8_t m_blob[kMaxBlobSize]{ 0 };         // Block template
    uint8_t m_index = 0;                        // Job index (0=normal, 1=donate)
};
```

**File:** `src/base/net/stratum/Job.h`

### Job Lifecycle

```
1. Pool sends job notification
   ↓
2. Client parses JSON and creates Job object
   ↓
3. Network distributes job to workers
   ↓
4. Workers mine job, incrementing nonce
   ↓
5. Worker finds valid hash
   ↓
6. JobResult created and submitted
   ↓
7. Client submits result to pool
   ↓
8. Pool accepts/rejects result
```

### Nonce Management

The nonce is embedded in the blob at a specific offset:

```cpp
size_t Job::nonceOffset() const
{
    switch (algorithm().family()) {
        case Algorithm::RANDOM_X:
        case Algorithm::CN:
            return 39;  // CryptoNote nonce offset

        case Algorithm::KAWPOW:
            return 32;  // KawPow nonce offset after header hash

        default:
            return 39;
    }
}
```

**NiceHash Mode:**
- NiceHash pools require specific nonce handling
- Only lower 24 bits of nonce can be modified
- Upper bits reserved for pool's extra nonce

```cpp
uint64_t nonceMask = isNicehash() ? 0xFFFFFFULL : 0xFFFFFFFFULL;
```

**File:** `src/base/net/stratum/Job.h`

---

## Result Submission System

### JobResult Structure

The `JobResult` class (`src/net/JobResult.h`) encapsulates a mining result:

```cpp
class JobResult
{
public:
    inline JobResult(const Job &job, uint64_t nonce, const uint8_t *result,
                     const uint8_t* header_hash = nullptr,
                     const uint8_t *mix_hash = nullptr,
                     const uint8_t* miner_signature = nullptr) :
        algorithm(job.algorithm()),
        index(job.index()),
        clientId(job.clientId()),
        jobId(job.id()),
        backend(job.backend()),
        nonce(nonce),
        diff(job.diff())
    {
        memcpy(m_result, result, sizeof(m_result));

        if (header_hash) memcpy(m_headerHash, header_hash, sizeof(m_headerHash));
        if (mix_hash) memcpy(m_mixHash, mix_hash, sizeof(m_mixHash));
        if (miner_signature) {
            m_hasMinerSignature = true;
            memcpy(m_minerSignature, miner_signature, sizeof(m_minerSignature));
        }
    }

    inline const uint8_t *result() const     { return m_result; }
    inline uint64_t actualDiff() const       { return Job::toDiff(reinterpret_cast<const uint64_t*>(m_result)[3]); }
    inline const uint8_t *minerSignature() const { return m_hasMinerSignature ? m_minerSignature : nullptr; }

    const Algorithm algorithm;
    const uint8_t index;                     // 0=normal, 1=donate
    const String clientId;                   // Client ID for routing
    const String jobId;                      // Job ID
    const uint32_t backend;                  // Backend type
    const uint64_t nonce;                    // Nonce that produced result
    const uint64_t diff;                     // Job difficulty

private:
    uint8_t m_result[32] = { 0 };           // Hash result
    uint8_t m_headerHash[32] = { 0 };       // Header hash (KawPow)
    uint8_t m_mixHash[32] = { 0 };          // Mix hash (KawPow)
    uint8_t m_minerSignature[64] = { 0 };   // Miner signature (P2Pool)
    bool m_hasMinerSignature = false;
};
```

**File:** `src/net/JobResult.h`

### JobResults - Static Submission Interface

The `JobResults` class (`src/net/JobResults.h/cpp`) provides a static interface for result submission:

```cpp
class JobResults
{
public:
    static void setListener(IJobResultListener *listener, bool hwAES);
    static void stop();

    // Submit from CPU worker
    static void submit(const Job &job, uint32_t nonce, const uint8_t *result);
    static void submit(const Job& job, uint32_t nonce, const uint8_t* result, const uint8_t* miner_signature);
    static void submit(const JobResult &result);

    // Submit from GPU worker (batch submission)
    #if defined(XMRIG_FEATURE_OPENCL) || defined(XMRIG_FEATURE_CUDA)
    static void submit(const Job &job, uint32_t *results, size_t count, uint32_t device_index);
    #endif
};
```

**File:** `src/net/JobResults.h`

### Async Result Handling

Results from workers are handled asynchronously using libuv:

```cpp
class JobResultsPrivate : public IAsyncListener
{
public:
    inline void submit(const JobResult &result)
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        m_results.push_back(result);
        m_async->send();  // Trigger async callback
    }

protected:
    inline void onAsync() override { submit(); }

private:
    inline void submit()
    {
        std::list<JobResult> results;

        m_mutex.lock();
        m_results.swap(results);  // Lock-free swap
        m_mutex.unlock();

        // Forward to listener (Network class)
        for (const auto &result : results) {
            m_listener->onJobResult(result);
        }
    }

    IJobResultListener *m_listener;     // Network class
    std::list<JobResult> m_results;
    std::mutex m_mutex;
    std::shared_ptr<Async> m_async;
};
```

**File:** `src/net/JobResults.cpp:198-292`

### GPU Result Verification

GPU-submitted results are verified asynchronously in a worker thread:

```cpp
void JobResults::submit(const Job &job, uint32_t *results, size_t count, uint32_t device_index)
{
    // Queue GPU results
    std::lock_guard<std::mutex> lock(m_mutex);
    m_bundles.emplace_back(job, results, count, device_index);
    m_async->send();
}

// In async handler:
uv_queue_work(uv_default_loop(), &baton->req,
    [](uv_work_t *req) {
        // Worker thread: verify each GPU result
        auto baton = static_cast<JobBaton*>(req->data);
        for (JobBundle &bundle : baton->bundles) {
            getResults(bundle, baton->results, baton->errors, baton->hwAES);
        }
    },
    [](uv_work_t *req, int) {
        // Main thread: submit verified results
        auto baton = static_cast<JobBaton*>(req->data);
        for (const auto &result : baton->results) {
            baton->listener->onJobResult(result);
        }
        delete baton;
    }
);
```

**Why GPU verification is needed:**
- GPU results may be incorrect due to hardware errors
- Re-hashing in CPU confirms validity before submission
- Prevents wasting bandwidth on invalid shares
- Detects GPU compute errors early

**File:** `src/net/JobResults.cpp:224-278`

---

## Stratum Protocol Implementation

### Protocol Basics

Stratum is a line-based JSON-RPC protocol used by most mining pools:

```json
// Pool sends job notification
{
  "jsonrpc": "2.0",
  "method": "job",
  "params": {
    "id": "1234567890abcdef",
    "job_id": "job123",
    "blob": "0606...",
    "target": "b88d0600",
    "algo": "rx/0",
    "height": 123456,
    "seed_hash": "abcd..."
  }
}

// Miner submits result
{
  "id": 1,
  "jsonrpc": "2.0",
  "method": "submit",
  "params": {
    "id": "1234567890abcdef",
    "job_id": "job123",
    "nonce": "12345678",
    "result": "0123456789abcdef..."
  }
}

// Pool responds
{
  "id": 1,
  "jsonrpc": "2.0",
  "result": {
    "status": "OK"
  },
  "error": null
}
```

### JSON-RPC Send/Receive

```cpp
int64_t Client::send(const rapidjson::Value &obj)
{
    using namespace rapidjson;

    // Serialize JSON to string
    StringBuffer buffer(nullptr, 512);
    Writer<StringBuffer> writer(buffer);
    obj.Accept(writer);

    const size_t size = buffer.GetSize();
    if (size > kMaxSendBufferSize) {
        LOG_ERR("send failed: max send buffer size exceeded");
        close();
        return -1;
    }

    // Copy to send buffer with newline
    memcpy(m_sendBuf.data(), buffer.GetString(), size);
    m_sendBuf[size] = '\n';
    m_sendBuf[size + 1] = '\0';

    return send(size + 1);
}
```

**File:** `src/base/net/stratum/Client.cpp:150-175`

### Line-Based Parsing

The `LineReader` class handles line-based protocol parsing:

```cpp
class LineReader
{
public:
    void parse(const char *data, size_t size);
    void setListener(ILineListener *listener);

private:
    void getline(char *line, size_t size);

    ILineListener *m_listener;
    std::vector<char> m_buf;
};

// Client implements ILineListener
void Client::onLine(char *line, size_t size) override
{
    parse(line, size);
}

void Client::parse(char *line, size_t len)
{
    // Parse JSON-RPC message
    using namespace rapidjson;
    Document doc;
    if (doc.ParseInsitu(line).HasParseError()) {
        LOG_ERR("JSON parse error");
        return;
    }

    // Handle method (notification) or response
    if (doc.HasMember("method")) {
        parseNotification(doc["method"].GetString(), doc["params"], doc["error"]);
    } else {
        parseResponse(doc["id"].GetInt64(), doc["result"], doc["error"]);
    }
}
```

**File:** `src/base/net/stratum/Client.cpp`

### Submit Result to Pool

```cpp
int64_t Client::submit(const JobResult &result)
{
    // Validate result
    if (result.clientId != m_rpcId || m_state != ConnectedState) {
        return -1;
    }

    // Convert binary to hex
    char *nonce = m_tempBuf.data();
    char *data  = m_tempBuf.data() + 16;
    Cvt::toHex(nonce, 8, reinterpret_cast<const uint8_t*>(&result.nonce), 4);
    Cvt::toHex(data, 64, result.result(), 32);

    // Build JSON-RPC submit request
    using namespace rapidjson;
    Document doc(kObjectType);
    auto &allocator = doc.GetAllocator();

    Value params(kObjectType);
    params.AddMember("id",     m_rpcId.toJSON(), allocator);
    params.AddMember("job_id", result.jobId.toJSON(), allocator);
    params.AddMember("nonce",  StringRef(nonce), allocator);
    params.AddMember("result", StringRef(data), allocator);

    // Add algorithm-specific fields
    if (result.algorithm.family() == Algorithm::KAWPOW) {
        // KawPow requires header_hash and mix_hash
        char header_hash[65];
        char mix_hash[65];
        Cvt::toHex(header_hash, 65, result.headerHash(), 32);
        Cvt::toHex(mix_hash, 65, result.mixHash(), 32);
        params.AddMember("header_hash", StringRef(header_hash), allocator);
        params.AddMember("mix_hash", StringRef(mix_hash), allocator);
    }

    JsonRequest::create(doc, m_sequence, "submit", params);

    // Track pending result
    m_results[m_sequence] = SubmitResult(m_sequence, result.diff, result.actualDiff(), m_sequence, result.backend);

    return send(doc);
}
```

**File:** `src/base/net/stratum/Client.cpp:178-240`

### Login/Authentication

```cpp
void Client::login()
{
    using namespace rapidjson;
    Document doc(kObjectType);
    auto &allocator = doc.GetAllocator();

    Value params(kObjectType);
    params.AddMember("login", m_user.toJSON(), allocator);
    params.AddMember("pass",  m_password.toJSON(), allocator);
    params.AddMember("agent", StringRef(m_agent), allocator);

    // Add rig ID if configured
    if (!m_rigId.isNull()) {
        params.AddMember("rigid", m_rigId.toJSON(), allocator);
    }

    // Add supported algorithms
    Value algo(kArrayType);
    for (const Algorithm &a : algorithms) {
        algo.PushBack(StringRef(a.name()), allocator);
    }
    params.AddMember("algo", algo, allocator);

    JsonRequest::create(doc, m_sequence, "login", params);

    send(doc, [this](const rapidjson::Value &result, bool success, uint64_t elapsed) {
        if (!success) {
            close();
            return;
        }

        // Parse login response
        int code = -1;
        if (parseLogin(result, &code)) {
            m_listener->onLoginSuccess(this);
        } else {
            close();
        }
    });
}
```

**File:** `src/base/net/stratum/Client.cpp`

### Extension Detection

Stratum supports various extensions detected via login response:

```cpp
void Client::parseExtensions(const rapidjson::Value &result)
{
    if (result.HasMember("extensions")) {
        const Value &extensions = result["extensions"];

        for (const auto &ext : extensions.GetArray()) {
            const String name = ext.GetString();

            if (name == "algo") {
                setExtension(EXT_ALGO, true);
            }
            else if (name == "nicehash") {
                setExtension(EXT_NICEHASH, true);
            }
            else if (name == "keepalive") {
                setExtension(EXT_KEEPALIVE, true);
            }
        }
    }
}
```

**File:** `src/base/net/stratum/Client.cpp`

---

## Connection Management

### DNS Resolution

DNS resolution is handled asynchronously via libuv:

```cpp
int Client::resolve(const String &host)
{
    setState(HostLookupState);

    m_dns = Dns::resolve(host, this);
    if (!m_dns) {
        return -1;
    }

    startTimeout();  // Start connection timeout
    return 0;
}

// DNS callback
void Client::onResolved(const DnsRecords &records, int status, const char *error)
{
    if (status < 0) {
        LOG_ERR("DNS error: %s", error);
        reconnect();
        return;
    }

    // Connect to first resolved address
    const auto &record = records[0];
    connect(record.addr());
}
```

**File:** `src/base/net/stratum/Client.cpp`

### TLS Support

TLS connections are supported via OpenSSL:

```cpp
#ifdef XMRIG_FEATURE_TLS
class Client::Tls
{
public:
    Tls(const Pool &pool);
    ~Tls();

    bool handshake();
    bool send(const char *data, size_t size);
    bool read(char *data, size_t size);
    const char *fingerprint() const;
    const char *version() const;

private:
    SSL *m_ssl;
    SSL_CTX *m_ctx;
    BIO *m_readBio;
    BIO *m_writeBio;
    String m_fingerprint;
};

void Client::handshake()
{
    if (m_pool.isTLS()) {
        m_tls = new Tls(m_pool);
        if (!m_tls->handshake()) {
            close();
            return;
        }
    }

    login();
}
#endif
```

**File:** `src/base/net/stratum/Client.cpp`

### SOCKS5 Proxy Support

SOCKS5 proxy support for pools behind firewalls:

```cpp
class Client::Socks5
{
public:
    Socks5(Client *client, const String &host, uint16_t port);

    bool connect();
    bool read(const char *data, size_t size);

private:
    enum State {
        MethodSelectionSent,
        MethodSelectionReceived,
        ConnectRequestSent,
        ConnectRequestReceived,
        Connected
    };

    Client *m_client;
    State m_state;
    String m_host;
    uint16_t m_port;
};
```

**File:** `src/base/net/stratum/Socks5.h`

### Connection Timeouts

Timeouts are managed via periodic tick:

```cpp
void Client::tick(uint64_t now)
{
    // Check connection timeout
    if (m_expire && now > m_expire) {
        LOG_ERR("connect timeout");
        close();
        return;
    }

    // Check response timeout
    for (auto it = m_callbacks.begin(); it != m_callbacks.end();) {
        if (now - it->second.ts > kResponseTimeout) {
            LOG_WARN("response timeout for request %lld", it->first);
            it = m_callbacks.erase(it);
        } else {
            ++it;
        }
    }

    // Send keep-alive ping
    if (m_keepAlive && now > m_keepAlive) {
        ping();
        m_keepAlive = now + (has<EXT_KEEPALIVE>() ? m_pool.keepAlive() * 1000 : 60000);
    }
}
```

**File:** `src/base/net/stratum/Client.cpp`

### Reconnection Logic

```cpp
void Client::reconnect()
{
    setState(ReconnectingState);

    // Close current connection
    close();

    // Increment failure counter
    m_failures++;

    // Calculate retry delay with exponential backoff
    uint64_t delay = m_retryPause * 1000;
    if (m_failures > 1) {
        delay *= m_failures;  // Exponential backoff
    }

    // Schedule reconnection
    m_expire = Chrono::steadyMSecs() + delay;
}
```

**File:** `src/base/net/stratum/Client.cpp`

---

## Network State Tracking

### NetworkState Class

The `NetworkState` class (`src/base/net/stratum/NetworkState.h`) tracks connection statistics:

```cpp
class NetworkState : public StrategyProxy
{
public:
    NetworkState(IStrategyListener *listener);

    inline const Algorithm &algorithm() const   { return m_algorithm; }
    inline uint64_t accepted() const            { return m_accepted; }
    inline uint64_t rejected() const            { return m_rejected; }

    void printConnection() const;
    void printResults() const;

protected:
    void onActive(IStrategy *strategy, IClient *client) override;
    void onJob(IStrategy *strategy, IClient *client, const Job &job, const rapidjson::Value &params) override;
    void onResultAccepted(IStrategy *strategy, IClient *client, const SubmitResult &result, const char *error) override;

private:
    void add(const SubmitResult &result, const char *error);

    Algorithm m_algorithm;
    bool m_active = false;
    char m_pool[256]{};
    std::array<uint64_t, 10> m_topDiff { { } };  // Top 10 difficulties
    std::vector<uint16_t> m_latency;             // Latency samples
    String m_fingerprint;
    String m_ip;
    String m_tls;
    uint64_t m_accepted = 0;                     // Accepted shares
    uint64_t m_connectionTime = 0;               // Connection timestamp
    uint64_t m_diff = 0;                         // Current difficulty
    uint64_t m_failures = 0;                     // Failed shares
    uint64_t m_hashes = 0;                       // Total hashes submitted
    uint64_t m_rejected = 0;                     // Rejected shares
};
```

**File:** `src/base/net/stratum/NetworkState.h`

### Statistics Tracking

```cpp
void NetworkState::add(const SubmitResult &result, const char *error)
{
    if (error) {
        m_rejected++;
        return;
    }

    m_accepted++;
    m_hashes += result.diff;

    // Track latency
    m_latency.push_back(static_cast<uint16_t>(result.elapsed));
    if (m_latency.size() > 100) {
        m_latency.erase(m_latency.begin());
    }

    // Track top difficulties
    const uint64_t diff = result.actualDiff;
    for (size_t i = 0; i < m_topDiff.size(); i++) {
        if (diff > m_topDiff[i]) {
            std::rotate(m_topDiff.begin() + i, m_topDiff.end() - 1, m_topDiff.end());
            m_topDiff[i] = diff;
            break;
        }
    }
}
```

### SubmitResult Tracking

```cpp
class SubmitResult
{
public:
    inline SubmitResult(int64_t seq, uint64_t diff, uint64_t actualDiff, int64_t reqId, uint32_t backend) :
        reqId(reqId),
        seq(seq),
        backend(backend),
        actualDiff(actualDiff),
        diff(diff),
        m_start(Chrono::steadyMSecs())
    {}

    inline void done() { elapsed = Chrono::steadyMSecs() - m_start; }

    int64_t reqId = 0;          // JSON-RPC request ID
    int64_t seq = 0;            // Sequence number
    uint32_t backend = 0;       // Backend type
    uint64_t actualDiff = 0;    // Actual difficulty of hash
    uint64_t diff = 0;          // Job difficulty
    uint64_t elapsed = 0;       // Response time (ms)

private:
    uint64_t m_start = 0;       // Submission timestamp
};
```

**File:** `src/base/net/stratum/SubmitResult.h`

---

## Optimization Opportunities

### 1. Connection Pooling

**Current:** Each pool connection creates new sockets/TLS contexts

**Opportunity:** Implement connection pooling for frequently reconnected pools
```cpp
class ConnectionPool {
    std::map<String, std::vector<uv_tcp_t*>> m_idle;
    uv_tcp_t* acquire(const String &host, uint16_t port);
    void release(uv_tcp_t *socket);
};
```

**Benefit:** Faster reconnection, reduced TLS handshake overhead

**Estimated Impact:** 10-20% faster reconnection times

### 2. Batch Result Submission

**Current:** Results submitted one at a time

**Opportunity:** Batch multiple results in single JSON-RPC message
```json
{
  "method": "submit",
  "params": {
    "results": [
      {"job_id": "...", "nonce": "...", "result": "..."},
      {"job_id": "...", "nonce": "...", "result": "..."}
    ]
  }
}
```

**Benefit:** Reduced network overhead, better latency for high hashrate miners

**Estimated Impact:** 5-10% reduction in network traffic for multi-GPU setups

### 3. Protocol Compression

**Current:** Plain JSON over TCP

**Opportunity:** Add optional zlib/gzip compression for Stratum messages
```cpp
class CompressedClient : public Client {
    z_stream m_deflate;
    z_stream m_inflate;
    bool compress(const char *in, size_t in_len, char *out, size_t *out_len);
    bool decompress(const char *in, size_t in_len, char *out, size_t *out_len);
};
```

**Benefit:** Reduced bandwidth usage (JSON is highly compressible)

**Estimated Impact:** 60-70% reduction in bandwidth for job notifications

**File Reference:** Would extend `src/base/net/stratum/Client.cpp`

### 4. Smart Failover Prediction

**Current:** Failover only on connection loss

**Opportunity:** Predict connection issues and preemptively failover
```cpp
class PredictiveFailover {
    // Track metrics
    std::deque<uint64_t> m_latencies;
    uint64_t m_avgLatency;
    uint64_t m_stdDevLatency;

    bool shouldFailover() {
        // Failover if latency > avg + 3*stddev
        return currentLatency > (m_avgLatency + 3 * m_stdDevLatency);
    }
};
```

**Benefit:** Reduced downtime from degrading connections

**Estimated Impact:** 2-5% reduction in stale shares

### 5. Job Prefetching

**Current:** Wait for new job notification

**Opportunity:** Request next job template in advance
```cpp
void Client::prefetchNextJob() {
    // Send getblocktemplate request before current job completes
    send(JsonRequest::create("getblocktemplate"));
}
```

**Benefit:** Reduced job switch latency

**Estimated Impact:** 1-2% reduction in stale shares

### 6. Result Caching for Pool Switching

**Current:** Discard pending results on pool switch

**Opportunity:** Cache results and resubmit to new pool if compatible
```cpp
class ResultCache {
    std::vector<JobResult> m_pending;

    void onPoolSwitch(IClient *oldPool, IClient *newPool) {
        // Resubmit compatible results
        for (const auto &result : m_pending) {
            if (isCompatible(result, newPool)) {
                newPool->submit(result);
            }
        }
    }
};
```

**Benefit:** No lost work during pool switches

**Estimated Impact:** 0.5-1% hashrate improvement during failover

### 7. DNS Result Caching

**Current:** DNS lookup on every connection

**Opportunity:** Cache DNS results with TTL
```cpp
class DnsCache {
    struct Entry {
        DnsRecords records;
        uint64_t expiry;
    };
    std::map<String, Entry> m_cache;

    const DnsRecords* lookup(const String &host) {
        auto it = m_cache.find(host);
        if (it != m_cache.end() && it->second.expiry > now()) {
            return &it->second.records;
        }
        return nullptr;
    }
};
```

**Benefit:** Faster reconnection, reduced DNS load

**Estimated Impact:** 5-10% faster reconnection

**File Reference:** Would extend `src/base/net/dns/Dns.cpp`

### 8. Adaptive Keep-Alive

**Current:** Fixed keep-alive interval

**Opportunity:** Dynamically adjust based on pool behavior
```cpp
class AdaptiveKeepAlive {
    uint64_t m_interval = 60000;  // Start at 60s

    void onPong(uint64_t latency) {
        if (latency < 100) {
            m_interval = std::min(m_interval + 5000, 120000);  // Increase
        } else {
            m_interval = std::max(m_interval - 5000, 30000);   // Decrease
        }
    }
};
```

**Benefit:** Reduced keep-alive traffic, better connection reliability

**Estimated Impact:** 10-20% reduction in keep-alive overhead

### 9. Parallel Pool Testing

**Current:** Test pools sequentially during failover

**Opportunity:** Test multiple pools in parallel
```cpp
void FailoverStrategy::connect() {
    // Start connections to multiple pools
    for (size_t i = 0; i < std::min(m_pools.size(), 3); i++) {
        m_pools[i]->connect();
    }

    // Use first successful connection
}
```

**Benefit:** Faster failover recovery

**Estimated Impact:** 50-70% faster failover (seconds vs minutes)

### 10. Protocol-Level Job Validation

**Current:** Workers may mine invalid jobs

**Opportunity:** Validate jobs before distribution
```cpp
bool Job::validate() const {
    // Check blob size
    if (m_size == 0 || m_size > kMaxBlobSize) return false;

    // Check difficulty
    if (m_diff == 0) return false;

    // Validate blob structure
    if (!validateBlobStructure()) return false;

    // Check algorithm compatibility
    if (!algorithm().isValid()) return false;

    return true;
}
```

**Benefit:** Prevent wasted work on invalid jobs

**Estimated Impact:** Prevents rare but costly invalid job scenarios

**File Reference:** `src/base/net/stratum/Job.h`

---

## Code References

### Primary Files

| File | Lines | Purpose |
|------|-------|---------|
| `src/net/Network.h` | 95 | Main network coordinator class |
| `src/net/Network.cpp` | ~300 | Network implementation |
| `src/base/net/stratum/Client.h` | 156 | Stratum client interface |
| `src/base/net/stratum/Client.cpp` | ~1500 | Stratum protocol implementation |
| `src/base/net/stratum/Pool.h` | 180 | Pool configuration |
| `src/base/net/stratum/Job.h` | 201 | Mining job structure |
| `src/net/JobResult.h` | 112 | Mining result structure |
| `src/net/JobResults.h` | 62 | Result submission interface |
| `src/net/JobResults.cpp` | 366 | Async result handling |
| `src/base/net/stratum/FailoverStrategy.h` | 85 | Pool failover logic |
| `src/net/strategies/DonateStrategy.h` | 118 | Donation mining logic |
| `src/base/net/stratum/NetworkState.h` | 90 | Statistics tracking |

### Interface Files

| File | Purpose |
|------|---------|
| `src/base/kernel/interfaces/IClient.h` | Client interface |
| `src/base/kernel/interfaces/IStrategy.h` | Strategy interface |
| `src/base/kernel/interfaces/IClientListener.h` | Client event callbacks |
| `src/base/kernel/interfaces/IStrategyListener.h` | Strategy event callbacks |
| `src/net/interfaces/IJobResultListener.h` | Result callback interface |

### Supporting Files

| File | Purpose |
|------|---------|
| `src/base/net/stratum/Pools.h` | Pool collection management |
| `src/base/net/stratum/SubmitResult.h` | Result submission tracking |
| `src/base/net/stratum/BaseClient.h` | Common client functionality |
| `src/base/net/stratum/Tls.h` | TLS connection support |
| `src/base/net/stratum/Socks5.h` | SOCKS5 proxy support |
| `src/base/net/dns/Dns.h` | Async DNS resolution |
| `src/base/net/tools/LineReader.h` | Line-based protocol parsing |

---

## Summary

The network layer of X provides a robust, extensible architecture for pool communication:

**Strengths:**
- Clean separation of concerns (Network → Strategy → Client)
- Flexible strategy pattern for pool management
- Async I/O throughout (libuv-based)
- Comprehensive error handling and retry logic
- Support for multiple pool modes (standard, daemon, self-select)
- TLS and SOCKS5 proxy support
- Donation system integrated at architecture level

**Performance Characteristics:**
- Low-latency result submission via async queue
- Efficient JSON-RPC implementation
- Connection pooling via failover strategy
- Minimal overhead in hot paths (result submission)

**Architecture Decisions:**
1. **Static JobResults interface** - Allows workers to submit without network dependencies
2. **Strategy pattern** - Enables different pool management policies
3. **Async result verification** - GPU results verified in worker threads
4. **Line-based protocol** - Simple, debuggable, standard Stratum

**Identified Optimizations:**
The 10 optimization opportunities range from simple (DNS caching) to complex (protocol compression), with potential improvements of 5-20% in various metrics (latency, bandwidth, failover time).

---

**Last Updated:** 2025-12-02
**Author:** Claude (AI Assistant)
**Review Status:** Initial technical analysis
