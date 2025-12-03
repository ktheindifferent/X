#!/bin/bash
#
# X Miner - Huge Pages Setup Script
# Sets up 2MB huge pages for optimal mining performance
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root${NC}"
    echo "Usage: sudo $0 [num_pages]"
    exit 1
fi

# Determine number of huge pages to allocate
# Default: enough for 4GB (2048 pages of 2MB each)
if [ -n "$1" ]; then
    NUM_PAGES=$1
else
    # Auto-calculate: 1280 pages = 2.5GB (good for most single-instance mining)
    NUM_PAGES=1280
fi

echo "============================================"
echo " X Miner - Huge Pages Setup"
echo "============================================"
echo

# Show current status
echo "Current huge pages configuration:"
grep -i huge /proc/meminfo | head -n 3
echo

# Calculate memory size
MEMORY_SIZE_MB=$((NUM_PAGES * 2))
MEMORY_SIZE_GB=$(echo "scale=2; $MEMORY_SIZE_MB / 1024" | bc)

echo "This will allocate ${NUM_PAGES} huge pages (${MEMORY_SIZE_GB} GB)"
echo

# Check if we have enough free memory
TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
FREE_MEM_KB=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
REQUIRED_MEM_KB=$((NUM_PAGES * 2048))

if [ $FREE_MEM_KB -lt $REQUIRED_MEM_KB ]; then
    echo -e "${YELLOW}Warning: May not have enough free memory${NC}"
    echo "  Required: $((REQUIRED_MEM_KB / 1024)) MB"
    echo "  Available: $((FREE_MEM_KB / 1024)) MB"
    echo
fi

# Set huge pages
echo "Setting vm.nr_hugepages to ${NUM_PAGES}..."
sysctl -w vm.nr_hugepages=$NUM_PAGES

# Wait a moment for allocation
sleep 1

# Verify allocation
ACTUAL_PAGES=$(cat /proc/sys/vm/nr_hugepages)
if [ "$ACTUAL_PAGES" -eq "$NUM_PAGES" ]; then
    echo -e "${GREEN}✓ Successfully allocated $ACTUAL_PAGES huge pages${NC}"
else
    echo -e "${YELLOW}⚠ Only allocated $ACTUAL_PAGES of $NUM_PAGES requested huge pages${NC}"
    if [ "$ACTUAL_PAGES" -lt "$NUM_PAGES" ]; then
        echo "This may indicate insufficient memory fragmentation."
        echo "Try rebooting and running this script immediately after boot."
    fi
fi

# Make permanent if requested
echo
read -p "Make this setting permanent? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if grep -q "^vm.nr_hugepages" /etc/sysctl.conf; then
        sed -i "s/^vm.nr_hugepages.*/vm.nr_hugepages=$NUM_PAGES/" /etc/sysctl.conf
        echo -e "${GREEN}✓ Updated /etc/sysctl.conf${NC}"
    else
        echo "vm.nr_hugepages=$NUM_PAGES" >> /etc/sysctl.conf
        echo -e "${GREEN}✓ Added to /etc/sysctl.conf${NC}"
    fi
    echo "Huge pages will persist across reboots."
fi

echo
echo "Final status:"
grep -i huge /proc/meminfo | head -n 3
echo
echo -e "${GREEN}Huge pages setup complete!${NC}"
echo "You can now run X miner with improved performance."
