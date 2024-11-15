#!/bin/bash

# ensure it's run as sudo
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or use sudo."
  exit 1
fi

# Configuration Section
UUID_A="273c3d88-09e8-477b-a2ba-c160340bbcdb"  # UUID of USB Drive A (Storage)
UUID_B="f78d83e6-e275-4a15-bd36-ff69e2050de5"  # UUID of USB Drive B (Backup)
MOUNT_POINT_A="/mnt/myown_storage_A"  # Mount point for USB Drive A (e.g., /mnt/usbA)
MOUNT_POINT_B="/mnt/myown_storage_B"  # Mount point for USB Drive B (e.g., /mnt/usbB)
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
  echo "UUID=$UUID_A $MOUNT_POINT_A $DEVICE_A_TYPE defaults,nofail 0 2" | sudo tee -a /etc/fstab
fi

if ! grep -qs "$UUID_B" /etc/fstab; then
  echo "Adding Drive B to /etc/fstab"
  echo "UUID=$UUID_B $MOUNT_POINT_B $DEVICE_B_TYPE defaults,nofail 0 2" | sudo tee -a /etc/fstab
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
    sudo mount "$DEVICE_A" "$MOUNT_POINT_A"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to mount $DEVICE_A to $MOUNT_POINT_A"
        exit 1
    fi
    sudo chmod 777 "$MOUNT_POINT_A"
else
    echo "$MOUNT_POINT_A is already mounted"
fi
if ! mountpoint -q "$MOUNT_POINT_B"; then
    echo "Mounting $DEVICE_B to $MOUNT_POINT_B"
    sudo mount "$DEVICE_B" "$MOUNT_POINT_B"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to mount $DEVICE_B to $MOUNT_POINT_B"
        exit 1
    fi
    sudo chmod 777 "$MOUNT_POINT_B"
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
if [[ ! -d "$MOUNT_POINT_A/myown_storage_vault" ]]; then
  echo "Creating Vault Dir on source drive"
  sudo mkdir -p "$MOUNT_POINT_A/myown_storage_vault"
  sudo chmod 777 "$MOUNT_POINT_A/myown_storage_vault"
fi

# Install cron job for regular backups
# Prevent duplicate cron entries by ensuring the script checks for an existing entry
(crontab -l 2>/dev/null | grep -v "$BACKUP_SCRIPT"; echo "$CRONJOB") | crontab -

echo "Cron job installed to back up Drive A to Drive B every hour."

# Create the backup script at the specified path
echo "Writing backup script to $BACKUP_SCRIPT"
sudo tee "$BACKUP_SCRIPT" > /dev/null <<EOL
#!/bin/bash

# Configuration Section
MOUNT_POINT_A="$MOUNT_POINT_A"  # Mount point for USB Drive A
MOUNT_POINT_B="$MOUNT_POINT_B"  # Mount point for USB Drive B
LOG_FILE="$LOG_FILE"  # Log file for backup logs



# Run rsync backup
echo "Starting backup from \$MOUNT_POINT_A/myown_storage_vault to \$MOUNT_POINT_B/myown_storage_vault_backup at \$(date)" >> "\$LOG_FILE"

if ! mountpoint -q "$MOUNT_POINT_A"; then
    echo "Error: $MOUNT_POINT_A is not mounted. Aborting!" >> "\$LOG_FILE"
    exit 1
fi

if ! mountpoint -q "$MOUNT_POINT_B"; then
    echo "Error: $MOUNT_POINT_B is not mounted. Aborting!" >> "\$LOG_FILE"
    exit 1
fi


# Create Temp Dir if it Does Not Exist
if [[ ! -d "\$MOUNT_POINT_B/myown_storage_vault_backup_temp" ]]; then
  echo "Creating Temp Dir"
  sudo mkdir -p "\$MOUNT_POINT_B/myown_storage_vault_backup_temp"
  sudo chmod 777 "\$MOUNT_POINT_B/myown_storage_vault_backup_temp"
fi
# Create Backup Dir if it Does Not Exist
if [[ ! -d "\$MOUNT_POINT_B/myown_storage_vault_backup" ]]; then
  echo "Creating Backup Dir"
  sudo mkdir -p "\$MOUNT_POINT_B/myown_storage_vault_backup"
  sudo chmod 777 "\$MOUNT_POINT_B/myown_storage_vault_backup"
fi
# use flock in combination with rsync to prevent other processes to 
# interfere with the source while sync is in progress
# also wait only 600s (10 min) then exit
sudo flock -x -w 600 /var/lock/myown_storage_rsync.lock rsync -av --delete --temp-dir="\$MOUNT_POINT_B/myown_storage_vault_backup_temp" "\$MOUNT_POINT_A/myown_storage_vault" "\$MOUNT_POINT_B/myown_storage_vault_backup" >> "\$LOG_FILE" 2>&1

if [ \$? -ne 0 ]; then
  echo "Failed to acquire lock or run rsync." >> "\$LOG_FILE"
fi

# Check if rsync was successful and log any errors
if [ \$? -eq 0 ]; then
  echo "Backup completed successfully at \$(date)" >> "\$LOG_FILE"
else
  echo "Backup failed at \$(date)" >> "\$LOG_FILE"
fi

EOL

# Make the backup script executable
sudo chmod +x "$BACKUP_SCRIPT"

echo "Backup script created and installed at $BACKUP_SCRIPT."

exit 0
