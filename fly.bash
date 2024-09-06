#!/bin/bash

# Initialize variables for curl command
server_ip=""
server_port=""
username=""
password=""

# Log start time
echo "$(date): Starting script"

# Log current directory and environment
echo "$(date): Current directory: $(pwd)"
echo "$(date): PATH: $PATH"

# Extract the QUIL per hour value using absolute path
quil_per_hour=$(/root/quiltracker.bash 1 2>&1 | awk '/QUIL per hour since last:/ {print $NF}')

# Log extracted value
echo "$(date): QUIL per hour extracted: $quil_per_hour"

if [ -z "$quil_per_hour" ]; then
    echo "$(date): Error: QUIL per hour value is empty. Exiting."
    exit 1
fi

# Change to the working directory and run the command
cd /root/ceremonyclient/node || { echo "$(date): Failed to change directory"; exit 1; }

# Run node command and process output
node_output=$(./node-1.4.21.1-linux-amd64 --node-info 2>&1)

# Echo node command output
echo "$(date): Node command output: $node_output"

# Extract Peer ID and Unclaimed balance from node output
peer_id=$(echo "$node_output" | awk '/Peer ID:/ {print $3}')
unclaimed_balance=$(echo "$node_output" | awk '/Unclaimed balance:/ {print $3}')

# Log extracted values
echo "$(date): Extracted Peer ID: $peer_id"
echo "$(date): Extracted Unclaimed balance: $unclaimed_balance"

# Define the get_increment function to capture the latest increment and time_taken from logs
get_increment() {
    # Limit journalctl to the last 100 lines for performance improvement
    log_entry=$(sudo journalctl -u ceremonyclient.service --no-hostname -o cat -n 200 | grep -oP '"increment":\d+,"time_taken":\d+\.\d+' | tail -n 1)

    increment=$(echo $log_entry | awk -F'[:,]' '{print $2}')
    time_taken=$(echo $log_entry | awk -F'[:,]' '{print $4}')

    echo "$(date): Extracted Increment: $increment"
    echo "$(date): Extracted Time Taken: $time_taken"
}

# Call the get_increment function
get_increment

# Format data for curl including the new increment and time_taken values
data="peer_id=$peer_id&unclaimed_balance=$unclaimed_balance&quil_per_hour=$quil_per_hour&increment=$increment&time_taken=$time_taken"

# Echo formatted data
echo "$(date): Formatted data: $data"

# Run curl command using the isolated variables
curl_output=$(curl -k -X POST -d "$data" https://$server_ip:$server_port/receive_data.php --user $username:"$password" 2>&1)

# Echo curl command output
echo "$(date): Curl command output: $curl_output"

# Log end time
echo "$(date): Script completed"
