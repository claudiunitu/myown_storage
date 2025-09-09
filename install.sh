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
BACKUP_SCRIPT_FILENAME="incremental-vault-backup.sh"
BACKUP_SCRIPT_ORIGINAL_PATH="./$BACKUP_SCRIPT_FILENAME"
BACKUP_SCRIPT_BASE="/usr/local/bin"
BACKUP_SCRIPT="$BACKUP_SCRIPT_BASE/$BACKUP_SCRIPT_FILENAME"  # Path to the incremental backup script
BACKUP_SYNC_SCRIPT_BASE="$BACKUP_SCRIPT_BASE/backup_sync"  # Path to the backup sync script
BACKUP_SYNC_SCRIPT="$BACKUP_SYNC_SCRIPT_BASE/sync.sh"  # Path to the backup sync script

SERVICE_NAME="myown-backup"


#Minute (0 - 59)
#Hour (0 - 23)
#Day of Month (1 - 31) */2 every 2 days
#Month (1 - 12)
#Day of Week (0 - 7, where 0 and 7 both represent Sunday)
CRONJOB="0 0 */2 * * $BACKUP_SYNC_SCRIPT ; $BACKUP_SCRIPT"

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

# Install scripts

echo "Copying backup script sync to the right location to $BACKUP_SYNC_SCRIPT_BASE"
sudo mkdir "$BACKUP_SYNC_SCRIPT_BASE"
sudo cp -r ./backup_sync/* "$BACKUP_SYNC_SCRIPT_BASE"
sudo chmod +x "$BACKUP_SYNC_SCRIPT"

echo "Copying incremental backup script to the right location to $BACKUP_SCRIPT_BASE"
sudo mkdir "$BACKUP_SCRIPT_BASE"
sudo cp -r "$BACKUP_SCRIPT_ORIGINAL_PATH" "$BACKUP_SCRIPT_BASE"
sudo chmod +x "$BACKUP_SCRIPT"

# Create service unit


cat >/etc/systemd/system/${SERVICE_NAME}.service <<EOF
[Unit]
Description=MyOwn Storage Backup
After=local-fs.target
Requires=local-fs.target

[Service]
Type=oneshot
ExecStart=$BACKUP_SYNC_SCRIPT
ExecStartPost=$BACKUP_SCRIPT
Nice=10
IOSchedulingClass=best-effort
IOSchedulingPriority=7
PrivateTmp=yes
ProtectSystem=full
ProtectHome=yes
NoNewPrivileges=yes
EOF

# Create timer unit
cat >/etc/systemd/system/${SERVICE_NAME}.timer <<EOF
[Unit]
Description=Run MyOwn Storage Backup Daily

[Timer]
OnCalendar=daily
RandomizedDelaySec=30m
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Reload, enable, start timer
echo "Reloading systemd units..."
systemctl daemon-reload
systemctl enable --now ${SERVICE_NAME}.timer

echo "Done. Check status with: systemctl list-timers | grep $SERVICE_NAME"

echo "Backup script created and installed at $BACKUP_SCRIPT."

exit 0
