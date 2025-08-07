#!/bin/bash

# The disks need to be formatted as ext4 to work properly

# ensure it's running as sudo
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or use sudo."
  exit 1
fi

# Configuration Section
UUID_A="7669a2e8-88dc-4a2f-9900-9644226ac573"  # UUID of USB Drive A (Storage)
UUID_B="5c7023ed-0418-478d-b3fc-870752f059d7"  # UUID of USB Drive B (Backup)
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

  
# Create Vault Backup Dir if it Does Not Exist
if [[ ! -d "$MOUNT_POINT_B_VAULT_BACKUP_DIR" ]]; then
  echo "Creating Vault Backup Dir"
  sudo mkdir -p "$MOUNT_POINT_B_VAULT_BACKUP_DIR"
  sudo chmod 755 "$MOUNT_POINT_B_VAULT_BACKUP_DIR"
fi

# Create Vault Backup Temp Dir if it Does Not Exist
if [[ ! -d "$MOUNT_POINT_B_VAULT_BACKUP_TEMP_DIR" ]]; then
  echo "Creating Vault Backup temp Dir"
  sudo mkdir -p "$MOUNT_POINT_B_VAULT_BACKUP_TEMP_DIR"
  sudo chmod 755 "$MOUNT_POINT_B_VAULT_BACKUP_TEMP_DIR"
fi

# Install cron job for regular Vault backups
# Prevent duplicate cron entries by ensuring the script checks for an existing entry
(crontab -l 2>/dev/null | grep -v "$BACKUP_SCRIPT"; echo "$CRONJOB") | crontab -

echo "Cron job installed to back up Drive A to Drive B every hour."

echo "Writing backup script to $BACKUP_SCRIPT"
sudo tee "$BACKUP_SCRIPT" > /dev/null <<EOL
#!/bin/bash

TIMESTAMP=\$(date +%F_%H-%M-%S)
SOURCE_DIR="$MOUNT_POINT_A_VAULT_DIR"

BACKUP_BASE="$MOUNT_POINT_B_VAULT_BACKUP_DIR"
TEMP_DIR="$MOUNT_POINT_B_VAULT_BACKUP_TEMP_DIR"


BACKUP_DIR="\$BACKUP_BASE/backup-\$TIMESTAMP"
LATEST_LINK="\$BACKUP_BASE/latest"
LOCK_FILE_PATH="/var/lock/myown_storage_rsync.lock"

LOG_PATH="\$BACKUP_BASE/myown_storage_backup.log"

# Delete backups older than X days
RETENTION_DAYS=60


exec >> "\$LOG_PATH" 2>&1
echo "=== Backup started at \$(date) ==="

if ! sudo flock -x -w 600 "\$LOCK_FILE_PATH" true; then
  echo "Failed to acquire lock" >> "\$LOG_PATH"
  exit 1
fi

if [ -L "\$LATEST_LINK" ] && [ -d "\$LATEST_LINK" ]; then
  LINK_DEST="--link-dest=\$LATEST_LINK"
else
  LINK_DEST=""
fi

sudo flock -x -w 600 \$LOCK_FILE_PATH \
  sudo rsync --verbose --times --recursive --perms --acls \
        --owner --group --delete --temp-dir="\$TEMP_DIR" \
        \$LINK_DEST \
        "\$SOURCE_DIR" "\$BACKUP_DIR" >> "\$LOG_PATH" 2>&1 && \
  sudo ln -sfn "\$BACKUP_DIR" "\$LATEST_LINK"
  
# Cleanup old backups
NOW_EPOCH=\$(date +%s)

for dir in "\$BACKUP_BASE"/backup-*; do
  # Skip if not a directory
  if [ ! -d "\$dir" ]; then
    continue
  fi

  basename_dir=\$(basename "\$dir")
  # Remove 'backup-' prefix safely
  timestamp=\$(echo "\$basename_dir" | sed 's/^backup-//')

  # Replace underscore with space to separate date and time
  date_string=\$(echo "\$timestamp" | tr '_' ' ')

  # Split date and time parts
  date_part=\$(echo "\$date_string" | cut -d' ' -f1)
  time_part=\$(echo "\$date_string" | cut -d' ' -f2)

  # Replace dashes in time part with colons for date parsing
  time_part=\$(echo "\$time_part" | tr '-' ':')

  # Recombine into a single date string
  date_string="\$date_part \$time_part"

  # Parse date to epoch seconds
  backup_epoch=\$(date -d "\$date_string" +%s 2>/dev/null)

  if [ -z "\$backup_epoch" ]; then
    echo "Warning: cannot parse date from \$dir"
    continue
  fi

  # Calculate age in days
  age_days=\$(( (NOW_EPOCH - backup_epoch) / 86400 ))

  # Remove backup if older than retention period
  if [ "\$age_days" -gt "\$RETENTION_DAYS" ]; then
    echo "Removing old backup \$dir (age \$age_days days)"
    sudo rm -rf "\$dir"
  fi
done

echo "=== Backup finished at \$(date) ==="

EOL

# Make the backup script executable
sudo chmod +x "$BACKUP_SCRIPT"

echo "Backup script created and installed at $BACKUP_SCRIPT."

exit 0
