# X Miner Algorithm Performance Comparison

**Date:** Tue Dec  2 23:05:12 EST 2025
**System:** Darwin x86_64
**CPU:** Intel(R) Core(TM) i9-9880H CPU @ 2.30GHz
**Cores:** 16
**Binary:** /Users/calebsmith/Documents/ktheindifferent/X/build/x
**Profile Duration:** 45s per algorithm

---

## Executive Summary

This report compares the performance characteristics of different mining algorithms on the same hardware.


## randomx Algorithm

### Configuration
- Benchmark: 10M iterations
- Threads: 16

### Performance Metrics

```

```

**Resource Usage:**
- CPU: 1455.2%
- Memory: 2433524 KB (2376.48 MB)

### Hot Functions (Top 10)

```
Call graph:
    15065 Thread_1382747   DispatchQueue_1: com.apple.main-thread  (serial)
    + 15065 start  (in dyld) + 3457  [0x7ff808443781]
    +   15065 ???  (in x)  load address 0x109c5a000 + 0xcb908  [0x109d25908]
    +     15065 ???  (in x)  load address 0x109c5a000 + 0xbe2c0  [0x109d182c0]
    +       15064 ???  (in x)  load address 0x109c5a000 + 0x4e7865  [0x10a141865]
    +       ! 15056 ???  (in x)  load address 0x109c5a000 + 0x4f7b69  [0x10a151b69]
    +       ! : 15056 kevent  (in libsystem_kernel.dylib) + 10  [0x7ff8087db806]
    +       ! 8 ???  (in x)  load address 0x109c5a000 + 0x4f7d26  [0x10a151d26]
    +       !   8 ???  (in x)  load address 0x109c5a000 + 0x4e7408  [0x10a141408]
    +       !     8 ???  (in x)  load address 0x109c5a000 + 0xc585c  [0x109d1f85c]
    +       !       8 ???  (in x)  load address 0x109c5a000 + 0x8c026  [0x109ce6026]
    +       !         8 xmrig::Workers<xmrig::CpuLaunchData>::start(std::vector<xmrig::CpuLaunchData> const&, std::shared_ptr<xmrig::Benchmark> const&)  (in x) + 29  [0x109ce1f2d]
    +       !           8 xmrig::Workers<xmrig::CpuLaunchData>::start(std::vector<xmrig::CpuLaunchData> const&, bool)  (in x) + 621  [0x109ce1b6d]
    +       !             5 _pthread_create  (in libsystem_pthread.dylib) + 358  [0x7ff80881ab50]
    +       !             | 5 mach_vm_map  (in libsystem_kernel.dylib) + 86  [0x7ff8087d6900]
    +       !             |   5 _kernelrpc_mach_vm_map_trap  (in libsystem_kernel.dylib) + 10  [0x7ff8087d69e6]
    +       !             3 _pthread_create  (in libsystem_pthread.dylib) + 580,1049  [0x7ff80881ac2e,0x7ff80881ae03]
    +       1 ???  (in x)  load address 0x109c5a000 + 0x4e7998  [0x10a141998]
    +         1 ???  (in x)  load address 0x109c5a000 + 0x4e3fd8  [0x10a13dfd8]
    +           1 ???  (in x)  load address 0x109c5a000 + 0xc4000  [0x109d1e000]
    15065 Thread_1382749
    + 15065 thread_start  (in libsystem_pthread.dylib) + 15  [0x7ff808815857]
    +   15065 _pthread_start  (in libsystem_pthread.dylib) + 115  [0x7ff808819e4d]
    +     15065 ???  (in x)  load address 0x109c5a000 + 0x19f813  [0x109df9813]
    +       13984 ???  (in x)  load address 0x109c5a000 + 0x19ea4b  [0x109df8a4b]
    +       ! 13984 std::condition_variable::wait(std::unique_lock<std::mutex>&)  (in libc++.1.dylib) + 18  [0x7ff8087561ae]
    +       !   13984 _pthread_cond_wait  (in libsystem_pthread.dylib) + 988  [0x7ff80881a2f6]
    +       !     13984 __psynch_cvwait  (in libsystem_kernel.dylib) + 10  [0x7ff8087d96fa]
    +       1081 ???  (in x)  load address 0x109c5a000 + 0x19ec6a  [0x109df8c6a]
    +         1081 ???  (in x)  load address 0x109c5a000 + 0x19c9ef  [0x109df69ef]
    +           1081 ???  (in x)  load address 0x109c5a000 + 0x19e0cc  [0x109df80cc]
    +             1081 std::thread::join()  (in libc++.1.dylib) + 24  [0x7ff8087577b0]
    +               1081 _pthread_join  (in libsystem_pthread.dylib) + 348  [0x7ff80881b703]
    +                 1081 __ulock_wait  (in libsystem_kernel.dylib) + 10  [0x7ff8087d831e]
    13984 Thread_1382888
    + 1001 ???  (in <unknown binary>)  [0x10a5ee0cc]
    + 914 thread_start  (in libsystem_pthread.dylib) + 15  [0x7ff808815857]
    + ! 914 _pthread_start  (in libsystem_pthread.dylib) + 115  [0x7ff808819e4d]
    + !   912 xmrig::Workers<xmrig::CpuLaunchData>::onReady(void*)  (in x) + 62  [0x109ce1fde]
    + !   : 894 xmrig::CpuWorker<1ul>::start()  (in x) + 868  [0x109ceabe4]
```


### Analysis

**Key bottlenecks identified:**

- Load Address:    0x109c5a000
- + 15065 start  (in dyld) + 3457  [0x7ff808443781]
- +   15065 ???  (in x)  load address 0x109c5a000 + 0xcb908  [0x109d25908]
- +     15065 ???  (in x)  load address 0x109c5a000 + 0xbe2c0  [0x109d182c0]
- +       15064 ???  (in x)  load address 0x109c5a000 + 0x4e7865  [0x10a141865]
- +       ! 15056 ???  (in x)  load address 0x109c5a000 + 0x4f7b69  [0x10a151b69]
- +       ! : 15056 kevent  (in libsystem_kernel.dylib) + 10  [0x7ff8087db806]
- +       ! 8 ???  (in x)  load address 0x109c5a000 + 0x4f7d26  [0x10a151d26]
- +       !   8 ???  (in x)  load address 0x109c5a000 + 0x4e7408  [0x10a141408]
- +       !     8 ???  (in x)  load address 0x109c5a000 + 0xc585c  [0x109d1f85c]

---


## cn Algorithm

### Configuration
- Benchmark: 1M iterations
- Threads: 16

### Performance Metrics

```

```

**Resource Usage:**
- CPU: 1323.2%
- Memory: 2433468 KB (2376.43 MB)

### Hot Functions (Top 10)

```
Call graph:
    14916 Thread_1383825   DispatchQueue_1: com.apple.main-thread  (serial)
    + 14916 start  (in dyld) + 3457  [0x7ff808443781]
    +   14916 ???  (in x)  load address 0x10c4ba000 + 0xcb908  [0x10c585908]
    +     14916 ???  (in x)  load address 0x10c4ba000 + 0xbe2c0  [0x10c5782c0]
    +       14916 ???  (in x)  load address 0x10c4ba000 + 0x4e7865  [0x10c9a1865]
    +         14910 ???  (in x)  load address 0x10c4ba000 + 0x4f7b69  [0x10c9b1b69]
    +         ! 14910 kevent  (in libsystem_kernel.dylib) + 10  [0x7ff8087db806]
    +         6 ???  (in x)  load address 0x10c4ba000 + 0x4f7d26  [0x10c9b1d26]
    +           6 ???  (in x)  load address 0x10c4ba000 + 0x4e7408  [0x10c9a1408]
    +             6 ???  (in x)  load address 0x10c4ba000 + 0xc585c  [0x10c57f85c]
    +               6 ???  (in x)  load address 0x10c4ba000 + 0x8c026  [0x10c546026]
    +                 6 xmrig::Workers<xmrig::CpuLaunchData>::start(std::vector<xmrig::CpuLaunchData> const&, std::shared_ptr<xmrig::Benchmark> const&)  (in x) + 29  [0x10c541f2d]
    +                   6 xmrig::Workers<xmrig::CpuLaunchData>::start(std::vector<xmrig::CpuLaunchData> const&, bool)  (in x) + 621  [0x10c541b6d]
    +                     3 _pthread_create  (in libsystem_pthread.dylib) + 358  [0x7ff80881ab50]
    +                     : 3 mach_vm_map  (in libsystem_kernel.dylib) + 86  [0x7ff8087d6900]
    +                     :   3 _kernelrpc_mach_vm_map_trap  (in libsystem_kernel.dylib) + 10  [0x7ff8087d69e6]
    +                     3 _pthread_create  (in libsystem_pthread.dylib) + 580  [0x7ff80881ac2e]
    14916 Thread_1383826
    + 14916 thread_start  (in libsystem_pthread.dylib) + 15  [0x7ff808815857]
    +   14916 _pthread_start  (in libsystem_pthread.dylib) + 115  [0x7ff808819e4d]
    +     14916 ???  (in x)  load address 0x10c4ba000 + 0x19f813  [0x10c659813]
    +       14544 ???  (in x)  load address 0x10c4ba000 + 0x19ea4b  [0x10c658a4b]
    +       ! 14544 std::condition_variable::wait(std::unique_lock<std::mutex>&)  (in libc++.1.dylib) + 18  [0x7ff8087561ae]
    +       !   14544 _pthread_cond_wait  (in libsystem_pthread.dylib) + 988  [0x7ff80881a2f6]
    +       !     14544 __psynch_cvwait  (in libsystem_kernel.dylib) + 10  [0x7ff8087d96fa]
    +       372 ???  (in x)  load address 0x10c4ba000 + 0x19ec6a  [0x10c658c6a]
    +         372 ???  (in x)  load address 0x10c4ba000 + 0x19c9ef  [0x10c6569ef]
    +           372 ???  (in x)  load address 0x10c4ba000 + 0x19e0cc  [0x10c6580cc]
    +             372 std::thread::join()  (in libc++.1.dylib) + 24  [0x7ff8087577b0]
    +               370 _pthread_join  (in libsystem_pthread.dylib) + 348  [0x7ff80881b703]
    +               : 370 __ulock_wait  (in libsystem_kernel.dylib) + 10  [0x7ff8087d831e]
    +               2 _pthread_join  (in libsystem_pthread.dylib) + 694  [0x7ff80881b85d]
    +                 2 _pthread_deallocate  (in libsystem_pthread.dylib) + 69  [0x7ff808819a2a]
    +                   2 mach_vm_deallocate  (in libsystem_kernel.dylib) + 67  [0x7ff8087d8135]
    +                     2 _kernelrpc_mach_vm_deallocate_trap  (in libsystem_kernel.dylib) + 10  [0x7ff8087d69c2]
    14544 Thread_1383904
    + 1012 ???  (in <unknown binary>)  [0x10ce4e0cc]
    + 951 thread_start  (in libsystem_pthread.dylib) + 15  [0x7ff808815857]
    + ! 951 _pthread_start  (in libsystem_pthread.dylib) + 115  [0x7ff808819e4d]
    + !   949 xmrig::Workers<xmrig::CpuLaunchData>::onReady(void*)  (in x) + 62  [0x10c541fde]
```


### Analysis

**Key bottlenecks identified:**

- Load Address:    0x10c4ba000
- + 14916 start  (in dyld) + 3457  [0x7ff808443781]
- +   14916 ???  (in x)  load address 0x10c4ba000 + 0xcb908  [0x10c585908]
- +     14916 ???  (in x)  load address 0x10c4ba000 + 0xbe2c0  [0x10c5782c0]
- +       14916 ???  (in x)  load address 0x10c4ba000 + 0x4e7865  [0x10c9a1865]
- +         14910 ???  (in x)  load address 0x10c4ba000 + 0x4f7b69  [0x10c9b1b69]
- +         ! 14910 kevent  (in libsystem_kernel.dylib) + 10  [0x7ff8087db806]
- +         6 ???  (in x)  load address 0x10c4ba000 + 0x4f7d26  [0x10c9b1d26]
- +           6 ???  (in x)  load address 0x10c4ba000 + 0x4e7408  [0x10c9a1408]
- +             6 ???  (in x)  load address 0x10c4ba000 + 0xc585c  [0x10c57f85c]

---


## cn-lite Algorithm

### Configuration
- Benchmark: 1M iterations
- Threads: 16

### Performance Metrics

```

```

**Resource Usage:**
- CPU: 1386.7%
- Memory: 2433560 KB (2376.52 MB)

### Hot Functions (Top 10)

```
Call graph:
    15369 Thread_1384965   DispatchQueue_1: com.apple.main-thread  (serial)
    + 15369 start  (in dyld) + 3457  [0x7ff808443781]
    +   15369 ???  (in x)  load address 0x1073df000 + 0xcb908  [0x1074aa908]
    +     15369 ???  (in x)  load address 0x1073df000 + 0xbe2c0  [0x10749d2c0]
    +       15368 ???  (in x)  load address 0x1073df000 + 0x4e7865  [0x1078c6865]
    +       ! 15361 ???  (in x)  load address 0x1073df000 + 0x4f7b69  [0x1078d6b69]
    +       ! : 15361 kevent  (in libsystem_kernel.dylib) + 10  [0x7ff8087db806]
    +       ! 7 ???  (in x)  load address 0x1073df000 + 0x4f7d26  [0x1078d6d26]
    +       !   7 ???  (in x)  load address 0x1073df000 + 0x4e7408  [0x1078c6408]
    +       !     7 ???  (in x)  load address 0x1073df000 + 0xc585c  [0x1074a485c]
    +       !       7 ???  (in x)  load address 0x1073df000 + 0x8c026  [0x10746b026]
    +       !         7 xmrig::Workers<xmrig::CpuLaunchData>::start(std::vector<xmrig::CpuLaunchData> const&, std::shared_ptr<xmrig::Benchmark> const&)  (in x) + 29  [0x107466f2d]
    +       !           6 xmrig::Workers<xmrig::CpuLaunchData>::start(std::vector<xmrig::CpuLaunchData> const&, bool)  (in x) + 621  [0x107466b6d]
    +       !           | 3 _pthread_create  (in libsystem_pthread.dylib) + 358  [0x7ff80881ab50]
    +       !           | + 3 mach_vm_map  (in libsystem_kernel.dylib) + 86  [0x7ff8087d6900]
    +       !           | +   3 _kernelrpc_mach_vm_map_trap  (in libsystem_kernel.dylib) + 10  [0x7ff8087d69e6]
    +       !           | 2 _pthread_create  (in libsystem_pthread.dylib) + 537  [0x7ff80881ac03]
    +       !           | + 2 mach_vm_protect  (in libsystem_kernel.dylib) + 34  [0x7ff8087d9b05]
    +       !           | +   2 _kernelrpc_mach_vm_protect_trap  (in libsystem_kernel.dylib) + 10  [0x7ff8087d69da]
    +       !           | 1 _pthread_create  (in libsystem_pthread.dylib) + 580  [0x7ff80881ac2e]
    +       !           1 xmrig::Workers<xmrig::CpuLaunchData>::start(std::vector<xmrig::CpuLaunchData> const&, bool)  (in x) + 514  [0x107466b02]
    +       !             1 ???  (in x)  load address 0x1073df000 + 0x8287a  [0x10746187a]
    +       !               1 _platform_bzero$VARIANT$Haswell  (in libsystem_platform.dylib) + 41  [0x7ff808821e09]
    +       1 ???  (in x)  load address 0x1073df000 + 0x4e7998  [0x1078c6998]
    +         1 ???  (in x)  load address 0x1073df000 + 0x4e3fd8  [0x1078c2fd8]
    +           1 ???  (in x)  load address 0x1073df000 + 0xc4000  [0x1074a3000]
    15369 Thread_1384969
    + 15369 thread_start  (in libsystem_pthread.dylib) + 15  [0x7ff808815857]
    +   15369 _pthread_start  (in libsystem_pthread.dylib) + 115  [0x7ff808819e4d]
    +     15369 ???  (in x)  load address 0x1073df000 + 0x19f813  [0x10757e813]
    +       14802 ???  (in x)  load address 0x1073df000 + 0x19ea4b  [0x10757da4b]
    +       ! 14802 std::condition_variable::wait(std::unique_lock<std::mutex>&)  (in libc++.1.dylib) + 18  [0x7ff8087561ae]
    +       !   14802 _pthread_cond_wait  (in libsystem_pthread.dylib) + 988  [0x7ff80881a2f6]
    +       !     14802 __psynch_cvwait  (in libsystem_kernel.dylib) + 10  [0x7ff8087d96fa]
    +       567 ???  (in x)  load address 0x1073df000 + 0x19ec6a  [0x10757dc6a]
    +         567 ???  (in x)  load address 0x1073df000 + 0x19c9ef  [0x10757b9ef]
    +           567 ???  (in x)  load address 0x1073df000 + 0x19e0cc  [0x10757d0cc]
    +             567 std::thread::join()  (in libc++.1.dylib) + 24  [0x7ff8087577b0]
    +               567 _pthread_join  (in libsystem_pthread.dylib) + 348  [0x7ff80881b703]
    +                 567 __ulock_wait  (in libsystem_kernel.dylib) + 10  [0x7ff8087d831e]
```


### Analysis

**Key bottlenecks identified:**

- Load Address:    0x1073df000
- + 15369 start  (in dyld) + 3457  [0x7ff808443781]
- +   15369 ???  (in x)  load address 0x1073df000 + 0xcb908  [0x1074aa908]
- +     15369 ???  (in x)  load address 0x1073df000 + 0xbe2c0  [0x10749d2c0]
- +       15368 ???  (in x)  load address 0x1073df000 + 0x4e7865  [0x1078c6865]
- +       ! 15361 ???  (in x)  load address 0x1073df000 + 0x4f7b69  [0x1078d6b69]
- +       ! : 15361 kevent  (in libsystem_kernel.dylib) + 10  [0x7ff8087db806]
- +       ! 7 ???  (in x)  load address 0x1073df000 + 0x4f7d26  [0x1078d6d26]
- +       !   7 ???  (in x)  load address 0x1073df000 + 0x4e7408  [0x1078c6408]
- +       !     7 ???  (in x)  load address 0x1073df000 + 0xc585c  [0x1074a485c]

---


## Comparative Analysis

### Algorithm Characteristics

| Algorithm | Best For | Memory Usage | CPU Intensity |
|-----------|----------|--------------|---------------|
| RandomX | Monero, TARI | High (2GB+) | Very High |
| CryptoNight | Monero legacy | Medium (2MB per thread) | High |
| CryptoNight-Lite | Lightweight coins | Low (1MB per thread) | Medium |

### Performance Summary

**randomx:**
- Hashrate: 
- CPU: 1455.2%
- Memory: 2376.48 MB

**cn:**
- Hashrate: 
- CPU: 1323.2%
- Memory: 2376.43 MB

**cn-lite:**
- Hashrate: 
- CPU: 1386.7%
- Memory: 2376.52 MB


### Recommendations

Based on the profiling results:

1. **Algorithm Selection**
   - For CPU mining: RandomX typically provides best results on modern CPUs
   - Memory-constrained systems: Consider CryptoNight-Lite
   - Multi-threaded systems: RandomX scales well with cores

2. **Optimization Opportunities**
   - Check hot functions for optimization potential
   - Verify huge pages are enabled (10-30% improvement for RandomX)
   - Ensure CPU affinity is properly configured
   - Monitor memory bandwidth utilization

3. **Next Steps**
   - Run extended profiling sessions (5+ minutes)
   - Profile with different thread counts
   - Test with huge pages enabled vs disabled
   - Compare with and without NUMA awareness

---

## Files Reference

All profiling data saved to: `/Users/calebsmith/Documents/ktheindifferent/X/profiling_results/`

**randomx:**
- `profile_randomx_20251202_230512.sample.txt` - CPU sampling data
- `profile_randomx_20251202_230512.stdout.txt` - Miner output
- `profile_randomx_20251202_230512.stats.txt` - Resource usage

**cn:**
- `profile_cn_20251202_230512.sample.txt` - CPU sampling data
- `profile_cn_20251202_230512.stdout.txt` - Miner output
- `profile_cn_20251202_230512.stats.txt` - Resource usage

**cn-lite:**
- `profile_cn-lite_20251202_230512.sample.txt` - CPU sampling data
- `profile_cn-lite_20251202_230512.stdout.txt` - Miner output
- `profile_cn-lite_20251202_230512.stats.txt` - Resource usage


---

**Generated by:** `scripts/profile_all_algorithms.sh`
**Last Updated:** Tue Dec  2 23:08:22 EST 2025
