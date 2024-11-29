#!/bin/bash

# The disks need to be formatted as ext4 to work properly

# ensure it's running as sudo
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or use sudo."
  exit 1
fi

# Configuration Section
UUID_A="7669a2e8-88dc-4a2f-9900-9644226ac573"  # UUID of USB Drive A (Storage)
UUID_B="2f9886c6-c954-4745-9c65-354e6e42a65c"  # UUID of USB Drive B (Backup)
MOUNT_POINT_A="/mnt/myown_storage_A"  # Mount point for USB Drive A (e.g., /mnt/usbA)
MOUNT_POINT_B="/mnt/myown_storage_B"  # Mount point for USB Drive B (e.g., /mnt/usbB)
MOUNT_POINT_A_VAULT_DIR="$MOUNT_POINT_A/myown_storage_vault"  
VAULT_USERS_DIR="$MOUNT_POINT_A_VAULT_DIR/users/"
MOUNT_POINT_A_VAULT_TEMP_DIR="$MOUNT_POINT_A/myown_storage_vault_temp"  
MOUNT_POINT_B_VAULT_BACKUP_DIR="$MOUNT_POINT_B/myown_storage_vault_backup"  
MOUNT_POINT_B_VAULT_BACKUP_TEMP_DIR="$MOUNT_POINT_B/myown_storage_vault_backup_temp"  
LOG_FILE="/var/log/myown_storage_backup.log"  # Log file for cron job logs
BACKUP_SCRIPT="/usr/local/bin/myown_storage_backup.sh"  # Path to the backup script

#Minute (0 - 59)
#Hour (0 - 23)
#Day of Month (1 - 31) */2 every 2 days
#Month (1 - 12)
#Day of Week (0 - 7, where 0 and 7 both represent Sunday)
CRONJOB="0 0 */2 * * $BACKUP_SCRIPT"

# Check if UUIDs and Mount Points are specified
if [[ -z "$UUID_A" || -z "$UUID_B" || -z "$MOUNT_POINT_A" || -z "$MOUNT_POINT_B" ]]; then
  echo "Error: UUIDs and mount points must be specified within the script. Please use: sudo blkid"
  exit 1
fi

# Confirm UUIDs for Drive A and Drive B
DETECTED_UUID_A=$(blkid -s UUID -o value /dev/disk/by-uuid/"$UUID_A" 2>/dev/null)
DETECTED_UUID_B=$(blkid -s UUID -o value /dev/disk/by-uuid/"$UUID_B" 2>/dev/null)

if [[ -z "$DETECTED_UUID_A" ]]; then
  echo "Error: Drive A with UUID $UUID_A not found. Please verify the UUID."
  exit 1
else 
  echo "Drive A with UUID $UUID_A found."
fi

if [[ -z "$DETECTED_UUID_B" ]]; then
  echo "Error: Drive B with UUID $UUID_B not found. Please verify the UUID."
  exit 1
else 
  echo "Drive B with UUID $UUID_B found."
fi

# Create Mount Points if They Don't Exist
if [[ ! -d "$MOUNT_POINT_A" ]]; then
  echo "Creating mount point for Drive A at $MOUNT_POINT_A"
  sudo mkdir -p "$MOUNT_POINT_A"
fi
if [[ ! -d "$MOUNT_POINT_B" ]]; then
  echo "Creating mount point for Drive B at $MOUNT_POINT_B"
  sudo mkdir -p "$MOUNT_POINT_B"
fi

# Add UUIDs to fstab for automatic mounting at boot

DEVICE_A_TYPE=$(blkid -s TYPE -o value /dev/disk/by-uuid/"$UUID_A" 2>/dev/null)
DEVICE_B_TYPE=$(blkid -s TYPE -o value /dev/disk/by-uuid/"$UUID_B" 2>/dev/null)


if ! grep -qs "$UUID_A" /etc/fstab; then
  echo "Adding Drive A to /etc/fstab"
  # noatime used to protect the disk of uneccessary write (no access time written to files on read)
  echo "UUID=$UUID_A $MOUNT_POINT_A $DEVICE_A_TYPE defaults,noatime,nofail 0 2" | sudo tee -a /etc/fstab
fi

if ! grep -qs "$UUID_B" /etc/fstab; then
  echo "Adding Drive B to /etc/fstab"
  # noatime used to protect the disk of uneccessary write (no access time written to files on read)
  echo "UUID=$UUID_B $MOUNT_POINT_B $DEVICE_B_TYPE defaults,noatime,nofail 0 2" | sudo tee -a /etc/fstab
fi

echo "Running systemctl daemon-reload..."
sudo systemctl daemon-reload
#sudo mount -a

## Mount the drives
echo "Mounting drives..."

DEVICE_A=$(blkid -U "$UUID_A" 2>/dev/null)
# Check if we could get the device path
if [ -z "$DEVICE_A" ]; then
    echo "Error: Could not find device with UUID $UUID_A"
    exit 1
fi

DEVICE_B=$(blkid -U "$UUID_B" 2>/dev/null)
if [ -z "$DEVICE_B" ]; then
    echo "Error: Could not find device with UUID $UUID_B"
    exit 1
fi

# Find the current mount point using the UUID
CURRENT_MOUNT_A=$(findmnt -n -o TARGET -S UUID="$UUID_A")
CURRENT_MOUNT_B=$(findmnt -n -o TARGET -S UUID="$UUID_B")

# If the device is mounted somewhere else, unmount it
if [ -n "$CURRENT_MOUNT_A" ]; then
    echo "Drive is already mounted at $CURRENT_MOUNT_A. Unmounting..."
    sudo umount "$CURRENT_MOUNT_A"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to unmount $CURRENT_MOUNT_A"
        exit 1
    fi
else
    echo "Drive $CURRENT_MOUNT_A is not currently mounted."
fi
if [ -n "$CURRENT_MOUNT_B" ]; then
    echo "Drive is already mounted at $CURRENT_MOUNT_B. Unmounting..."
    sudo umount "$CURRENT_MOUNT_B"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to unmount $CURRENT_MOUNT_B"
        exit 1
    fi
else
    echo "Drive $CURRENT_MOUNT_B is not currently mounted."
fi

# Now mount the drive at the desired mount point
if ! mountpoint -q "$MOUNT_POINT_A"; then
    echo "Mounting $DEVICE_A to $MOUNT_POINT_A"
    sudo mount -o noatime "$DEVICE_A" "$MOUNT_POINT_A"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to mount $DEVICE_A to $MOUNT_POINT_A"
        exit 1
    fi
    sudo chmod 755 "$MOUNT_POINT_A"
else
    echo "$MOUNT_POINT_A is already mounted"
fi
if ! mountpoint -q "$MOUNT_POINT_B"; then
    echo "Mounting $DEVICE_B to $MOUNT_POINT_B"
    sudo mount -o noatime "$DEVICE_B" "$MOUNT_POINT_B"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to mount $DEVICE_B to $MOUNT_POINT_B"
        exit 1
    fi
    sudo chmod 755 "$MOUNT_POINT_B"
else
    echo "$MOUNT_POINT_B is already mounted"
fi


# Verify if drives are mounted successfully
if mountpoint -q "$MOUNT_POINT_A" && mountpoint -q "$MOUNT_POINT_B"; then
  echo "Both drives mounted successfully."
else
  echo "Error: One or both drives failed to mount."
  exit 1
fi

# Create Vault Dir if it Does Not Exist
# Only this Dir will be subject to backups
if [[ ! -d "$MOUNT_POINT_A_VAULT_DIR" ]]; then
  echo "Creating Vault Dir on source drive"
  sudo mkdir -p "$MOUNT_POINT_A_VAULT_DIR"
  sudo chmod 755 "$MOUNT_POINT_A_VAULT_DIR"
fi

# Create Vault Temp Dir if it Does Not Exist
if [[ ! -d "$MOUNT_POINT_A_VAULT_TEMP_DIR" ]]; then
  echo "Creating Vault Temp Dir"
  sudo mkdir -p "$MOUNT_POINT_A_VAULT_TEMP_DIR"
  sudo chmod 755 "$MOUNT_POINT_A_VAULT_TEMP_DIR"
fi

# Create Vault Users Dir if it Does Not Exist
if [[ ! -d "$VAULT_USERS_DIR" ]]; then
  echo "Creating Vault Users Dir"
  sudo mkdir -p "$VAULT_USERS_DIR"
  sudo chmod 755 "$VAULT_USERS_DIR"
fi


# Install cron job for regular Vault backups
# Prevent duplicate cron entries by ensuring the script checks for an existing entry
(crontab -l 2>/dev/null | grep -v "$BACKUP_SCRIPT"; echo "$CRONJOB") | crontab -

echo "Cron job installed to back up Drive A to Drive B every hour."

echo "Writing backup script to $BACKUP_SCRIPT"
sudo tee "$BACKUP_SCRIPT" > /dev/null <<EOL
#!/bin/bash


# Run rsync backup
echo "Starting backup from $MOUNT_POINT_A_VAULT_DIR to $MOUNT_POINT_B_VAULT_BACKUP_DIR at \$(date)" >> "$LOG_FILE"

if ! mountpoint -q "$MOUNT_POINT_A"; then
    echo "Error: $MOUNT_POINT_A is not mounted. Aborting!" >> "$LOG_FILE"
    exit 1
fi

if ! mountpoint -q "$MOUNT_POINT_B"; then
    echo "Error: $MOUNT_POINT_B is not mounted. Aborting!" >> "$LOG_FILE"
    exit 1
fi


# Create Temp Dir if it Does Not Exist
if [[ ! -d "$MOUNT_POINT_B_VAULT_BACKUP_TEMP_DIR" ]]; then
  echo "Creating Temp Dir"
  sudo mkdir -p "$MOUNT_POINT_B_VAULT_BACKUP_TEMP_DIR"
  sudo chmod 755 "$MOUNT_POINT_B_VAULT_BACKUP_TEMP_DIR"
fi
# Create Backup Dir if it Does Not Exist
if [[ ! -d "$MOUNT_POINT_B_VAULT_BACKUP_DIR" ]]; then
  echo "Creating Backup Dir"
  sudo mkdir -p "$MOUNT_POINT_B_VAULT_BACKUP_DIR"
  sudo chmod 755 "$MOUNT_POINT_B_VAULT_BACKUP_DIR"
fi
# use flock in combination with rsync to prevent other processes to 
# interfere with the source while sync is in progress
# also wait only 600s (10 min) then exit
sudo flock -x -w 600 /var/lock/myown_storage_rsync.lock rsync --verbose --times --atimes --open-noatime --recursive --delete --temp-dir="$MOUNT_POINT_B_VAULT_BACKUP_TEMP_DIR" "$MOUNT_POINT_A_VAULT_DIR" "$MOUNT_POINT_B_VAULT_BACKUP_DIR" >> "$LOG_FILE" 2>&1

if [ \$? -ne 0 ]; then
  echo "Vault Backup failed. Failed to acquire lock or run rsync." >> "$LOG_FILE"
else
  echo "Vault Backup completed successfully at \$(date)" >> "$LOG_FILE"
fi
EOL

# Make the backup script executable
sudo chmod +x "$BACKUP_SCRIPT"

echo "Backup script created and installed at $BACKUP_SCRIPT."

exit 0
