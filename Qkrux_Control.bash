#!/bin/bash

# GitHub URLs for the server scripts
github_url_qkrux="https://raw.githubusercontent.com/qrux-opterator/qrux/main/Qrux.bash.txt"
github_url_tgsender="https://raw.githubusercontent.com/qrux-opterator/qrux/main/tgsender.bash.txt"
github_url_tgschedule="https://raw.githubusercontent.com/qrux-opterator/qrux/main/tgschedule.bash.txt"
github_url_statplane="https://raw.githubusercontent.com/qrux-opterator/qrux/main/statplane.bash.txt"
github_url_fly="https://raw.githubusercontent.com/qrux-opterator/qrux/main/fly.bash.txt"

# Destination paths
destination_qkrux="/var/www/html/qkrux.bash"
destination_tgsender="/var/www/html/tgsender.bash"
destination_tgschedule="/var/www/html/tgschedule.bash"
destination_statplane="/var/www/html/statplane.bash"
destination_fly="/var/www/html/fly.bash"

config_file="/var/www/html/Qrux_config.txt"

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
    sudo bash -c 'cat > /var/www/html/receive_data.php <<EOL
<?php
if (\$_SERVER["REQUEST_METHOD"] === "POST") {
    \$peer_id = \$_POST["peer_id"];
    \$unclaimed_balance = \$_POST["unclaimed_balance"];
    \$quil_per_hour = \$_POST["quil_per_hour"];

    // Debugging: Log raw POST data and interpreted values
    file_put_contents("raw_post_data.log", print_r(\$_POST, true), FILE_APPEND);
    file_put_contents("interpreted_data.log", "peer_id: \$peer_id, unclaimed_balance: \$unclaimed_balance, quil_per_hour: \$quil_per_hour\n", FILE_APPEND);

    if (\$peer_id && \$unclaimed_balance && \$quil_per_hour) {
        \$timestamp = date("Y-m-d H:i:s"); // Get current timestamp
        file_put_contents("data.log", "\$timestamp \$peer_id \$unclaimed_balance \$quil_per_hour\n", FILE_APPEND);
        echo "Data received and logged.";
    } else {
        echo "Invalid data.";
    }
} else {
    echo "Invalid request method.";
}
?>
EOL'
}

# Function to parse the Qrux_config.txt file
parse_config() {
    while IFS= read -r line; do
        case "$line" in
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
    installer_command="bash -c 'SERVER_IP=\"$External_IP\"; USERNAME=\"$Username\"; PORT=\"$Apache_Port\"; PASSWORD=\"$escaped_password\"; curl -s -o /root/statplane.bash \"$github_url_statplane\" && curl -s -o /root/fly.bash \"$github_url_fly\" && sed -i \"s/\r//\" /root/statplane.bash && sed -i \"s/\r//\" /root/fly.bash && sed -i \"s|^server_ip=.*|server_ip=\\\"\$SERVER_IP\\\"|\" /root/fly.bash && sed -i \"s|^server_port=.*|server_port=\\\"\$PORT\\\"|\" /root/fly.bash && sed -i \"s|^username=.*|username=\\\"\$USERNAME\\\"|\" /root/fly.bash && sed -i \"s|^password=.*|password=\\\"\$PASSWORD\\\"|\" /root/fly.bash && chmod +x /root/statplane.bash /root/fly.bash && echo \"Installation complete: run statplane to schedule your sending interval\"'"

    # Output the one-liner command for the user
    echo "Copy and paste the following command to the client server to install:"
    echo "$installer_command"
}

# Function to download and install server scripts
install_server_scripts() {
    download_and_fix_script "$github_url_qkrux" "$destination_qkrux"
    download_and_fix_script "$github_url_tgsender" "$destination_tgsender"
    download_and_fix_script "$github_url_tgschedule" "$destination_tgschedule"
    download_and_fix_script "$github_url_statplane" "$destination_statplane"
    download_and_fix_script "$github_url_fly" "$destination_fly"
}

# Function to run the TelegramScheduler script
run_telegram_scheduler() {
    /bin/bash /var/www/html/tgschedule.bash
}

# Main menu
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
        ./install_apache.bash  # Run the Apache installation script
        add_php_file
        save_config_details
        echo "Installation completed."
        ;;
    2)
        install_server_scripts
        echo "Server script installation completed."
        ;;
    3)
        setup_telegram_bot
        echo "Telegram bot setup completed."
        ;;
    4)
        generate_client_installer
        ;;
    5)
        run_telegram_scheduler
        ;;
    6)
        echo "Exiting installer."
        exit 0
        ;;
    *)
        echo "Invalid option. Exiting."
        exit 1
        ;;
esac
