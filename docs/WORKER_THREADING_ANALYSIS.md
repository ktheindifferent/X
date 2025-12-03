# Worker and Threading Architecture Analysis

## Overview

This document provides a comprehensive analysis of the worker and threading architecture in X miner, including the backend system, worker lifecycle, thread management, and job processing pipeline.

**Analysis Date**: 2025-12-02
**X Version**: 1.0.0 (based on XMRIG 6.24.0)
**Analyst**: Development Team

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Class Hierarchy](#class-hierarchy)
3. [Backend System](#backend-system)
4. [Worker Lifecycle](#worker-lifecycle)
5. [Thread Management](#thread-management)
6. [Job Processing Pipeline](#job-processing-pipeline)
7. [CPU Worker Implementation](#cpu-worker-implementation)
8. [Synchronization and Concurrency](#synchronization-and-concurrency)
9. [Performance Considerations](#performance-considerations)
10. [Optimization Opportunities](#optimization-opportunities)

---

## Architecture Overview

X miner uses a multi-threaded architecture where:
- **Backend**: Manages worker lifecycle and job distribution
- **Workers**: Execute mining algorithms in separate threads
- **Threads**: Wrapper around OS threads with affinity support
- **Job Queue**: Distributes work to workers

```
Application Flow
├── Controller
│   └── Miner
│       └── Backends (CPU, OpenCL, CUDA)
│           └── Workers
│               └── Threads (OS threads)
│                   └── Worker::start() (mining loop)
```

**Key Components**:
- **IWorker**: Worker interface
- **Worker**: Base worker implementation
- **CpuWorker<N>**: CPU worker (template for intensity)
- **GpuWorker**: Base GPU worker
- **Workers<T>**: Worker pool manager
- **Thread<T>**: Thread wrapper with affinity

**Code References**:
- `src/backend/common/interfaces/IWorker.h` - Worker interface
- `src/backend/common/Worker.h` - Base worker
- `src/backend/cpu/CpuWorker.h` - CPU worker
- `src/backend/common/Workers.h` - Worker manager
- `src/backend/common/Thread.h` - Thread wrapper

---

## Class Hierarchy

### Worker Hierarchy

```cpp
IWorker (interface)
├── Worker (base implementation)
    ├── CpuWorker<N> (CPU mining)
    │   ├── CpuWorker<1> (intensity 1)
    │   ├── CpuWorker<2> (intensity 2)
    │   ├── CpuWorker<3> (intensity 3)
    │   ├── CpuWorker<4> (intensity 4)
    │   ├── CpuWorker<5> (intensity 5)
    │   └── CpuWorker<8> (intensity 8)
    └── GpuWorker (GPU base)
        ├── OclWorker (AMD OpenCL)
        └── CudaWorker (NVIDIA CUDA)
```

**Code Reference**: `src/backend/cpu/CpuWorker.h:46-122`

### IWorker Interface

```cpp
class IWorker {
public:
    virtual bool selfTest() = 0;
    virtual const VirtualMemory *memory() const = 0;
    virtual size_t id() const = 0;
    virtual size_t intensity() const = 0;
    virtual size_t threads() const = 0;
    virtual void hashrateData(...) const = 0;
    virtual void jobEarlyNotification(const Job &job) = 0;
    virtual void start() = 0;
};
```

**Methods**:
- `selfTest()` - Verify algorithm implementation correctness
- `memory()` - Get worker's memory allocation
- `id()` - Get worker ID (0-based index)
- `intensity()` - Get hash intensity (N for CpuWorker<N>)
- `threads()` - Get thread count (usually 1, 2 for GhostRider)
- `hashrateData()` - Get hashrate statistics
- `jobEarlyNotification()` - Early notification of new job
- `start()` - Main mining loop (blocking)

**Code Reference**: `src/backend/common/interfaces/IWorker.h:37-53`

### Worker Base Class

```cpp
class Worker : public IWorker {
public:
    Worker(size_t id, int64_t affinity, int priority);
    size_t threads() const override { return 1; }

protected:
    int64_t affinity() const { return m_affinity; }
    size_t id() const override { return m_id; }
    uint32_t node() const { return m_node; }

    uint64_t m_count = 0;  // Hash count

private:
    const int64_t m_affinity;  // CPU affinity (-1 = no affinity)
    const size_t m_id;         // Worker ID
    uint32_t m_node = 0;       // NUMA node
};
```

**Purpose**: Base implementation providing common worker functionality

**Key Features**:
- CPU affinity support
- NUMA node awareness
- Hash count tracking

**Code Reference**: `src/backend/common/Worker.h:29-48`

---

## Backend System

### IBackend Interface

Backends manage workers for different mining hardware types:
- **CpuBackend** - CPU mining
- **OclBackend** - AMD GPU mining (OpenCL)
- **CudaBackend** - NVIDIA GPU mining (CUDA)

**Key Methods**:
```cpp
class IBackend {
public:
    virtual bool isEnabled() const = 0;
    virtual bool tick(uint64_t ticks) = 0;
    virtual const Hashrate *hashrate() const = 0;
    virtual void prepare(const Job &nextJob) = 0;
    virtual void setJob(const Job &job) = 0;
    virtual void start(IWorker *worker, bool ready) = 0;
    virtual void stop() = 0;
};
```

**Backend Lifecycle**:
1. `prepare()` - Prepare for new job (e.g., dataset initialization)
2. `start()` - Start workers
3. `setJob()` - Distribute new job to workers
4. `tick()` - Periodic update (hashrate calculation)
5. `stop()` - Stop all workers

**Code Reference**: `src/backend/common/interfaces/IBackend.h`

### CpuBackend

**Location**: `src/backend/cpu/CpuBackend.{h,cpp}`

**Responsibilities**:
- Create CpuWorker instances
- Manage CPU worker pool
- Handle job distribution
- Collect hashrate statistics
- Manage RandomX dataset/cache

**Configuration**:
- Thread count (based on CPU cores/L3 cache)
- CPU affinity (bind threads to specific cores)
- Priority (thread scheduling priority)
- Huge pages support
- Assembly optimizations

**Code Reference**: `src/backend/cpu/CpuBackend.h:38-74`

---

## Worker Lifecycle

### Worker Creation and Initialization

**Step 1: Worker Creation**

```cpp
// Workers<T>::create() creates appropriate worker type
template<>
IWorker *Workers<CpuLaunchData>::create(Thread<CpuLaunchData> *handle)
{
    // Instantiate CpuWorker<N> based on intensity
    switch (handle->config().intensity) {
        case 1: return new CpuWorker<1>(handle->id(), handle->config());
        case 2: return new CpuWorker<2>(handle->id(), handle->config());
        case 3: return new CpuWorker<3>(handle->id(), handle->config());
        case 4: return new CpuWorker<4>(handle->id(), handle->config());
        case 5: return new CpuWorker<5>(handle->id(), handle->config());
        case 8: return new CpuWorker<8>(handle->id(), handle->config());
    }
}
```

**Code Reference**: `src/backend/common/Workers.cpp` (template specialization)

**Step 2: Worker Initialization (CpuWorker Constructor)**

```cpp
template<size_t N>
CpuWorker<N>::CpuWorker(size_t id, const CpuLaunchData &data) :
    Worker(id, data.affinity, data.priority),
    m_algorithm(data.algorithm),
    m_assembly(data.assembly),
    m_hwAES(data.hwAES),
    m_yield(data.yield),
    m_miner(data.miner),
    m_threads(data.threads)
{
    // Allocate memory (scratchpad, etc.)
    m_memory = new VirtualMemory(
        m_algorithm.l3() * N,  // Size (e.g., 2MB * intensity)
        data.hugePages,        // Use huge pages
        false,                 // Not 1GB pages
        true,                  // Use memory pool
        node()                 // NUMA node
    );

    // Initialize algorithm-specific resources
    // (e.g., GhostRider helper thread)
}
```

**Memory Allocation**:
- **Size**: Algorithm L3 requirement × intensity
  - RandomX: 2MB × N
  - CryptoNight: 2MB × N
  - GhostRider: Variable
- **Huge Pages**: Preferred for performance
- **Memory Pool**: Allocate from shared pool
- **NUMA**: Bind to appropriate NUMA node

**Code Reference**: `src/backend/cpu/CpuWorker.cpp:68-103`

**Step 3: Self Test**

Before mining starts, worker runs self-test:

```cpp
bool CpuWorker<N>::selfTest()
{
    // Test algorithm implementations against known outputs
    // RandomX: N must be 1
    // GhostRider: N must be 8
    // CryptoNight: Test all variants

    return verify(Algorithm::CN_0, test_output_v0) &&
           verify(Algorithm::CN_1, test_output_v1) &&
           // ... more tests
}
```

**Purpose**: Ensure algorithm implementation is correct before mining

**Code Reference**: `src/backend/cpu/CpuWorker.cpp:159-235`

### Worker Destruction

```cpp
template<size_t N>
CpuWorker<N>::~CpuWorker()
{
    // Destroy RandomX VM
    RxVm::destroy(m_vm);

    // Release CryptoNight context
    CnCtx::release(m_ctx, N);

    // Free memory (unless shared cn_heavyZen3Memory)
    delete m_memory;

    // Destroy GhostRider helper thread
    ghostrider::destroy_helper_thread(m_ghHelper);
}
```

**Code Reference**: `src/backend/cpu/CpuWorker.cpp:107-125`

---

## Thread Management

### Thread<T> Wrapper

**Purpose**: Wraps OS threads with additional features:
- CPU affinity support
- Thread priority
- Worker lifecycle management

```cpp
template<class T>
class Thread {
public:
    Thread(IBackend *backend, size_t id, const T &config);
    ~Thread();  // Joins thread, deletes worker

    void start(void *(*callback)(void *));
    void setWorker(IWorker *worker);

    IWorker *worker() const;
    size_t id() const;
    const T &config() const;

private:
    const size_t m_id;
    const T m_config;
    IBackend *m_backend;
    IWorker *m_worker = nullptr;

#ifdef XMRIG_OS_APPLE
    pthread_t m_thread;
#else
    std::thread m_thread;
#endif
};
```

**Code Reference**: `src/backend/common/Thread.h:42-91`

### CPU Affinity

**Purpose**: Bind thread to specific CPU cores for better cache locality

**Linux/Windows**:
```cpp
void start(void *(*callback)(void *)) {
    m_thread = std::thread(callback, this);
    // Affinity set in callback via platform-specific API
}
```

**macOS** (special handling):
```cpp
void start(void *(*callback)(void *)) {
    if (m_config.affinity >= 0) {
        // Create thread in suspended state
        pthread_create_suspended_np(&m_thread, nullptr, callback, this);

        // Set affinity policy
        mach_port_t mach_thread = pthread_mach_thread_np(m_thread);
        thread_affinity_policy_data_t policy = {
            static_cast<integer_t>(m_config.affinity + 1)
        };
        thread_policy_set(mach_thread, THREAD_AFFINITY_POLICY,
                          reinterpret_cast<thread_policy_t>(&policy),
                          THREAD_AFFINITY_POLICY_COUNT);

        // Resume thread
        thread_resume(mach_thread);
    } else {
        pthread_create(&m_thread, nullptr, callback, this);
    }
}
```

**Why macOS is Different**: macOS doesn't support setting affinity on running threads

**Code Reference**: `src/backend/common/Thread.h:52-66`

### Workers<T> Manager

**Purpose**: Manages a pool of workers

```cpp
template<class T>
class Workers {
public:
    void start(const std::vector<T> &data);
    void stop();
    bool tick(uint64_t ticks);
    const Hashrate *hashrate() const;
    void jobEarlyNotification(const Job &job);

private:
    static IWorker *create(Thread<T> *handle);
    static void *onReady(void *arg);

    std::vector<Thread<T> *> m_workers;
    WorkersPrivate *d_ptr;
};
```

**Worker Pool Management**:
1. Create Thread<T> wrappers
2. Start threads with `onReady` callback
3. Callback creates Worker and calls `worker->start()`
4. Worker runs mining loop until stopped
5. On stop, join threads and delete workers

**Code Reference**: `src/backend/common/Workers.h:49-77`

---

## Job Processing Pipeline

### Job Distribution Flow

```
New Job Arrives
    ↓
Backend::prepare(job)  (prepare resources, e.g., dataset)
    ↓
Backend::setJob(job)  (distribute to workers)
    ↓
Workers<T>::jobEarlyNotification(job)  (optional early notification)
    ↓
Workers detect new job via Nonce::isOutdated()
    ↓
Worker::consumeJob()  (copy job, reset nonce)
    ↓
Mining Loop continues with new job
```

### Job Early Notification

**Purpose**: Give workers advance notice of incoming job

```cpp
void jobEarlyNotification(const Job &job)
{
    for (Thread<T>* t : m_workers) {
        if (t->worker()) {
            t->worker()->jobEarlyNotification(job);
        }
    }
}
```

**Use Case**: RandomX can precompute parts of the next job

**Code Reference**: `src/backend/common/Workers.h:81-88`

### Nonce Management

**Purpose**: Global nonce sequence prevents stale work

**Key Functions**:
- `Nonce::sequence(Backend)` - Get current sequence number
- `Nonce::isOutdated(Backend, seq)` - Check if job is stale
- `Nonce::isPaused()` - Check if mining is paused
- `Nonce::touch(Backend)` - Update timestamp

**Mining Loop Check**:
```cpp
while (!Nonce::isOutdated(Nonce::CPU, m_job.sequence())) {
    // Mine current job
}
// Job outdated, get new job
```

**Code Reference**: `src/backend/cpu/CpuWorker.cpp:262`

---

## CPU Worker Implementation

### CpuWorker<N> Template

**Template Parameter N**: Hash intensity (how many hashes computed per iteration)

**Common Intensities**:
- `CpuWorker<1>`: Standard (1 hash/iteration) - Default
- `CpuWorker<2>`: Double (2 hashes/iteration) - Better for some CPUs
- `CpuWorker<4>`: Quad (4 hashes/iteration) - High-end CPUs
- `CpuWorker<8>`: Octa (8 hashes/iteration) - GhostRider only

**Code Reference**: `src/backend/cpu/CpuWorker.h:117-122`

### Main Mining Loop

```cpp
template<size_t N>
void CpuWorker<N>::start()
{
    // Outer loop: while mining is active
    while (Nonce::sequence(Nonce::CPU) > 0) {

        // Handle pause
        if (Nonce::isPaused()) {
            std::this_thread::sleep_for(std::chrono::milliseconds(20));
            continue;
        }

        // Inner loop: while current job is valid
        while (!Nonce::isOutdated(Nonce::CPU, m_job.sequence())) {
            const Job &job = m_job.currentJob();

            // Check if algorithm changed
            if (job.algorithm().l3() != m_algorithm.l3()) {
                break;
            }

            // Get current nonces
            uint32_t current_job_nonces[N];
            for (size_t i = 0; i < N; ++i) {
                current_job_nonces[i] = readUnaligned(m_job.nonce(i));
            }

            // Compute hash(es)
            switch (job.algorithm().family()) {
                case Algorithm::RANDOM_X:
                    randomx_calculate_hash(...);
                    break;
                case Algorithm::GHOSTRIDER:
                    ghostrider::hash_octa(...);
                    break;
                default:
                    fn(job.algorithm())(blob, size, hash, ctx, height);
                    break;
            }

            // Increment nonce
            if (!nextRound()) {
                break;
            }

            // Check if hash meets target
            for (size_t i = 0; i < N; ++i) {
                const uint64_t value = *reinterpret_cast<uint64_t*>(
                    m_hash + (i * 32) + 24
                );

                if (value < job.target()) {
                    // Found valid share!
                    JobResults::submit(JobResult(...));
                }
            }

            m_count += N;  // Update hash count

            // Optional yield
            if (m_yield) {
                std::this_thread::yield();
            }
        }

        // Job outdated, consume new job
        consumeJob();
    }
}
```

**Code Reference**: `src/backend/cpu/CpuWorker.cpp:241-400`

### Algorithm-Specific Handling

#### RandomX

```cpp
if (job.algorithm().family() == Algorithm::RANDOM_X) {
    // First hash: initialize VM
    if (first) {
        first = false;
        randomx_calculate_hash_first(m_vm, tempHash, blob, size);
    }

    if (!nextRound()) break;

    // Subsequent hashes: use cached state
    randomx_calculate_hash_next(m_vm, tempHash, blob, size, m_hash);
}
```

**Optimization**: `calculate_hash_first` and `calculate_hash_next` reuse VM state

**Code Reference**: `src/backend/cpu/CpuWorker.cpp:292-311`

#### GhostRider

```cpp
case Algorithm::GHOSTRIDER:
    if (N == 8) {
        // GhostRider requires intensity 8
        ghostrider::hash_octa(blob, size, m_hash, m_ctx, m_ghHelper);
    }
    break;
```

**Special Feature**: Uses helper thread for parallel computation

**Code Reference**: `src/backend/cpu/CpuWorker.cpp:318-325`

#### CryptoNight Variants

```cpp
default:
    // Use function pointer selected at worker creation
    fn(job.algorithm())(blob, size, m_hash, m_ctx, height);
    break;
```

**Function Pointer**: Selected based on algorithm, AES-NI, assembly

**Code Reference**: `src/backend/cpu/CpuWorker.cpp:328-330`

---

## Synchronization and Concurrency

### Lock-Free Job Distribution

**Mechanism**: Nonce sequence numbers for job versioning

**Advantages**:
- No mutexes in hot path
- Workers independently check for stale jobs
- Minimal synchronization overhead

**Implementation**:
```cpp
// Atomic sequence number
std::atomic<uint64_t> sequence;

// Worker checks
while (!Nonce::isOutdated(Nonce::CPU, m_job.sequence())) {
    // Mine
}
```

### Hashrate Collection

**Thread-Safe Update**:
```cpp
bool Workers<T>::tick(uint64_t ticks)
{
    uint64_t ts = Chrono::steadyMSecs();

    for (Thread<T> *handle : m_workers) {
        IWorker *worker = handle->worker();
        if (worker) {
            uint64_t hashCount, rawHashes;
            worker->hashrateData(hashCount, ts, rawHashes);
            d_ptr->hashrate->add(handle->id(), hashCount, ts);
        }
    }
}
```

**No Locks Needed**: Each worker has independent counters

**Code Reference**: `src/backend/common/Workers.cpp:79-114`

### Pause/Resume

**Mechanism**: Workers check `Nonce::isPaused()` in main loop

```cpp
if (Nonce::isPaused()) {
    do {
        std::this_thread::sleep_for(std::chrono::milliseconds(20));
    } while (Nonce::isPaused() && Nonce::sequence(Nonce::CPU) > 0);

    // Resume: consume new job
    consumeJob();
}
```

**Code Reference**: `src/backend/cpu/CpuWorker.cpp:244-255`

---

## Performance Considerations

### Thread Affinity Benefits

**Performance Impact**: 5-15% improvement

**Why It Matters**:
- Keeps thread on same CPU core
- Better L1/L2 cache locality
- Reduces cache line migrations
- Minimizes context switch overhead

**Recommendation**: Always enable CPU affinity for mining

### CPU Yield Behavior

**Configuration**: `--cpu-no-yield` flag

**With Yield** (default):
```cpp
if (m_yield) {
    std::this_thread::yield();
}
```

**Effect**:
- Allows other threads to run
- Better for systems running other apps
- Slightly lower hashrate (1-3%)

**Without Yield** (`--cpu-no-yield`):
- Maximizes mining performance
- Monopolizes CPU
- Better for dedicated mining

**Code Reference**: `src/backend/cpu/CpuWorker.cpp:70`

### Hash Intensity Selection

**Factors**:
- CPU architecture (superscalar capabilities)
- Memory bandwidth
- Cache size

**General Guidelines**:
- `N=1`: Default, works everywhere
- `N=2`: Better for modern CPUs with good memory bandwidth
- `N=4`: High-end CPUs with large caches
- `N=8`: GhostRider only

**Trade-off**: Higher N = more memory pressure, may not always be faster

### NUMA Optimization

**For Multi-Socket Systems**:
- Allocate memory on local NUMA node
- Bind threads to CPUs on same node
- Reduces cross-socket memory latency (50-100%)

**Implementation**:
```cpp
uint32_t m_node = VirtualMemory::bindToNUMANode(affinity());
m_memory = new VirtualMemory(..., node());
```

**Code Reference**: Worker base class and VirtualMemory

---

## Optimization Opportunities

Based on the threading and worker analysis, here are identified optimization opportunities:

### 1. **Work Stealing / Load Balancing**

**Current**: Static work distribution (nonce ranges)

**Opportunity**:
- Implement work stealing queue
- Dynamic load balancing between threads
- Adapt to heterogeneous CPU configurations (P-cores vs E-cores)

**Impact**: Moderate (3-5% on mixed CPU configurations)

**Location**: New feature - Worker pool management

---

### 2. **Batch Job Processing**

**Current**: Process one hash, check result, repeat

**Opportunity**:
- Process small batches before checking target
- Reduce branch prediction failures
- Better instruction pipeline utilization

**Impact**: Low to Moderate (2-4%)

**Location**: `src/backend/cpu/CpuWorker.cpp:start()` main loop

---

### 3. **Prefetch Optimization**

**Current**: No explicit prefetching

**Opportunity**:
- Prefetch next job data
- Prefetch scratchpad memory regions
- Software prefetch hints: `__builtin_prefetch()`

**Impact**: Low to Moderate (3-5%)

**Location**: Worker main loop, before hash computation

---

### 4. **Thread Pool Reuse**

**Current**: Create/destroy threads on algorithm change

**Opportunity**:
- Reuse threads across jobs
- Change worker type without recreating threads
- Reduce thread creation overhead

**Impact**: Low (matters for frequent algorithm changes)

**Location**: `src/backend/common/Workers.cpp`

---

### 5. **SIMD-Friendly Batch Processing**

**Current**: Process N hashes sequentially

**Opportunity**:
- Reorganize data for SIMD operations
- Process multiple nonces with vector instructions
- Better utilization of AVX/AVX2/AVX-512

**Impact**: Moderate to High (5-15% for some algorithms)

**Location**: Algorithm implementations

---

### 6. **Adaptive Intensity**

**Current**: Fixed intensity (N) at worker creation

**Opportunity**:
- Runtime intensity adjustment based on system load
- Detect CPU throttling, reduce intensity
- Increase intensity when thermals improve

**Impact**: Moderate (better sustained performance)

**Location**: Worker configuration and monitoring

---

### 7. **Lock-Free Result Submission**

**Current**: JobResults::submit() may use locks

**Opportunity**:
- Lock-free queue for result submission
- Per-worker result buffers
- Batch submission to reduce contention

**Impact**: Low (rarely a bottleneck, but can matter at very high hashrates)

**Location**: `src/net/JobResults.cpp`

---

### 8. **Thread Priority Tuning**

**Current**: Fixed thread priority

**Opportunity**:
- Dynamic priority adjustment
- Boost priority when shares are close
- Lower priority during background tasks

**Impact**: Low to Moderate (system-dependent)

**Location**: Thread creation and management

---

### 9. **Cache-Aware Work Distribution**

**Current**: Sequential nonce assignment

**Opportunity**:
- Distribute work based on cache topology
- Keep related work on same cache domain
- Minimize cross-cache traffic

**Impact**: Low to Moderate (3-5% on large systems)

**Location**: Job distribution logic

---

### 10. **Helper Thread Optimization** (GhostRider)

**Current**: One helper thread per worker

**Opportunity**:
- Shared helper thread pool
- Better load distribution across helpers
- Reduce helper thread overhead

**Impact**: Moderate (GhostRider only, 5-10%)

**Location**: `src/crypto/ghostrider/` helper thread implementation

---

## Best Practices

### For Users

1. **Enable CPU Affinity**: Bind threads to cores for best cache performance

2. **Use `--cpu-no-yield`** for dedicated mining: Maximize hashrate

3. **Match Thread Count to L3 Cache**:
   ```
   optimal_threads = L3_cache_MB / 2
   ```

4. **NUMA-Aware Configuration** (multi-socket):
   ```json
   {
       "cpu": {
           "enabled": true,
           "huge-pages": true
       },
       "randomx": {
           "numa": true
       }
   }
   ```

5. **Monitor CPU Temperature**: Sustained boost clocks are critical

---

### For Developers

1. **Minimize Synchronization**: Use lock-free algorithms where possible

2. **Avoid Allocations in Hot Path**: Pre-allocate all buffers

3. **Profile Before Optimizing**: Use perf/vtune to find real bottlenecks

4. **Test on Various Hardware**: Performance characteristics vary

5. **Respect Cache Lines**: Align data structures to 64-byte boundaries

6. **Consider False Sharing**: Separate frequently-written data

---

## References

### Internal Documentation
- `docs/RANDOMX_ANALYSIS.md` - RandomX implementation details
- `docs/MEMORY_MANAGEMENT_ANALYSIS.md` - Memory system
- `PERFORMANCE.md` - Performance tuning guide

### Source Files
- `src/backend/common/interfaces/IWorker.h` - Worker interface (line 37-53)
- `src/backend/common/Worker.h` - Base worker (line 29-48)
- `src/backend/cpu/CpuWorker.h` - CPU worker (line 46-122)
- `src/backend/cpu/CpuWorker.cpp` - CPU worker implementation (line 68-538)
- `src/backend/common/Workers.h` - Worker manager (line 49-110)
- `src/backend/common/Workers.cpp` - Worker manager implementation
- `src/backend/common/Thread.h` - Thread wrapper (line 42-91)
- `src/backend/cpu/CpuBackend.h` - CPU backend (line 38-74)

### External Resources
- [C++ std::thread Documentation](https://en.cppreference.com/w/cpp/thread/thread)
- [pthread Documentation](https://man7.org/linux/man-pages/man7/pthreads.7.html)
- [NUMA Best Practices](https://www.kernel.org/doc/html/latest/vm/numa.html)
- [CPU Affinity on Linux](https://man7.org/linux/man-pages/man3/pthread_setaffinity_np.3.html)

---

## Next Steps

Based on this analysis, recommended next steps:

1. ✅ **Worker Architecture Analysis** - Completed
2. ⏳ **Profile Worker Hot Paths** - Use perf to find bottlenecks
3. ⏳ **Implement Work Stealing** - Improve load distribution
4. ⏳ **Optimize Batch Processing** - Reduce per-hash overhead
5. ⏳ **Test on Heterogeneous CPUs** - Validate P-core/E-core handling

---

**Document Version**: 1.0
**Last Updated**: 2025-12-02
**Status**: Initial Analysis Complete
