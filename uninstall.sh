#!/bin/bash

# Configuration - should match the original script's configuration
UUID_A="7669a2e8-88dc-4a2f-9900-9644226ac573"  # UUID of USB Drive A (Storage)
UUID_B="2f9886c6-c954-4745-9c65-354e6e42a65c"  # UUID of USB Drive B (Backup)
MOUNT_POINT_A="/mnt/myown_storage_A"
MOUNT_POINT_B="/mnt/myown_storage_B"
LOG_FILE="/var/log/myown_storage_backup.log"
LOCK_FILE="/var/run/myown_storage_backup.lock"
BACKUP_SCRIPT="/usr/local/bin/incremental-vault-backup.sh"
SERVICE_NAME="myown-backup"

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


# Remove service and timer

echo "Stopping systemd units..."
systemctl stop ${SERVICE_NAME}.timer || true
systemctl stop ${SERVICE_NAME}.service || true

echo "Disabling systemd units..."
systemctl disable ${SERVICE_NAME}.timer || true
systemctl disable ${SERVICE_NAME}.service || true

echo "Removing unit files..."
rm -f /etc/systemd/system/${SERVICE_NAME}.service
rm -f /etc/systemd/system/${SERVICE_NAME}.timer

echo "Reloading systemd..."
systemctl daemon-reload
systemctl reset-failed


if [ -f "$BACKUP_SCRIPT" ]; then
    echo "Deleting the backup script at $BACKUP_SCRIPT"
    sudo rm -f "$BACKUP_SCRIPT"
fi

echo "Uninstall complete. Verify with:"
echo "  systemctl list-unit-files | grep ${SERVICE_NAME}"
echo "  systemctl list-timers | grep ${SERVICE_NAME}"


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
