#!/bin/bash

# Correct GitHub URLs for the server scripts (raw content)
github_url_qkrux="https://raw.githubusercontent.com/qrux-opterator/qrux/qrux-v0.1/qkrux.bash"
github_url_qkrux_blaster="https://raw.githubusercontent.com/qrux-opterator/qrux/qrux-v0.1/qkrux_blaster.bash"
github_url_blaster_schedule="https://raw.githubusercontent.com/qrux-opterator/qrux/qrux-v0.1/qblaster_schedule.bash"
github_url_statplane="https://raw.githubusercontent.com/qrux-opterator/qrux/qrux-v0.1/statplane.bash"
github_url_fly="https://raw.githubusercontent.com/qrux-opterator/qrux/qrux-v0.1/fly.bash"
github_url_php="https://raw.githubusercontent.com/qrux-opterator/qrux/qrux-v0.1/receive_data.php"
github_url_install_apache="https://raw.githubusercontent.com/qrux-opterator/qrux/qrux-v0.1/install_apache.bash"
github_url_quiltracker="https://raw.githubusercontent.com/qrux-opterator/qrux/qrux-v0.1/quiltracker.bash"

# Destination paths
destination_qkrux="/var/www/html/qkrux.bash"
destination_qkrux_blaster="/var/www/html/qkrux_blaster.bash"
destination_qblaster_schedule="/var/www/html/qblaster_schedule.bash"
destination_statplane="/root/statplane.bash"
destination_fly="/root/fly.bash"
destination_php="/var/www/html/receive_data.php"
destination_install_apache="/root/install_apache.bash"
destination_quiltracker="/root/quiltracker.bash"
config_file="/var/www/html/Qrux_config.txt"

# Default Apache port
Apache_Port=6969

# Function to parse the Qrux_config.txt file
parse_config() {
    while IFS= read -r line; do
        case "$line" in
            "External IP"*)
                External_IP=$(echo "$line" | cut -d ':' -f2 | xargs)
                ;;
            "Apache Port"*)
                Apache_Port=$(echo "$line" | cut -d ':' -f2 | xargs)
                ;;
            "Username"*)
                Username=$(echo "$line" | cut -d ':' -f2 | xargs)
                ;;
            "BOT_TOKEN"*)
                BOT_TOKEN=$(echo "$line" | cut -d '=' -f2 | xargs)
                ;;
            "CHAT_ID"*)
                CHAT_ID=$(echo "$line" | cut -d '=' -f2 | xargs)
                ;;
        esac
    done < "$config_file"
}

# Function to download and fix line endings
download_and_fix_script() {
    local url=$1
    local destination=$2

    # Download the script
    curl -s -o "$destination" "$url"

    # Convert line endings to Unix format
    sed -i 's/\r//' "$destination"

    # Make the script executable
    chmod +x "$destination"
}

# Function to install PHP if not already installed
install_php() {
    if ! command -v php &> /dev/null; then
        sudo apt-get update -y
        sudo apt-get install php libapache2-mod-php -y
    fi
}

# Function to add the receive_data.php file
add_php_file() {
    download_and_fix_script "$github_url_php" "$destination_php"
    echo "PHP file added."
}

# Function to create or overwrite the Qrux_config.txt file with default values if it doesn't exist
initialize_config_file() {
    if [ ! -f "$config_file" ]; then
        External_IP=$(curl -s ifconfig.me)
        sudo bash -c "cat > $config_file <<EOL
External IP: $External_IP
Apache Port: $Apache_Port
Username: 
BOT_TOKEN=""
CHAT_ID=""
EOL"
        echo "Configuration file Qrux_config.txt created with default values."
    else
        echo "Configuration file already exists. Skipping initialization."
    fi
}

# Function to update specific fields in Qrux_config.txt
update_config_field() {
    local field=$1
    local value=$2
    if grep -q "^$field" "$config_file"; then
        sudo sed -i "s|^$field.*|$field: $value|" "$config_file"
    else
        echo "$field: $value" | sudo tee -a "$config_file" > /dev/null
    fi
}

# Function to generate a one-line installer for the client
generate_client_installer() {
    # Parse the configuration file
    parse_config

    # Get the external server IP from the system
    External_IP=$(curl -s ifconfig.me)

    # Prompt the user for the password
    read -sp "Enter the password: " password
    echo

    # Escape any special characters in the password for use in sed
    escaped_password=$(printf '%s\n' "$password" | sed 's:[\/&]:\\&:g')

    # Generate the one-liner command
    installer_command="bash -c 'SERVER_IP=\"$External_IP\"; USERNAME=\"$Username\"; PORT=\"$Apache_Port\"; PASSWORD=\"$escaped_password\"; curl -s -o /root/statplane.bash \"$github_url_statplane\" && curl -s -o /root/fly.bash \"$github_url_fly\" && curl -s -o /root/quiltracker.bash \"$github_url_quiltracker\" && sed -i \"s/\r//\" /root/statplane.bash && sed -i \"s/\r//\" /root/fly.bash && sed -i \"s/\r//\" /root/quiltracker.bash && sed -i \"s|^server_ip=.*|server_ip=\\\"\$SERVER_IP\\\"|\" /root/fly.bash && sed -i \"s|^server_port=.*|server_port=\\\"\$PORT\\\"|\" /root/fly.bash && sed -i \"s|^username=.*|username=\\\"\$USERNAME\\\"|\" /root/fly.bash && sed -i \"s|^password=.*|password=\\\"\$PASSWORD\\\"|\" /root/fly.bash && chmod +x /root/statplane.bash /root/fly.bash /root/quiltracker.bash && echo \"Installation complete: run statplane to schedule your sending interval\"'"

    # Output the one-liner command for the user
    echo ""
    echo "Copy and paste the following command to the client server to install:"
    echo ""
    echo "$installer_command"
    echo ""
    echo "You can control your timer by running ./statplane.bash - To setup how often you want to log data and send to the QKrux."
    echo "You can log more often, and can set a lower interval to get Telegram notifications by setting your qblaster_schedule.bash."
    echo "Find more info in the How-To section."
    echo "Default interval is set to 30 minutes."
    echo ""
    read -p "Press Enter to return to the main menu..." 
}

# Function to download and install server scripts
install_server_scripts() {
    echo "Starting the installation of server scripts..."

    # Array to hold the file paths
    local files_created=()

    # Download and fix the scripts, adding the created file paths to the array
    echo "Downloading and installing qkrux.bash..."
    download_and_fix_script "$github_url_qkrux" "$destination_qkrux"
    files_created+=("$destination_qkrux")

    echo "Downloading and installing qkrux_blaster.bash..."
    download_and_fix_script "$github_url_qkrux_blaster" "$destination_qkrux_blaster"
    files_created+=("$destination_qkrux_blaster")

    echo "Downloading and installing qblaster_schedule.bash..."
    download_and_fix_script "$github_url_blaster_schedule" "$destination_qblaster_schedule"
    files_created+=("$destination_qblaster_schedule")

    echo "Downloading and installing statplane.bash..."
    download_and_fix_script "$github_url_statplane" "$destination_statplane"
    files_created+=("$destination_statplane")

    echo "Downloading and installing fly.bash..."
    download_and_fix_script "$github_url_fly" "$destination_fly"
    files_created+=("$destination_fly")

    echo "Downloading and installing quiltracker.bash..."
    download_and_fix_script "$github_url_quiltracker" "$destination_quiltracker"
    files_created+=("$destination_quiltracker")

    # Show the files that were created
    echo "Server script installation completed. The following files were created:"
    for file in "${files_created[@]}"; do
        echo " - $file"
    done

    # Return to the menu after installation
    read -p "Press Enter to return to the main menu..." 
}

# Function to download and install Apache if the script is not already present
install_apache() {
    if [ ! -f "$destination_install_apache" ]; then
        # Download the install_apache script to /root
        download_and_fix_script "$github_url_install_apache" "$destination_install_apache"
    fi
    
    # Initialize the configuration file with default values (only if it doesn't exist)
    initialize_config_file
    
    # Run the install_apache script without prompting for a username
    sudo bash "$destination_install_apache"

    # Add PHP file
    add_php_file

    # Indicate completion
    echo "Installation completed."
}

# Function to run the TelegramScheduler script
run_telegram_scheduler() {
    /bin/bash /var/www/html/qblaster_schedule.bash
}

# Function to guide the user in setting up the Telegram bot and retrieve the CHAT_ID
setup_telegram_bot() {
    clear
    echo "Create a Telegram Bot and Get the Bot Token:"
    echo ""
    echo "    - Open Telegram and search for the user @BotFather."
    echo "    - Start a chat with BotFather and send the command /newbot."
    echo "    - Choose a name and username for your bot."
    echo "    - BotFather will send you a message containing the Bot Token."
    echo "      It will look something like this: 123456789:ABC-DEF1234ghIkl-zyx57W2v1u123ew11."
    echo ""
    read -p "Hit ENTER when you have your new Bot Token from BotFather..."

    read -p "Now, enter your Bot Token: " BOT_TOKEN

    # Save the BOT_TOKEN into the config file
    update_config_field "BOT_TOKEN" "$BOT_TOKEN"
    echo "Bot Token saved: $BOT_TOKEN"

    while true; do
        # Prompt the user before retrieving the CHAT_ID
        echo ""
        echo "Next, we will get your CHAT_ID to connect the Bot."
        echo "Make sure you already have a chat with your new Bot."
        echo "This step could take a minute while Telegram servers are updated."
        echo "Hit ENTER to proceed..."
        read -p ""

        # Attempt to retrieve the CHAT_ID from the Telegram API
        response=$(curl -s "https://api.telegram.org/bot$BOT_TOKEN/getUpdates")
        CHAT_ID=$(echo $response | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)

        if [ -n "$CHAT_ID" ]; then
            echo "CHAT_ID retrieved: $CHAT_ID"
            # Save the CHAT_ID into the config file
            update_config_field "CHAT_ID" "$CHAT_ID"
            break
        else
            echo "Chat ID could not be retrieved. Try again in a minute."
            echo "1. Try Again"
            echo "2. Exit to Menu"
            read -p "Choose an option: " retry_option
            if [ "$retry_option" -ne 1 ]; then
                break
            fi
        fi
    done

    # Return to the menu after setup
    read -p "Press Enter to return to the main menu..." 
}

# Main menu
while true; do
    clear
    echo "InstallQrux.bash Installer"
    echo "1. Install Apache Server"
    echo "2. Install Server Scripts"
    echo "3. Set Up Telegram Bot"
    echo "4. Generate One-Line Client Installer"
    echo "5. Go to TelegramScheduler"
    echo "6. Exit"
    read -p "Choose an option: " option

    case $option in
        1)
            install_php
            install_apache  # Run the Apache installation script without capturing the username
            read -p "Press Enter to return to the main menu..."
            ;;
        2)
            install_server_scripts
            ;;
        3)
            setup_telegram_bot
            ;;
        4)
            # Prompt for password and generate the one-line installer command
            parse_config
            generate_client_installer
            read -p "Press Enter to return to the main menu..." 
            ;;
        5)
            run_telegram_scheduler
            ;;
        6)
            echo "Exiting installer."
            exit 0
            ;;
        *)
            echo "Invalid option. Please choose again."
            read -p "Press Enter to return to the main menu..." 
            ;;
    esac
done
