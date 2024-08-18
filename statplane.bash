#!/bin/bash

# Function to display the menu
show_menu() {
    local interval=$(get_current_cron_interval)
    local time_until_next_execution=$(get_time_until_next_execution)
    
    if [[ -n "$interval" ]]; then
        echo "====================================================================="
        echo "         STATPLANE - Schedule Upload Time to Master"
        echo "    🛠✅ Plane is set for departure every $interval ✅🛫"
        echo "                  Takeoff: T minus $time_until_next_execution"
        echo "====================================================================="
    else
        echo "======================================================================"
        echo "            STATPLANE - Schedule Upload Time to Master"
        echo "                   💤😴 Plane is on Standby 😴💤"
        echo "======================================================================"
    fi

    echo "1. Set Interval"
    echo "2. Stop Cron Job"
    echo "3. Refresh"
    echo "5. Exit"
    echo "=========================================================================="
    echo "             Additional Info: cat /var/log/fly_bash.log"
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
    local cronjob="*/$interval * * * * /root/fly.bash >> /var/log/fly_bash.log 2>&1"

    # For intervals of 60 minutes or more, adjust to hours and minutes
    if [ $interval -ge 60 ]; then
        local hours=$((interval / 60))
        local minutes=$((interval % 60))
        
        if [ $interval -eq 1440 ]; then  # 1440 minutes = 1 day
            cronjob="0 0 * * * /root/fly.bash >> /var/log/fly_bash.log 2>&1"
        elif [ $interval -ge 60 ]; then
            if [ $minutes -eq 0 ]; then
                cronjob="0 */$hours * * * /root/fly.bash >> /var/log/fly_bash.log 2>&1"
            else
                cronjob="$minutes */$hours * * * /root/fly.bash >> /var/log/fly_bash.log 2>&1"
            fi
        fi
    fi

    crontab -l | grep -v '/root/fly.bash' > /tmp/crontab.tmp
    echo "$cronjob" >> /tmp/crontab.tmp
    crontab /tmp/crontab.tmp
    rm /tmp/crontab.tmp
    echo "Cron job updated to run every $interval minutes."
}

# Function to stop the cron job
stop_cron_job() {
    crontab -l | grep -v '/root/fly.bash' > /tmp/crontab.tmp
    crontab /tmp/crontab.tmp
    rm /tmp/crontab.tmp
    echo "Cron job for /root/fly.bash has been removed."
}

# Function to get the current cron job interval
get_current_cron_interval() {
    local cronjob=$(crontab -l | grep '/root/fly.bash')
    
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
        echo "No cron job found for /root/fly.bash."
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
