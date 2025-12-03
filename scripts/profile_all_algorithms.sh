#!/bin/bash
# profile_all_algorithms.sh - Profile all CPU algorithms for comparison
# Creates comprehensive performance report

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BINARY="$PROJECT_DIR/build/x"
RESULTS_DIR="$PROJECT_DIR/profiling_results"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== X Miner Multi-Algorithm Profiling ===${NC}"
echo

# Check if binary exists
if [ ! -f "$BINARY" ]; then
    echo -e "${RED}Error: X binary not found at $BINARY${NC}"
    echo "Please build the project first: cd build && make"
    exit 1
fi

# Create results directory
mkdir -p "$RESULTS_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT="$RESULTS_DIR/algorithm_comparison_${TIMESTAMP}.md"

# Algorithms to test (CPU-only, no GPU algorithms)
# Format: "algorithm:benchmark_size"
ALGORITHMS=(
    "randomx:10M"
    "cn:1M"
    "cn-lite:1M"
)

DURATION=45  # Profile duration in seconds

echo -e "${GREEN}Configuration:${NC}"
echo "  Binary: $BINARY"
echo "  Duration: ${DURATION}s per algorithm"
echo "  Algorithms: randomx, cn, cn-lite"
echo "  Report: $REPORT"
echo

# Initialize report
cat > "$REPORT" <<EOF
# X Miner Algorithm Performance Comparison

**Date:** $(date)
**System:** $(uname -s) $(uname -m)
**CPU:** $(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Unknown")
**Cores:** $(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo "Unknown")
**Binary:** $BINARY
**Profile Duration:** ${DURATION}s per algorithm

---

## Executive Summary

This report compares the performance characteristics of different mining algorithms on the same hardware.

EOF

# Profile each algorithm
for algo_spec in "${ALGORITHMS[@]}"; do
    # Split algorithm:benchmark_size
    algo="${algo_spec%%:*}"
    bench_size="${algo_spec##*:}"

    echo
    echo -e "${BLUE}=== Profiling $algo algorithm ===${NC}"
    echo

    OUTPUT_PREFIX="$RESULTS_DIR/profile_${algo}_${TIMESTAMP}"

    # Run miner in benchmark mode
    echo -e "${GREEN}Starting benchmark (${bench_size} iterations)...${NC}"
    "$BINARY" \
        --bench=$bench_size \
        --threads=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo "4") \
        --no-color \
        > "$OUTPUT_PREFIX.stdout.txt" 2>&1 &

    MINER_PID=$!
    echo "Miner PID: $MINER_PID"

    # Wait for miner to initialize
    sleep 3

    # Check if miner is still running
    if ! kill -0 $MINER_PID 2>/dev/null; then
        echo -e "${RED}Error: Miner failed to start for $algo${NC}"
        echo "Check output: cat $OUTPUT_PREFIX.stdout.txt"
        continue
    fi

    # Profile with sample (macOS)
    echo -e "${YELLOW}Collecting CPU samples for ${DURATION} seconds...${NC}"
    sample $MINER_PID $DURATION -file "$OUTPUT_PREFIX.sample.txt" 2>&1 > /dev/null &
    SAMPLE_PID=$!

    # Show progress
    for i in $(seq 1 $DURATION); do
        if ! kill -0 $MINER_PID 2>/dev/null; then
            echo -e "\n${RED}Miner stopped unexpectedly${NC}"
            break
        fi
        printf "."
        sleep 1
    done
    echo

    # Wait for sample to finish
    wait $SAMPLE_PID 2>/dev/null || true

    # Get final stats
    if kill -0 $MINER_PID 2>/dev/null; then
        ps -p $MINER_PID -o %cpu,%mem,rss,vsz,time > "$OUTPUT_PREFIX.stats.txt"

        # Stop miner
        kill $MINER_PID 2>/dev/null || true
        wait $MINER_PID 2>/dev/null || true
    fi

    # Wait a bit for output to flush
    sleep 2

    # Extract hashrate
    HASHRATE=$(grep -i "speed" "$OUTPUT_PREFIX.stdout.txt" | tail -1 || echo "Not found")
    echo -e "${GREEN}Hashrate: ${NC}$HASHRATE"

    # Extract CPU usage
    CPU_USAGE=$(cat "$OUTPUT_PREFIX.stats.txt" 2>/dev/null | tail -1 | awk '{print $1}' || echo "N/A")
    MEM_USAGE=$(cat "$OUTPUT_PREFIX.stats.txt" 2>/dev/null | tail -1 | awk '{print $3}' || echo "N/A")

    echo -e "${GREEN}CPU: ${NC}${CPU_USAGE}%"
    echo -e "${GREEN}Memory: ${NC}${MEM_USAGE} KB"

    # Add to report
    cat >> "$REPORT" <<EOF

## $algo Algorithm

### Configuration
- Benchmark: ${bench_size} iterations
- Threads: $(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo "4")

### Performance Metrics

EOF

    # Add hashrate
    echo '```' >> "$REPORT"
    echo "$HASHRATE" >> "$REPORT"
    echo '```' >> "$REPORT"
    echo >> "$REPORT"

    # Add resource usage
    cat >> "$REPORT" <<EOF
**Resource Usage:**
- CPU: ${CPU_USAGE}%
- Memory: ${MEM_USAGE} KB ($(echo "scale=2; $MEM_USAGE / 1024" | bc 2>/dev/null || echo "N/A") MB)

### Hot Functions (Top 10)

\`\`\`
EOF

    # Extract top functions from sample
    if [ -f "$OUTPUT_PREFIX.sample.txt" ]; then
        grep -A 40 "Call graph:" "$OUTPUT_PREFIX.sample.txt" | head -50 >> "$REPORT" || echo "Profile data unavailable" >> "$REPORT"
    else
        echo "Profile data unavailable" >> "$REPORT"
    fi

    echo '```' >> "$REPORT"
    echo >> "$REPORT"

    # Extract top 5 hot functions
    cat >> "$REPORT" <<EOF

### Analysis

EOF

    if [ -f "$OUTPUT_PREFIX.sample.txt" ]; then
        echo "**Key bottlenecks identified:**" >> "$REPORT"
        echo >> "$REPORT"
        # Try to extract meaningful function names
        grep -E "0x[0-9a-f]+" "$OUTPUT_PREFIX.sample.txt" 2>/dev/null | head -10 | while read line; do
            echo "- $line" >> "$REPORT"
        done 2>/dev/null || echo "- See detailed profile for function-level analysis" >> "$REPORT"
    else
        echo "Profile data not available for detailed analysis." >> "$REPORT"
    fi

    echo >> "$REPORT"
    echo "---" >> "$REPORT"
    echo >> "$REPORT"
done

# Add comparative analysis
cat >> "$REPORT" <<EOF

## Comparative Analysis

### Algorithm Characteristics

| Algorithm | Best For | Memory Usage | CPU Intensity |
|-----------|----------|--------------|---------------|
| RandomX | Monero, TARI | High (2GB+) | Very High |
| CryptoNight | Monero legacy | Medium (2MB per thread) | High |
| CryptoNight-Lite | Lightweight coins | Low (1MB per thread) | Medium |

### Performance Summary

EOF

# Extract all hashrates for comparison
for algo_spec in "${ALGORITHMS[@]}"; do
    algo="${algo_spec%%:*}"
    OUTPUT_PREFIX="$RESULTS_DIR/profile_${algo}_${TIMESTAMP}"
    if [ -f "$OUTPUT_PREFIX.stdout.txt" ]; then
        HASHRATE=$(grep -i "speed" "$OUTPUT_PREFIX.stdout.txt" | tail -1 || echo "N/A")
        CPU=$(cat "$OUTPUT_PREFIX.stats.txt" 2>/dev/null | tail -1 | awk '{print $1}' || echo "N/A")
        MEM=$(cat "$OUTPUT_PREFIX.stats.txt" 2>/dev/null | tail -1 | awk '{print $3}' || echo "N/A")

        cat >> "$REPORT" <<EOF
**$algo:**
- Hashrate: $HASHRATE
- CPU: ${CPU}%
- Memory: $(echo "scale=2; $MEM / 1024" | bc 2>/dev/null || echo "N/A") MB

EOF
    fi
done

cat >> "$REPORT" <<EOF

### Recommendations

Based on the profiling results:

1. **Algorithm Selection**
   - For CPU mining: RandomX typically provides best results on modern CPUs
   - Memory-constrained systems: Consider CryptoNight-Lite
   - Multi-threaded systems: RandomX scales well with cores

2. **Optimization Opportunities**
   - Check hot functions for optimization potential
   - Verify huge pages are enabled (10-30% improvement for RandomX)
   - Ensure CPU affinity is properly configured
   - Monitor memory bandwidth utilization

3. **Next Steps**
   - Run extended profiling sessions (5+ minutes)
   - Profile with different thread counts
   - Test with huge pages enabled vs disabled
   - Compare with and without NUMA awareness

---

## Files Reference

All profiling data saved to: \`$RESULTS_DIR/\`

EOF

for algo_spec in "${ALGORITHMS[@]}"; do
    algo="${algo_spec%%:*}"
    cat >> "$REPORT" <<EOF
**$algo:**
- \`profile_${algo}_${TIMESTAMP}.sample.txt\` - CPU sampling data
- \`profile_${algo}_${TIMESTAMP}.stdout.txt\` - Miner output
- \`profile_${algo}_${TIMESTAMP}.stats.txt\` - Resource usage

EOF
done

cat >> "$REPORT" <<EOF

---

**Generated by:** \`scripts/profile_all_algorithms.sh\`
**Last Updated:** $(date)
EOF

echo
echo -e "${GREEN}=== Profiling Complete ===${NC}"
echo
echo -e "${BLUE}Performance comparison report:${NC}"
echo "  $REPORT"
echo
echo -e "${BLUE}View report:${NC}"
echo "  cat $REPORT"
echo "  # or open in editor"
echo
