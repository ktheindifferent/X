#!/bin/bash
#
# X Miner - Quick Benchmark Script
# Runs benchmarks with different configurations to find optimal settings
#

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default binary location
X_BINARY="./build/x"

# Check if binary exists
if [ ! -f "$X_BINARY" ]; then
    X_BINARY="./x"
    if [ ! -f "$X_BINARY" ]; then
        echo -e "${RED}Error: X miner binary not found${NC}"
        echo "Build the miner first or specify path with: $0 /path/to/x"
        exit 1
    fi
fi

# Allow override
if [ -n "$1" ]; then
    X_BINARY="$1"
fi

echo "============================================"
echo " X Miner - Quick Benchmark"
echo "============================================"
echo
echo "Binary: $X_BINARY"
echo

# Get version
echo "Version:"
$X_BINARY --version 2>&1 | head -n3
echo

# Determine benchmark iterations
# 1M = quick test (~30 seconds)
# 10M = thorough test (~5 minutes)
BENCH_SIZE="1M"

if [ "$2" == "thorough" ]; then
    BENCH_SIZE="10M"
    echo "Running thorough benchmark (this will take ~5 minutes)..."
else
    echo "Running quick benchmark (this will take ~30 seconds)..."
    echo "For thorough benchmark: $0 $X_BINARY thorough"
fi
echo

# Function to extract hashrate from output
extract_hashrate() {
    grep "H/s" | tail -n1 | grep -oP '\d+\s+H/s' | awk '{print $1}'
}

# Test 1: Default configuration
echo -e "${BLUE}Test 1: Default Configuration${NC}"
echo "Running: $X_BINARY --bench=$BENCH_SIZE"
OUTPUT=$($X_BINARY --bench=$BENCH_SIZE 2>&1)
HASHRATE=$(echo "$OUTPUT" | extract_hashrate)
echo "Result: $HASHRATE H/s"
echo "$OUTPUT" | grep "algo\|time\|H/s" | tail -n2
echo

# Test 2: No yield (better for dedicated mining)
echo -e "${BLUE}Test 2: CPU No Yield${NC}"
echo "Running: $X_BINARY --bench=$BENCH_SIZE --cpu-no-yield"
OUTPUT=$($X_BINARY --bench=$BENCH_SIZE --cpu-no-yield 2>&1)
HASHRATE2=$(echo "$OUTPUT" | extract_hashrate)
echo "Result: $HASHRATE2 H/s"
echo "$OUTPUT" | grep "algo\|time\|H/s" | tail -n2
echo

# Compare
if [ -n "$HASHRATE" ] && [ -n "$HASHRATE2" ]; then
    DIFF=$((HASHRATE2 - HASHRATE))
    PERCENT=$(echo "scale=2; ($DIFF * 100) / $HASHRATE" | bc)
    if [ ${DIFF:0:1} != "-" ]; then
        echo -e "${GREEN}No-yield improved performance by $DIFF H/s ($PERCENT%)${NC}"
    else
        echo -e "${YELLOW}Default configuration performed better${NC}"
    fi
    echo
fi

# Test 3: Test with explicit huge pages (Linux only)
if [ -f /proc/meminfo ]; then
    HUGEPAGES_FREE=$(grep HugePages_Free /proc/meminfo | awk '{print $2}')
    if [ "$HUGEPAGES_FREE" -gt 0 ]; then
        echo -e "${BLUE}Test 3: With Huge Pages${NC}"
        echo "Running: $X_BINARY --bench=$BENCH_SIZE --cpu-no-yield --randomx-no-numa"
        OUTPUT=$($X_BINARY --bench=$BENCH_SIZE --cpu-no-yield --randomx-no-numa 2>&1)
        HASHRATE3=$(echo "$OUTPUT" | extract_hashrate)
        echo "Result: $HASHRATE3 H/s"
        echo "$OUTPUT" | grep "algo\|time\|H/s" | tail -n2
        echo
    fi
fi

# Summary
echo "============================================"
echo " Benchmark Summary"
echo "============================================"
echo
echo "Algorithm: RandomX (rx/0)"
echo
echo "Results:"
printf "  %-30s: %s H/s\n" "Default" "$HASHRATE"
printf "  %-30s: %s H/s\n" "CPU No Yield" "$HASHRATE2"
if [ -n "$HASHRATE3" ]; then
    printf "  %-30s: %s H/s\n" "No Yield + No NUMA" "$HASHRATE3"
fi
echo

# Recommendations
echo "Recommendations:"
echo

if [ -f /proc/meminfo ]; then
    HUGEPAGES_TOTAL=$(grep HugePages_Total /proc/meminfo | awk '{print $2}')
    if [ "$HUGEPAGES_TOTAL" -eq 0 ]; then
        echo -e "  ${YELLOW}• Enable huge pages:${NC} sudo ./scripts/setup_hugepages.sh"
    fi

    # Check for AMD CPU
    if grep -q "AMD" /proc/cpuinfo; then
        echo -e "  ${YELLOW}• Optimize for AMD Ryzen:${NC} sudo ./scripts/randomx_boost.sh"
    fi
fi

echo "  • Use --cpu-no-yield for dedicated mining"
echo "  • Adjust thread count based on L3 cache (L3_MB / 2)"
echo "  • See PERFORMANCE.md for detailed tuning guide"
echo

echo -e "${GREEN}Benchmark complete!${NC}"
