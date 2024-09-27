#!/bin/bash
# sleep 60

/var/www/html/qkrux.bash show_performance_and_bag

# Path to the Qrux_config.txt file
config_file="/var/www/html/Qrux_config.txt"

# Function to read the bot token and chat ID from the configuration file
load_bot_config() {
    if [[ -f "$config_file" ]]; then
        BOT_TOKEN=$(grep -oP '(?<=BOT_TOKEN: ).*' "$config_file")
        CHAT_ID=$(grep -oP '(?<=CHAT_ID: ).*' "$config_file")
        
        if [[ -z "$BOT_TOKEN" || -z "$CHAT_ID" ]]; then
            echo "Configuration error: BOT_TOKEN or CHAT_ID not set in $config_file"
            exit 1
        fi
    else
        echo "Configuration error: $config_file not found"
        exit 1
    fi
}

# Load the bot token and chat ID
load_bot_config

# Path to the krux_data.log file
log_file_krux_data="/var/www/html/krux_data.log"

# Initialize variables
sum_unclaimed=0
sum_quil_h=0
sum_delta=0
all_passed=true
output_lines=()
message_number=0

# Function to round or truncate values
round_two_places() {
    printf "%.2f" "$1"
}

round_four_places() {
    printf "%.4f" "$1"
}

# Read the file in reverse to get the last block first
block_lines=()
while IFS= read -r line; do
    if [[ -z "$line" ]]; then
        # Empty line indicates the end of a block
        if [[ ${#block_lines[@]} -gt 0 ]]; then
            # Process the last block found
            break
        fi
    elif [[ "$line" == Message\ Count:* ]]; then
        # Extract the message number from the line
        message_number=$(echo "$line" | awk '{print $3}')
    else
        block_lines=("$line" "${block_lines[@]}")
    fi
done < <(tac "$log_file_krux_data")

# Process the block
for line in "${block_lines[@]}"; do
    # Extract values from the line
    timestamp=$(echo "$line" | awk -F'"' '{print $2}')
    peer_id=$(echo "$line" | awk -F'"' '{print $4}')
    display_name=$(echo "$line" | awk -F'"' '{print $6}')
    unclaimed_quil=$(echo "$line" | awk -F'"' '{print $8}')
    quil_per_hour=$(echo "$line" | awk -F'"' '{print $10}')
    percentage_change=$(echo "$line" | awk -F'"' '{print $12}')
    status=$(echo "$line" | awk -F'"' '{print $14}')

    # Round the values
    unclaimed_quil=$(round_two_places "$unclaimed_quil")
    quil_per_hour=$(round_two_places "$quil_per_hour")
    thirty_day_quil=$(round_two_places "$(echo "$quil_per_hour * 30 * 24" | bc)")

    # Calculate the cumulative sums
    sum_unclaimed=$(echo "$sum_unclaimed + $unclaimed_quil" | bc)
    sum_quil_h=$(echo "$sum_quil_h + $quil_per_hour" | bc)
    sum_delta=$(echo "$sum_delta + ${percentage_change%\%}" | bc)

    # Determine the status icon
    if [[ "$status" == "pass" ]]; then
        status_icon="✅"
    else
        status_icon="❌"
        all_passed=false
    fi

    # Construct the output line with the peer ID after the other values
    output_line="$display_name%0AQuil/h: $quil_per_hour - 30d: $thirty_day_quil - Bag: $unclaimed_quil - Δ: $percentage_change - 🌐: $status_icon"
    if [[ "$status" != "pass" ]]; then
        output_line="$output_line%0A❌ $peer_id"
    fi
    output_lines+=("$output_line")
done

# Round the total values
sum_unclaimed=$(round_two_places "$sum_unclaimed")
sum_quil_h=$(round_two_places "$sum_quil_h")
sum_thirty_day_quil=$(round_two_places "$(echo "$sum_quil_h * 30 * 24" | bc)")

# Determine the overall check status
total_check="✅"
if [ "$all_passed" = false ]; then
    total_check="❌"
fi

# Function to create the Telegram message
create_telegram_message() {
    local sum_quil_h="$1"
    local sum_thirty_day_quil="$2"
    local sum_unclaimed="$3"
    local total_check="$4"
    local message_number="$5"
    local output_lines=("${!6}")

    local message="Report ($message_number): $total_check%0ATOTAL: -- Quil/h: $sum_quil_h -- 30d: $sum_thirty_day_quil -- Bag: $sum_unclaimed -- Check: $total_check%0A%0A"
    for output in "${output_lines[@]}"; do
        message+="$output%0A%0A"
    done

    echo "$message"
}



# Create the Telegram message
telegram_message=$(create_telegram_message "$sum_quil_h" "$sum_thirty_day_quil" "$sum_unclaimed" "$total_check" "$message_number" output_lines[@])

# Update Message Counter by +=1
awk '/msg_count:/ {sub($2, $2+1)}1' Qrux_config.txt > tmp && mv tmp Qrux_config.txt


# Call the send_message.sh script with the message as an argument
/var/www/html/send_message.sh "$telegram_message"
sudo pkill -f /var/www/html/qkrux.bash
root@s12299180:/var/www/html# cat Qrux_config.txt^C
root@s12299180:/var/www/html# ls
 compare2.py            last_results.txt               pullmessage.sh            qkrux_send3.bash
 compare3.py            newbot.py                      __pycache__               qkrux_send_msg1-list.bash
 compare4.py            newbot.wsgi                    qblaster_schedule.bash    qkrux_send_msg1-listSAVE.bash
 data.log               ngrok-stable-linux-amd64.zip   qkruxBackup2.bash         qrkuxBackup3kruxdatamissing
 debug.log              nohup.out                      qkruxBackup.bash          Qrux_config.txt
 DEBUG.txt              output.log                     qkruxBACKUP_LAST.bash     raw_post_data.log
 increment_checker.sh   output.txt                     qkrux.bash                receive_data.php
 interpreted_data.log   peerid_name_configBACKUP.txt   qkrux_blaster_SAVE.bash   send_message.sh
 krux_data.log          peerid_name_config.txt         qkrux_data.log            ServerData_latest.log
 krux.log               PRIVATE.key                    qkruxLogbroken.bash      'udo apt-get update'
 last_increments.txt    PUBLIC.pem                     qkrux_send_2.bash
root@s12299180:/var/www/html# cat qkrux.bash
#!/bin/bash

# Paths to the log files
log_file="/var/www/html/data.log"
log_file_krux="/var/www/html/krux.log"
log_file_krux_data="/var/www/html/krux_data.log"
config_file="/var/www/html/Qrux_config.txt"

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

# Function to check if the message count is already logged in the last 200 lines
is_msg_count_logged() {
    local msg_count="$1"
    
    # Check if the message count exists in the last 200 lines of krux_data.log
    if tail -n 200 "$log_file_krux_data" | grep -q "$msg_count"; then
        return 0  # Found
    else
        return 1  # Not found
    fi
}

# Function to get the message count from the config file
get_msg_count() {
    grep 'msg_count:' "$config_file" | awk '{print $2}'
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

# Get the current msg_count
msg_count=$(get_msg_count)

# Check if the message count is already logged
if ! is_msg_count_logged "$msg_count"; then
    echo "New message count ($msg_count), logging performance and bag..."
    echo "Message Count: $msg_count" >> "$log_file_krux_data"
    show_performance_and_bag
else
    echo "Message count ($msg_count) is already logged. Skipping."
fi

root@s12299180:/var/www/html# clar
Command 'clar' not found, did you mean:
  command 'clear' from deb ncurses-bin (6.3-2ubuntu0.1)
  command 'car' from deb ucommon-utils (7.0.0-20ubuntu2)
Try: apt install <deb name>
root@s12299180:/var/www/html# cat qkrux.bash
#!/bin/bash

# Paths to the log files
log_file="/var/www/html/data.log"
log_file_krux="/var/www/html/krux.log"
log_file_krux_data="/var/www/html/krux_data.log"
config_file="/var/www/html/Qrux_config.txt"

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

# Function to check if the message count is already logged in the last 200 lines
is_msg_count_logged() {
    local msg_count="$1"
    
    # Check if the message count exists in the last 200 lines of krux_data.log
    if tail -n 200 "$log_file_krux_data" | grep -q "$msg_count"; then
        return 0  # Found
    else
        return 1  # Not found
    fi
}

# Function to get the message count from the config file
get_msg_count() {
    grep 'msg_count:' "$config_file" | awk '{print $2}'
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

# Get the current msg_count
msg_count=$(get_msg_count)

# Check if the message count is already logged
if ! is_msg_count_logged "$msg_count"; then
    echo "New message count ($msg_count), logging performance and bag..."
    echo "Message Count: $msg_count" >> "$log_file_krux_data"
    show_performance_and_bag
else
    echo "Message count ($msg_count) is already logged. Skipping."
fi
