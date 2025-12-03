#!/bin/bash
# run_clang_tidy.sh - Run clang-tidy on X-specific source files
# Excludes third-party code

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

echo -e "${BLUE}=== X Miner Clang-Tidy Analysis ===${NC}"
echo

# Check if compile_commands.json exists
if [ ! -f "$BUILD_DIR/compile_commands.json" ]; then
    echo -e "${YELLOW}compile_commands.json not found, generating...${NC}"
    cd "$BUILD_DIR"
    cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON .. > /dev/null
    cd "$PROJECT_DIR"
fi

# Create results directory
mkdir -p "$RESULTS_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_FILE="$RESULTS_DIR/clang_tidy_${TIMESTAMP}.txt"

echo -e "${GREEN}Configuration:${NC}"
echo "  Project: $PROJECT_DIR"
echo "  Build dir: $BUILD_DIR"
echo "  Output: $OUTPUT_FILE"
echo

# Check if clang-tidy is available
if ! command -v clang-tidy &> /dev/null; then
    echo -e "${RED}Error: clang-tidy not found${NC}"
    echo "Install with:"
    echo "  macOS: brew install llvm"
    echo "  Ubuntu: sudo apt-get install clang-tidy"
    exit 1
fi

CLANG_TIDY=$(command -v clang-tidy)
echo -e "${GREEN}Using clang-tidy: $CLANG_TIDY${NC}"
$CLANG_TIDY --version | head -1
echo

# Find X-specific source files (exclude 3rdparty)
echo -e "${BLUE}Finding X-specific source files...${NC}"
SOURCE_FILES=$(find "$PROJECT_DIR/src" -type f \( -name "*.cpp" -o -name "*.h" \) \
    ! -path "*/3rdparty/*" \
    ! -path "*/build/*" \
    2>/dev/null)

FILE_COUNT=$(echo "$SOURCE_FILES" | wc -l | tr -d ' ')
echo -e "${GREEN}Found $FILE_COUNT X-specific source files${NC}"
echo

# Sample of files to analyze
echo -e "${YELLOW}Sample files (first 10):${NC}"
echo "$SOURCE_FILES" | head -10
echo "..."
echo

# Run clang-tidy on a subset first (for speed)
SAMPLE_SIZE=20
echo -e "${BLUE}Running clang-tidy on first $SAMPLE_SIZE files (sample)...${NC}"
echo "This may take a few minutes..."
echo

# Create output file with header
cat > "$OUTPUT_FILE" <<EOF
X Miner Clang-Tidy Analysis
============================

Date: $(date)
Clang-Tidy Version: $($CLANG_TIDY --version | head -1)
Files Analyzed: $SAMPLE_SIZE (sample)
Build Directory: $BUILD_DIR

================================

EOF

# Run clang-tidy on sample
SAMPLE_FILES=$(echo "$SOURCE_FILES" | head -$SAMPLE_SIZE)
ISSUE_COUNT=0

for file in $SAMPLE_FILES; do
    echo -ne "\r${YELLOW}Analyzing: $(basename $file)${NC}                    "

    # Run clang-tidy and capture output
    $CLANG_TIDY \
        -p="$BUILD_DIR" \
        "$file" \
        2>&1 | tee -a "$OUTPUT_FILE" | grep -c "warning:" || true > /tmp/count.txt

    # Count warnings from this file
    COUNT=$(cat /tmp/count.txt || echo "0")
    ISSUE_COUNT=$((ISSUE_COUNT + COUNT))
done

echo -e "\r${GREEN}Analysis complete!${NC}                              "
echo

# Generate summary
echo -e "${BLUE}Generating summary...${NC}"

cat >> "$OUTPUT_FILE" <<EOF


================================
Summary
================================

Total Warnings Found: $ISSUE_COUNT in $SAMPLE_SIZE files

Top Issue Categories:
EOF

# Extract and count warning types
grep "warning:" "$OUTPUT_FILE" | \
    sed -E 's/.*warning: (.*) \[.*/\1/' | \
    sort | uniq -c | sort -rn | head -20 >> "$OUTPUT_FILE"

cat >> "$OUTPUT_FILE" <<EOF

Top Checks Triggered:
EOF

grep "warning:" "$OUTPUT_FILE" | \
    sed -E 's/.*\[(.*)\]/\1/' | \
    sort | uniq -c | sort -rn | head -20 >> "$OUTPUT_FILE"

echo >> "$OUTPUT_FILE"

# Display summary
echo -e "${GREEN}=== Summary ===${NC}"
echo "Total warnings found: $ISSUE_COUNT in $SAMPLE_SIZE files"
echo "Average per file: $((ISSUE_COUNT / SAMPLE_SIZE))"
echo
echo -e "${YELLOW}Top 5 issue categories:${NC}"
grep "warning:" "$OUTPUT_FILE" | \
    sed -E 's/.*warning: (.*) \[.*/\1/' | \
    sort | uniq -c | sort -rn | head -5
echo
echo -e "${YELLOW}Top 5 checks triggered:${NC}"
grep "warning:" "$OUTPUT_FILE" | \
    sed -E 's/.*\[(.*)\]/\1/' | \
    sort | uniq -c | sort -rn | head -5
echo

echo -e "${GREEN}Full report saved to:${NC}"
echo "  $OUTPUT_FILE"
echo
echo -e "${BLUE}To run on all files:${NC}"
echo "  # Edit this script and change SAMPLE_SIZE=$FILE_COUNT"
echo
echo -e "${BLUE}To analyze specific files:${NC}"
echo "  clang-tidy -p=build src/path/to/file.cpp"
echo
