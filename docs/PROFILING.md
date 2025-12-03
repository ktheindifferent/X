# X Miner Performance Profiling Guide

This guide covers performance profiling methodologies, tools, and analysis techniques for the X miner.

## Table of Contents

1. [Overview](#overview)
2. [Profiling Tools](#profiling-tools)
3. [Quick Start](#quick-start)
4. [Platform-Specific Profiling](#platform-specific-profiling)
5. [Interpreting Results](#interpreting-results)
6. [Optimization Workflow](#optimization-workflow)
7. [Common Bottlenecks](#common-bottlenecks)

## Overview

Performance profiling helps identify:
- CPU hotspots (functions consuming most time)
- Memory allocation patterns
- Cache efficiency
- Thread synchronization overhead
- GPU kernel performance
- I/O bottlenecks

### When to Profile

Profile the miner when:
- Implementing new optimizations
- Adding new algorithms
- Investigating performance regressions
- Comparing different configurations
- Preparing release builds

## Profiling Tools

### macOS

**Built-in Tools:**
- `sample` - CPU sampling profiler (included in script)
- `time` - Basic execution timing
- `top` / `htop` - Real-time resource monitoring

**Xcode Instruments:**
- Time Profiler - Function-level CPU profiling
- System Trace - Thread scheduling, syscalls
- Allocations - Memory profiling
- Leaks - Memory leak detection

**Installation:**
```bash
# Instruments comes with Xcode Command Line Tools
xcode-select --install
```

### Linux

**CPU Profiling:**
- `perf` - Linux performance counters
- `gprof` - GNU profiler (requires compilation with `-pg`)
- `valgrind --tool=callgrind` - Call graph profiling

**GPU Profiling:**
- `nvprof` / `nsys` - NVIDIA profiler (CUDA)
- `rocprof` - AMD profiler (ROCm)

**Installation:**
```bash
# Ubuntu/Debian
sudo apt-get install linux-tools-common linux-tools-generic valgrind

# Fedora
sudo dnf install perf valgrind

# Arch
sudo pacman -S perf valgrind
```

### Windows

**CPU Profiling:**
- Visual Studio Profiler
- Intel VTune
- AMD uProf

**GPU Profiling:**
- NVIDIA Nsight Compute
- NVIDIA Nsight Systems
- AMD Radeon GPU Profiler

## Quick Start

### Using the Profiling Script (macOS/Linux)

```bash
# Profile RandomX (default algorithm) for 30 seconds
./scripts/profile_mining.sh

# Profile specific algorithm for 60 seconds
./scripts/profile_mining.sh rx/0 60

# Profile KawPow
./scripts/profile_mining.sh kawpow 45

# Analyze results
./scripts/analyze_profile.sh profiling_results/profile_randomx_20251202_140000
```

### Manual Profiling

#### macOS - Using sample

```bash
# Build the miner
cd build && make -j$(sysctl -n hw.ncpu)

# Start miner in benchmark mode
./x --bench=rx/0 --bench-submit &
MINER_PID=$!

# Profile for 30 seconds
sample $MINER_PID 30 -file profile.txt

# Stop miner
kill $MINER_PID

# View results
less profile.txt
```

#### macOS - Using Instruments

```bash
# Time Profiler
instruments -t 'Time Profiler' -D profile.trace ./x --bench=rx/0

# Open in Instruments.app
open profile.trace
```

#### Linux - Using perf

```bash
# Build with debug symbols
cd build
cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo ..
make -j$(nproc)

# Record profile
perf record -g --call-graph dwarf ./x --bench=rx/0 &
MINER_PID=$!
sleep 30
kill $MINER_PID

# View report
perf report

# Generate flamegraph (requires flamegraph tools)
perf script | stackcollapse-perf.pl | flamegraph.pl > profile.svg
firefox profile.svg
```

#### Linux - Using valgrind/callgrind

```bash
# Profile with callgrind
valgrind --tool=callgrind --dump-instr=yes --collect-jumps=yes \
    ./x --bench=rx/0 --threads=1 --bench-submit

# Visualize with kcachegrind
kcachegrind callgrind.out.*
```

## Platform-Specific Profiling

### CPU Mining Profiling

#### RandomX Algorithm

RandomX is CPU-intensive with specific characteristics:
- Heavy JIT compilation during initialization
- Large memory working set (2GB+ dataset)
- Integer and floating-point mix
- Cache-sensitive operations

**Profiling focus:**
```bash
# Profile RandomX with different configs
./scripts/profile_mining.sh rx/0 60

# Check JIT compiler time
# Look for functions: randomx::JitCompilerX86::*
# Should be minimal in steady state

# Check VM execution
# Look for: randomx::*Vm::run
# Should dominate CPU time

# Check memory access
# Look for dataset access patterns
# Huge pages should reduce TLB misses
```

**Expected hotspots:**
- `randomx::InterpretedVm::execute()` or `randomx::CompiledVm::execute()`
- `randomx::VmBase::getMemory()`
- `randomx::Dataset::getItem()`
- AES and Blake2 hash functions

#### CryptoNight Algorithm

CryptoNight is memory-hard:
- 2MB scratchpad per thread
- Sequential memory access
- AES-NI instructions critical

**Profiling focus:**
```bash
# Profile CryptoNight variant
./scripts/profile_mining.sh cn/r 60

# Check AES-NI usage
# Should see heavy use of AES instructions
```

**Expected hotspots:**
- `cn_slow_hash()` variants
- AES round functions
- Memory mixing operations

### GPU Mining Profiling

#### CUDA Profiling (NVIDIA)

```bash
# Using nvprof (deprecated but simple)
nvprof --print-gpu-trace ./x -o POOL:PORT -u WALLET -a kawpow

# Using nsys (new profiler)
nsys profile --trace=cuda,nvtx --output=profile \
    ./x --bench=kawpow --bench-submit

# View in GUI
nsys-ui profile.qdrep

# Using ncu for kernel analysis
ncu --set full --target-processes all \
    ./x --bench=kawpow --bench-submit
```

**CUDA metrics to check:**
- Kernel execution time
- Memory bandwidth utilization
- Occupancy
- Register usage
- Shared memory bank conflicts
- Warp divergence

#### OpenCL Profiling (AMD/NVIDIA)

```bash
# AMD ROCm profiler
rocprof --stats ./x -o POOL:PORT -u WALLET -a kawpow

# OpenCL event profiling (built into X)
# Enable with --opencl-profile flag
./x --opencl-profile --bench=kawpow

# CodeXL (AMD profiler)
# Use GUI to analyze kernel performance
```

**OpenCL metrics to check:**
- Kernel compilation time
- Kernel execution time
- Memory transfer time (host↔device)
- Wavefront occupancy (AMD)
- VGPR/SGPR usage (AMD)

## Interpreting Results

### CPU Profile Analysis

#### Sample/perf Output Format

```
Total Time: 30.0s
Sample Count: 3000

Call graph:
  3000 Thread_1234
    2850 start (main thread)
      2850 xmrig::Worker::run()
        2700 randomx::CompiledVm::execute()  [90%]
          2000 randomx::executeProgram()     [66%]
            800 randomx::IntegerMath         [26%]
            600 randomx::FloatMath          [20%]
            400 randomx::Memory::read       [13%]
          700 randomx::hashAes1Rx4          [23%]
        100 xmrig::JobResults::submit()     [3%]
        50 xmrig::Workers::tick()           [1.6%]
```

**Interpretation:**
- 90% time in VM execution (expected for RandomX)
- Integer/float operations dominate (expected)
- Memory reads are 13% (check huge pages if higher)
- Results submission is minimal (good)

#### Identifying Optimization Opportunities

**High CPU time (>5%) in:**
- **Lock functions** (`pthread_mutex_lock`, `std::mutex::lock`)
  → Reduce lock contention, use lock-free structures
- **Memory allocation** (`malloc`, `new`, `std::allocator`)
  → Use memory pools, reduce allocations
- **Hash functions** (in hot path)
  → Check for hardware acceleration (AES-NI, SHA-NI)
- **Syscalls** (`read`, `write`, `select`)
  → Batch operations, use async I/O
- **String operations** (`memcpy`, `strcpy`)
  → Reduce string manipulation, use string views

**Low CPU time (<80% in algorithm):**
- Check thread count vs CPU cores
- Check CPU affinity settings
- Check for I/O blocking
- Check for excessive logging

### GPU Profile Analysis

#### Kernel Performance Metrics

**Good indicators:**
- Kernel time > 95% of total time
- Memory transfer time < 5%
- High occupancy (>50% for CUDA, >80% for OpenCL)
- Memory bandwidth utilization > 70%

**Bad indicators:**
- Frequent kernel launches (<10ms per launch)
- High host↔device transfer time
- Low occupancy (<30%)
- Low memory bandwidth (<50%)
- High register pressure (spilling to memory)

#### Common GPU Bottlenecks

**Memory bandwidth limited:**
- Optimize memory access patterns
- Use shared memory for reused data
- Coalesce memory accesses

**Compute limited:**
- Increase intensity (more work per kernel)
- Reduce register usage
- Optimize arithmetic operations

**Latency limited:**
- Increase occupancy
- Use asynchronous operations
- Hide latency with more threads

## Optimization Workflow

### 1. Baseline Profile

```bash
# Establish baseline
./scripts/profile_mining.sh rx/0 60

# Record hashrate and hotspots
# Example: 15.2 KH/s, 90% in VM execution
```

### 2. Identify Bottleneck

From profile analysis:
- Top function consuming >30% time
- Lock contention
- Memory allocation
- I/O operations

### 3. Hypothesize Optimization

Based on bottleneck:
- "JIT compiler could use AVX-512 instead of AVX2"
- "Memory pool could reduce malloc calls"
- "Better CPU affinity could reduce cache misses"

### 4. Implement Change

Make targeted optimization:
```cpp
// Before: AVX2
__m256i data = _mm256_load_si256(...);

// After: AVX-512
__m512i data = _mm512_load_si512(...);
```

### 5. Re-profile

```bash
# Profile with optimization
./scripts/profile_mining.sh rx/0 60

# Compare hashrate and hotspots
# Example: 16.8 KH/s (+10.5%), VM execution now 85%
```

### 6. Validate & Document

- Run extended benchmark
- Test on different hardware
- Document optimization in code
- Update CHANGELOG.md

## Common Bottlenecks

### RandomX

**Bottleneck:** JIT compiler time
**Symptom:** Slow initialization (>5 seconds)
**Fix:** Optimize JIT code generation, cache compiled code

**Bottleneck:** Dataset access
**Symptom:** High time in `Dataset::getItem()`
**Fix:** Enable huge pages, check NUMA placement

**Bottleneck:** VM execution
**Symptom:** 95%+ time in `execute()` but low hashrate
**Fix:** Optimize JIT generated code, use newer instruction sets

### CryptoNight

**Bottleneck:** AES operations
**Symptom:** High time in AES functions
**Fix:** Enable AES-NI, use hardware acceleration

**Bottleneck:** Memory access
**Symptom:** Cache misses, high memory latency
**Fix:** Optimize scratchpad access, use huge pages

### KawPow (GPU)

**Bottleneck:** Memory bandwidth
**Symptom:** Low hashrate on high-end GPUs
**Fix:** Optimize memory access patterns, tune intensity

**Bottleneck:** Kernel launch overhead
**Symptom:** High CPU time in `cuLaunchKernel`
**Fix:** Increase work per kernel, use persistent kernels

### Network/Pool

**Bottleneck:** Result submission latency
**Symptom:** High time in network functions
**Fix:** Use async submission, batch results

**Bottleneck:** Job update frequency
**Symptom:** Frequent job changes (<5s per job)
**Fix:** Tune pool stratum settings, check network latency

## Advanced Profiling Techniques

### Differential Profiling

Compare two profiles to measure optimization impact:

```bash
# Baseline
./scripts/profile_mining.sh rx/0 60
mv profiling_results/profile_randomx_*.sample.txt baseline.txt

# After optimization
./scripts/profile_mining.sh rx/0 60
mv profiling_results/profile_randomx_*.sample.txt optimized.txt

# Compare
diff -u baseline.txt optimized.txt | less
```

### Multi-Algorithm Profiling

Profile different algorithms to find best fit for hardware:

```bash
# Profile each algorithm
for algo in rx/0 cn/r kawpow; do
    ./scripts/profile_mining.sh $algo 45
done

# Compare hashrates and efficiency
```

### Hardware Counter Analysis (Linux)

Use `perf stat` for detailed hardware metrics:

```bash
perf stat -e cycles,instructions,cache-references,cache-misses,branches,branch-misses \
    ./x --bench=rx/0 --bench-submit

# Analyze:
# - IPC (instructions per cycle) - higher is better (>1.5 good)
# - Cache miss rate - lower is better (<5% good)
# - Branch miss rate - lower is better (<2% good)
```

### Memory Profiling

Check for memory leaks and allocation patterns:

```bash
# Valgrind memcheck
valgrind --leak-check=full --show-leak-kinds=all \
    ./x --bench=rx/0 --threads=1 --bench-submit

# macOS leaks tool
./x --bench=rx/0 --bench-submit &
MINER_PID=$!
sleep 30
leaks $MINER_PID
kill $MINER_PID
```

## Profiling Best Practices

### Do's

✅ **Always compare with baseline** - Profile before and after changes
✅ **Use release builds** - Profile optimized code (`-O3`)
✅ **Profile realistic workloads** - Use actual mining scenarios
✅ **Profile long enough** - 30-60 seconds minimum for stable results
✅ **Control variables** - Same hardware, same config, same pool load
✅ **Document results** - Save profiles for future reference
✅ **Focus on hot paths** - Optimize functions with >5% CPU time

### Don'ts

❌ **Don't profile debug builds** - Performance is not representative
❌ **Don't optimize without profiling** - Premature optimization is wasteful
❌ **Don't profile too short** - <10s can give misleading results
❌ **Don't ignore cold paths** - But prioritize hot paths first
❌ **Don't forget platform differences** - Profile on target platforms
❌ **Don't trust single runs** - Run multiple profiles for consistency

## Integration with Development

### Pre-commit Profiling

Before committing optimizations:

```bash
# 1. Baseline
./scripts/profile_mining.sh rx/0 60 > baseline.log

# 2. Make changes
# ... edit code ...

# 3. Rebuild
cd build && make -j$(nproc)

# 4. Profile again
./scripts/profile_mining.sh rx/0 60 > optimized.log

# 5. Compare
diff baseline.log optimized.log
```

### CI/CD Integration

Add performance regression detection:

```yaml
# .github/workflows/performance.yml
- name: Benchmark
  run: |
    ./scripts/profile_mining.sh rx/0 60
    # Compare with baseline, fail if regression >5%
```

## Profiling Results Repository

All profiling results are saved to `profiling_results/`:

```
profiling_results/
├── profile_randomx_20251202_140000.sample.txt
├── profile_randomx_20251202_140000.stdout.txt
├── profile_randomx_20251202_140000.stats.txt
├── profile_randomx_20251202_140000.summary.txt
└── profile_randomx_20251202_140000.analysis.md
```

**File descriptions:**
- `*.sample.txt` - CPU sampling data (raw profiler output)
- `*.stdout.txt` - Miner output with hashrate information
- `*.stats.txt` - CPU/memory resource usage
- `*.summary.txt` - Quick text summary
- `*.analysis.md` - Detailed analysis report (from analyze_profile.sh)

## References

### Documentation
- [PERFORMANCE.md](../PERFORMANCE.md) - Performance optimization guide
- [RANDOMX_ANALYSIS.md](RANDOMX_ANALYSIS.md) - RandomX implementation analysis
- [MEMORY_MANAGEMENT_ANALYSIS.md](MEMORY_MANAGEMENT_ANALYSIS.md) - Memory system analysis
- [WORKER_THREADING_ANALYSIS.md](WORKER_THREADING_ANALYSIS.md) - Threading architecture

### External Resources
- [Linux perf Wiki](https://perf.wiki.kernel.org/)
- [Brendan Gregg's Flame Graphs](https://www.brendangregg.com/flamegraphs.html)
- [Intel VTune Documentation](https://software.intel.com/content/www/us/en/develop/tools/vtune-profiler.html)
- [NVIDIA Nsight Compute](https://developer.nvidia.com/nsight-compute)
- [AMD ROCProfiler](https://rocmdocs.amd.com/en/latest/ROCm_Tools/ROCm-Tools.html)

---

**Last Updated:** 2025-12-02
**Maintainers:** X Development Team
