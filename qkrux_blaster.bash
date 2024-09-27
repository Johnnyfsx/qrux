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
sed -i '/msg_count:/s/[0-9]\+$/$(($(grep -oP "(?<=msg_count: )\d+" '"$config_file"')+1))/e' "$config_file"
# Create the Telegram message
telegram_message=$(create_telegram_message "$sum_quil_h" "$sum_thirty_day_quil" "$sum_unclaimed" "$total_check" "$message_number" output_lines[@])

# Call the send_message.sh script with the message as an argument
/var/www/html/send_message.sh "$telegram_message"
sudo pkill -f /var/www/html/qkrux.bash
