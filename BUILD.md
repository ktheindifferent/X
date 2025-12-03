# Building X from Source

This guide provides detailed instructions for building X on various platforms.

## Table of Contents

- [Build Requirements](#build-requirements)
- [Linux](#linux)
- [macOS](#macos)
- [Windows](#windows)
- [FreeBSD](#freebsd)
- [Build Options](#build-options)
- [Troubleshooting](#troubleshooting)

## Build Requirements

### Common Requirements

- **CMake** 3.10 or newer
- **C/C++ Compiler**:
  - GCC 7.0+ (Linux)
  - Clang 6.0+ (macOS, FreeBSD)
  - MSVC 2019+ (Windows)
- **libuv** 1.x
- **OpenSSL** 1.1.x or 3.x (for TLS support)
- **hwloc** (optional, for CPU topology detection)

### Optional Dependencies

- **OpenCL** - For AMD GPU mining
- **CUDA Toolkit** 11.0+ - For NVIDIA GPU mining (requires separate CUDA plugin)

## Linux

### Ubuntu/Debian

Install dependencies:
```bash
sudo apt-get update
sudo apt-get install git build-essential cmake libuv1-dev libssl-dev libhwloc-dev
```

Build:
```bash
git clone https://github.com/ktheindifferent/X
cd X
mkdir build
cd build
cmake ..
make -j$(nproc)
```

The binary will be located at `build/x`.

### Fedora/CentOS/RHEL

Install dependencies:
```bash
sudo dnf install git cmake gcc gcc-c++ libuv-devel openssl-devel hwloc-devel
```

Build:
```bash
git clone https://github.com/ktheindifferent/X
cd X
mkdir build
cd build
cmake ..
make -j$(nproc)
```

### Arch Linux

Install dependencies:
```bash
sudo pacman -S git cmake base-devel libuv openssl hwloc
```

Build:
```bash
git clone https://github.com/ktheindifferent/X
cd X
mkdir build
cd build
cmake ..
make -j$(nproc)
```

### Alpine Linux

Install dependencies:
```bash
apk add git cmake make gcc g++ libuv-dev openssl-dev hwloc-dev linux-headers
```

Build:
```bash
git clone https://github.com/ktheindifferent/X
cd X
mkdir build
cd build
cmake .. -DCMAKE_C_FLAGS="-march=native" -DCMAKE_CXX_FLAGS="-march=native"
make -j$(nproc)
```

## macOS

### Prerequisites

Install Xcode Command Line Tools:
```bash
xcode-select --install
```

Install Homebrew (if not already installed):
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Install Dependencies

```bash
brew install cmake libuv openssl hwloc
```

### Build

```bash
git clone https://github.com/ktheindifferent/X
cd X
mkdir build
cd build
cmake .. -DOPENSSL_ROOT_DIR=/usr/local/opt/openssl
make -j$(sysctl -n hw.logicalcpu)
```

The binary will be located at `build/x`.

### Apple Silicon (M1/M2/M3)

For Apple Silicon Macs, use the same build instructions above. CMake will automatically detect ARM64 architecture and optimize accordingly.

## Windows

### Using Visual Studio 2019/2022

#### Prerequisites

1. Install [Visual Studio 2019 or 2022](https://visualstudio.microsoft.com/) with C++ development tools
2. Install [CMake](https://cmake.org/download/) (Windows installer)
3. Install [Git for Windows](https://git-scm.com/download/win)

#### Install Dependencies with vcpkg

```powershell
git clone https://github.com/microsoft/vcpkg
cd vcpkg
.\bootstrap-vcpkg.bat
.\vcpkg install libuv:x64-windows openssl:x64-windows hwloc:x64-windows
```

#### Build

Open "x64 Native Tools Command Prompt for VS 2022":

```powershell
git clone https://github.com/ktheindifferent/X
cd X
mkdir build
cd build
cmake .. -G "Visual Studio 17 2022" -A x64 ^
    -DCMAKE_TOOLCHAIN_FILE=C:\path\to\vcpkg\scripts\buildsystems\vcpkg.cmake
cmake --build . --config Release
```

The binary will be located at `build\Release\x.exe`.

### Using MSYS2/MinGW

Install [MSYS2](https://www.msys2.org/) and then:

```bash
pacman -S mingw-w64-x86_64-gcc mingw-w64-x86_64-cmake mingw-w64-x86_64-libuv \
          mingw-w64-x86_64-openssl mingw-w64-x86_64-hwloc make git
```

Build:
```bash
git clone https://github.com/ktheindifferent/X
cd X
mkdir build
cd build
cmake .. -G "Unix Makefiles"
make -j$(nproc)
```

## FreeBSD

Install dependencies:
```bash
pkg install git cmake gcc libuv openssl hwloc
```

Build:
```bash
git clone https://github.com/ktheindifferent/X
cd X
mkdir build
cd build
cmake ..
make -j$(sysctl -n hw.ncpu)
```

## Build Options

X supports various CMake build options to enable/disable features:

### Algorithm Support

```bash
cmake .. -DWITH_RANDOMX=ON          # RandomX (default: ON)
cmake .. -DWITH_KAWPOW=ON           # KawPow (default: ON)
cmake .. -DWITH_GHOSTRIDER=ON       # GhostRider (default: ON)
cmake .. -DWITH_ARGON2=ON           # Argon2 (default: ON)
cmake .. -DWITH_CN_LITE=ON          # CryptoNight-Lite (default: ON)
cmake .. -DWITH_CN_HEAVY=ON         # CryptoNight-Heavy (default: ON)
cmake .. -DWITH_CN_PICO=ON          # CryptoNight-Pico (default: ON)
cmake .. -DWITH_CN_FEMTO=ON         # CryptoNight-Femto (default: ON)
```

### Backend Support

```bash
cmake .. -DWITH_OPENCL=ON           # OpenCL AMD GPU support (default: ON)
cmake .. -DWITH_CUDA=ON             # CUDA NVIDIA GPU support (default: ON)
```

### Features

```bash
cmake .. -DWITH_HTTP=ON             # HTTP API support (default: ON)
cmake .. -DWITH_TLS=ON              # TLS support (default: ON)
cmake .. -DWITH_ASM=ON              # ASM optimizations (default: ON)
cmake .. -DWITH_MSR=ON              # MSR support (default: ON, Linux/Windows only)
cmake .. -DWITH_HWLOC=ON            # hwloc support (default: ON)
cmake .. -DWITH_BENCHMARK=ON        # Benchmark mode (default: ON)
cmake .. -DWITH_PROFILING=OFF       # Profiling support (default: OFF)
cmake .. -DWITH_DEBUG_LOG=OFF       # Debug logging (default: OFF)
```

### Build Configuration

```bash
cmake .. -DCMAKE_BUILD_TYPE=Release # Release build (default)
cmake .. -DCMAKE_BUILD_TYPE=Debug   # Debug build
cmake .. -DBUILD_STATIC=ON          # Static linking (default: OFF)
```

### Complete Example with Options

```bash
cmake .. \
  -DCMAKE_BUILD_TYPE=Release \
  -DWITH_HWLOC=ON \
  -DWITH_HTTP=ON \
  -DWITH_TLS=ON \
  -DWITH_OPENCL=ON \
  -DWITH_CUDA=OFF \
  -DWITH_MSR=ON \
  -DWITH_ASM=ON
make -j$(nproc)
```

## Static Builds

For creating a portable static binary that doesn't depend on system libraries:

### Linux Static Build

```bash
cmake .. -DBUILD_STATIC=ON -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
```

This will create a fully static binary that can be copied to other Linux systems without dependency issues.

## Cross-Compilation

### ARM/ARM64 (Raspberry Pi, etc.)

On the target device:
```bash
cmake .. -DCMAKE_C_FLAGS="-march=native" -DCMAKE_CXX_FLAGS="-march=native"
make -j$(nproc)
```

For cross-compilation, use appropriate toolchain files.

## GPU Support

### OpenCL (AMD GPUs)

OpenCL support is enabled by default. Make sure you have the appropriate OpenCL drivers installed:

- **AMD**: Install AMD ROCm or AMDGPU-PRO drivers
- **NVIDIA**: Install CUDA Toolkit
- **Intel**: Install Intel OpenCL Runtime

To disable OpenCL:
```bash
cmake .. -DWITH_OPENCL=OFF
```

### CUDA (NVIDIA GPUs)

CUDA support requires a separate CUDA plugin. Build with:
```bash
cmake .. -DWITH_CUDA=ON
make -j$(nproc)
```

## Troubleshooting

### CMake can't find OpenSSL

Specify OpenSSL location manually:
```bash
cmake .. -DOPENSSL_ROOT_DIR=/path/to/openssl
```

### CMake can't find libuv

Specify libuv location:
```bash
cmake .. -DLIBUV_INCLUDE_DIR=/path/to/libuv/include \
         -DLIBUV_LIBRARY=/path/to/libuv/lib/libuv.a
```

### Compiler warnings

To build with maximum warnings enabled:
```bash
cmake .. -DCMAKE_C_FLAGS="-Wall -Wextra" -DCMAKE_CXX_FLAGS="-Wall -Wextra"
```

### Out of memory during compilation

Reduce parallel jobs:
```bash
make -j2  # Instead of -j$(nproc)
```

### MSR support issues on Linux

MSR support requires loading the `msr` kernel module:
```bash
sudo modprobe msr
```

If you don't need MSR support:
```bash
cmake .. -DWITH_MSR=OFF
```

### macOS ARM64 issues

Ensure you're using the native ARM toolchain, not Rosetta:
```bash
arch  # Should output: arm64
```

If building under Rosetta (x86_64), reinstall Homebrew for ARM64.

## Verification

After building, verify the binary works:
```bash
./x --version
./x --help
```

Test with benchmark mode (requires no pool connection):
```bash
./x --bench=1M --cpu-no-yield
```

## Next Steps

After successfully building X:

1. See [README.md](README.md) for usage instructions
2. Check [config.json](src/config.json) for configuration examples
3. Read [doc/ALGORITHMS.md](doc/ALGORITHMS.md) for supported algorithms
4. Review [doc/CPU.md](doc/CPU.md) for CPU optimization tips

## Getting Help

If you encounter build issues:

1. Check this troubleshooting section
2. Search existing issues: https://github.com/ktheindifferent/X/issues
3. Create a new issue with:
   - Your OS and version
   - Compiler version
   - Full CMake output
   - Full build error output

---

**Note**: X is based on XMRig and shares similar build requirements and procedures. Many XMRig build guides and troubleshooting resources may also be applicable to X.
