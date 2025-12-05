# X Miner - Developer Guide

**Version:** 1.0.0
**Last Updated:** December 3, 2025
**Target Audience:** Developers contributing to X

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [Architecture Overview](#architecture-overview)
3. [Building from Source](#building-from-source)
4. [Code Organization](#code-organization)
5. [Performance Optimizations](#performance-optimizations)
6. [Testing](#testing)
7. [Contributing](#contributing)
8. [Debugging](#debugging)

---

## Getting Started

### Prerequisites

- **C++14** compatible compiler (GCC 7+, Clang 6+, MSVC 2019+)
- **CMake** 3.10 or newer
- **Git** for version control
- Platform-specific dependencies (see [BUILD.md](../BUILD.md))

### Quick Start

```bash
# Clone the repository
git clone https://github.com/yourusername/X
cd X

# Build
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)

# Run self-test
./x --bench=1M

# Start mining
./x -o pool.example.com:3333 -u YOUR_WALLET
```

---

## Architecture Overview

### Core Components

```
X Miner Architecture
├── Backend Layer (CPU/GPU mining)
│   ├── CPU Backend (x86/ARM)
│   ├── CUDA Backend (NVIDIA)
│   └── OpenCL Backend (AMD)
├── Algorithm Layer
│   ├── RandomX (Monero, TARI)
│   ├── CryptoNight (variants)
│   ├── KawPow (Ravencoin)
│   └── GhostRider
├── Network Layer
│   ├── Stratum Protocol
│   ├── Pool Management
│   └── Job Distribution
└── Core Services
    ├── Configuration
    ├── Logging
    └── API Server
```

### Key Subsystems

#### 1. Backend System

**Location:** `src/backend/`

Manages mining hardware (CPU, CUDA, OpenCL):
- Worker thread lifecycle
- Job scheduling
- Hashrate tracking
- Hardware detection

**Key Files:**
- `src/backend/cpu/CpuBackend.cpp` - CPU mining coordination
- `src/backend/cpu/CpuWorker.cpp` - Worker thread implementation
- `src/backend/cuda/CudaBackend.cpp` - NVIDIA GPU support
- `src/backend/opencl/OclBackend.cpp` - AMD GPU support

#### 2. RandomX Implementation

**Location:** `src/crypto/randomx/`

High-performance RandomX algorithm implementation:
- **Cache:** Argon2-based cache (256 MB)
- **Dataset:** 2+ GB dataset for mining
- **VM:** Interpreted and JIT-compiled virtual machines
- **JIT:** x86-64 and ARM64 assembly code generation

**Key Files:**
- `src/crypto/randomx/randomx.cpp` - Main API
- `src/crypto/randomx/jit_compiler_x86.cpp` - x86-64 JIT compiler
- `src/crypto/randomx/vm_compiled.cpp` - JIT VM implementation
- `src/crypto/randomx/dataset.cpp` - Dataset initialization

**Performance Features:**
- AVX2/AVX-512 SIMD optimizations
- Huge pages support (2MB/1GB)
- NUMA-aware memory allocation
- CPU-specific prefetch tuning

#### 3. Memory Management

**Location:** `src/crypto/common/`

Advanced memory management for performance:
- **VirtualMemory:** OS-level memory allocation
- **MemoryPool:** Fast allocation for small objects
- **NUMAMemoryPool:** NUMA-aware allocation
- **Huge Pages:** 2MB and 1GB page support

**Key Files:**
- `src/crypto/common/VirtualMemory.cpp` - Cross-platform memory allocation
- `src/crypto/common/MemoryPool.cpp` - Pool allocator
- `src/crypto/common/NUMAMemoryPool.cpp` - NUMA support

#### 4. Network Layer

**Location:** `src/base/net/stratum/`

Stratum protocol implementation:
- Connection management
- Job distribution
- Share submission
- Failover handling

**Key Files:**
- `src/base/net/stratum/Client.cpp` - Stratum client
- `src/base/net/stratum/Pool.cpp` - Pool configuration
- `src/base/net/stratum/Job.cpp` - Mining job management

---

## Building from Source

### Platform-Specific Instructions

#### macOS

```bash
# Install dependencies
brew install cmake hwloc libuv openssl

# Build
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(sysctl -n hw.ncpu)
```

#### Linux (Ubuntu/Debian)

```bash
# Install dependencies
sudo apt-get install git build-essential cmake libuv1-dev \
    libssl-dev libhwloc-dev

# Build
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
```

#### Windows

```powershell
# Install dependencies via vcpkg
vcpkg install libuv openssl hwloc

# Build with Visual Studio
mkdir build
cd build
cmake .. -G "Visual Studio 16 2019"
cmake --build . --config Release
```

### Build Options

```bash
# Debug build
cmake .. -DCMAKE_BUILD_TYPE=Debug

# Enable CUDA support
cmake .. -DWITH_CUDA=ON

# Enable OpenCL support
cmake .. -DWITH_OPENCL=ON

# Disable CPU backend
cmake .. -DWITH_CPU=OFF

# Enable MSR (Model Specific Register) support
cmake .. -DWITH_MSR=ON
```

---

## Code Organization

### Directory Structure

```
X/
├── src/
│   ├── App.cpp                 # Application entry point
│   ├── backend/                # Mining backends
│   │   ├── common/             # Shared backend code
│   │   ├── cpu/                # CPU backend
│   │   ├── cuda/               # NVIDIA GPU backend
│   │   └── opencl/             # AMD GPU backend
│   ├── base/                   # Core utilities
│   │   ├── crypto/             # Cryptographic utilities
│   │   ├── io/                 # I/O and logging
│   │   ├── kernel/             # Platform abstraction
│   │   ├── net/                # Networking
│   │   └── tools/              # Utility functions
│   ├── core/                   # Core mining logic
│   │   ├── config/             # Configuration management
│   │   ├── Controller.cpp      # Main controller
│   │   └── Miner.cpp           # Mining coordinator
│   ├── crypto/                 # Algorithm implementations
│   │   ├── argon2/             # Argon2 implementation
│   │   ├── cn/                 # CryptoNight variants
│   │   ├── ghostrider/         # GhostRider algorithm
│   │   ├── kawpow/             # KawPow (Ravencoin)
│   │   └── randomx/            # RandomX implementation
│   └── net/                    # Network services
├── docs/                       # Documentation
├── scripts/                    # Utility scripts
└── examples/                   # Configuration examples
```

### Naming Conventions

**Files:**
- Classes: `CamelCase.cpp` / `CamelCase.h`
- Utilities: `snake_case.cpp` / `snake_case.h`

**Code:**
- Classes: `CamelCase`
- Functions: `camelCase()`
- Variables: `camelCase` or `m_memberVariable`
- Constants: `kConstant` or `MACRO_CONSTANT`

**Namespaces:**
- Primary: `xmrig::`
- Nested: `xmrig::randomx::`

---

## Performance Optimizations

### Applied Optimizations

#### 1. Memory Copy Reduction

**Location:** `src/base/net/stratum/Job.cpp:420-465`

**What:** Eliminated 408-byte memcpy in signature generation
**Impact:** 84% reduction in memory traffic (408 → 64 bytes)
**Expected Gain:** 1-3% hashrate

**Details:**
- Original code copied entire blob to zero signature field
- Optimized to modify in-place with save/restore
- Thread-safe (each worker has own Job copy)

#### 2. Dataset Prefetching

**Location:** `src/crypto/rx/Rx.cpp:136-165`

**What:** CPU-specific prefetch mode auto-detection
**Impact:** 3-7% hashrate improvement on modern CPUs
**Modes:**
- `0` = Disabled (baseline)
- `1` = PREFETCHT0 (default for older CPUs)
- `2` = PREFETCHNTA (non-temporal)
- `3` = Forced read (best for Zen4/Zen5, Ice Lake+)

**Auto-Detection:**
```cpp
// AMD Zen4/Zen5: Use mode 3
if (arch == ARCH_ZEN4 || arch == ARCH_ZEN5) {
    prefetchMode = ScratchpadPrefetchMov;  // Mode 3
}

// Intel Ice Lake+: Use mode 3
if (model >= 0x7E) {
    prefetchMode = ScratchpadPrefetchMov;  // Mode 3
}
```

#### 3. AVX-512 Infrastructure

**Location:** `src/backend/cpu/` and `src/crypto/randomx/`

**What:** AVX-512 detection and infrastructure
**Status:** Infrastructure complete, assembly implementation pending
**Expected Gain:** 5-20% on supported CPUs

**Implementation:**
- `hasAVX512()` method in CPU info
- JIT compiler flags: `hasAVX512`, `initDatasetAVX512`
- Fallback hierarchy: AVX-512 → AVX2 → baseline

#### 4. JIT Compilation

**Location:** `src/crypto/randomx/jit_compiler_x86.cpp`

**What:** Runtime code generation for RandomX VM
**Impact:** 10-50x faster than interpreted mode
**Features:**
- x86-64 and ARM64 support
- Register allocation optimization
- Instruction fusion
- Cache-efficient code layout

### Performance Best Practices

#### CPU Mining

1. **Enable Huge Pages**
   ```bash
   # Linux
   sudo sysctl -w vm.nr_hugepages=1280

   # macOS (automatic)
   # Windows: Enable "Lock pages in memory" privilege
   ```

2. **Set CPU Affinity**
   ```json
   {
     "cpu": {
       "affinity": [0, 2, 4, 6, 8, 10, 12, 14]
     }
   }
   ```

3. **Disable Hyperthreading** (optional for better cache utilization)

4. **Configure Prefetch Mode**
   ```json
   {
     "randomx": {
       "scratchpad_prefetch_mode": 3
     }
   }
   ```

#### GPU Mining

1. **Optimize Thread Configuration**
2. **Enable Compute Mode** (NVIDIA)
3. **Increase Power Limit** (if thermally safe)
4. **Use Latest Drivers**

---

## Testing

### Unit Tests

Currently, X uses runtime tests via benchmarking:

```bash
# Test RandomX
./x --bench=rx/0 --bench-submit

# Test CryptoNight
./x --bench=cn/0 --bench-submit

# Test KawPow
./x --bench=kawpow --bench-submit
```

### Performance Testing

```bash
# Quick benchmark (1M hashes)
./x --bench=1M --threads=8

# Full benchmark (10M hashes)
./x --bench=10M --threads=$(nproc)

# Algorithm-specific
./x --bench=rx/0 --threads=16
```

### Profiling

See [docs/PROFILING.md](PROFILING.md) for detailed profiling instructions.

**Quick profile (macOS):**
```bash
./scripts/profile_mining.sh randomx 45
```

**Quick profile (Linux):**
```bash
perf record -g ./x --bench=10M
perf report
```

---

## Contributing

### Code Style

X follows LLVM coding style with modifications:

- **Indentation:** 4 spaces (no tabs)
- **Line Length:** 120 characters max
- **Braces:** K&R style
- **Comments:** Doxygen-style for public APIs

**Format code:**
```bash
clang-format -i src/**/*.cpp src/**/*.h
```

### Pull Request Process

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-optimization`)
3. **Implement** your changes
4. **Test** thoroughly (benchmarks, different algorithms)
5. **Commit** with clear messages
6. **Push** to your fork
7. **Submit** pull request with description

### Code Review Checklist

- [ ] Code compiles without warnings
- [ ] Passes all benchmarks
- [ ] No performance regressions
- [ ] Follows coding style
- [ ] Includes documentation
- [ ] Thread-safe (if applicable)
- [ ] Memory-safe (no leaks)

---

## Debugging

### Build with Debug Symbols

```bash
cmake .. -DCMAKE_BUILD_TYPE=Debug
make -j$(nproc)
```

### Common Issues

#### 1. Low Hashrate

**Symptoms:** Hashrate significantly below expected

**Check:**
- Huge pages enabled?
- Correct thread count?
- CPU/GPU not throttling?
- Background applications?

**Debug:**
```bash
./x --print-time=5  # Show hashrate every 5 seconds
```

#### 2. Crashes

**Symptoms:** Miner crashes or segfaults

**Debug:**
```bash
# Enable core dumps (Linux)
ulimit -c unlimited

# Run with debugger
gdb ./x
run --bench=1M
```

#### 3. Memory Issues

**Symptoms:** Out of memory errors

**Check:**
- Sufficient RAM? (4GB+ for RandomX)
- Huge pages configured correctly?
- Too many threads?

**Debug:**
```bash
# Check memory usage
./x --bench=1M --threads=4  # Reduce threads
```

### Sanitizers

Build with AddressSanitizer and UndefinedBehaviorSanitizer:

```bash
cmake .. -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_CXX_FLAGS="-fsanitize=address,undefined -fno-omit-frame-pointer"
make -j$(nproc)

# Run with sanitizers
ASAN_OPTIONS=detect_leaks=1 ./x --bench=1M
```

---

## Advanced Topics

### Adding a New Algorithm

1. **Create algorithm directory:** `src/crypto/newalgo/`
2. **Implement algorithm:** Hash function, initialization
3. **Add backend support:** `src/backend/cpu/`
4. **Register algorithm:** `src/base/crypto/Algorithm.cpp`
5. **Add tests:** Benchmark and validation
6. **Document:** Update ALGORITHMS.md

### Implementing Hardware Backend

1. **Create backend directory:** `src/backend/newbackend/`
2. **Implement IBackend interface**
3. **Add configuration:** `src/core/config/Config.cpp`
4. **Implement workers:** Thread management
5. **Add kernel code:** Device-specific optimizations
6. **Test thoroughly:** Multiple devices, algorithms

### Custom Prefetch Modes

Add new prefetch mode in `src/crypto/randomx/randomx.cpp`:

```cpp
case 4:  // New custom mode
    *a = 0x... // Your prefetch instruction
    *b = 0x...
    break;
```

---

## Resources

### Documentation

- [BUILD.md](../BUILD.md) - Build instructions
- [PERFORMANCE.md](../PERFORMANCE.md) - Performance tuning
- [PROFILING.md](PROFILING.md) - Profiling guide
- [ALGORITHMS.md](../ALGORITHMS.md) - Supported algorithms
- [API.md](../API.md) - HTTP API documentation

### Architecture Analysis

- [RANDOMX_ANALYSIS.md](RANDOMX_ANALYSIS.md) - RandomX deep dive
- [MEMORY_MANAGEMENT_ANALYSIS.md](MEMORY_MANAGEMENT_ANALYSIS.md) - Memory systems
- [WORKER_THREADING_ANALYSIS.md](WORKER_THREADING_ANALYSIS.md) - Threading model
- [NETWORK_ANALYSIS.md](NETWORK_ANALYSIS.md) - Network layer
- [GPU_BACKEND_ANALYSIS.md](GPU_BACKEND_ANALYSIS.md) - GPU backends

### Optimization Guides

- [MEMORY_COPY_OPTIMIZATION.md](MEMORY_COPY_OPTIMIZATION.md) - Memory copy reduction
- [PREFETCH_OPTIMIZATION.md](PREFETCH_OPTIMIZATION.md) - Prefetch tuning
- [AVX512_IMPLEMENTATION_PLAN.md](AVX512_IMPLEMENTATION_PLAN.md) - AVX-512 roadmap

### Community

- **Repository:** https://github.com/yourusername/X
- **Issues:** https://github.com/yourusername/X/issues
- **Discussions:** https://github.com/yourusername/X/discussions

---

## FAQ

### Q: How do I enable huge pages on my system?

**Linux:**
```bash
sudo sysctl -w vm.nr_hugepages=1280
echo "vm.nr_hugepages=1280" | sudo tee -a /etc/sysctl.conf
```

**Windows:** Enable "Lock pages in memory" in Local Security Policy

**macOS:** Automatic (transparent huge pages)

### Q: Why is my hashrate lower than expected?

Check:
1. Huge pages enabled
2. Correct algorithm selected
3. Sufficient cooling (check temperatures)
4. No background applications
5. Power settings (high performance mode)

### Q: How do I mine multiple algorithms?

X mines one algorithm at a time. For multiple algorithms:
1. Run multiple instances with different ports
2. Use different configuration files
3. Manage via scripting

### Q: Can I contribute without being a C++ expert?

Yes! Contributions welcome in:
- Documentation improvements
- Bug reports and testing
- Configuration examples
- Translation
- Performance benchmarking

---

## License

X is open-source software. See [LICENSE](../LICENSE) for details.

---

**Document Version:** 1.0
**Last Updated:** December 3, 2025
**Maintainers:** X Development Team
