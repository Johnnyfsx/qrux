#!/bin/bash

# Define default variables
apache_port=6969
domain_name="localhost"  # Default domain name for self-signed SSL, can be changed later
config_file="/var/www/html/Qrux_config.txt"  # Path to the existing config file

# Function to install Apache and configure it
install_apache() {
    echo "$(date): Installing Apache server..."

    # Update package list and install Apache and dependencies for SSL
    sudo apt-get update -y
    sudo apt-get install apache2 -y
    sudo apt-get install openssl -y

    echo "$(date): Apache installed successfully."

    # Ensure Apache listens on the custom port
    if ! grep -q "Listen $apache_port" /etc/apache2/ports.conf; then
        echo "$(date): Adding Listen $apache_port to /etc/apache2/ports.conf"
        echo "Listen $apache_port" | sudo tee -a /etc/apache2/ports.conf
    fi

    # Prompt for a username and password for Apache authentication
    read -p "Enter a username for Apache access: " apache_user
    read -sp "Enter a password for $apache_user: " apache_password
    echo

    # Debug: echo the username before writing it to the config file
    echo "$(date): Captured username: $apache_user"

    # Create a .htpasswd file with the username and encrypted password
    sudo htpasswd -cb /etc/apache2/.htpasswd "$apache_user" "$apache_password"
    echo "$(date): .htpasswd file created with user $apache_user."

    # Debug: show that we are about to write the username to the config file
    echo "$(date): Writing username $apache_user to $config_file"

    # Save the username in the existing config file
    if grep -q "^Username:" "$config_file"; then
        sudo sed -i "s/^Username:.*/Username: $apache_user/" "$config_file"
    else
        echo "Username: $apache_user" | sudo tee -a "$config_file" > /dev/null
    fi

    # Debug: Read back the username from the config file to verify it was written correctly
    echo "$(date): Verifying username saved to config file..."
    grep "^Username:" "$config_file"

    # Create a self-signed SSL certificate
    sudo openssl req -new -x509 -days 365 -nodes -out /etc/ssl/certs/qrux.crt -keyout /etc/ssl/private/qrux.key -subj "/C=US/ST=State/L=City/O=Organization/OU=OrgUnit/CN=$domain_name"
    echo "$(date): Self-signed SSL certificate created at /etc/ssl/certs/qrux.crt."

    # Create the VirtualHost configuration
    sudo bash -c "cat > /etc/apache2/sites-available/qrux.conf <<EOL
<VirtualHost *:$apache_port>
    <Directory \"/var/www/html\">
        AuthType Basic
        AuthName \"Restricted Access\"
        AuthUserFile /etc/apache2/.htpasswd
        Require valid-user
    </Directory>

    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html

    SSLEngine on
    SSLCertificateFile /etc/ssl/certs/qrux.crt
    SSLCertificateKeyFile /etc/ssl/private/qrux.key

    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOL"

    echo "$(date): VirtualHost configuration created at /etc/apache2/sites-available/qrux.conf."

    # Enable the new site configuration and SSL module
    sudo a2enmod ssl
    sudo a2ensite qrux.conf

    # Reload Apache to apply the new configuration
    sudo systemctl reload apache2

    echo "$(date): Apache configuration reloaded with SSL enabled."

    # Enable UFW firewall and open the custom port, without SSH prompt
    sudo ufw allow $apache_port/tcp
    echo "y" | sudo ufw enable

    echo "$(date): UFW firewall enabled and port $apache_port opened."
}

# Function to set correct permissions on the web directory
set_permissions() {
    echo "$(date): Setting ownership and permissions for /var/www/html"
    sudo chown -R www-data:www-data /var/www/html
    sudo chmod -R 755 /var/www/html
    echo "$(date): Ownership and permissions set."
}

# Run the Apache installation and configuration
install_apache
set_permissions

echo "$(date): Apache installation and configuration completed."
