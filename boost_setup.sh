#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_NAME="set_cpu_performance.sh"
SCRIPT_PATH="/root/scripts/$SCRIPT_NAME"

echo -e "${YELLOW}Starting setup for CPU Performance Script...${NC}"

# Function to add cron jobs
add_cron_jobs() {
    local script_path="$1"
    local cron_reboot="@reboot $script_path"
    local cron_periodic="0 */6 * * * $script_path"

    # Check if cron jobs already exist
    local cron_reboot_exists=$(crontab -l 2>/dev/null | grep "$cron_reboot")
    local cron_periodic_exists=$(crontab -l 2>/dev/null | grep "$cron_periodic")

    if [ -z "$cron_reboot_exists" ]; then
        (crontab -l 2>/dev/null; echo "$cron_reboot") | crontab -
        echo "Added cron job for reboot: $cron_reboot"
    else
        echo "Cron job for reboot already exists: $cron_reboot"
    fi

    if [ -z "$cron_periodic_exists" ]; then
        (crontab -l 2>/dev/null; echo "$cron_periodic") | crontab -
        echo "Added cron job for every 6 hours: $cron_periodic"
    else
        echo "Cron job for every 6 hours already exists: $cron_periodic"
    fi
}

# Add cron jobs for set_cpu_performance.sh
add_cron_jobs "$SCRIPT_PATH"

echo -e "${GREEN}Setup complete!${NC}"
echo "The CPU performance script cron jobs are now configured."
echo "It will run at system reboot and every 6 hours."
