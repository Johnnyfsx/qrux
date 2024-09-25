#!/bin/bash

# Paths to the log files
log_file="/var/www/html/data.log"
log_file_krux="/var/www/html/krux.log"
log_file_krux_data="/var/www/html/krux_data.log"

# Path to the peer ID to display name configuration file
peerid_name_config="/var/www/html/peerid_name_config.txt"

# Define the expected meeting interval (in minutes)
Meeting_Interval=35

# Set a fixed width for the Peer ID / Display Name column
fixed_width=46

# Function to load the Peer ID mappings from the configuration file
load_peer_id_mappings() {
    peer_id_map=""
    while IFS= read -r line; do
        # Ignore comments and empty lines
        if [[ "$line" =~ ^# ]] || [[ -z "$line" ]]; then
            continue
        fi

        # Get the active/inactive status and the rest of the line
        status=$(echo "$line" | awk '{print $1}')
        peer_id=$(echo "$line" | awk '{print $2}')
        display_name=$(echo "$line" | awk '{ $1=$2=""; print $0 }' | sed 's/^ *//;s/ *$//')

        # Only add active peer IDs to the mapping
        if [[ "$status" == "active" ]]; then
            peer_id_map+="$peer_id:$display_name,"
        fi
    done < "$peerid_name_config"
}

# Function to display performance and bag combined (Menu 1)
show_performance_and_bag() {
    # Calculate the number of lines to read
    config_lines=$(wc -l < "$peerid_name_config")
    lines_to_read=$((config_lines * 3))

    # Prepare the log separator and timestamp
    log_separator="-----------------------------"
    log_timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Print header
    echo "$log_separator" | tee -a "$log_file_krux"
    echo "Performance and Bag Check - $log_timestamp" | tee -a "$log_file_krux"
    echo "$log_separator" | tee -a "$log_file_krux"

    # Read the last part of the log file (3 times the number of lines in the config)
    tail -n "$lines_to_read" "$log_file" | awk -v meeting_interval="$Meeting_Interval" -v peer_id_map="$peer_id_map" -v fixed_width="$fixed_width" -v krux_data_log="$log_file_krux_data" '
    BEGIN {
        # Convert peer_id_map string to an associative array in awk
        split(peer_id_map, pairs, ",");
        for (i in pairs) {
            split(pairs[i], kv, ":");
            map[kv[1]] = kv[2];
        }
    }
    {
        # Adjust the field positions according to the new file format
        timestamp = $1 " " $2;
        peer_id = $3;
        unclaimed_quil = $4;
        quil_per_hour = $5;

        # Convert timestamp to epoch time for easier comparison
        command = "date -d \"" timestamp "\" +%s";
        command | getline epoch_time;
        close(command);

        # Store the current quil_per_hour, unclaimed_quil, and timestamp for comparison
        if (peer_id in last_quil_per_hour) {
            previous_quil_per_hour[peer_id] = last_quil_per_hour[peer_id];
        }
        last_quil_per_hour[peer_id] = quil_per_hour;
        last_unclaimed_quil[peer_id] = unclaimed_quil;
        last_timestamp[peer_id] = epoch_time;
        last_line[peer_id] = $0;

        # Update the most recent timestamp
        if (epoch_time > latest_timestamp) {
            latest_timestamp = epoch_time;
            latest_peer_id = peer_id;
        }
    }
    END {
        total_quil_per_hour = 0;
        total_quil_per_month = 0;
        total_unclaimed_quil = 0;
        total_percentage_change = 0;
        count_percentage_changes = 0;
        failed_wellness_check = 0;

        # Calculate the current time
        command = "date +%s";
        command | getline current_time;
        close(command);

        # Loop over the last entries for each peer_id
        for (peer_id in last_quil_per_hour) {
            quil_per_hour = last_quil_per_hour[peer_id];
            unclaimed_quil = last_unclaimed_quil[peer_id];
            timestamp = strftime("%Y-%m-%d %H:%M:%S", last_timestamp[peer_id]);

            # Get the display name for the Peer ID or use the Peer ID if no mapping exists
            display_name = (peer_id in map) ? map[peer_id] : peer_id;

            # Check if the peer_id is active, skip if inactive
            if (!(peer_id in map)) {
                # Skip this entry if the peer is inactive
                continue;
            }

            # Calculate the percentage change
            if (peer_id in previous_quil_per_hour) {
                prev_quil = previous_quil_per_hour[peer_id];
                change_in_quil_per_hour = ((quil_per_hour - prev_quil) / prev_quil) * 100;
                change_str = sprintf("%.2f%%", change_in_quil_per_hour);
            } else {
                change_str = "-";
            }

            # Calculate the wellness check
            time_difference = (current_time - last_timestamp[peer_id]) / 60; # time difference in minutes
            if (time_difference <= meeting_interval) {
                wellness_check = "pass";
            } else {
                wellness_check = "fail";
            }

            # Save the entry to the krux_data.log file with values enclosed in quotes
            printf "\"%s\" \"%s\" \"%s\" \"%s\" \"%s\" \"%s\" \"%s\"\n", timestamp, peer_id, display_name, unclaimed_quil, quil_per_hour, change_str, wellness_check >> krux_data_log;
        }

        # Add a new line after the block
        printf "\n" >> krux_data_log;
    }
    '

    # Log the end of the performance check
    echo "$log_separator" | tee -a "$log_file_krux"

    # Output the krux_data.log contents
    echo "Content of krux_data.log:"
    cat "$log_file_krux_data"
}

# Load the Peer ID mappings
load_peer_id_mappings

# Main script execution
if [[ "$1" == "show_performance_and_bag" ]]; then
    show_performance_and_bag
else
    while true; do
        clear
        echo "1. Performance & Bag"
        echo "2. Exit"

        read -p "Choose an option: " choice

        case "$choice" in
            1)
                show_performance_and_bag
                ;;
            2)
                exit 0
                ;;
            *)
                echo "Invalid choice. Please try again."
                ;;
        esac

        read -p "Press Enter to continue..."
    done
fi

# If the script is called with 'show_performance_and_bag' as an argument, run the function directly
if [[ "$1" == "show_performance_and_bag" ]]; then
    show_performance_and_bag
    exit 0
fi
