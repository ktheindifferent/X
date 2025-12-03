#!/bin/bash
# analyze_profile.sh - Analyze profiling results and generate reports
# Usage: ./analyze_profile.sh <profile_results_prefix>

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <profile_results_prefix>"
    echo
    echo "Example: $0 profiling_results/profile_randomx_20251202_140000"
    echo
    echo "Available profiles:"
    ls -1t profiling_results/profile_*.summary.txt 2>/dev/null | head -10 | sed 's/.summary.txt//' || echo "  (none found)"
    exit 1
fi

PREFIX="$1"
REPORT="${PREFIX}.analysis.md"

# Color output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=== Analyzing Profile Results ===${NC}"
echo "Input prefix: $PREFIX"
echo "Output report: $REPORT"
echo

# Check if files exist
if [ ! -f "${PREFIX}.sample.txt" ]; then
    echo "Error: Sample file not found: ${PREFIX}.sample.txt"
    exit 1
fi

echo -e "${GREEN}Generating analysis report...${NC}"

# Create markdown report
cat > "$REPORT" <<'EOF'
# X Miner Performance Profile Analysis

## Overview

This document contains the analysis of a performance profiling session for the X miner.

EOF

# Add metadata
cat >> "$REPORT" <<EOF
**Profile Date:** $(date)
**Results Prefix:** $(basename "$PREFIX")

## Summary

EOF

# Include summary if available
if [ -f "${PREFIX}.summary.txt" ]; then
    echo '```' >> "$REPORT"
    cat "${PREFIX}.summary.txt" >> "$REPORT"
    echo '```' >> "$REPORT"
    echo >> "$REPORT"
fi

# Analyze sample data for hot functions
cat >> "$REPORT" <<EOF
## Top CPU Hotspots

The following functions consumed the most CPU time during profiling:

EOF

if [ -f "${PREFIX}.sample.txt" ]; then
    echo '```' >> "$REPORT"

    # Extract call graph section
    sed -n '/Call graph:/,/^$/p' "${PREFIX}.sample.txt" | head -50 >> "$REPORT"

    echo '```' >> "$REPORT"
    echo >> "$REPORT"
fi

# Extract hashrate information
cat >> "$REPORT" <<EOF
## Hashrate Performance

EOF

if [ -f "${PREFIX}.stdout.txt" ]; then
    # Find speed lines
    SPEED_LINES=$(grep -i "speed\|hashrate" "${PREFIX}.stdout.txt" | tail -10 || echo "No hashrate data found")

    echo '```' >> "$REPORT"
    echo "$SPEED_LINES" >> "$REPORT"
    echo '```' >> "$REPORT"
    echo >> "$REPORT"
fi

# Memory analysis
cat >> "$REPORT" <<EOF
## Resource Usage

EOF

if [ -f "${PREFIX}.stats.txt" ]; then
    echo '```' >> "$REPORT"
    cat "${PREFIX}.stats.txt" >> "$REPORT"
    echo '```' >> "$REPORT"
    echo >> "$REPORT"
fi

# Optimization recommendations
cat >> "$REPORT" <<'EOF'
## Analysis & Recommendations

### Hot Function Analysis

Based on the CPU sampling data above, the top functions should be analyzed for:

1. **Algorithm-specific optimizations**
   - JIT compiler improvements
   - SIMD instruction usage
   - Cache optimization

2. **Memory access patterns**
   - Huge pages utilization
   - NUMA awareness
   - Memory alignment

3. **Threading efficiency**
   - Lock contention
   - Thread synchronization overhead
   - CPU affinity settings

### Next Steps

1. **Identify bottlenecks**: Focus on functions consuming >5% CPU time
2. **Compare with baseline**: Run additional profiles with different configurations
3. **Implement optimizations**: Based on identified hotspots
4. **Measure improvement**: Re-profile after optimizations

### Profiling Recommendations

For deeper analysis, consider:

- **Instruments Time Profiler**: More detailed function-level analysis
- **Instruments System Trace**: Thread scheduling and system calls
- **Memory profiling**: Heap allocations and memory patterns
- **Cachegrind**: Cache miss analysis (via Valgrind)

## Files Reference

- `*.sample.txt` - Raw CPU sampling data
- `*.stdout.txt` - Complete miner output with hashrate
- `*.stats.txt` - CPU and memory usage statistics
- `*.summary.txt` - Quick summary
- `*.analysis.md` - This analysis report

EOF

echo -e "${GREEN}Analysis complete!${NC}"
echo
echo "Report generated: $REPORT"
echo
echo -e "${BLUE}View report:${NC}"
echo "  cat $REPORT"
echo "  # or open in editor"
echo

# Show quick summary
if [ -f "${PREFIX}.summary.txt" ]; then
    echo -e "${YELLOW}Quick Summary:${NC}"
    grep -A 2 "Hashrate:" "${PREFIX}.summary.txt" || true
    echo
fi
