#!/bin/bash

# Configuration - should match the original script's configuration
UUID_A="273c3d88-09e8-477b-a2ba-c160340bbcdb"  # UUID of USB Drive A (Storage)
UUID_B="f78d83e6-e275-4a15-bd36-ff69e2050de5"  # UUID of USB Drive B (Backup)
MOUNT_POINT_A="/mnt/myown_storage_A"
MOUNT_POINT_B="/mnt/myown_storage_B"
LOG_FILE="/var/log/myown_storage_backup.log"
LOCK_FILE="/var/run/myown_storage_backup.lock"
BACKUP_SCRIPT="/usr/local/bin/myown_storage_backup.sh"

# Unmount the drives if they are mounted
if mountpoint -q "$MOUNT_POINT_A"; then
    echo "Unmounting Drive A from $MOUNT_POINT_A"
    sudo umount "$MOUNT_POINT_A"
fi

if mountpoint -q "$MOUNT_POINT_B"; then
    echo "Unmounting Drive B from $MOUNT_POINT_B"
    sudo umount "$MOUNT_POINT_B"
fi

# Remove entries from /etc/fstab
echo "Removing entries for Drive A and Drive B from /etc/fstab"
sudo sed -i "\|UUID=$UUID_A|d" /etc/fstab
sudo sed -i "\|UUID=$UUID_B|d" /etc/fstab


# Remove cron job for the backup script
echo "Removing cron job for the backup script"
crontab -l | grep -v "$BACKUP_SCRIPT" | crontab -

# Delete the backup script
if [ -f "$BACKUP_SCRIPT" ]; then
    echo "Deleting the backup script at $BACKUP_SCRIPT"
    sudo rm -f "$BACKUP_SCRIPT"
fi

# Delete the log and lock files
if [ -f "$LOG_FILE" ]; then
    echo "Deleting the log file at $LOG_FILE"
    sudo rm -f "$LOG_FILE"
fi

if [ -f "$LOCK_FILE" ]; then
    echo "Deleting the lock file at $LOCK_FILE"
    sudo rm -f "$LOCK_FILE"
fi

echo "Uninstallation completed successfully."
exit 0
