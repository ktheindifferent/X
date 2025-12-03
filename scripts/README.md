# X Miner Utility Scripts

This directory contains utility scripts for building, configuring, and optimizing X miner.

## Table of Contents

- [System Configuration](#system-configuration)
- [Performance Optimization](#performance-optimization)
- [Build Scripts](#build-scripts)
- [Benchmarking](#benchmarking)
- [Examples](#examples)

---

## System Configuration

### check_system.sh

**Purpose**: Comprehensive system capability checker

**Usage**:
```bash
./scripts/check_system.sh
```

**What it checks**:
- Operating system and kernel version
- CPU model, cores, and features (AES-NI)
- L3 cache size and recommended thread count
- RAM size and availability
- Huge pages status
- MSR module status (for Ryzen optimization)
- NUMA configuration
- GPU detection (NVIDIA and AMD)
- Build dependencies
- Performance recommendations

**Output**: Detailed report with recommendations for optimal configuration

**Supported Platforms**: Linux, macOS

---

### setup_hugepages.sh

**Purpose**: Interactive huge pages setup for Linux

**Usage**:
```bash
sudo ./scripts/setup_hugepages.sh [num_pages]
```

**Parameters**:
- `num_pages` (optional): Number of 2MB huge pages to allocate (default: 1280 = 2.5GB)

**Features**:
- Checks current huge pages status
- Calculates memory requirements
- Verifies sufficient free memory
- Sets huge pages configuration
- Option to make setting permanent (adds to `/etc/sysctl.conf`)

**Example**:
```bash
# Allocate 2048 pages (4GB) and make permanent
sudo ./scripts/setup_hugepages.sh 2048
```

**Why it matters**: Huge pages can improve RandomX mining performance by 10-30%

**Supported Platforms**: Linux only

---

### enable_1gb_pages.sh

**Purpose**: Enable 1GB huge pages (Linux only)

**Usage**:
```bash
sudo ./scripts/enable_1gb_pages.sh
```

**Requirements**:
- Root access
- CPU support for 1GB pages
- Kernel boot parameter: `default_hugepagesz=1G hugepagesz=1G`

**What it does**:
- Sets up standard huge pages
- Configures 1GB pages for each NUMA node
- Allocates 3 pages per node

**Note**: 1GB pages provide the best performance but require special kernel configuration

**Supported Platforms**: Linux only (requires kernel support)

---

## Performance Optimization

### randomx_boost.sh

**Purpose**: Apply MSR (Model-Specific Register) optimizations for AMD Ryzen and Intel CPUs

**Usage**:
```bash
sudo ./scripts/randomx_boost.sh
```

**Requirements**:
- Root access
- MSR kernel module: `modprobe msr allow_writes=on`
- AMD Ryzen/EPYC or Intel CPU

**Supported CPUs**:
- **AMD Zen1/Zen2** (Ryzen 1000/2000 series)
- **AMD Zen3** (Ryzen 5000 series)
- **AMD Zen4** (Ryzen 7000 series)
- **AMD Zen5** (Ryzen 9000 series)
- **Intel** (all modern processors)

**What it does**:
- Loads MSR module with write permissions
- Detects CPU architecture
- Applies architecture-specific MSR optimizations
- Improves RandomX performance by tweaking CPU behavior

**Performance Impact**: 3-10% hashrate improvement on Ryzen CPUs

**Supported Platforms**: Linux only

**Warning**: Modifies CPU registers. Use at your own risk. Safe for mining but may affect system stability if other intensive workloads are running.

---

## Build Scripts

### build_deps.sh

**Purpose**: Downloads and builds dependencies

**Usage**:
```bash
./scripts/build_deps.sh
```

**What it builds**: Checks for missing dependencies and guides installation

**Supported Platforms**: Linux, macOS

---

### build.hwloc.sh / build.hwloc1.sh

**Purpose**: Build hwloc library for NUMA support

**Usage**:
```bash
./scripts/build.hwloc.sh     # hwloc 2.x
./scripts/build.hwloc1.sh    # hwloc 1.x (legacy)
```

**Output**: `hwloc` library for NUMA-aware memory allocation

**Use case**: Multi-socket systems, advanced NUMA optimizations

**Supported Platforms**: Linux, FreeBSD

---

### build.openssl.sh / build.openssl3.sh / build.libressl.sh

**Purpose**: Build OpenSSL/LibreSSL for TLS pool connections

**Usage**:
```bash
./scripts/build.openssl.sh     # OpenSSL 1.1.x
./scripts/build.openssl3.sh    # OpenSSL 3.x
./scripts/build.libressl.sh    # LibreSSL
```

**Use case**: Custom TLS/SSL library for secure pool connections

**Supported Platforms**: Linux, macOS, FreeBSD

---

### build.uv.sh

**Purpose**: Build libuv for async I/O

**Usage**:
```bash
./scripts/build.uv.sh
```

**Output**: `libuv` library for networking

**Use case**: Custom libuv version for compatibility

**Supported Platforms**: Linux, macOS, FreeBSD

---

## Benchmarking

### quick_benchmark.sh

**Purpose**: Quick performance benchmarking with different configurations

**Usage**:
```bash
./scripts/quick_benchmark.sh [binary_path] [thorough]
```

**Parameters**:
- `binary_path` (optional): Path to X binary (default: `./build/x`)
- `thorough` (optional): Run 10M iteration benchmark instead of 1M

**Tests performed**:
1. Default configuration
2. CPU no-yield mode (better for dedicated mining)
3. Huge pages test (if available)

**Example**:
```bash
# Quick benchmark (default)
./scripts/quick_benchmark.sh

# Thorough benchmark (takes ~5 minutes)
./scripts/quick_benchmark.sh ./build/x thorough

# Custom binary location
./scripts/quick_benchmark.sh /usr/local/bin/x
```

**Output**:
- Hashrate for each configuration
- Performance comparison
- Optimization recommendations

**Supported Platforms**: Linux, macOS

---

### benchmark_1M.cmd / benchmark_10M.cmd

**Purpose**: Windows batch files for benchmarking

**Usage**:
```cmd
benchmark_1M.cmd    :: Quick 1M iteration test
benchmark_10M.cmd   :: Thorough 10M iteration test
```

**Supported Platforms**: Windows only

---

## Profiling

### profile_mining.sh

**Purpose**: Profile X miner CPU performance to identify bottlenecks

**Usage**:
```bash
./scripts/profile_mining.sh [algorithm] [duration]
```

**Parameters**:
- `algorithm` (optional): Algorithm to profile (default: `rx/0` for RandomX)
- `duration` (optional): Profiling duration in seconds (default: 30)

**Supported Algorithms**:
- `rx/0` - RandomX (Monero, TARI)
- `cn/r` - CryptoNight R
- `kawpow` - KawPow (Ravencoin)
- `gr` - GhostRider (Raptoreum)

**What it does**:
- Runs miner in benchmark mode
- Collects CPU sampling data using `sample` tool (macOS)
- Records hashrate and performance metrics
- Generates multiple output files for analysis

**Example**:
```bash
# Profile RandomX for 30 seconds (default)
./scripts/profile_mining.sh

# Profile RandomX for 60 seconds
./scripts/profile_mining.sh rx/0 60

# Profile KawPow for 45 seconds
./scripts/profile_mining.sh kawpow 45
```

**Output Files** (in `profiling_results/`):
- `*.sample.txt` - CPU sampling data (raw profiler output)
- `*.stdout.txt` - Miner output with hashrate
- `*.stats.txt` - CPU/memory resource usage
- `*.summary.txt` - Quick text summary

**Use Case**: Identify CPU hotspots, measure optimization impact, compare algorithm performance

**Supported Platforms**: macOS (uses `sample` tool), Linux (can be adapted for `perf`)

---

### analyze_profile.sh

**Purpose**: Analyze profiling results and generate detailed reports

**Usage**:
```bash
./scripts/analyze_profile.sh <profile_results_prefix>
```

**Parameters**:
- `profile_results_prefix`: Path to profile results without extension

**Example**:
```bash
# List available profiles
./scripts/analyze_profile.sh

# Analyze specific profile
./scripts/analyze_profile.sh profiling_results/profile_randomx_20251202_140000
```

**What it does**:
- Parses CPU sampling data
- Extracts hot functions (>5% CPU time)
- Analyzes hashrate performance
- Identifies optimization opportunities
- Generates markdown analysis report

**Output**:
- `*.analysis.md` - Detailed markdown report with:
  - Hot function call graphs
  - Hashrate metrics
  - Resource usage
  - Optimization recommendations
  - Next steps

**Use Case**: Understand profiling results, identify bottlenecks, guide optimization work

**Supported Platforms**: macOS, Linux

---

### profile_all_algorithms.sh

**Purpose**: Profile all CPU algorithms and create performance comparison

**Usage**:
```bash
./scripts/profile_all_algorithms.sh
```

**Algorithms Profiled**:
- RandomX (rx/0) - 10M iterations
- CryptoNight (cn/r) - 1M iterations
- CryptoNight-Lite (cn-lite/1) - 1M iterations

**What it does**:
- Profiles each algorithm for 45 seconds
- Collects CPU sampling data and resource usage
- Extracts hashrate metrics
- Generates comprehensive comparison report

**Output** (in `profiling_results/`):
- `algorithm_comparison_*.md` - Comparative analysis report
- `profile_<algorithm>_*.sample.txt` - CPU profiling data
- `profile_<algorithm>_*.stdout.txt` - Miner output with hashrate
- `profile_<algorithm>_*.stats.txt` - Resource usage statistics

**Use Case**: Compare algorithm performance, identify best algorithm for hardware, validate optimization impact

**Supported Platforms**: macOS (uses `sample`), Linux (adaptable for `perf`)

**Duration**: ~5 minutes total

---

## Examples

### pool_mine_example.cmd

**Purpose**: Example pool mining configuration (Windows)

**Usage**:
```cmd
pool_mine_example.cmd
```

**Demonstrates**: Basic pool mining with TARI/Monero

**Supported Platforms**: Windows

---

### solo_mine_example.cmd

**Purpose**: Example solo mining configuration (Windows)

**Usage**:
```cmd
solo_mine_example.cmd
```

**Demonstrates**: Solo mining setup with local node

**Supported Platforms**: Windows

---

### rtm_ghostrider_example.cmd

**Purpose**: Example Raptoreum (GhostRider algorithm) mining (Windows)

**Usage**:
```cmd
rtm_ghostrider_example.cmd
```

**Demonstrates**: GhostRider algorithm configuration

**Supported Platforms**: Windows

---

## Quick Start Guide

### New User Setup (Linux)

1. **Check system capabilities**:
   ```bash
   ./scripts/check_system.sh
   ```

2. **Enable huge pages** (recommended):
   ```bash
   sudo ./scripts/setup_hugepages.sh
   ```

3. **Optimize for AMD Ryzen** (if applicable):
   ```bash
   sudo ./scripts/randomx_boost.sh
   ```

4. **Run benchmark**:
   ```bash
   ./scripts/quick_benchmark.sh
   ```

5. **Profile performance** (optional, for developers):
   ```bash
   ./scripts/profile_mining.sh rx/0 60
   ```

6. **Start mining** (see examples in `examples/` directory)

---

### Developer Setup

1. **Install build dependencies**:
   ```bash
   # Ubuntu/Debian
   sudo apt-get install build-essential cmake libuv1-dev libssl-dev libhwloc-dev

   # Fedora
   sudo dnf install gcc gcc-c++ cmake libuv-devel openssl-devel hwloc-devel

   # macOS
   brew install cmake libuv openssl hwloc
   ```

2. **Build X**:
   ```bash
   mkdir build
   cd build
   cmake ..
   make -j$(nproc)
   ```

3. **Test build**:
   ```bash
   ./build/x --version
   ./scripts/quick_benchmark.sh
   ```

---

## Troubleshooting

### Huge Pages Not Allocating

**Problem**: `setup_hugepages.sh` allocates fewer pages than requested

**Solutions**:
1. **Reboot and try immediately** - Memory fragmentation reduces over time
2. **Free up memory** - Close applications
3. **Reduce requested pages** - Try smaller allocation
4. **Check available memory**:
   ```bash
   cat /proc/meminfo | grep MemAvailable
   ```

---

### MSR Module Not Loading

**Problem**: `randomx_boost.sh` fails with "MSR module not found"

**Solutions**:
1. **Load MSR module**:
   ```bash
   sudo modprobe msr allow_writes=on
   ```

2. **Make permanent** (add to `/etc/modules`):
   ```bash
   echo "msr" | sudo tee -a /etc/modules
   ```

3. **Check if loaded**:
   ```bash
   lsmod | grep msr
   ```

---

### Permission Denied

**Problem**: Scripts fail with "Permission denied"

**Solution**: Make scripts executable:
```bash
chmod +x scripts/*.sh
```

---

## Additional Resources

- **[PERFORMANCE.md](../PERFORMANCE.md)** - Detailed performance tuning guide
- **[docs/PROFILING.md](../docs/PROFILING.md)** - Comprehensive profiling guide
- **[BUILD.md](../BUILD.md)** - Platform-specific build instructions
- **[examples/](../examples/)** - Mining configuration examples
- **[docs/](../docs/)** - Technical documentation

---

## Contributing

Have a useful script to share? Please submit a pull request!

**Guidelines**:
- Shell scripts should have `.sh` extension
- Include usage documentation in this README
- Test on multiple platforms if possible
- Use clear error messages
- Include safety checks (root requirements, etc.)

See [CONTRIBUTING.md](../CONTRIBUTING.md) for details.

---

## Script Summary Table

| Script | Platform | Root Required | Purpose |
|--------|----------|---------------|---------|
| `check_system.sh` | Linux, macOS | No | System capability checker |
| `setup_hugepages.sh` | Linux | Yes | Configure 2MB huge pages |
| `enable_1gb_pages.sh` | Linux | Yes | Configure 1GB huge pages |
| `randomx_boost.sh` | Linux | Yes | MSR optimizations (Ryzen/Intel) |
| `quick_benchmark.sh` | Linux, macOS | No | Quick performance test |
| `profile_mining.sh` | macOS, Linux* | No | CPU performance profiling |
| `analyze_profile.sh` | macOS, Linux | No | Analyze profiling results |
| `build.*.sh` | Linux, macOS | No | Build dependencies |
| `benchmark_*.cmd` | Windows | No | Windows benchmarks |
| `*_example.cmd` | Windows | No | Windows mining examples |

---

**Last Updated**: 2025-12-02
