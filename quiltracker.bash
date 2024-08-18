#!/bin/bash

# Global variables
script_path=$(realpath "$0")
script_dir=$(dirname "$script_path")
start_date=""
start_quil=0.0
last_quil_per_month=""
last_timestamp=""
monthly_cost=0.0
total_quil=0.0
log_file="$script_dir/quilreward.log"
node_directory="/root/ceremonyclient/node"
node_command="./node-1.4.21.1-linux-amd64"
service_file="/etc/systemd/system/quilreward.service"
timer_file="/etc/systemd/system/quilreward.timer"

# Function to read the log file and set initial values
read_log_file() {
  if [ -f "$log_file" ]; then
    while IFS= read -r line; do
      if [[ "$line" == Start* ]]; then
        start_date=$(echo "$line" | awk -F': ' '{print $2}')
      elif [[ "$line" == Initial* ]]; then
        start_quil=$(echo "$line" | awk -F': ' '{print $2}')
      elif [[ "$line" == "Last QUIL per month:"* ]]; then
        last_quil_per_month=$(echo "$line" | awk -F': ' '{print $2}')
      elif [[ "$line" == Timestamp* ]]; then
        last_timestamp=$(echo "$line" | awk -F': ' '{print $2}')
      elif [[ "$line" == "Monthly Cost:"* ]]; then
        monthly_cost=$(echo "$line" | awk -F': ' '{print $2}')
      elif [[ "$line" == "Unclaimed QUIL:"* ]]; then
        total_quil=$(echo "$line" | awk -F': ' '{print $2}')
      fi
    done < "$log_file"
  fi
}

# Function to log initial values
log_initial_values() {
  echo "Start date: $start_date" > "$log_file"
  echo "Initial QUIL: $start_quil" >> "$log_file"
}

# Function to log the QUIL per month to a file
log_quil_per_month() {
  local quil_per_month="$1"
  local unclaimed_quil="$2"
  local cpu_load="$3"
  local timestamp="$4"
  echo -e "\nLast QUIL per month: $quil_per_month" >> "$log_file"
  echo "Unclaimed QUIL: $unclaimed_quil" >> "$log_file"
  echo "CPU Load: $cpu_load" >> "$log_file"
  echo "Timestamp: $timestamp" >> "$log_file"
  echo "$(date +"%Y-%m-%d %H:%M:%S"): QUIL per month: $quil_per_month" >> "$log_file"
  echo "Monthly Cost: $monthly_cost" >> "$log_file"
}

# Function to set the start date and initial QUIL amount
set_start_date() {
  read -p "Enter the start date and time (YYYY-MM-DD HH:MM:SS): " start_date
  read -p "Enter the initial QUIL amount: " start_quil
  log_initial_values
}

# Function to set the monthly cost
set_monthly_cost() {
  read -p "Enter the monthly cost: " monthly_cost
  echo "Monthly Cost: $monthly_cost" >> "$log_file"
}

# Function to extract QUIL and date from command output
extract_quil_data() {
  local output="$1"
  local quil_amount=$(echo "$output" | grep -oP 'Unclaimed balance:\s\K[0-9.]+')
  local date_str=$(echo "$output" | grep -oP '\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}')
  local date_epoch=$(date -d "$date_str" +%s)
  echo "$quil_amount $date_epoch"
}

# Function to calculate QUIL per month and QUIL per hour
calculate_quil_per_month_and_hour() {
  local end_date_epoch="$1"
  local end_quil="$2"
  
  local start_date_epoch=$(date -d "$start_date" +%s)
  local seconds_elapsed=$((end_date_epoch - start_date_epoch))
  local hours_elapsed=$(echo "scale=10; $seconds_elapsed / 3600" | bc -l)
  local months_elapsed=$(echo "scale=10; $seconds_elapsed / 2592000" | bc -l)
  
  local quil_per_month=$(echo "scale=10; ($end_quil - $start_quil) / $months_elapsed" | bc -l)
  local quil_per_hour=$(echo "scale=10; ($end_quil - $start_quil) / $hours_elapsed" | bc -l)
  
  echo "$quil_per_month $quil_per_hour"
}

# Function to calculate QUIL per hour since the last saved timestamp
calculate_quil_per_hour_since_last() {
  local last_time="$1"
  local current_time="$2"
  local last_quil="$3"
  local current_quil="$4"

  local last_date_epoch=$(date -d "$last_time" +%s)
  local current_date_epoch=$(date -d "$current_time" +%s)
  local seconds_elapsed=$((current_date_epoch - last_date_epoch))
  local hours_elapsed=$(echo "scale=10; $seconds_elapsed / 3600" | bc -l)
  
  local quil_per_hour_since_last=$(echo "scale=10; ($current_quil - $last_quil) / $hours_elapsed" | bc -l)
  
  echo "$quil_per_hour_since_last $hours_elapsed"
}

# Function to calculate time passed since last timestamp
calculate_time_passed() {
  local last_time="$1"
  local current_time="$2"
  
  local last_date_epoch=$(date -d "$last_time" +%s)
  local current_date_epoch=$(date -d "$current_time" +%s)
  local seconds_elapsed=$((current_date_epoch - last_date_epoch))
  local days_elapsed=$((seconds_elapsed / 86400))
  local hours_elapsed=$(( (seconds_elapsed % 86400) / 3600 ))
  local minutes_elapsed=$(( (seconds_elapsed % 3600) / 60 ))

  echo "${days_elapsed}d ${hours_elapsed}h ${minutes_elapsed}min"
}

# Function to check QUIL per month and QUIL per hour
check_quil_per_month_and_hour() {
  local current_dir=$(pwd)
  cd "$node_directory" || { echo "Failed to change directory to $node_directory"; return; }
  
  local output=$($node_command -node-info && date +"%Y-%m-%d %H:%M:%S")
  if [ $? -ne 0 ]; then
    echo "Failed to execute node command. Please check the path and try again."
    cd "$current_dir"
    return
  fi
  
  cd "$current_dir"
  
  local quil_data=$(extract_quil_data "$output")
  local end_quil=$(echo "$quil_data" | awk '{print $1}')
  local end_date_epoch=$(echo "$quil_data" | awk '{print $2}')
  local cpu_load=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')%
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  
  if [ -z "$start_date" ]; then
    start_date=$(date -d @$end_date_epoch +"%Y-%m-%d %H:%M:%S")
    start_quil=$end_quil
    echo "Initial date and QUIL set from the provided data."
    log_initial_values
  else
    local quil_per_month_and_hour=$(calculate_quil_per_month_and_hour "$end_date_epoch" "$end_quil")
    local new_quil_per_month=$(echo "$quil_per_month_and_hour" | awk '{print $1}')
    local quil_per_hour=$(echo "$quil_per_month_and_hour" | awk '{print $2}')
    local difference=$(echo "scale=10; $new_quil_per_month - $last_quil_per_month" | bc -l)
    local quil_per_hour_since_last=$(calculate_quil_per_hour_since_last "$last_timestamp" "$timestamp" "$total_quil" "$end_quil")
    local quil_per_hour_since_last_value=$(echo "$quil_per_hour_since_last" | awk '{print $1}')
    local hours_since_last_check=$(echo "$quil_per_hour_since_last" | awk '{print $2}')
    local time_passed=$(calculate_time_passed "$last_timestamp" "$timestamp")
    
    local quil_per_cost=$(echo "scale=10; $new_quil_per_month * 0.26" | bc -l)
    local roi=$(echo "scale=10; ($quil_per_cost - $monthly_cost) / $monthly_cost * 100" | bc -l)
    
    # Color formatting removed from ROI output
    if (( $(echo "$roi > 0" | bc -l) )); then
      roi="$roi%"  # Positive ROI
    else
      roi="$roi%"  # Negative ROI
    fi
    
    local quil_per_hour_gain=$(echo "scale=10; ($quil_per_hour_since_last_value - $quil_per_hour) / $quil_per_hour_since_last_value * 100" | bc -l)
    # Color formatting removed from QUIL per hour gain
    if (( $(echo "$quil_per_hour_gain > 0" | bc -l) )); then
      quil_per_hour_gain="$quil_per_hour_gain%"  # Positive gain
    else
      quil_per_hour_gain="$quil_per_hour_gain%"  # Negative gain
    fi
    
    echo "QUIL per hour since last: $quil_per_hour_since_last_value"
    echo "Time passed since last check: $time_passed"
    echo "ΔQuil/h-$hours_since_last_check hours: $quil_per_hour_gain"
    echo "_________________________________________________|"
    echo "Last QUIL per month: $last_quil_per_month"
    echo "New QUIL per month: $new_quil_per_month"
    echo "Difference: $difference"
    echo "QUIL per hour: $(printf "%.4f" $quil_per_hour)"
    echo "CPU Load: $cpu_load"
    echo "QUIL @ 0.26: $(printf "%.4f" $quil_per_cost)"
    echo "ROI: $roi"
    echo "_________________________________________________|"
    
    last_quil_per_month="$new_quil_per_month"
    total_quil="$end_quil"
    last_timestamp="$timestamp"
    log_quil_per_month "$new_quil_per_month" "$end_quil" "$cpu_load" "$timestamp"
  fi
}

# Read log file on startup
read_log_file

# Check if a command-line argument is provided
if [ $# -gt 0 ]; then
  case $1 in
    1)
      check_quil_per_month_and_hour
      exit 0
      ;;
    2)
      set_start_date
      exit 0
      ;;
    3)
      set_monthly_cost
      exit 0
      ;;
    4)
      exit 0
      ;;
    *)
      echo "Invalid option"
      exit 1
      ;;
  esac
fi

# Main menu
while true; do
  clear
  if [ ! -z "$start_date" ]; then
    echo "Start date: $start_date"
  else
    echo "Start date not set."
  fi
  if [ ! -z "$last_quil_per_month" ]; then
    echo "Last QUIL per month: $last_quil_per_month"
  fi
  if [ ! -z "$monthly_cost" ]; then
    echo "Monthly Cost: $monthly_cost"
  fi

  echo "1. Start / Refresh tracker"
  echo "2. Set beginning date"
  echo "3. Set monthly cost"
  echo "4. Exit"

  read -p "Choose an option: " choice

  case "$choice" in
    1)
      check_quil_per_month_and_hour
      ;;
    2)
      set_start_date
      ;;
    3)
      set_monthly_cost
      ;;
    4)
      exit 0
      ;;
    *)
      echo "Invalid choice. Please try again."
      ;;
  esac

  read -p "Press Enter to continue..."
done
