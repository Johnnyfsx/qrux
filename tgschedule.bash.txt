#!/bin/bash

# Path to the scripts
QKRUX_SCRIPT="/var/www/html/qkrux.bash"
TGSENDER_SCRIPT="/var/www/html/tgsender.bash"

# Function to display the menu
show_menu() {
    local interval=$(get_current_cron_interval)
    local time_until_next_execution=$(get_time_until_next_execution)
    
    if [[ -n "$interval" ]]; then
        echo "====================================================================="
        echo "         Telegram Info Blaster 🔫"
        echo "    🛠✅ Canon shoots every $interval ✅🛫"
        echo "                  Blast in $time_until_next_execution"
        echo "====================================================================="
    else
        echo "======================================================================"
        echo "            Telegram Info Blaster 🔫"
        echo "                   💤😴 Canon is on Standby 😴💤"
        echo "======================================================================"
    fi

    echo "1. Start/Update Scheduler"
    echo "2. Stop Scheduler"
    echo "3. Refresh"
    echo "5. Exit"
    echo "=========================================================================="
    echo -n "Choose an option [1-5]: "
}

# Function to set the interval and update the cron job
set_interval() {
    local interval_input=$1
    local interval_minutes=0

    if [[ $interval_input =~ ^[0-9]+[mM]$ ]]; then
        # Convert minutes
        interval_minutes=${interval_input%m}
    elif [[ $interval_input =~ ^[0-9]+[hH]$ ]]; then
        # Convert hours to minutes
        interval_minutes=$(( ${interval_input%h} * 60 ))
    else
        echo "Invalid interval format. Please enter a positive integer followed by 'm' for minutes or 'h' for hours."
        return
    fi

    if [[ $interval_minutes -lt 1 ]]; then
        echo "Invalid interval. Please enter a positive integer."
        return
    fi

    update_cron_job "$interval_minutes"
}

# Function to update the cron job with the specified interval
update_cron_job() {
    local interval=$1
    local cronjob_qkrux="*/$interval * * * * $QKRUX_SCRIPT >> /var/log/qkrux.log 2>&1"
    local cronjob_tgsender="*/$interval * * * * sleep 10 && $TGSENDER_SCRIPT >> /var/log/tgsender.log 2>&1"

    # For intervals of 60 minutes or more, adjust to hours and minutes
    if [ $interval -ge 60 ]; then
        local hours=$((interval / 60))
        local minutes=$((interval % 60))
        
        if [ $interval -eq 1440 ]; then  # 1440 minutes = 1 day
            cronjob_qkrux="0 0 * * * $QKRUX_SCRIPT >> /var/log/qkrux.log 2>&1"
            cronjob_tgsender="0 0 * * * sleep 10 && $TGSENDER_SCRIPT >> /var/log/tgsender.log 2>&1"
        elif [ $interval -ge 60 ]; then
            if [ $minutes -eq 0 ]; then
                cronjob_qkrux="0 */$hours * * * $QKRUX_SCRIPT >> /var/log/qkrux.log 2>&1"
                cronjob_tgsender="0 */$hours * * * sleep 10 && $TGSENDER_SCRIPT >> /var/log/tgsender.log 2>&1"
            else
                cronjob_qkrux="$minutes */$hours * * * $QKRUX_SCRIPT >> /var/log/qkrux.log 2>&1"
                cronjob_tgsender="$minutes */$hours * * * sleep 10 && $TGSENDER_SCRIPT >> /var/log/tgsender.log 2>&1"
            fi
        fi
    fi

    crontab -l | grep -v "$QKRUX_SCRIPT" | grep -v "$TGSENDER_SCRIPT" > /tmp/crontab.tmp
    echo "$cronjob_qkrux" >> /tmp/crontab.tmp
    echo "$cronjob_tgsender" >> /tmp/crontab.tmp
    crontab /tmp/crontab.tmp
    rm /tmp/crontab.tmp
    echo "Cron jobs updated to run every $interval minutes."
}

# Function to stop the cron job
stop_cron_job() {
    crontab -l | grep -v "$QKRUX_SCRIPT" | grep -v "$TGSENDER_SCRIPT" > /tmp/crontab.tmp
    crontab /tmp/crontab.tmp
    rm /tmp/crontab.tmp
    echo "Cron jobs for $QKRUX_SCRIPT and $TGSENDER_SCRIPT have been removed."
}

# Function to get the current cron job interval
get_current_cron_interval() {
    local cronjob=$(crontab -l | grep "$QKRUX_SCRIPT")
    
    if [[ -z "$cronjob" ]]; then
        echo ""
        return
    fi

    local minute_field=$(echo "$cronjob" | awk '{print $1}')
    local hour_field=$(echo "$cronjob" | awk '{print $2}')
    
    if [[ "$minute_field" =~ ^\*/([0-9]+)$ ]]; then
        echo "${BASH_REMATCH[1]} minutes"
    elif [[ "$minute_field" == "0" && "$hour_field" =~ ^\*/([0-9]+)$ ]]; then
        echo "every ${BASH_REMATCH[1]} hours"
    elif [[ "$minute_field" == "0" && "$hour_field" == "0" ]]; then
        echo "once a day"
    else
        echo "custom schedule"
    fi
}

# Function to get the time until the next cron job execution
get_time_until_next_execution() {
    local current_time=$(date +%s)
    local interval=$(get_current_cron_interval)

    if [[ -z $interval ]]; then
        echo "No cron job found for $QKRUX_SCRIPT."
        return
    fi

    local interval_minutes=0

    if [[ "$interval" =~ ^([0-9]+)\ minutes$ ]]; then
        interval_minutes=${BASH_REMATCH[1]}
    elif [[ "$interval" =~ ^every\ ([0-9]+)\ hours$ ]]; then
        interval_minutes=$(( ${BASH_REMATCH[1]} * 60 ))
    elif [[ "$interval" == "once a day" ]]; then
        interval_minutes=1440
    else
        echo "Custom schedule detected."
        return
    fi

    local last_execution_time=$(( (current_time / (interval_minutes * 60)) * (interval_minutes * 60) ))
    local next_execution_time=$(( last_execution_time + (interval_minutes * 60) ))
    local time_left=$(( next_execution_time - current_time ))
    local time_left_formatted=$(printf '%02d:%02d:%02d' $((time_left / 3600)) $(( (time_left % 3600) / 60 )) $((time_left % 60)))

    echo "$time_left_formatted"
}

# Function to refresh the menu
refresh() {
    clear
    show_menu
}

# Main script logic
while true; do
    refresh
    read -r choice
    case $choice in
        1)
            read -p "Enter the interval (e.g., 30m for 30 minutes, 2h for 2 hours): " interval
            set_interval "$interval"
            ;;
        2)
            stop_cron_job
            ;;
        3)
            refresh
            ;;
        5)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid option. Please choose a number between 1 and 5."
            ;;
    esac
done
