#!/bin/bash
# Benchmark different scratchpad prefetch modes for RandomX
# This script tests modes 0-3 and measures hashrate impact

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
BINARY="$BUILD_DIR/x"
RESULTS_DIR="$PROJECT_DIR/prefetch_benchmarks"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== RandomX Prefetch Mode Benchmark ===${NC}"
echo "Testing all prefetch modes (0-3) for optimal performance"
echo

# Check if binary exists
if [ ! -f "$BINARY" ]; then
    echo -e "${RED}Error: Binary not found at $BINARY${NC}"
    echo "Please build the project first: cd build && make"
    exit 1
fi

# Create results directory
mkdir -p "$RESULTS_DIR"

# Get timestamp for results
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_FILE="$RESULTS_DIR/prefetch_comparison_${TIMESTAMP}.md"

# Benchmark parameters
BENCHMARK_DURATION=30  # seconds per test
POOL="pool-global.tari.snipanet.com:3333"
WALLET="127PHAz3ePq93yWJ1Gsz8VzznQFui5LYne5jbwtErzD5WsnqWAfPR37KwMyGAf5UjD2nXbYZiQPz7GMTEQRCTrGV3fH"
WORKER="prefetch_test"

# Start results file
cat > "$RESULTS_FILE" << EOF
# RandomX Prefetch Mode Benchmark Results
**Date**: $(date '+%Y-%m-%d %H:%M:%S')
**CPU**: $(sysctl -n machdep.cpu.brand_string 2>/dev/null || lscpu | grep "Model name" || echo "Unknown")
**Cores**: $(sysctl -n hw.ncpu 2>/dev/null || nproc || echo "Unknown")
**Duration**: ${BENCHMARK_DURATION} seconds per mode

## Prefetch Modes Explained

- **Mode 0**: No prefetching (disabled)
  - Baseline performance, highest latency
  - Instruction: NOP (no operation)

- **Mode 1**: PREFETCHT0 (default)
  - Prefetch to all cache levels (L1, L2, L3)
  - Best for data accessed soon
  - Instruction: prefetcht0 [rsi+rax]

- **Mode 2**: PREFETCHNTA
  - Non-temporal prefetch (bypass L1, goes to L2/L3)
  - Minimizes cache pollution
  - Instruction: prefetchnta [rsi+rax]

- **Mode 3**: Forced Memory Read
  - Actually loads data (not just prefetch hint)
  - Guaranteed cache presence
  - Instruction: mov rcx, [rsi+rax]

## Results

| Mode | Description | Avg Hashrate | vs Mode 1 | vs Best |
|------|-------------|--------------|-----------|---------|
EOF

# Array to store results
declare -a HASHRATES
declare -a MODES=("0" "1" "2" "3")
declare -a MODE_NAMES=(
    "Disabled (NOP)"
    "PREFETCHT0 (default)"
    "PREFETCHNTA"
    "Forced Read (MOV)"
)

echo -e "${YELLOW}Starting benchmark... This will take about $((BENCHMARK_DURATION * 4 / 60)) minutes${NC}"
echo

# Test each mode
for i in "${!MODES[@]}"; do
    MODE="${MODES[$i]}"
    NAME="${MODE_NAMES[$i]}"

    echo -e "${GREEN}Testing Mode $MODE: $NAME${NC}"
    echo "Duration: ${BENCHMARK_DURATION}s"

    # Run benchmark
    # Note: This would need to be implemented in the C++ code to actually set the prefetch mode
    # For now, this is a template showing how it would be tested

    echo -e "${YELLOW}  Starting mining...${NC}"

    # TODO: Actual implementation would call:
    # randomx_set_scratchpad_prefetch_mode($MODE) before starting
    # This requires exposing the function via command-line argument or config

    # Simulated run (replace with actual benchmark once C++ support is added)
    # HASHRATE=$("$BINARY" --bench=rx/0 --no-color 2>&1 | grep -oP 'speed.*\K[0-9.]+' | head -n 1)

    echo -e "${YELLOW}  Mode $MODE benchmark would run here${NC}"
    echo "  (Requires C++ implementation to expose prefetch mode setting)"

    # Store result (placeholder)
    HASHRATES[$i]="TBD"

    echo
done

# Write summary
cat >> "$RESULTS_FILE" << EOF

## Analysis

### Key Findings

(To be filled after actual benchmark runs)

### Recommendations

Based on CPU architecture:
- **Intel CPUs**: Test modes 1 and 3
- **AMD Zen**: Test modes 1 and 2
- **AMD Zen4/5**: Test mode 3 (strong out-of-order execution)

### Implementation Notes

To enable prefetch mode testing, add to \`src/crypto/rx/RxConfig.cpp\`:

\`\`\`cpp
// Add to config
int prefetchMode = 1;  // Default

// In initialization:
randomx_set_scratchpad_prefetch_mode(prefetchMode);
\`\`\`

Add command-line option:
\`\`\`cpp
--randomx-prefetch-mode=<0-3>
\`\`\`

Or JSON config:
\`\`\`json
{
  "randomx": {
    "prefetch-mode": 1
  }
}
\`\`\`

---

**Next Steps**:
1. Implement configuration option for prefetch mode
2. Run actual benchmarks on various CPUs
3. Set CPU-specific defaults based on results
4. Document optimal settings per CPU family

EOF

echo -e "${GREEN}=== Benchmark Template Created ===${NC}"
echo "Results template saved to: $RESULTS_FILE"
echo
echo -e "${YELLOW}Note: This is a template script.${NC}"
echo "To run actual benchmarks, the prefetch mode needs to be exposed"
echo "as a configuration option in the C++ code."
echo
echo -e "${GREEN}Recommended implementation:${NC}"
echo "1. Add --randomx-prefetch-mode=N command-line option"
echo "2. Add prefetch-mode to JSON config"
echo "3. Call randomx_set_scratchpad_prefetch_mode() during RxDataset initialization"
echo "4. Re-run this script with actual benchmarking"

