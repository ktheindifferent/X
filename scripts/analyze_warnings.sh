#!/bin/bash
# analyze_warnings.sh - Analyze compiler warnings from build
# Creates detailed report of warnings in X-specific vs third-party code

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
RESULTS_DIR="$PROJECT_DIR/code_quality_results"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== X Miner Compiler Warning Analysis ===${NC}"
echo

# Create results directory
mkdir -p "$RESULTS_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BUILD_LOG="$RESULTS_DIR/build_${TIMESTAMP}.log"
REPORT="$RESULTS_DIR/warning_analysis_${TIMESTAMP}.md"

echo -e "${GREEN}Configuration:${NC}"
echo "  Project: $PROJECT_DIR"
echo "  Build dir: $BUILD_DIR"
echo "  Build log: $BUILD_LOG"
echo "  Report: $REPORT"
echo

# Clean and rebuild with warnings
echo -e "${BLUE}Rebuilding project with full warnings...${NC}"
cd "$BUILD_DIR"

# Clean build
echo -e "${YELLOW}Cleaning build directory...${NC}"
make clean > /dev/null 2>&1 || true

# Build and capture all output
echo -e "${YELLOW}Building with -Wall -Wextra...${NC}"
echo "This may take a few minutes..."
make -j$(sysctl -n hw.ncpu 2>/dev/null || echo "4") 2>&1 | tee "$BUILD_LOG"

echo
echo -e "${GREEN}Build complete!${NC}"
echo

# Analyze warnings
cd "$PROJECT_DIR"

echo -e "${BLUE}Analyzing warnings...${NC}"

# Count total warnings
TOTAL_WARNINGS=$(grep -c "warning:" "$BUILD_LOG" || echo "0")

# Separate X-specific vs third-party warnings
X_WARNINGS=$(grep "warning:" "$BUILD_LOG" | grep -v "3rdparty" | grep -v "crypto/ghostrider" || echo "")
X_COUNT=$(echo "$X_WARNINGS" | grep -c "warning:" || echo "0")

THIRD_PARTY_WARNINGS=$(grep "warning:" "$BUILD_LOG" | grep -E "3rdparty|crypto/ghostrider" || echo "")
THIRD_PARTY_COUNT=$(echo "$THIRD_PARTY_WARNINGS" | grep -c "warning:" || echo "0")

echo -e "${GREEN}Warning Summary:${NC}"
echo "  Total warnings: $TOTAL_WARNINGS"
echo "  X-specific: $X_COUNT"
echo "  Third-party: $THIRD_PARTY_COUNT"
echo

# Generate markdown report
cat > "$REPORT" <<EOF
# X Miner Compiler Warning Analysis

**Date:** $(date)
**Compiler:** $(clang --version | head -1)
**Build Type:** Release with -Wall -Wextra

## Summary

- **Total Warnings:** $TOTAL_WARNINGS
- **X-Specific Code:** $X_COUNT
- **Third-Party Code:** $THIRD_PARTY_COUNT

## Warning Distribution

\`\`\`
X-Specific:   $X_COUNT ($((X_COUNT * 100 / (TOTAL_WARNINGS + 1)))%)
Third-Party:  $THIRD_PARTY_COUNT ($((THIRD_PARTY_COUNT * 100 / (TOTAL_WARNINGS + 1)))%)
\`\`\`

---

## X-Specific Warnings ($X_COUNT)

These warnings are in X miner code and should be reviewed for fixes:

\`\`\`
EOF

if [ ! -z "$X_WARNINGS" ]; then
    echo "$X_WARNINGS" | head -50 >> "$REPORT"
else
    echo "No X-specific warnings found!" >> "$REPORT"
fi

cat >> "$REPORT" <<EOF
\`\`\`

### X-Specific Warning Categories

EOF

if [ ! -z "$X_WARNINGS" ]; then
    echo "$X_WARNINGS" | sed -E 's/.*warning: (.*) \[.*/\1/' | sort | uniq -c | sort -rn >> "$REPORT"
else
    echo "None" >> "$REPORT"
fi

cat >> "$REPORT" <<EOF

---

## Third-Party Warnings ($THIRD_PARTY_COUNT)

These warnings are in third-party dependencies (acceptable):

### By Library

EOF

# Count warnings by library
if [ ! -z "$THIRD_PARTY_WARNINGS" ]; then
    echo "$THIRD_PARTY_WARNINGS" | grep -o "3rdparty/[^/]*" | sort | uniq -c | sort -rn >> "$REPORT"
    echo >> "$REPORT"
    echo "$THIRD_PARTY_WARNINGS" | grep -o "crypto/ghostrider" | wc -l | xargs -I {} echo "  {} crypto/ghostrider" >> "$REPORT"
fi

cat >> "$REPORT" <<EOF

### Sample Third-Party Warnings (first 20)

\`\`\`
EOF

if [ ! -z "$THIRD_PARTY_WARNINGS" ]; then
    echo "$THIRD_PARTY_WARNINGS" | head -20 >> "$REPORT"
else
    echo "No third-party warnings found!" >> "$REPORT"
fi

cat >> "$REPORT" <<EOF
\`\`\`

---

## Analysis

### X-Specific Code Quality

EOF

if [ $X_COUNT -eq 0 ]; then
    cat >> "$REPORT" <<EOF
✅ **Excellent!** No warnings in X-specific code.

The X miner codebase is clean with no compiler warnings in the custom code.
EOF
elif [ $X_COUNT -lt 10 ]; then
    cat >> "$REPORT" <<EOF
✅ **Very Good!** Only $X_COUNT warnings in X-specific code.

These warnings should be reviewed and fixed if possible, but the overall code quality is high.

#### Recommended Actions:
1. Review each warning individually
2. Fix warnings where appropriate
3. Add \`[[maybe_unused]]\" attribute for intentionally unused parameters
4. Document any warnings that cannot be fixed
EOF
else
    cat >> "$REPORT" <<EOF
⚠️ **Needs Attention:** $X_COUNT warnings in X-specific code.

These warnings should be systematically reviewed and addressed.

#### Recommended Actions:
1. Categorize warnings by type
2. Prioritize fixes (unused parameters, potential bugs, etc.)
3. Create issues for each category
4. Fix systematically, testing after each change
EOF
fi

cat >> "$REPORT" <<EOF

### Third-Party Code

✅ Third-party warnings are **acceptable** and do not require fixes.

These come from external libraries and crypto implementations:
- argon2 (password hashing)
- llhttp (HTTP parser)
- ghostrider crypto libraries
- Other external dependencies

### Recommendations

#### Short-term
- Fix all critical warnings in X-specific code
- Add \`-Werror\` flag for X-specific code (CI/CD)
- Document acceptable third-party warnings

#### Long-term
- Consider updating third-party dependencies
- Contribute fixes upstream where applicable
- Enable additional warning flags (-Wconversion, -Wshadow)

---

## Files Reference

- **Build Log:** \`$(basename $BUILD_LOG)\`
- **Full warnings:** See build log for complete output

## Next Steps

1. Review X-specific warnings in detail
2. Create plan for fixing each category
3. Test fixes with \`./scripts/quick_benchmark.sh\`
4. Consider enabling \`-Werror\` for CI builds

---

**Generated by:** \`scripts/analyze_warnings.sh\`
**Last Updated:** $(date)
EOF

# Display report
echo -e "${GREEN}=== Analysis Complete ===${NC}"
echo
cat "$REPORT"

echo
echo -e "${BLUE}Full report saved to:${NC}"
echo "  $REPORT"
echo
echo -e "${BLUE}Build log saved to:${NC}"
echo "  $BUILD_LOG"
echo
