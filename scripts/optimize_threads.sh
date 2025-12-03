#!/bin/bash
# optimize_threads.sh - Find optimal thread count for mining
# Tests different thread counts and recommends the best configuration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BINARY="$PROJECT_DIR/build/x"
RESULTS_DIR="$PROJECT_DIR/thread_optimization_results"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get CPU info
TOTAL_THREADS=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo "16")
PHYSICAL_CORES=$((TOTAL_THREADS / 2))  # Assume HT/SMT

echo -e "${BLUE}=== X Miner Thread Count Optimization ===${NC}"
echo
echo -e "${GREEN}System Information:${NC}"
echo "  CPU: $(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Unknown")"
echo "  Total Threads: $TOTAL_THREADS"
echo "  Physical Cores: $PHYSICAL_CORES (estimated)"
echo

# Check if binary exists
if [ ! -f "$BINARY" ]; then
    echo -e "${RED}Error: X binary not found at $BINARY${NC}"
    echo "Please build the project first: cd build && cmake .. && make"
    exit 1
fi

# Create results directory
mkdir -p "$RESULTS_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Algorithm to test (default RandomX)
ALGORITHM="${1:-rx/0}"
BENCHMARK_SIZE="10M"
DURATION=30  # seconds per test

echo -e "${YELLOW}Testing algorithm: $ALGORITHM${NC}"
echo -e "${YELLOW}Benchmark size: $BENCHMARK_SIZE${NC}"
echo -e "${YELLOW}Duration per test: ${DURATION}s${NC}"
echo

# Thread counts to test
# Test: all threads, physical cores, and a few in between
THREAD_COUNTS=(
    $TOTAL_THREADS
    $((TOTAL_THREADS * 3 / 4))
    $PHYSICAL_CORES
    $((PHYSICAL_CORES * 3 / 4))
    $((PHYSICAL_CORES / 2))
)

# Remove duplicates and sort
THREAD_COUNTS=($(printf '%s\n' "${THREAD_COUNTS[@]}" | sort -rn | uniq))

echo -e "${GREEN}Thread counts to test:${NC} ${THREAD_COUNTS[*]}"
echo

# Results storage
declare -a RESULTS_THREADS
declare -a RESULTS_HASHRATE
declare -a RESULTS_CPU
declare -a RESULTS_TEMP

RESULT_FILE="$RESULTS_DIR/thread_optimization_${ALGORITHM//\//_}_${TIMESTAMP}.md"

# Initialize report
cat > "$RESULT_FILE" <<EOF
# Thread Count Optimization Results

**Date:** $(date)
**System:** $(uname -s) $(uname -m)
**CPU:** $(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Unknown")
**Total Threads:** $TOTAL_THREADS
**Physical Cores:** $PHYSICAL_CORES
**Algorithm:** $ALGORITHM
**Test Duration:** ${DURATION}s per configuration

---

## Test Results

| Threads | Hashrate | CPU Usage | Efficiency | Notes |
|---------|----------|-----------|------------|-------|
EOF

# Test each thread count
BEST_HASHRATE=0
BEST_THREADS=0

for THREADS in "${THREAD_COUNTS[@]}"; do
    echo
    echo -e "${BLUE}=== Testing with $THREADS threads ===${NC}"
    echo

    # Run benchmark
    OUTPUT_FILE="$RESULTS_DIR/test_${THREADS}threads_${TIMESTAMP}.txt"

    echo -e "${GREEN}Starting benchmark...${NC}"
    timeout ${DURATION}s "$BINARY" \
        --bench=$BENCHMARK_SIZE \
        --threads=$THREADS \
        --no-color \
        > "$OUTPUT_FILE" 2>&1 || true

    # Wait for completion
    sleep 2

    # Extract hashrate (last "speed" line)
    HASHRATE=$(grep -i "speed" "$OUTPUT_FILE" | tail -1 | awk '{print $3}' || echo "0")

    # Extract CPU usage if available
    CPU_USAGE="N/A"

    echo -e "${GREEN}Results:${NC}"
    echo "  Threads: $THREADS"
    echo "  Hashrate: $HASHRATE H/s"

    # Store results
    RESULTS_THREADS+=("$THREADS")
    RESULTS_HASHRATE+=("$HASHRATE")
    RESULTS_CPU+=("$CPU_USAGE")

    # Calculate efficiency (hashrate per thread)
    if [ "$HASHRATE" != "0" ] && [ "$HASHRATE" != "" ]; then
        EFFICIENCY=$(echo "scale=2; $HASHRATE / $THREADS" | bc 2>/dev/null || echo "N/A")
    else
        EFFICIENCY="N/A"
    fi

    # Add to report
    echo "| $THREADS | $HASHRATE H/s | $CPU_USAGE | $EFFICIENCY H/s/thread | |" >> "$RESULT_FILE"

    # Track best
    if [ "$HASHRATE" != "0" ] && [ "$HASHRATE" != "" ]; then
        if (( $(echo "$HASHRATE > $BEST_HASHRATE" | bc -l 2>/dev/null || echo "0") )); then
            BEST_HASHRATE=$HASHRATE
            BEST_THREADS=$THREADS
        fi
    fi
done

# Add analysis to report
cat >> "$RESULT_FILE" <<EOF

---

## Analysis

### Best Configuration

**Recommended Thread Count:** $BEST_THREADS threads
**Expected Hashrate:** $BEST_HASHRATE H/s

### Observations

EOF

# Add observations based on results
if [ $BEST_THREADS -eq $TOTAL_THREADS ]; then
    cat >> "$RESULT_FILE" <<EOF
- ✅ **Using all threads ($TOTAL_THREADS) provides best performance**
- Your CPU handles HyperThreading/SMT well for mining
- Thermal throttling is not an issue
EOF
elif [ $BEST_THREADS -eq $PHYSICAL_CORES ]; then
    cat >> "$RESULT_FILE" <<EOF
- ✅ **Using physical cores only ($PHYSICAL_CORES) is optimal**
- HyperThreading/SMT doesn't provide benefit for this algorithm
- This is common for memory-intensive algorithms
EOF
else
    cat >> "$RESULT_FILE" <<EOF
- ⚠️ **Optimal thread count ($BEST_THREADS) is less than total ($TOTAL_THREADS)**
- Possible reasons:
  - Thermal throttling with all cores at 100%
  - Memory bandwidth limitations
  - Cache contention
- Consider improving cooling if using fewer threads due to thermals
EOF
fi

cat >> "$RESULT_FILE" <<EOF

### Recommendations

1. **Configure X with optimal thread count:**
   \`\`\`json
   {
     "cpu": {
       "enabled": true,
       "max-threads-hint": $BEST_THREADS
     }
   }
   \`\`\`

2. **Monitor temperatures during extended mining:**
   \`\`\`bash
   pmset -g thermlog  # macOS
   \`\`\`

3. **Re-test periodically:**
   - After system updates
   - After cooling improvements
   - For different algorithms

EOF

# Print summary
echo
echo -e "${GREEN}=== Optimization Complete ===${NC}"
echo
echo -e "${BLUE}Best Configuration:${NC}"
echo "  Thread Count: $BEST_THREADS"
echo "  Hashrate: $BEST_HASHRATE H/s"
echo
echo -e "${BLUE}Full report saved to:${NC}"
echo "  $RESULT_FILE"
echo
echo -e "${BLUE}View report:${NC}"
echo "  cat $RESULT_FILE"
echo

# Show recommendation
echo -e "${YELLOW}=== Recommendation ===${NC}"
if [ $BEST_THREADS -eq $TOTAL_THREADS ]; then
    echo -e "${GREEN}✅ Use all $TOTAL_THREADS threads for best performance${NC}"
    echo "   Your system handles full load well"
elif [ $BEST_THREADS -eq $PHYSICAL_CORES ]; then
    echo -e "${YELLOW}⚠️ Use $PHYSICAL_CORES threads (physical cores only)${NC}"
    echo "   HyperThreading doesn't help for this algorithm"
else
    echo -e "${YELLOW}⚠️ Use $BEST_THREADS threads for optimal balance${NC}"
    echo "   This avoids thermal throttling or resource contention"
fi

echo
echo -e "${BLUE}To configure X with optimal settings:${NC}"
echo "  Edit your config.json and set:"
echo "  \"cpu\": { \"max-threads-hint\": $BEST_THREADS }"
echo
