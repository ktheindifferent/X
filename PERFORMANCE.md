# X Miner Performance Guide

This guide provides information on optimizing X miner performance for different hardware configurations and mining algorithms.

## Table of Contents

- [CPU Mining Optimization](#cpu-mining-optimization)
- [GPU Mining Optimization](#gpu-mining-optimization)
- [Memory Optimization](#memory-optimization)
- [Algorithm-Specific Tips](#algorithm-specific-tips)
- [Benchmarking](#benchmarking)
- [Troubleshooting Performance Issues](#troubleshooting-performance-issues)

## CPU Mining Optimization

### RandomX (TARI, Monero)

RandomX is CPU-intensive and benefits greatly from proper configuration.

#### Hardware Requirements
- **Minimum**: 2GB RAM per mining thread
- **Recommended**: 4GB+ RAM, modern CPU with AES-NI
- **Optimal**: CPU with large L3 cache (2MB+ per thread)

#### Configuration Tips

**1. Huge Pages (Critical for Performance)**

Enable huge pages for 10-30% performance increase:

**Linux:**
```bash
# Check current setting
cat /proc/sys/vm/nr_hugepages

# Enable 1GB pages (requires root)
sudo sysctl -w vm.nr_hugepages=1280

# Make permanent
echo "vm.nr_hugepages=1280" | sudo tee -a /etc/sysctl.conf

# Load MSR module for RandomX optimizations
sudo modprobe msr
```

**Windows:**
```powershell
# Run as Administrator
# Large pages are automatically enabled for the miner process
```

**macOS:**
```bash
# Huge pages are not available on macOS
# Use the standard configuration
```

**2. Thread Configuration**

Optimal thread count depends on CPU cache:

```json
{
    "cpu": {
        "enabled": true,
        "huge-pages": true,
        "max-threads-hint": 100,
        "priority": 2
    },
    "randomx": {
        "init": -1,
        "mode": "auto",
        "1gb-pages": false,
        "numa": true
    }
}
```

**Thread Count Guidelines:**
- **Intel**: L3 cache size / 2MB = thread count
- **AMD Ryzen**: L3 cache size / 2MB = thread count
- **AMD ThreadRipper**: Use NUMA-aware configuration
- **Apple Silicon**: Use all P-cores, exclude E-cores

**3. Scratchpad Prefetch Mode Tuning (NEW - 3-10% Performance Gain)**

The scratchpad prefetch mode controls how memory is prefetched during RandomX execution. **Auto-detection is enabled by default** and selects the best mode for your CPU.

**Available Modes:**
- **Mode 0**: Disabled (no prefetching) - For testing/baseline
- **Mode 1**: PREFETCHT0 - Prefetch to all cache levels (L1/L2/L3) - Default for older CPUs
- **Mode 2**: PREFETCHNTA - Non-temporal prefetch (bypass L1) - Minimizes cache pollution
- **Mode 3**: Forced Read (MOV) - Actually loads data into cache - **Best for modern CPUs**

**Auto-Detection Logic:**
- **AMD Zen4/Zen5**: Automatically uses Mode 3 (3-10% faster)
- **Intel Ice Lake and newer**: Automatically uses Mode 3 (2-7% faster)
- **Older CPUs**: Uses Mode 1 (safe default)

**Configuration Examples:**

Auto mode (recommended - lets X choose):
```json
{
    "randomx": {
        "mode": "auto"
    }
}
```

Force mode 3 for maximum performance on modern CPUs:
```json
{
    "randomx": {
        "scratchpad_prefetch_mode": 3
    }
}
```

**CPU-Specific Recommendations:**

| CPU Family | Recommended Mode | Expected Gain |
|------------|------------------|---------------|
| AMD Ryzen 7000/9000 (Zen4/Zen5) | 3 (auto) | +3-10% |
| AMD Ryzen 5000 (Zen3) | 1 or 3 (test both) | +0-5% |
| AMD Ryzen 3000/2000 (Zen2/+) | 1 (auto) | Baseline |
| Intel 12th/13th/14th Gen | 3 (auto) | +2-7% |
| Intel 10th/11th Gen (Ice Lake+) | 3 (auto) | +2-5% |
| Intel older than 10th Gen | 1 (auto) | Baseline |

**Benchmarking Your Configuration:**

Test all modes to find the best for your specific CPU:
```bash
# Test with auto-detection (recommended)
./x --bench=rx/0 --bench-submit

# Test mode 0 (disabled - baseline)
# Edit config.json: "scratchpad_prefetch_mode": 0
./x --config=config.json --bench=rx/0

# Test mode 3 (forced read - usually fastest on modern CPUs)
# Edit config.json: "scratchpad_prefetch_mode": 3
./x --config=config.json --bench=rx/0
```

**Example Configurations:**
- `config_prefetch_auto.json` - Auto-detection (recommended)
- `config_prefetch_mode3.json` - Forced mode 3 for Zen4/5 and Ice Lake+

**3. CPU Affinity**

For multi-CPU systems or NUMA:

```json
{
    "cpu": {
        "enabled": true,
        "priority": 2,
        "affinity": [0, 1, 2, 3, 4, 5, 6, 7]
    }
}
```

**4. MSR Modifications (Advanced)**

For Ryzen CPUs, MSR modifications can improve performance:

```bash
# Linux only - increases randomx performance on Ryzen
sudo ./scripts/randomx_boost.sh
```

### CryptoNight Variants

Lower memory requirements (2MB per thread):

```json
{
    "cpu": {
        "enabled": true,
        "huge-pages": true,
        "memory-pool": false,
        "max-threads-hint": 100
    }
}
```

**Optimal Thread Count:**
- Physical cores - 1 (leave one core for system)
- For HyperThreading: test with and without

### GhostRider (Raptoreum)

Hybrid algorithm requiring both CPU and cache optimization:

```json
{
    "cpu": {
        "enabled": true,
        "huge-pages": true,
        "max-threads-hint": 50
    }
}
```

## GPU Mining Optimization

### KawPow (Ravencoin)

GPU-intensive algorithm benefiting from memory bandwidth.

#### NVIDIA GPUs

**Configuration:**
```json
{
    "cuda": {
        "enabled": true,
        "nvml": true,
        "cuda-bfactor-hint": 8,
        "cuda-bsleep-hint": 100
    }
}
```

**Optimization Tips:**
- Increase power limit: +10-20%
- Overclock memory: +500-1000 MHz
- Core clock: +50-150 MHz
- Monitor temperature: keep under 75°C

**NVIDIA Settings (Linux):**
```bash
# Increase power limit (replace 0 with your GPU number)
nvidia-smi -i 0 -pl 250

# Set fan speed
nvidia-settings -a "[gpu:0]/GPUFanControlState=1" -a "[fan:0]/GPUTargetFanSpeed=70"
```

#### AMD GPUs

**Configuration:**
```json
{
    "opencl": {
        "enabled": true,
        "platform": "AMD",
        "adl": true
    }
}
```

**Optimization Tips:**
- Core clock: 1200-1400 MHz
- Memory clock: 1800-2000 MHz
- Voltage: reduce by 50-100mV
- Monitor HBM/GDDR6 temperature

**AMD Settings (Linux):**
```bash
# ROCm tools
rocm-smi --setfan 70
rocm-smi --setperflevel high
```

### OpenCL General Tips

```json
{
    "opencl": {
        "enabled": true,
        "cache": true,
        "platform": "AMD",
        "devices": [0, 1],
        "adl": true
    }
}
```

## Memory Optimization

### RAM Requirements by Algorithm

| Algorithm | Per Thread | Recommended Total |
|-----------|-----------|------------------|
| RandomX   | 2GB       | 8GB+            |
| CryptoNight | 2MB     | 4GB+            |
| KawPow    | GPU VRAM  | 4GB+ GPU        |
| GhostRider | Variable | 8GB+            |

### Memory Pool Configuration

For better memory management:

```json
{
    "cpu": {
        "memory-pool": true,
        "huge-pages": true
    }
}
```

**Memory Pool Benefits:**
- Reduced allocation overhead
- Better cache locality
- Lower latency

### Avoiding Memory Issues

**Symptoms of insufficient RAM:**
- Hashrate drops over time
- System freezing/swapping
- Miner crashes with OOM errors

**Solutions:**
1. Reduce thread count
2. Disable memory-intensive apps
3. Add swap space (not ideal)
4. Upgrade RAM

## Algorithm-Specific Tips

### RandomX Performance Factors

**1. CPU Cache Size** (Most Important)
- Larger L3 cache = more threads
- 2MB L3 per thread optimal

**2. Memory Bandwidth**
- Dual-channel RAM recommended
- 3200MHz+ for best results

**3. AES-NI Support**
- Modern CPUs only
- 2-4x performance improvement

**4. JIT Compiler**
- Enabled by default
- Requires executable memory pages

### CryptoNight Variants

**CN/0, CN/1, CN/2:**
```json
{
    "cpu": {
        "cn/0": false,
        "asm": true,
        "hw-aes": null
    }
}
```

**Performance Tips:**
- Use ASM optimizations
- Enable AES-NI
- One thread per core

### KawPow Performance

**GPU-Specific:**
- Memory bandwidth critical
- Power limit matters most
- Temperature affects hashrate

**Tuning Steps:**
1. Increase power limit
2. Overclock memory
3. Fine-tune core clock
4. Monitor for stability

## Benchmarking

### Built-in Benchmark

Test hashrate without pool connection:

```bash
# Basic benchmark (1M iterations)
./x --bench=1M

# Extended benchmark (10M iterations)
./x --bench=10M --cpu-no-yield

# Specific algorithm
./x --bench=1M --algo=rx/0

# With configuration file
./x --bench=1M -c config.json
```

### Interpreting Results

Benchmark output shows:
- Hashrate (H/s)
- Algorithm performance
- Thread efficiency

**Example Output:**
```
[2025-12-02 12:00:00.000]  BENCH  algo rx/0 prep 5000 ms
[2025-12-02 12:00:05.000]  BENCH  algo rx/0 1000000 hashes time 25.5s H/s 39215
```

### Performance Targets

**RandomX (rx/0):**
| CPU | Expected Hashrate |
|-----|------------------|
| Ryzen 5 5600X | ~8000 H/s |
| Ryzen 9 5950X | ~18000 H/s |
| Intel i9-12900K | ~15000 H/s |
| Apple M1 Max | ~12000 H/s |

**KawPow:**
| GPU | Expected Hashrate |
|-----|------------------|
| RTX 3060 Ti | ~25 MH/s |
| RTX 3080 | ~45 MH/s |
| RX 6800 XT | ~35 MH/s |
| RX 6900 XT | ~40 MH/s |

### Continuous Monitoring

Monitor hashrate over time:

```bash
# With logging
./x -c config.json --log-file=mining.log

# Check average hashrate
./x -c config.json --print-time=60
```

## Troubleshooting Performance Issues

### Low Hashrate

**Symptoms:**
- Below expected performance
- Fluctuating hashrate
- Poor efficiency

**Causes & Solutions:**

1. **Huge Pages Not Enabled**
   - Solution: Enable huge pages (see above)
   - Expected gain: 10-30%

2. **Wrong Thread Count**
   - Solution: Adjust based on L3 cache
   - Test different counts

3. **Thermal Throttling**
   - Solution: Improve cooling
   - Monitor temperatures

4. **Background Processes**
   - Solution: Close unnecessary apps
   - Use task priority settings

5. **Power Settings**
   - Solution: Set to "High Performance"
   - Disable CPU throttling

### Hashrate Degradation Over Time

**Causes:**
- Memory leaks (rare)
- Thermal throttling
- Power management
- Dataset resets

**Solutions:**
1. Monitor system temperature
2. Check memory usage
3. Review power settings
4. Update miner version

### GPU Issues

**Low GPU Hashrate:**
1. Check GPU usage (should be 95-100%)
2. Monitor memory clock
3. Check power limit
4. Update GPU drivers

**GPU Crashes:**
1. Reduce overclock
2. Increase power limit
3. Lower intensity settings
4. Check GPU temperatures

### System Instability

**Symptoms:**
- Random crashes
- System freezes
- Blue screen (Windows)
- Kernel panic (Linux/macOS)

**Solutions:**
1. Reduce overclock/undervolt
2. Check RAM stability (memtest)
3. Verify CPU temperatures
4. Check PSU capacity
5. Test with lower thread count

## Advanced Optimization

### NUMA-Aware Configuration

For multi-CPU systems:

```json
{
    "cpu": {
        "enabled": true
    },
    "randomx": {
        "numa": true,
        "mode": "auto"
    }
}
```

### Custom Thread Configuration

Manual thread configuration for experts:

```json
{
    "cpu": {
        "enabled": true,
        "max-threads-hint": 100,
        "priority": 2,
        "*": [
            {"affinity": 0, "intensity": 2},
            {"affinity": 2, "intensity": 2},
            {"affinity": 4, "intensity": 2},
            {"affinity": 6, "intensity": 2}
        ]
    }
}
```

### Performance Profiling

Use system tools to identify bottlenecks:

**Linux:**
```bash
# CPU usage
top -H -p $(pidof x)

# Detailed profiling
perf record -g ./x --bench=1M
perf report

# Memory usage
/usr/bin/time -v ./x --bench=1M
```

**macOS:**
```bash
# Monitor with Activity Monitor
# Or use Instruments.app for detailed profiling
```

**Windows:**
```powershell
# Use Task Manager (Performance tab)
# Or Windows Performance Analyzer
```

## Best Practices

1. **Start Conservative**
   - Use auto-configuration first
   - Test stability before optimization

2. **Change One Setting at a Time**
   - Easier to identify improvements
   - Avoid unstable configurations

3. **Monitor Everything**
   - Hashrate
   - Temperature
   - Power consumption
   - System stability

4. **Document Your Settings**
   - Save working configurations
   - Note hardware-specific tweaks

5. **Keep Software Updated**
   - Update X miner regularly
   - Update GPU drivers
   - Update system firmware

## Performance Checklist

Before reporting performance issues, verify:

- [ ] Huge pages enabled (Linux)
- [ ] Correct thread count for CPU
- [ ] No thermal throttling
- [ ] Background apps closed
- [ ] Latest miner version
- [ ] Proper GPU drivers
- [ ] Power settings optimized
- [ ] Sufficient RAM available
- [ ] No antivirus interference

## Getting Help

If performance is still poor after optimization:

1. Run benchmark: `./x --bench=10M`
2. Check hardware with system tools
3. Review configuration file
4. Search existing issues on GitHub
5. Create new issue with:
   - Hardware specifications
   - Benchmark results
   - Configuration file
   - System information

---

**Note**: Performance varies by hardware. These are guidelines, not guarantees. Always test changes in a controlled manner.
