#!/bin/bash
#
# X Miner - System Capability Checker
# Checks system configuration for optimal mining performance
#

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Symbols
CHECK="${GREEN}✓${NC}"
CROSS="${RED}✗${NC}"
WARN="${YELLOW}⚠${NC}"

echo "============================================"
echo " X Miner - System Capability Check"
echo "============================================"
echo

# Detect OS
echo -e "${BLUE}Operating System:${NC}"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "  OS: $NAME $VERSION"
elif [ "$(uname)" == "Darwin" ]; then
    echo "  OS: macOS $(sw_vers -productVersion)"
else
    echo "  OS: $(uname -s)"
fi
echo "  Kernel: $(uname -r)"
echo

# CPU Information
echo -e "${BLUE}CPU Information:${NC}"
if [ -f /proc/cpuinfo ]; then
    CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -n1 | cut -d':' -f2 | xargs)
    CPU_CORES=$(grep -c ^processor /proc/cpuinfo)
    echo "  Model: $CPU_MODEL"
    echo "  Cores: $CPU_CORES"

    # Check for AES-NI
    if grep -q " aes" /proc/cpuinfo; then
        echo -e "  AES-NI: $CHECK Available"
    else
        echo -e "  AES-NI: $CROSS Not available (performance will be reduced)"
    fi

    # Check L3 cache
    L3_CACHE=$(lscpu | grep "L3 cache" | awk '{print $3}')
    if [ -n "$L3_CACHE" ]; then
        echo "  L3 Cache: $L3_CACHE"
        # Recommend thread count
        L3_MB=$(echo $L3_CACHE | sed 's/[^0-9]//g')
        if [ -n "$L3_MB" ]; then
            RECOMMENDED_THREADS=$((L3_MB / 2))
            echo "  Recommended threads for RandomX: $RECOMMENDED_THREADS"
        fi
    fi
elif [ "$(uname)" == "Darwin" ]; then
    CPU_MODEL=$(sysctl -n machdep.cpu.brand_string)
    CPU_CORES=$(sysctl -n hw.ncpu)
    echo "  Model: $CPU_MODEL"
    echo "  Cores: $CPU_CORES"

    # Check for AES
    if sysctl -a 2>/dev/null | grep -q "machdep.cpu.features.*AES"; then
        echo -e "  AES-NI: $CHECK Available"
    fi
fi
echo

# Memory Information
echo -e "${BLUE}Memory Information:${NC}"
if [ -f /proc/meminfo ]; then
    TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    TOTAL_MEM_GB=$((TOTAL_MEM_KB / 1024 / 1024))
    FREE_MEM_KB=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    FREE_MEM_GB=$((FREE_MEM_KB / 1024 / 1024))

    echo "  Total RAM: ${TOTAL_MEM_GB} GB"
    echo "  Available RAM: ${FREE_MEM_GB} GB"

    if [ $TOTAL_MEM_GB -lt 4 ]; then
        echo -e "  $CROSS Insufficient RAM for RandomX mining (4GB+ recommended)"
    elif [ $TOTAL_MEM_GB -lt 8 ]; then
        echo -e "  $WARN Minimal RAM for RandomX mining (8GB+ recommended)"
    else
        echo -e "  $CHECK Sufficient RAM for RandomX mining"
    fi
elif [ "$(uname)" == "Darwin" ]; then
    TOTAL_MEM_BYTES=$(sysctl -n hw.memsize)
    TOTAL_MEM_GB=$((TOTAL_MEM_BYTES / 1024 / 1024 / 1024))
    echo "  Total RAM: ${TOTAL_MEM_GB} GB"

    if [ $TOTAL_MEM_GB -lt 4 ]; then
        echo -e "  $CROSS Insufficient RAM for RandomX mining (4GB+ recommended)"
    elif [ $TOTAL_MEM_GB -lt 8 ]; then
        echo -e "  $WARN Minimal RAM for RandomX mining (8GB+ recommended)"
    else
        echo -e "  $CHECK Sufficient RAM for RandomX mining"
    fi
fi
echo

# Huge Pages Status (Linux only)
if [ -f /proc/meminfo ]; then
    echo -e "${BLUE}Huge Pages Status (Linux):${NC}"
    NR_HUGEPAGES=$(cat /proc/sys/vm/nr_hugepages)
    HUGEPAGES_FREE=$(grep HugePages_Free /proc/meminfo | awk '{print $2}')
    HUGEPAGES_TOTAL=$(grep HugePages_Total /proc/meminfo | awk '{print $2}')

    echo "  Total huge pages: $HUGEPAGES_TOTAL"
    echo "  Free huge pages: $HUGEPAGES_FREE"

    if [ "$HUGEPAGES_TOTAL" -eq 0 ]; then
        echo -e "  $CROSS Huge pages not configured"
        echo "    Run: sudo ./scripts/setup_hugepages.sh"
    elif [ "$HUGEPAGES_FREE" -eq 0 ]; then
        echo -e "  $WARN All huge pages in use"
    else
        echo -e "  $CHECK Huge pages available"
    fi

    # Check MSR module (for Ryzen optimization)
    if [ -e /dev/cpu/0/msr ] || lsmod | grep -q "^msr"; then
        echo -e "  MSR module: $CHECK Loaded"
    else
        echo -e "  MSR module: $CROSS Not loaded (needed for Ryzen optimization)"
        echo "    Run: sudo modprobe msr"
    fi
    echo
fi

# NUMA Information (Linux only)
if command -v numactl &> /dev/null; then
    echo -e "${BLUE}NUMA Configuration:${NC}"
    NUMA_NODES=$(numactl --hardware | grep "available:" | awk '{print $2}')
    echo "  NUMA nodes: $NUMA_NODES"

    if [ "$NUMA_NODES" -gt 1 ]; then
        echo -e "  $CHECK Multi-socket system detected"
        echo "    Enable NUMA support in config for best performance"
    else
        echo -e "  Single-socket system (NUMA not needed)"
    fi
    echo
fi

# GPU Detection
echo -e "${BLUE}GPU Detection:${NC}"
GPU_FOUND=0

# NVIDIA
if command -v nvidia-smi &> /dev/null; then
    echo "  NVIDIA GPUs:"
    nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader | while read line; do
        echo "    - $line"
        GPU_FOUND=1
    done
fi

# AMD (Linux)
if command -v rocm-smi &> /dev/null; then
    echo "  AMD GPUs (ROCm):"
    rocm-smi --showproductname 2>/dev/null | grep "Card series" | while read line; do
        echo "    - $line"
        GPU_FOUND=1
    done
elif [ -d /sys/class/drm ]; then
    # Fallback AMD detection
    if ls /sys/class/drm/card*/device/vendor 2>/dev/null | xargs cat | grep -q "0x1002"; then
        echo -e "  AMD GPU detected (install rocm-smi for details)"
        GPU_FOUND=1
    fi
fi

if [ $GPU_FOUND -eq 0 ]; then
    echo "  No GPUs detected (CPU mining only)"
fi
echo

# Build Dependencies Check
echo -e "${BLUE}Build Dependencies:${NC}"

check_command() {
    if command -v $1 &> /dev/null; then
        VERSION=$($1 --version 2>&1 | head -n1)
        echo -e "  $CHECK $2: $VERSION"
    else
        echo -e "  $CROSS $2: Not found"
    fi
}

check_command gcc "GCC"
check_command g++ "G++"
check_command clang "Clang"
check_command cmake "CMake"
check_command make "Make"
echo

# Performance Recommendations
echo -e "${BLUE}Performance Recommendations:${NC}"
echo

if [ -f /proc/cpuinfo ]; then
    if grep -q "AMD" /proc/cpuinfo; then
        echo "  ${YELLOW}AMD CPU detected:${NC}"
        echo "    • Run: sudo ./scripts/randomx_boost.sh"
        echo "    • Enables MSR optimizations for better RandomX performance"
        echo
    fi
fi

if [ -f /proc/meminfo ] && [ "$HUGEPAGES_TOTAL" -eq 0 ]; then
    echo "  ${YELLOW}Huge pages not configured:${NC}"
    echo "    • Run: sudo ./scripts/setup_hugepages.sh"
    echo "    • Improves performance by 10-30%"
    echo
fi

if [ -f /proc/cpuinfo ]; then
    CPU_FREQ=$(lscpu | grep "CPU MHz" | head -n1 | awk '{print $3}')
    if [ -n "$CPU_FREQ" ]; then
        CPU_FREQ_INT=${CPU_FREQ%.*}
        if [ "$CPU_FREQ_INT" -lt 2000 ]; then
            echo "  ${YELLOW}CPU frequency is low:${NC}"
            echo "    • Current: ${CPU_FREQ} MHz"
            echo "    • Consider setting CPU governor to 'performance'"
            echo "    • Run: echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor"
            echo
        fi
    fi
fi

echo -e "${GREEN}System check complete!${NC}"
echo
echo "For more information, see:"
echo "  • PERFORMANCE.md - Performance tuning guide"
echo "  • BUILD.md - Build instructions"
echo "  • examples/ - Configuration examples"
