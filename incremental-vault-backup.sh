#!/bin/bash

set -euo pipefail
trap 'echo "Error at line $LINENO" >&2' ERR

TIMESTAMP=$(date +%F_%H-%M-%S)
SOURCE_DIR="/mnt/myown_storage_A/myown_storage_vault"

TARGET_DRIVE_BASE_PATH="/mnt/myown_storage_B"

BACKUP_BASE="$TARGET_DRIVE_BASE_PATH/myown_storage_vault_backup"
TEMP_DIR="$TARGET_DRIVE_BASE_PATH/myown_storage_vault_backup_temp"

FINAL_BACKUP_DIR="$BACKUP_BASE/backup-$TIMESTAMP"
STAGING_DIR="$BACKUP_BASE/.incomplete-$TIMESTAMP"

LATEST_LINK="$BACKUP_BASE/latest"
LOCK_FILE_PATH="/var/lock/myown_storage_rsync.lock"
LOG_PATH="$BACKUP_BASE/myown_storage_backup.log"

SERVICE_NAME="myown-backup"

FREE_SPACE_THRESHOLD=$((10*1024*1024*1024)) # 10 GB

RETENTION_DAYS=60

run_step() {
  local desc="$1"
  shift
  echo "[$(date)] Starting: $desc"
  "$@"
  local status=$?
  if [ $status -eq 0 ]; then
    echo "[$(date)] Success: $desc"
  else
    echo "[$(date)] FAILED ($status): $desc"
    exit $status
  fi
}

if command -v systemd-cat >/dev/null && systemctl is-active --quiet systemd-journald; then
    exec > >(tee -a "$LOG_PATH" | systemd-cat -t $SERVICE_NAME -p info) 2>&1
else
    exec >>"$LOG_PATH" 2>&1
fi

echo "=== Backup started at $(date) ==="

(
  flock -x -w 3600 200 || { echo "Failed to acquire lock"; exit 1; }
  
  # Free space check
  echo "[$(date)] Checking free space on $BACKUP_BASE"
  avail=$(df --output=avail -B1 "$BACKUP_BASE" | tail -n1)
  if [ "$avail" -lt "$FREE_SPACE_THRESHOLD" ]; then
      echo "[$(date)] ERROR: Not enough free space on $BACKUP_BASE (available: $avail bytes)"
      exit 1
  else
      echo "[$(date)] Free space OK ($avail bytes available)"
  fi

  # Find last backup for hardlinks
  if [ -L "$LATEST_LINK" ] && [ -d "$LATEST_LINK" ]; then
    LINK_DEST="$(readlink -f "$LATEST_LINK")"
  else
    LINK_DEST=""
  fi

  # Remove any leftover incomplete dir from a failed run
  [ -d "$STAGING_DIR" ] && rm -rf --one-file-system -- "$STAGING_DIR"

  # Rsync into staging dir
  run_step "Rsync data" rsync -aHAX --delete \
    --stats --human-readable \
    --link-dest="$LINK_DEST" \
    --partial --partial-dir="$TEMP_DIR/rsync-partial" \
    --temp-dir="$TEMP_DIR" \
    "$SOURCE_DIR" "$STAGING_DIR"
    
  
  run_step "Move staging to final" mv "$STAGING_DIR" "$FINAL_BACKUP_DIR"
  run_step "Update latest symlink" ln -sfn "$FINAL_BACKUP_DIR" "$LATEST_LINK"


  # Cleanup old backups only after successful backup
  NOW_EPOCH=$(date +%s)
  for dir in "$BACKUP_BASE"/backup-*; do
    [ -d "$dir" ] || continue
    timestamp="${dir##*/backup-}"
    
    timestamp_fixed=$(echo "$timestamp" | sed -E 's/_([0-9]{2})-([0-9]{2})-([0-9]{2})$/ \1:\2:\3/')
    backup_epoch=$(date -d "$timestamp_fixed" +%s 2>/dev/null || true)
  
    [ -n "$backup_epoch" ] || { echo "Warning: cannot parse $dir"; continue; }
    age_days=$(( (NOW_EPOCH - backup_epoch) / 86400 ))
    if [ "$age_days" -gt "$RETENTION_DAYS" ]; then
      run_step "Removing old backup $dir (age $age_days days)" rm -rf --one-file-system -- "$dir"
    fi
  done

) 200>"$LOCK_FILE_PATH"



echo "=== Backup finished at $(date) ==="
