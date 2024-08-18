#!/bin/bash

# Telegram Bot API token and chat ID
BOT_TOKEN=""
CHAT_ID=""  # Your chat ID

# Path to the krux_data.log file
log_file_krux_data="/var/www/html/krux_data.log"

# Initialize variables
sum_unclaimed=0
sum_quil_h=0
sum_delta=0
all_passed=true
output_lines=()

# Function to round or truncate to a specific number of decimal places
round_places() {
    printf "%.${2}f" "$1"
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

    # Round the values to the appropriate number of decimal places
    unclaimed_quil=$(round_places "$unclaimed_quil" 2)
    quil_per_hour=$(round_places "$quil_per_hour" 4)
    thirty_day_quil=$(round_places "$(echo "$quil_per_hour * 30 * 24" | bc)" 2)

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
    output_line="$display_name%0AQuil/h: $quil_per_hour - 30d: $thirty_day_quil - Bag: $unclaimed_quil - Δ: $percentage_change - Status: $status_icon"    if [[ "$status" != "pass" ]]; then
        output_line="$output_line%0A❌ $peer_id"
    fi
    output_lines+=("$output_line")
done

# Round the total values to two decimal places
sum_unclaimed=$(round_places "$sum_unclaimed" 2)
sum_quil_h=$(round_places "$sum_quil_h" 4)
sum_thirty_day_quil=$(round_places "$(echo "$sum_quil_h * 30 * 24" | bc)" 2)

# Combine the output lines into a single message
telegram_message="Node Report: $(if [ "$all_passed" = true ]; then echo "✅"; else echo "❌"; fi)%0ATOTAL: -- Quil/h: $sum_quil_h -- 30d: $sum_thirty_day_quil -- Bag: $sum_unclaimed -- Check: $(if [ "$all_passed" = true ]; then echo "✅"; else echo "❌"; fi)%0A%0A"
for output in "${output_lines[@]}"; do
    telegram_message+="$output%0A%0A"
done

# Function to send message via Telegram bot
send_telegram_message() {
    local message="$1"
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d text="$message" \
        -d parse_mode="Markdown"
}

# Send the message via Telegram
send_telegram_message "$telegram_message"
