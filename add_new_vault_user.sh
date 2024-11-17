#!/bin/bash

# Variables
USER="$1"
PASSWORD="$2"
MOUNT_POINT_A="/mnt/myown_storage_A"
MOUNT_POINT_A_VAULT_DIR="$MOUNT_POINT_A/myown_storage_vault"  
USER_DIR="$MOUNT_POINT_A_VAULT_DIR/users/$USER"

# Ensure script runs as root
if [[ $EUID -ne 0 ]]; then
    echo "Please run as root or use sudo."
    exit 1
fi

# Create User
if id "$USER" &>/dev/null; then
    echo "User $USER already exists."
    exit 1
else
    sudo adduser --disabled-password --gecos "" "$USER"
    echo "$USER:$PASSWORD" | chpasswd
    echo "User $USER created."
fi

# Create Directory for SFTP
if [[ ! -d $USER_DIR ]]; then
    echo "Creating directory $USER_DIR"
    sudo mkdir -p $USER_DIR
fi
sudo chown $USER:$USER $USER_DIR
sudo chmod 755 $USER_DIR




echo "Directory $USER_DIR assigned to $USER."

# Restart SSH Service
echo "Restarting SSH service to apply changes."
sudo systemctl restart sshd

echo "Setup complete. $USER can now access $USER_DIR via SFTP."
