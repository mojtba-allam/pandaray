#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Clear screen
clear

# Banner
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${WHITE}            PC USAGE STATISTICS CALCULATOR                    ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Ask for start date
echo -e "${YELLOW}Enter the start date (format: YYYY-MM-DD):${NC}"
read -p "Date: " start_date

# Validate date format
if ! date -d "$start_date" &>/dev/null; then
    echo -e "${RED}Error: Invalid date format!${NC}"
    exit 1
fi

# Get current date
end_date=$(date +%Y-%m-%d)
current_time=$(date "+%Y-%m-%d %H:%M:%S %z")

echo ""
echo -e "${BLUE}Calculating statistics from ${BOLD}$start_date${NC}${BLUE} to ${BOLD}$end_date${NC}"
echo -e "${BLUE}Please wait...${NC}"
echo ""

# Calculate calendar days
start_ts=$(date -d "$start_date" +%s)
end_ts=$(date +%s)
calendar_days=$(( (end_ts - start_ts) / 86400 ))

# Get boot logs and calculate
temp_file=$(mktemp)
journalctl --list-boots --no-pager > "$temp_file"

# Filter boots from start date
boot_count=0
total_hours=0
declare -A unique_dates

while IFS= read -r line; do
    # Extract date from boot line
    boot_date=$(echo "$line" | awk '{print $4}')
    
    # Check if boot is after start date
    if [[ ! -z "$boot_date" ]] && [[ "$boot_date" > "$start_date" || "$boot_date" == "$start_date" ]]; then
        boot_count=$((boot_count + 1))
        
        # Extract start and end times
        start_time=$(echo "$line" | awk '{print $4 " " $5 " " $6 " " $7}')
        end_time=$(echo "$line" | awk '{print $8 " " $9 " " $10 " " $11}')
        
        # Calculate duration
        start_epoch=$(date -d "$start_time" +%s 2>/dev/null)
        end_epoch=$(date -d "$end_time" +%s 2>/dev/null)
        
        if [[ ! -z "$start_epoch" ]] && [[ ! -z "$end_epoch" ]]; then
            duration=$(echo "scale=2; ($end_epoch - $start_epoch) / 3600" | bc)
            total_hours=$(echo "scale=2; $total_hours + $duration" | bc)
            
            # Track unique dates
            unique_dates["$boot_date"]=1
        fi
    fi
done < "$temp_file"

# Count unique days
days_used=${#unique_dates[@]}

# Add current boot time if system is running
current_boot_start=$(uptime -s)
current_boot_epoch=$(date -d "$current_boot_start" +%s)
current_epoch=$(date +%s)
current_boot_hours=$(echo "scale=2; ($current_epoch - $current_boot_epoch) / 3600" | bc)

# Check if current boot is after start date
if [[ "$current_boot_start" > "$start_date" ]]; then
    total_hours=$(echo "scale=2; $total_hours + $current_boot_hours" | bc)
fi

# Calculate average
if [ $days_used -gt 0 ]; then
    avg_hours=$(echo "scale=2; $total_hours / $days_used" | bc)
else
    avg_hours=0
fi

# Clean up
rm -f "$temp_file"

# Format current boot hours to always show leading zero
if (( $(echo "$current_boot_hours < 1" | bc -l) )); then
    current_boot_display=$(printf "%.2f" $current_boot_hours)
else
    current_boot_display=$current_boot_hours
fi
clear
# Display results
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${WHITE}                          RESULTS                             ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo -e "${CYAN}                                                               ${NC}"
echo -e "${CYAN} ${NC}  ${YELLOW}📅 Period:${NC}                                                  ${CYAN}${NC}"
echo -e "${CYAN} ${NC}     ${WHITE}From:${NC} ${GREEN}$start_date${NC}                                         ${CYAN}${NC}"
echo -e "${CYAN} ${NC}     ${WHITE}To:${NC}   ${GREEN}$end_date${NC}                                         ${CYAN}${NC}"
echo -e "${CYAN}                                                               ${NC}"
echo -e "${CYAN} ${NC}  ${YELLOW}📊 Statistics:${NC}                                              ${CYAN}${NC}"
echo -e "${CYAN} ${NC}     ${WHITE}Total Calendar Days:${NC}       ${MAGENTA}${BOLD}$calendar_days days${NC}                       ${CYAN}${NC}"
echo -e "${CYAN} ${NC}     ${WHITE}Days PC Was Used:${NC}          ${GREEN}${BOLD}$days_used days${NC}                       ${CYAN}${NC}"
echo -e "${CYAN} ${NC}     ${WHITE}Total Uptime Hours:${NC}        ${BLUE}${BOLD}$total_hours hours${NC}                  ${CYAN}${NC}"
echo -e "${CYAN} ${NC}     ${WHITE}Number of Boots:${NC}           ${YELLOW}${BOLD}$boot_count boots${NC}                      ${CYAN}${NC}"
echo -e "${CYAN}                                                               ${NC}"
echo -e "${CYAN} ${NC}  ${YELLOW}⚡ Average:${NC}                                                 ${CYAN}${NC}"
echo -e "${CYAN} ${NC}     ${WHITE}Hours per Active Day:${NC}      ${GREEN}${BOLD}$avg_hours hours/day${NC}                ${CYAN}${NC}"
echo -e "${CYAN}                                                               ${NC}"
echo -e "${CYAN} ${NC}  ${YELLOW}🖥️  Current Boot:${NC}                                            ${CYAN}${NC}"
echo -e "${CYAN} ${NC}     ${WHITE}Running for:${NC}               ${BLUE}${BOLD}$current_boot_display hours${NC}                    ${CYAN}${NC}"
echo -e "${CYAN}                                                               ${NC}"
echo -e "${CYAN}${NC}"
echo ""
