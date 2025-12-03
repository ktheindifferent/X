# X Miner

X is a high-performance, open-source, cross-platform cryptocurrency miner forked from [XMRig](https://github.com/xmrig/xmrig). It supports RandomX, KawPow, CryptoNight, GhostRider, and more algorithms with unified CPU/GPU mining capabilities. Binaries are available for Windows, Linux, macOS, and FreeBSD.

## About This Fork

X is a fork of XMRig with the following enhancements and goals:
- Enhanced multi-algorithm support
- Improved portability and compatibility
- Reduced antivirus false positives
- Planned GUI development
- Secure distributed node management system
- One-click mining experience for all supported coins

For the complete development roadmap, see [todo.md](todo.md).

## Mining Backends

- **CPU** (x86/x64/ARMv7/ARMv8)
- **OpenCL** for AMD GPUs
- **CUDA** for NVIDIA GPUs

## Supported Algorithms

- **RandomX** (Monero, TARI/XTM)
- **KawPow** (Ravencoin)
- **CryptoNight** and variants
- **GhostRider** (Raptoreum)
- **Argon2** family
- More algorithms planned (see roadmap)

## Quick Start

### Building from Source

```bash
git clone https://github.com/ktheindifferent/X
cd X
mkdir build
cd build
cmake ..
make -j$(nproc)
```

For detailed build instructions, see **[BUILD.md](BUILD.md)** for platform-specific guidance.

**Verify Installation**:
```bash
# Check system capabilities
./scripts/check_system.sh

# Run benchmark
./scripts/quick_benchmark.sh
```

### Basic Usage

Mining TARI (XTM) - default configuration:
```bash
./x -o pool-global.tari.snipanet.com:3333 -u YOUR_TARI_WALLET_ADDRESS -a rx/0
```

Mining other coins:
```bash
./x -o POOL_ADDRESS:PORT -u YOUR_WALLET_ADDRESS -a ALGORITHM
```

### Configuration

The miner can be configured via:
1. **JSON config file** (recommended) - `config.json`
2. **Command-line arguments** - for quick testing
3. **HTTP API** - for runtime control

**Configuration Examples**:
- **[examples/tari-xtm.json](examples/tari-xtm.json)** - TARI/XTM mining (default)
- **[examples/monero-xmr.json](examples/monero-xmr.json)** - Monero mining
- **[examples/ravencoin-rvn.json](examples/ravencoin-rvn.json)** - Ravencoin GPU mining

See **[examples/README.md](examples/README.md)** for detailed configuration guide.

### Performance Optimization (Linux)

For optimal mining performance:

```bash
# 1. Enable huge pages (10-30% performance boost)
sudo ./scripts/setup_hugepages.sh

# 2. Optimize for AMD Ryzen (if applicable)
sudo ./scripts/randomx_boost.sh

# 3. Run benchmark
./scripts/quick_benchmark.sh
```

See **[PERFORMANCE.md](PERFORMANCE.md)** for comprehensive tuning guide.

## Default Donation

The default donation level is 1% (1 minute in 100 minutes) to support X development. This helps fund:
- Ongoing development and optimization
- New algorithm implementations
- Bug fixes and security updates
- Infrastructure costs

**TARI/XTM Donation Wallet:**
```
127PHAz3ePq93yWJ1Gsz8VzznQFui5LYne5jbwtErzD5WsnqWAfPR37KwMyGAf5UjD2nXbYZiQPz7GMTEQRCTrGV3fH
```

The donation level can be adjusted in the config file with the `donate-level` option.

## Features

### Current Features (Inherited from XMRig)
- Multiple algorithm support
- CPU and GPU mining
- Pool and solo mining
- HTTP API for monitoring and control
- TLS support for secure connections
- Automatic config file generation
- Benchmark mode
- Hardware monitoring

### Planned Features (See Roadmap)
- Graphical user interface (GUI)
- One-click miner setup
- Automatic coin profitability switching
- Secure multi-node management system
- Additional PoW algorithms
- Reduced AV false positives
- Enhanced performance optimizations

## Documentation

### Getting Started
- **[BUILD.md](BUILD.md)** - Platform-specific build instructions
- **[CONTRIBUTING.md](CONTRIBUTING.md)** - Contribution guidelines
- **[examples/](examples/)** - Mining configuration examples for popular coins

### User Guides
- **[PERFORMANCE.md](PERFORMANCE.md)** - Performance optimization guide
  - CPU/GPU mining optimization
  - Algorithm-specific tips (RandomX, KawPow, CryptoNight, GhostRider)
  - Benchmarking and troubleshooting
- **[ALGORITHM_PERFORMANCE_ANALYSIS.md](ALGORITHM_PERFORMANCE_ANALYSIS.md)** - Real profiling results
  - Actual performance analysis from Intel i9-9880H
  - RandomX, CryptoNight, and CryptoNight-Lite comparison
  - Algorithm recommendations and optimization priorities
  - System-specific optimization opportunities (5-20% potential gains)
- **[docs/PROFILING.md](docs/PROFILING.md)** - Performance profiling guide
  - Profiling tools and techniques (macOS, Linux, Windows)
  - CPU and GPU profiling methodologies
  - Interpreting results and identifying bottlenecks
  - Optimization workflow
- **[docs/RUNTIME_PROFILING_PLAN.md](docs/RUNTIME_PROFILING_PLAN.md)** - Runtime profiling methodology
  - Comprehensive profiling plan based on architecture analysis
  - Expected bottlenecks and validation criteria
  - Algorithm-specific profiling scenarios
  - Performance baseline targets and optimization roadmap
- **[scripts/README.md](scripts/README.md)** - Utility scripts documentation
  - System configuration tools
  - Performance optimization scripts
  - Profiling tools (profile_mining.sh, analyze_profile.sh)
  - Benchmarking utilities

### Developer Documentation
- **[claude.md](claude.md)** - Project overview and current status
- **[todo.md](todo.md)** - Complete development roadmap (10 phases)
- **[PHASE2_SUMMARY.md](PHASE2_SUMMARY.md)** - Phase 2 achievements summary
  - Complete inventory of 7,800+ lines of technical documentation
  - 50 optimization opportunities cataloged and prioritized
  - Runtime profiling results and validation
  - Key learnings and next steps (Phase 2: 80% complete)
- **[docs/CODE_QUALITY_ANALYSIS.md](docs/CODE_QUALITY_ANALYSIS.md)** - Code quality analysis and recommendations
  - Compiler warning analysis
  - Code quality metrics
  - Memory safety assessment
  - Improvement recommendations
- **[docs/RANDOMX_ANALYSIS.md](docs/RANDOMX_ANALYSIS.md)** - RandomX implementation analysis
  - Architecture overview (Cache, Dataset, VM, JIT)
  - Memory management details
  - 10 optimization opportunities identified
- **[docs/MEMORY_MANAGEMENT_ANALYSIS.md](docs/MEMORY_MANAGEMENT_ANALYSIS.md)** - Memory management system analysis
  - VirtualMemory and memory pooling
  - Huge pages and NUMA support
  - Platform-specific implementations
  - 10 optimization opportunities identified
- **[docs/WORKER_THREADING_ANALYSIS.md](docs/WORKER_THREADING_ANALYSIS.md)** - Worker and threading architecture
  - Backend system and worker lifecycle
  - Thread management and CPU affinity
  - Job processing pipeline
  - 10 optimization opportunities identified
- **[docs/NETWORK_ANALYSIS.md](docs/NETWORK_ANALYSIS.md)** - Network and Stratum protocol analysis
  - Network layer architecture and job distribution
  - Stratum protocol implementation
  - Pool connection management and failover
  - Result submission system
  - 10 optimization opportunities identified
- **[docs/GPU_BACKEND_ANALYSIS.md](docs/GPU_BACKEND_ANALYSIS.md)** - GPU backend architecture (CUDA and OpenCL)
  - Backend system and worker architecture
  - Runner pattern for algorithm implementations
  - Device abstraction (NVIDIA and AMD)
  - OpenCL kernel compilation and caching
  - CUDA-specific optimizations
  - 10 optimization opportunities identified

### Original XMRig Documentation
- **[doc/](doc/)** - Original XMRig documentation
  - API.md - HTTP API reference
  - ALGORITHMS.md - Supported algorithms
  - CPU.md - CPU mining optimization

### License
- **[LICENSE](LICENSE)** - GPL-3.0 License

## Original XMRig Credits

This project is forked from XMRig. We acknowledge and thank the original developers:
- **XMRig Team**: [github.com/xmrig](https://github.com/xmrig)
- **SChernykh**: [github.com/SChernykh](https://github.com/SChernykh)

XMRig is licensed under GPL-3.0, and this fork maintains the same license.

## License

GPL-3.0 - See [LICENSE](LICENSE) file for details.

## Disclaimer

Cryptocurrency mining consumes significant computational resources and electricity. Users should:
- Understand the costs and potential returns before mining
- Respect pool terms of service
- Comply with local laws and regulations
- Only mine on hardware you own or have permission to use
- Monitor hardware temperatures and power consumption

## Contributing

Contributions are welcome! This is an open-source project and we encourage:
- Bug reports and fixes
- Performance improvements
- New algorithm implementations
- Documentation improvements
- Testing on different platforms

Please ensure your contributions follow the existing code style and include appropriate tests.

## Security

If you discover a security vulnerability, please report it responsibly. Do not create public issues for security vulnerabilities.
