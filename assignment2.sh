#!/bin/bash

# Function to display messages with a label
function display_message {
    echo -e "\e[1;32m$1\e[0m"
}

# Function to display error messages with a label
function display_error {
    echo -e "\e[1;31mError: $1\e[0m" >&2
    exit 1
}

# Check if the script is run with root privileges
if [ "$EUID" -ne 0 ]; then
    display_error "This script must be run with root privileges."
fi

# Update system and install required packages
display_message "Updating system and installing required packages..."
apt-get update || display_error "Failed to update the system."
apt-get install -y openssh-server apache2 squid ufw || display_error "Failed to install packages."

# Configure network
display_message "Configuring network..."
echo "network:
  version: 2
  ethernets:
    ens33: # Change to the correct interface name
      addresses:
        - 192.168.16.21/24
      gateway4: 192.168.16.1
      nameservers:
        addresses: [192.168.16.1]
        search: [home.arpa, localdomain]" > /etc/netplan/01-netcfg.yaml

# Apply network configuration
netplan apply || display_error "Failed to apply network configuration."

# Update /etc/hosts
sed -i '/192.168.16.21/s/.*/192.168.16.21\tnew-hostname/' /etc/hosts

# Configure SSH
display_message "Configuring SSH..."
sed -i '/PasswordAuthentication/s/yes/no/' /etc/ssh/sshd_config
systemctl restart ssh || display_error "Failed to restart SSH."

# Configure Apache
display_message "Configuring Apache..."
ufw allow 80
ufw allow 443
systemctl restart apache2 || display_error "Failed to restart Apache."

# Configure Squid
display_message "Configuring Squid..."
ufw allow 3128
systemctl restart squid || display_error "Failed to restart Squid."

# Configure UFW
display_message "Configuring UFW..."
ufw allow 22
ufw enable || display_error "Failed to enable UFW."

# Create user accounts
display_message "Creating user accounts..."
users=("dennis" "aubrey" "captain" "snibbles" "brownie" "scooter" "sandy" "perrier" "cindy" "tiger" "yoda")
for user in "${users[@]}"; do
    useradd -m -s /bin/bash "$user" || display_error "Failed to create user $user."
    mkdir -p /home/$user/.ssh
    echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4rT3vTt99Ox5kndS4HmgTrKBT8SKzhK4rhGkEVGlCI student@generic-vm" > "/home/$user/.ssh/authorized_keys"
done

# Grant sudo access to dennis
display_message "Granting sudo access to dennis..."
usermod -aG sudo dennis || display_error "Failed to grant sudo access to dennis."

display_message "Script execution completed successfully."
