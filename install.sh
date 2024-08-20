#!/bin/bash

cat << "EOF"

    _      _                            ___   ____    ____    ____
   / \    | |__    _   _   ___    ___  |_ _| |  _ \  |  _ \  | __ )
  / _ \   | '_ \  | | | | / __|  / _ \  | |  | |_) | | | | | |  _ \
 / ___ \  | |_) | | |_| | \__ \ |  __/  | |  |  __/  | |_| | | |_) |
/_/   \_\_|_.__/ _ \__,_| |___/  \___| |___| |_|     |____/  |____/

        (_)_ __ | |_ ___  __ _ _ __ __ _| |_(_) ___  _ __
        | | '_ \| __/ _ \/ _` | '__/ _` | __| |/ _ \| '_ \
        | | | | | ||  __/ (_| | | | (_| | |_| | (_) | | | |
        |_|_| |_|\__\___|\__, |_|  \__,_|\__|_|\___/|_| |_|
                         |___/


                    >> by https://sefinek.net <<

This installer configures the UFW-AbuseIPDB-Reporter tool, which analyzes
UFW firewall logs and reports malicious IP addresses to the AbuseIPDB database.


EOF

# Function to download a file using either wget or curl
download_file() {
    local url="$1"
    local output="$2"
    local user_agent="UFW-AbuseIPDB-Reporter/1.0.0 (+https://github.com/sefinek24/UFW-AbuseIPDB-Reporter)"

    if command -v wget >/dev/null 2>&1; then
        echo "INFO: Using wget to download the file. Please wait..."
        wget --header="User-Agent: $user_agent" -O "$output" "$url"
    elif command -v curl >/dev/null 2>&1; then
        echo "INFO: wget not found. Switching to curl to download the file. Please wait..."
        curl -A "$user_agent" -o "$output" "$url"
    else
        echo "ERROR: Neither wget nor curl is installed! Please install one of these tools and try running the script again."
        exit 1
    fi
}

# Function to remove the existing service
remove_service() {
    echo "INFO: Stopping and disabling the abuseipdb-ufw.service..."
    sudo systemctl stop abuseipdb-ufw.service
    sudo systemctl disable abuseipdb-ufw.service
    sudo rm /etc/systemd/system/abuseipdb-ufw.service
    sudo systemctl daemon-reload
    sudo systemctl reset-failed
    echo
}

# Function to validate the API token format
validate_token() {
    local token="$1"
    if [[ ! "$token" =~ ^[a-f0-9]{80}$ ]]; then
        return 1
    else
        return 0
    fi
}

# Set the installation directory
install_dir="/usr/local/bin/UFW-AbuseIPDB-Reporter"
script_path="$install_dir/reporter.sh"

# Get the username of the user who invoked sudo (if any)
invoking_user=$(logname)

# Check if the service already exists
if systemctl list-unit-files | grep -q '^abuseipdb-ufw.service'; then
    echo "WARNING: abuseipdb-ufw.service is already installed!"
    read -rp "> Do you want to remove the existing service? [Yes/no]: " remove_existing

    remove_existing=$(echo "$remove_existing" | tr '[:upper:]' '[:lower:]')
    if [[ "$remove_existing" =~ ^(yes|y)$ ]]; then
        remove_service
    else
        echo "INFO: Existing service will not be removed. Exiting..."
        exit 0
    fi
fi

# Create the installation directory
echo "INFO: Creating installation directory at $install_dir..."
if ! sudo mkdir -p "$install_dir"; then
    echo "ERROR: Failed to create installation directory. Please check your permissions!"
    exit 1
fi
echo "INFO: Installation directory created successfully"

# Download the reporter.sh script
GITHUB_URL="https://raw.githubusercontent.com/sefinek24/UFW-AbuseIPDB-Reporter/main/reporter.sh"
echo "INFO: Downloading reporter.sh from $GITHUB_URL"
if ! download_file "$GITHUB_URL" "$script_path"; then
    echo "ERROR: Failed to download reporter.sh from GitHub! Please check your permissions!"
    exit 1
fi
echo "INFO: Successfully downloaded reporter.sh to $script_path"

# Make the reporter.sh script executable
if ! sudo chmod +x "$script_path"; then
    echo "ERROR: Failed to make reporter.sh executable."
    exit 1
fi
echo -e "INFO: reporter.sh has been made executable\n"

# Prompt for API token with up to 3 attempts
max_attempts=3
attempts=0
valid_token=false

while [[ $attempts -lt $max_attempts ]]; do
    read -rsp "> Please enter your AbuseIPDB API token: " api_key
    echo

    if validate_token "$api_key"; then
        valid_token=true
        break
    else
        attempts_left=$((max_attempts - attempts - 1))
        echo "ERROR: Invalid API token format. Please enter an 80-character hexadecimal string. You have $attempts_left attempts left."
        ((attempts++))
    fi
done

if [[ "$valid_token" = false ]]; then
    echo "ERROR: Maximum number of attempts reached. Installation aborted!"
    exit 1
fi

# Encode the API token
token_file="$install_dir/.abuseipdb_token"
echo "INFO: Encoding data (file $token_file)..."
if ! echo -n "$api_key" | openssl enc -base64 | sudo tee "$token_file" >/dev/null; then
    echo "ERROR: Something went wrong. Failed to encode API token."
    exit 1
fi

# Update the ENCODED_API_KEY_FILE variable in reporter.sh by replacing the existing definition
echo "INFO: Updating ENCODED_API_KEY_FILE variable in reporter.sh..."
if ! sudo sed -i "s|^ENCODED_API_KEY_FILE=.*|ENCODED_API_KEY_FILE=\"$token_file\"|" "$script_path"; then
    echo "ERROR: Failed to update ENCODED_API_KEY_FILE in reporter.sh."
    exit 1
fi
echo

# Prompt to add reporter.sh as a service
read -rp "> Do you want to add reporter.sh as a service? [Yes/no]: " add_service

# Normalize input to lowercase to handle variations in input (yes, y, no, n)
add_service=$(echo "$add_service" | tr '[:upper:]' '[:lower:]')

if [[ "$add_service" =~ ^(yes|y)$ ]]; then
    service_file="/etc/systemd/system/abuseipdb-ufw.service"
    echo "INFO: Setting up reporter.sh as a service"
    if ! sudo bash -c "cat > $service_file" <<EOL
[Unit]
Description=UFW AbuseIPDB Reporter
After=network.target
Documentation=https://github.com/sefinek24/UFW-AbuseIPDB-Reporter

[Service]
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=$script_path
Restart=always
User=$invoking_user
WorkingDirectory=$install_dir
StandardOutput=journal+console
StandardError=journal+console

[Install]
WantedBy=multi-user.target
EOL
    then
        echo "ERROR: Failed to create service file. Please check your permissions!"
        exit 1
    fi
    sudo systemctl daemon-reload

    if sudo systemctl enable abuseipdb-ufw.service && sudo systemctl start abuseipdb-ufw.service; then
        echo "INFO: Attempting to start the abuseipdb-ufw.service..."
    else
        echo "ERROR: Failed to enable or start the abuseipdb-ufw.service. Please check the system logs for details."
        exit 1
    fi

    # Add a 5-second delay before checking the service status
    echo "INFO: Sleeping for 5 seconds..."
    sleep 5

    # Check if the service started successfully
    if sudo systemctl is-active --quiet abuseipdb-ufw.service; then
        echo "SUCCESS: abuseipdb-ufw.service is running!"
        sudo systemctl status abuseipdb-ufw.service --no-pager
    else
        echo "ERROR: abuseipdb-ufw.service failed to start."
        sudo systemctl status abuseipdb-ufw.service --no-pager
        exit 1
    fi
elif [[ "$add_service" =~ ^(no|n)$ ]]; then
    echo "INFO: reporter.sh will not be added as a service."
    echo "INFO: Running reporter.sh directly. Press CTRL+C to stop the script."
    if "$script_path"; then
        echo "INFO: reporter.sh executed successfully."
    else
        echo "ERROR: Failed to execute reporter.sh."
        exit 1
    fi
else
    echo "ERROR: Invalid input. Please enter Yes, No, y, or n."
    exit 1
fi

# Prompt to add the service to autostart
echo
read -rp "> Do you want to add abuseipdb-ufw.service to autostart? [Yes/no]: " add_autostart

add_autostart=$(echo "$add_autostart" | tr '[:upper:]' '[:lower:]')

if [[ "$add_autostart" =~ ^(yes|y)$ ]]; then
    if sudo systemctl enable abuseipdb-ufw.service; then
        echo "INFO: Great! abuseipdb-ufw.service has been added to autostart. Installation finished!"
        echo "INFO: Run 'journalctl -u abuseipdb-ufw.service -f' to view more logs."
    else
        echo "ERROR: Failed to add abuseipdb-ufw.service to autostart!"
        exit 1
    fi
elif [[ "$add_autostart" =~ ^(no|n)$ ]]; then
    echo "INFO: abuseipdb-ufw.service will not be added to autostart. Installation finished!"
else
    echo "ERROR: Invalid input. Please enter Yes, No, y, or n."
    exit 1
fi
