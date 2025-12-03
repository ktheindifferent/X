# Quick Profiling Guide for macOS

## Prerequisites

✅ Already complete:
- X binary built: `build/x`
- Profiling scripts: `scripts/profile_*.sh`
- `sample` tool (built into macOS)

## Option 1: Quick Profile (2 minutes)

Profile RandomX for 30 seconds:

```bash
# From X project directory
./scripts/profile_mining.sh rx/0 30
```

**What happens:**
1. Miner starts in benchmark mode
2. `sample` collects CPU data for 30 seconds
3. Results saved to `profiling_results/profile_randomx_TIMESTAMP.*`

**View results:**
```bash
# Quick summary
cat profiling_results/profile_randomx_*.summary.txt

# Detailed analysis
./scripts/analyze_profile.sh profiling_results/profile_randomx_20*
```

## Option 2: Full Comparison (5 minutes)

Profile all algorithms:

```bash
./scripts/profile_all_algorithms.sh
```

**What happens:**
1. Profiles RandomX (45 seconds)
2. Profiles CryptoNight (45 seconds)
3. Profiles CryptoNight-Lite (45 seconds)
4. Generates comparison report

**View results:**
```bash
# Open the comparison report
cat profiling_results/algorithm_comparison_*.md | less
```

## Option 3: Extended Profile (recommended for accurate data)

Profile with longer duration for more accurate results:

```bash
# 2 minutes of profiling
./scripts/profile_mining.sh rx/0 120
```

## Understanding the Output

### Files Created

Each profiling run creates 4 files in `profiling_results/`:

```
profile_randomx_20251202_HHMMSS.sample.txt    # CPU sampling data
profile_randomx_20251202_HHMMSS.stdout.txt    # Miner output with hashrate
profile_randomx_20251202_HHMMSS.stats.txt     # CPU/memory usage
profile_randomx_20251202_HHMMSS.summary.txt   # Quick summary
```

### Key Metrics to Look For

**1. Hashrate** (from stdout.txt or summary.txt):
```
speed 10s/60s/15m 15234.5 15198.2 n/a H/s
```
- 15.2 KH/s on RandomX = good for typical CPU

**2. CPU Usage** (from stats.txt):
```
%CPU  %MEM    RSS
965.0  7.3   2433676
```
- 965% = 9.65 cores utilized (good on 10+ core system)

**3. Hot Functions** (from sample.txt):
Look for functions consuming >10% of time - these are optimization targets.

## Common Commands

```bash
# Profile RandomX (default)
./scripts/profile_mining.sh

# Profile for longer (more accurate)
./scripts/profile_mining.sh rx/0 120

# Profile different algorithm
./scripts/profile_mining.sh cn/r 60

# Profile all algorithms
./scripts/profile_all_algorithms.sh

# Analyze any profile
./scripts/analyze_profile.sh profiling_results/profile_randomx_*

# Clean old results
rm -rf profiling_results/*
```

## Interpreting Results

### Good Performance Indicators
- ✅ CPU usage >900% on 10-core system
- ✅ Memory usage 2-3 GB for RandomX
- ✅ Hashrate matches expected for your CPU model
- ✅ Hot functions are in algorithm code (randomx::*, cn_*)

### Performance Issues to Investigate
- ⚠️ CPU usage <500% on multi-core system
- ⚠️ Hashrate significantly below expected
- ⚠️ Hot functions in unexpected areas (locks, memory allocation)
- ⚠️ High time in system calls

## Advanced: Using Instruments

For deeper analysis, use Xcode Instruments:

```bash
# Install Xcode Command Line Tools (if not already)
xcode-select --install

# Profile with Instruments Time Profiler
instruments -t 'Time Profiler' \
    -D profiling_results/instruments_profile.trace \
    build/x --bench=10M

# Open in Instruments app
open profiling_results/instruments_profile.trace
```

**Instruments gives you:**
- Function-level CPU time breakdown
- Call trees with percentages
- Timeline view of execution
- Thread-by-thread analysis

## Troubleshooting

### "Permission denied" error
```bash
chmod +x scripts/*.sh
```

### "Miner failed to start"
Check that binary exists and works:
```bash
ls -lh build/x
./build/x --version
```

### "sample: command not found"
`sample` is built into macOS - if missing, you may need to install Xcode Command Line Tools:
```bash
xcode-select --install
```

### Low hashrate
1. Check huge pages: `sysctl vm.stats.vm.v_free_count`
2. Check CPU throttling: `pmset -g thermlog`
3. Ensure no other CPU-intensive apps running

## Next Steps

After profiling:

1. **Review the results** - Look at hot functions
2. **Compare with baseline** - Is performance as expected?
3. **Identify bottlenecks** - What's taking the most time?
4. **Plan optimizations** - Based on profiling data
5. **Re-profile after changes** - Measure improvement

## Example Session

Here's a complete profiling session:

```bash
# 1. Profile RandomX
./scripts/profile_mining.sh rx/0 60

# 2. View summary
cat profiling_results/profile_randomx_*.summary.txt

# 3. Analyze
./scripts/analyze_profile.sh profiling_results/profile_randomx_*

# 4. View detailed analysis
cat profiling_results/profile_randomx_*.analysis.md

# 5. Profile all algorithms for comparison
./scripts/profile_all_algorithms.sh

# 6. View comparison
cat profiling_results/algorithm_comparison_*.md
```

## Expected Results on Your Mac

Based on your system, you should see approximately:

**Hashrate:**
- RandomX: Varies by CPU model (check PERFORMANCE.md for estimates)
- CryptoNight: Higher H/s than RandomX
- CryptoNight-Lite: Highest H/s

**CPU Usage:**
- Should be near 100% × number of cores
- RandomX scales well with cores

**Memory:**
- RandomX: 2-3 GB
- CryptoNight: ~500 MB
- CryptoNight-Lite: ~300 MB

---

For detailed profiling methodology, see [docs/RUNTIME_PROFILING_PLAN.md](docs/RUNTIME_PROFILING_PLAN.md)
