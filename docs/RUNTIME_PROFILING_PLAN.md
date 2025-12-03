# X Miner Runtime Profiling Plan

**Date:** 2025-12-02
**Status:** Ready for execution
**Prerequisites:** Profiling infrastructure complete, architecture analysis complete

## Overview

This document outlines the comprehensive runtime profiling plan for X miner, based on the architectural analysis completed in Phase 2. The goal is to validate theoretical bottlenecks with actual performance data and identify optimization opportunities.

## Profiling Objectives

### Primary Objectives
1. **Validate Architecture Analysis** - Confirm theoretical bottlenecks identified in analysis documents
2. **Identify Performance Hotspots** - Find functions consuming >5% CPU time
3. **Measure Algorithm Efficiency** - Compare relative performance of different PoW algorithms
4. **Baseline Performance** - Establish baseline metrics before optimizations
5. **Platform Differences** - Compare macOS vs Linux performance characteristics

### Secondary Objectives
1. Memory access patterns and cache efficiency
2. Thread synchronization overhead
3. JIT compilation impact on RandomX
4. Network latency effects on hashrate
5. GPU kernel efficiency (if applicable)

## Profiling Methodology

### Phase 1: Baseline CPU Profiling (Priority: HIGH)

**Algorithms to Profile:**
- RandomX (rx/0) - Primary focus
- CryptoNight (cn/r) - Secondary
- CryptoNight-Lite (cn-lite/1) - Comparison

**Configuration:**
- Thread count: All cores (no affinity)
- Duration: 60 seconds per test
- Iterations: 10M for RandomX, 1M for CN variants
- Huge pages: Disabled first, then enabled for comparison

**Tools:**
- **macOS**: `sample` (CPU sampling), `Instruments` (detailed analysis)
- **Linux**: `perf record`, `perf stat` (hardware counters)
- **Windows**: Visual Studio Profiler, Intel VTune

**Metrics to Collect:**
- Hashrate (H/s)
- CPU utilization (%)
- Memory usage (RSS, VSZ)
- L3 cache miss rate
- Instructions per cycle (IPC)
- Branch miss rate

### Phase 2: Memory Profiling (Priority: MEDIUM)

**Focus Areas** (based on MEMORY_MANAGEMENT_ANALYSIS.md):
1. Huge pages impact measurement
2. NUMA node placement efficiency
3. Memory allocation patterns
4. TLB miss rates

**Test Scenarios:**
```bash
# Scenario 1: No huge pages
./x --bench=10M --no-huge-pages

# Scenario 2: 2MB huge pages
sudo ./scripts/setup_hugepages.sh
./x --bench=10M

# Scenario 3: 1GB huge pages (Linux only)
sudo ./scripts/enable_1gb_pages.sh
./x --bench=10M --huge-pages
```

**Expected Results** (from analysis):
- 2MB huge pages: 10-20% improvement
- 1GB huge pages: 15-30% improvement
- NUMA-aware allocation: 5-10% improvement on multi-socket systems

### Phase 3: Thread Profiling (Priority: MEDIUM)

**Focus Areas** (based on WORKER_THREADING_ANALYSIS.md):
1. Job distribution overhead
2. Lock contention in JobResults::submit()
3. Thread wake-up latency
4. CPU affinity impact

**Test Scenarios:**
```bash
# Scenario 1: No affinity
./x --bench=10M

# Scenario 2: With affinity
./x --bench=10M --cpu-affinity=0

# Scenario 3: Half threads
./x --bench=10M --threads=8  # on 16-core system

# Scenario 4: Over-subscription
./x --bench=10M --threads=32  # on 16-core system
```

**Metrics:**
- Hashrate scaling vs thread count
- Lock wait time (from perf lock contention)
- Thread context switches
- CPU migration count

### Phase 4: JIT Profiling - RandomX (Priority: HIGH)

**Focus Areas** (based on RANDOMX_ANALYSIS.md):
1. JIT compilation time
2. VM execution efficiency
3. Dataset access patterns
4. Instruction cache efficiency

**Test Scenarios:**
```bash
# Scenario 1: Light mode (interpreted)
./x --bench=10M --randomx-mode=light

# Scenario 2: Fast mode (JIT)
./x --bench=10M --randomx-mode=fast

# Scenario 3: Check instruction set usage
# Profile and verify AVX2/AVX-512 usage in JIT code
```

**Expected Hotspots:**
- `randomx::CompiledVm::execute()` - Should be 80-90% of CPU time
- `randomx::JitCompilerX86::generateProgram()` - Should be <1% (one-time cost)
- `randomx::Dataset::getItem()` - 5-10% of time

**Optimization Opportunities to Validate:**
1. AVX-512 usage in JIT (vs current AVX2)
2. Better instruction scheduling
3. Cache prefetching in dataset access
4. Superscalar register allocation improvement

### Phase 5: Network Profiling (Priority: LOW)

**Focus Areas** (based on NETWORK_ANALYSIS.md):
1. Result submission latency
2. Job processing overhead
3. Stratum protocol efficiency

**Test Scenarios:**
```bash
# Benchmark mode (no network)
./x --bench=10M

# Real pool mining (with network)
./x -o pool.tari.com:3333 -u WALLET

# Compare hashrates to measure network overhead
```

**Expected Findings:**
- Benchmark mode should be 1-2% faster (no network overhead)
- Job changes should not cause >50ms hashrate drops
- Result submission should be <1% of CPU time

### Phase 6: Differential Profiling (Priority: MEDIUM)

**Objective:** Compare performance before and after optimizations

**Methodology:**
1. Profile baseline (current code)
2. Implement optimization
3. Profile optimized version
4. Calculate improvement
5. Verify no regressions

**Template:**
```bash
# Baseline
./scripts/profile_mining.sh rx/0 60
cp profiling_results/profile_*.txt baseline_profile.txt

# After optimization
# ... make code changes ...
make clean && make -j$(nproc)
./scripts/profile_mining.sh rx/0 60
cp profiling_results/profile_*.txt optimized_profile.txt

# Compare
diff -u baseline_profile.txt optimized_profile.txt
```

## Expected Bottlenecks by Algorithm

### RandomX (Based on RANDOMX_ANALYSIS.md)

**Expected CPU Time Distribution:**
- VM execution (executeProgram): 80-85%
- Dataset access (getItem): 5-10%
- Hash functions (Blake2, AES): 8-12%
- Memory operations: 2-5%
- Other: <3%

**Top Expected Hot Functions:**
1. `randomx::CompiledVm::execute()` or `randomx::InterpretedVm::execute()`
2. `randomx::executeProgram()` (inner VM loop)
3. `randomx::IntegerMath()` operations
4. `randomx::FloatMath()` operations
5. `randomx::Dataset::getItem()`
6. `randomx::hashAes1Rx4()`
7. `randomx::Cache::getMemory()`
8. `blake2b()` hash function
9. `_mm256_*` intrinsics (AVX2 operations)
10. Memory load/store operations

**Known Optimization Opportunities:**
1. **JIT - AVX-512 upgrade** (Est. 5-10% improvement)
   - Current: AVX2 (256-bit vectors)
   - Target: AVX-512 (512-bit vectors)
   - File: `src/crypto/randomx/jit_compiler_x86.cpp`

2. **JIT - Better instruction scheduling** (Est. 2-5% improvement)
   - Reduce pipeline stalls
   - Better register allocation
   - File: `src/crypto/randomx/jit_compiler_x86.cpp`

3. **Dataset cache prefetching** (Est. 3-7% improvement)
   - Prefetch dataset items before needed
   - Reduce memory latency
   - File: `src/crypto/randomx/dataset.cpp`

### CryptoNight (Based on Architecture)

**Expected CPU Time Distribution:**
- AES operations: 60-70%
- Memory mixing: 20-25%
- Hash finalization: 5-10%
- Other: <5%

**Top Expected Hot Functions:**
1. `cn_slow_hash()` variants
2. AES round functions (`_mm_aesenc_si128`)
3. Memory scratchpad operations
4. Keccak hash
5. Integer arithmetic

**Known Optimization Opportunities:**
1. **AES-NI utilization** (verify enabled)
2. **Memory alignment** (2MB huge pages critical)
3. **Cache-friendly access patterns**

### CryptoNight-Lite

**Expected CPU Time Distribution:**
Similar to CryptoNight but lighter:
- AES operations: 55-65%
- Memory mixing: 20-30%
- Hash finalization: 8-12%

**Known Optimization Opportunities:**
1. Lower memory footprint (1MB vs 2MB)
2. Better L3 cache utilization
3. Potential for higher thread count

## Profiling Tools Configuration

### macOS - sample

```bash
# Basic sampling
sample $PID 60 -file profile.txt

# With call tree
sample $PID 60 -file profile.txt -fullCallGraph

# System-wide
sudo sample 60 -file system_profile.txt
```

### macOS - Instruments

```bash
# Time Profiler
instruments -t 'Time Profiler' -D profile.trace ./x --bench=10M

# System Trace (thread scheduling)
instruments -t 'System Trace' -D trace.trace ./x --bench=10M

# Allocations
instruments -t 'Allocations' -D alloc.trace ./x --bench=10M
```

### Linux - perf

```bash
# CPU profiling with call graph
perf record -g --call-graph dwarf -F 1000 ./x --bench=10M

# View report
perf report --stdio

# Hardware counters
perf stat -e cycles,instructions,cache-references,cache-misses,branches,branch-misses ./x --bench=10M

# Cache analysis
perf stat -e L1-dcache-loads,L1-dcache-load-misses,LLC-loads,LLC-load-misses ./x --bench=10M

# Lock contention
perf lock record ./x --bench=10M
perf lock report
```

### Linux - valgrind/callgrind

```bash
# Call graph profiling
valgrind --tool=callgrind \
         --dump-instr=yes \
         --collect-jumps=yes \
         --cache-sim=yes \
         ./x --bench=1M --threads=1

# Visualize
kcachegrind callgrind.out.*
```

### Linux - cachegrind

```bash
# Cache simulation
valgrind --tool=cachegrind ./x --bench=1M --threads=1

# Annotate source
cg_annotate cachegrind.out.* --auto=yes
```

## Performance Baseline Targets

### RandomX (Based on Industry Standards)

**Expected Performance (per thread):**
- **Modern CPU (Ryzen 5000/Intel 12th gen)**: 1,000-1,500 H/s per thread
- **Older CPU (Ryzen 3000/Intel 9th gen)**: 600-1,000 H/s per thread
- **Apple M1**: 800-1,200 H/s per thread
- **Server CPU (EPYC/Xeon)**: 1,200-1,800 H/s per thread

**Scaling:**
- Linear scaling expected up to core count
- 95%+ efficiency with proper affinity
- 10-30% boost with huge pages

### CryptoNight

**Expected Performance (per thread):**
- **Modern CPU**: 600-900 H/s per thread
- **Older CPU**: 400-600 H/s per thread
- **Server CPU**: 700-1,000 H/s per thread

## Profiling Schedule

### Week 1: Baseline Profiling
- **Day 1-2**: RandomX profiling (all scenarios)
- **Day 3**: CryptoNight profiling
- **Day 4**: Thread scaling analysis
- **Day 5**: Memory profiling (huge pages impact)

### Week 2: Deep Analysis
- **Day 1-2**: JIT compiler analysis
- **Day 3**: Hot function analysis and optimization planning
- **Day 4**: Differential profiling (test optimizations)
- **Day 5**: Report generation

### Week 3: Advanced Profiling
- **Day 1-2**: Hardware counter analysis
- **Day 3**: Cache profiling
- **Day 4**: NUMA profiling (if multi-socket available)
- **Day 5**: Final report and recommendations

## Expected Findings Summary

Based on architecture analysis, we expect to find:

### ✅ Confirmed Expectations
1. **RandomX VM execution dominates** (80-90% CPU time)
2. **AES operations dominate CryptoNight** (60-70% CPU time)
3. **Huge pages provide 10-30% improvement**
4. **Lock contention in result submission is minimal** (<1%)
5. **Network overhead is negligible in benchmark mode**

### 🔍 Areas Requiring Validation
1. **Actual IPC of JIT-generated code** - Need to measure
2. **Cache miss rates** - Theoretical vs actual
3. **Memory bandwidth utilization** - May be bottleneck
4. **Thread scaling efficiency** - Verify linear scaling
5. **JIT compilation overhead** - Measure one-time cost

### 🎯 Optimization Opportunities to Prioritize
1. **AVX-512 JIT upgrade** (High impact: 5-10%)
2. **Dataset prefetching** (Medium impact: 3-7%)
3. **Instruction scheduling** (Low impact: 2-5%)
4. **Memory alignment improvements** (Low impact: 1-3%)

## Success Criteria

Profiling is considered successful when:

1. ✅ **Baseline established** - Clean profiling data for all algorithms
2. ✅ **Hotspots identified** - Top 10 functions consuming >80% time identified
3. ✅ **Bottlenecks validated** - Architecture analysis predictions confirmed
4. ✅ **Optimization targets prioritized** - Clear list of what to optimize first
5. ✅ **Performance metrics documented** - Hashrate, IPC, cache misses recorded
6. ✅ **Comparison data available** - Different configurations compared

## Deliverables

### Documentation
1. **Profiling results** - Raw profiling data files
2. **Performance report** - Markdown report with findings
3. **Optimization roadmap** - Prioritized list of optimizations
4. **Benchmark results** - Comparative performance data

### Data Files
- `profiling_results/profile_randomx_*.txt` - RandomX profiles
- `profiling_results/profile_cn_*.txt` - CryptoNight profiles
- `profiling_results/algorithm_comparison_*.md` - Comparison report
- `profiling_results/optimization_plan_*.md` - Optimization roadmap

## Next Steps After Profiling

1. **Review findings** - Analyze all profiling data
2. **Validate with team** - Discuss optimization priorities
3. **Create implementation plan** - Detailed plan for top optimizations
4. **Benchmark improvements** - Before/after measurements
5. **Document learnings** - Update architecture documents with real data

---

## Quick Start

To begin profiling:

```bash
# 1. Profile all algorithms (takes ~5 minutes)
./scripts/profile_all_algorithms.sh

# 2. Profile single algorithm
./scripts/profile_mining.sh rx/0 60

# 3. Analyze results
./scripts/analyze_profile.sh profiling_results/profile_randomx_*

# 4. Compare configurations
# Run with different settings and compare results
```

---

## References

- [RANDOMX_ANALYSIS.md](RANDOMX_ANALYSIS.md) - RandomX architecture
- [MEMORY_MANAGEMENT_ANALYSIS.md](MEMORY_MANAGEMENT_ANALYSIS.md) - Memory system
- [WORKER_THREADING_ANALYSIS.md](WORKER_THREADING_ANALYSIS.md) - Threading architecture
- [NETWORK_ANALYSIS.md](NETWORK_ANALYSIS.md) - Network layer
- [PROFILING.md](PROFILING.md) - Profiling guide
- [PERFORMANCE.md](../PERFORMANCE.md) - Performance optimization guide

---

**Last Updated:** 2025-12-02
**Status:** Ready for execution
**Owner:** X Development Team
