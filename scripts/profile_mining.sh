#!/bin/bash
# profile_mining.sh - Profile X miner performance on macOS
# Usage: ./profile_mining.sh [algorithm] [duration]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BINARY="$PROJECT_DIR/build/x"
RESULTS_DIR="$PROJECT_DIR/profiling_results"

# Default parameters
ALGORITHM="${1:-rx/0}"  # RandomX by default
DURATION="${2:-30}"     # 30 seconds by default
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== X Miner Profiling Tool ===${NC}"
echo

# Check if binary exists
if [ ! -f "$BINARY" ]; then
    echo -e "${RED}Error: X binary not found at $BINARY${NC}"
    echo "Please build the project first: cd build && make"
    exit 1
fi

# Create results directory
mkdir -p "$RESULTS_DIR"

# Determine algorithm name for file naming
case "$ALGORITHM" in
    rx/0|rx/*) ALG_NAME="randomx" ;;
    cn/*) ALG_NAME="cryptonight" ;;
    kawpow) ALG_NAME="kawpow" ;;
    ghostrider|gr) ALG_NAME="ghostrider" ;;
    *) ALG_NAME="unknown" ;;
esac

OUTPUT_PREFIX="$RESULTS_DIR/profile_${ALG_NAME}_${TIMESTAMP}"

echo -e "${GREEN}Configuration:${NC}"
echo "  Algorithm: $ALGORITHM"
echo "  Duration: ${DURATION}s"
echo "  Binary: $BINARY"
echo "  Results: $OUTPUT_PREFIX.*"
echo

# Function to cleanup on exit
cleanup() {
    if [ ! -z "$MINER_PID" ] && kill -0 $MINER_PID 2>/dev/null; then
        echo -e "\n${YELLOW}Stopping miner...${NC}"
        kill $MINER_PID 2>/dev/null || true
        wait $MINER_PID 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM

echo -e "${BLUE}=== Starting Benchmark Mode ===${NC}"
echo "This will run the miner in benchmark mode for profiling."
echo

# Run miner in benchmark mode in background
# Use 10M iterations which is long enough for profiling
echo -e "${GREEN}Starting miner in benchmark mode...${NC}"
"$BINARY" \
    --bench=10M \
    --threads=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo "4") \
    --no-color \
    > "$OUTPUT_PREFIX.stdout.txt" 2>&1 &

MINER_PID=$!
echo "Miner PID: $MINER_PID"
echo

# Wait for miner to initialize
sleep 3

# Check if miner is still running
if ! kill -0 $MINER_PID 2>/dev/null; then
    echo -e "${RED}Error: Miner failed to start${NC}"
    echo "Check output: cat $OUTPUT_PREFIX.stdout.txt"
    exit 1
fi

echo -e "${BLUE}=== Profiling with 'sample' tool ===${NC}"
echo "Collecting CPU samples for ${DURATION} seconds..."

# Run sample profiler
sample "$MINER_PID" "$DURATION" -file "$OUTPUT_PREFIX.sample.txt" 2>&1 | head -20 &
SAMPLE_PID=$!

# Show real-time stats while profiling
echo
echo -e "${YELLOW}Profiling in progress...${NC}"
for i in $(seq 1 $DURATION); do
    if ! kill -0 $MINER_PID 2>/dev/null; then
        echo -e "\n${RED}Miner stopped unexpectedly${NC}"
        break
    fi
    printf "."
    sleep 1
done
echo
echo

# Wait for sample to finish
wait $SAMPLE_PID 2>/dev/null || true

# Collect CPU usage statistics
echo -e "${BLUE}=== Collecting CPU Usage Stats ===${NC}"
if kill -0 $MINER_PID 2>/dev/null; then
    ps -p $MINER_PID -o %cpu,%mem,rss,vsz,time | tee "$OUTPUT_PREFIX.stats.txt"
    echo
fi

# Get final hashrate from output
echo -e "${BLUE}=== Extracting Hashrate ===${NC}"
sleep 2  # Let final stats flush
if [ -f "$OUTPUT_PREFIX.stdout.txt" ]; then
    echo -e "${GREEN}Last 20 lines of output:${NC}"
    tail -20 "$OUTPUT_PREFIX.stdout.txt"
    echo

    # Extract hashrate if available
    HASHRATE=$(grep -i "speed" "$OUTPUT_PREFIX.stdout.txt" | tail -1 || echo "Not found")
    echo -e "${GREEN}Hashrate: ${NC}$HASHRATE"
fi

# Stop the miner
kill $MINER_PID 2>/dev/null || true
wait $MINER_PID 2>/dev/null || true
MINER_PID=""

echo
echo -e "${GREEN}=== Profiling Complete ===${NC}"
echo
echo "Results saved to:"
echo "  - $OUTPUT_PREFIX.sample.txt (CPU sampling data)"
echo "  - $OUTPUT_PREFIX.stdout.txt (Miner output)"
echo "  - $OUTPUT_PREFIX.stats.txt (CPU/Memory stats)"
echo
echo -e "${BLUE}To analyze results:${NC}"
echo "  1. View sample data: less $OUTPUT_PREFIX.sample.txt"
echo "  2. View miner output: less $OUTPUT_PREFIX.stdout.txt"
echo "  3. View CPU stats: cat $OUTPUT_PREFIX.stats.txt"
echo
echo -e "${YELLOW}For more detailed profiling, use Instruments.app:${NC}"
echo "  instruments -t 'Time Profiler' -D $OUTPUT_PREFIX.trace $BINARY --bench=$ALGORITHM"
echo

# Generate summary report
cat > "$OUTPUT_PREFIX.summary.txt" <<EOF
X Miner Profiling Summary
========================

Date: $(date)
Algorithm: $ALGORITHM
Duration: ${DURATION}s
Binary: $BINARY

Hashrate:
$HASHRATE

CPU/Memory Stats:
$(cat "$OUTPUT_PREFIX.stats.txt" 2>/dev/null || echo "Not available")

Top Functions (from sample):
$(grep -A 30 "Call graph:" "$OUTPUT_PREFIX.sample.txt" 2>/dev/null | head -40 || echo "Parse sample.txt for details")

Files:
- sample.txt: CPU sampling data
- stdout.txt: Complete miner output
- stats.txt: Resource usage statistics
- summary.txt: This summary
EOF

echo -e "${GREEN}Summary saved to: $OUTPUT_PREFIX.summary.txt${NC}"
echo
