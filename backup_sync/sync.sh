#!/usr/bin/env bash
set -euo pipefail

# Path to your input file (label <tab> source_dir)

SCRIPT_DIR=$(dirname "$(realpath "$0")")
INPUT_FILE="$SCRIPT_DIR/backup_list.txt"

# Base target directory
TARGET_BASE="/mnt/myown_storage_A/myown_storage_vault/users/synced-backups"

# Temporary rsync staging directory
TEMP_DIR="/mnt/myown_storage_A/myown_storage_vault_temp"


## !!! this should be unified with the one from main script
###################################################
# Lock file for flock
LOCK_FILE="/var/lock/myown_storage_rsync.lock"

LOG_PATH="$TARGET_BASE/backup.log"

# Mapping file
MAPPING_FILE="$TARGET_BASE/mapping.txt"


## !!! this is common with the one from main script
###################################################
SERVICE_NAME="myown-backup"

## !!! this is common with the one from main script
###################################################
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


# Ensure mapping file exists
sudo mkdir -p "$(dirname "$MAPPING_FILE")"
sudo touch "$MAPPING_FILE"

echo "=== Syncing directories started at $(date) ==="

(
  flock -x -w 3600 200 || { echo "[$(date)] ERROR: Failed to acquire lock"; exit 1; }

    while IFS=$'\t' read -r CURRENT_ITERATIONS_LABEL CURRENT_ITERATION_DIR; do
	
	CURRENT_ITERATION_DIR=$(echo "$CURRENT_ITERATION_DIR" | tr -d '\r' | xargs)
	# Skip empty lines or comments
	[[ -z "$CURRENT_ITERATIONS_LABEL" || "$CURRENT_ITERATION_DIR" =~ ^# ]] && continue

	# Check if source directory exists
	if [[ ! -d "$CURRENT_ITERATION_DIR" ]]; then
	    echo "[$(date)] !!! WARNING: Source directory '$CURRENT_ITERATION_DIR' does not exist. Skipping."
	    continue
	fi

	# Turn full path into safe directory name by replacing "/" with "_"
	SAFE_NAME=$(echo "$CURRENT_ITERATION_DIR" | sed 's#/#_#g; s#^_##')
	DEST_DIR="$TARGET_BASE/$CURRENT_ITERATIONS_LABEL/$SAFE_NAME"

	# Ensure destination directory exists
	sudo mkdir -p "$DEST_DIR"

	echo "[$(date)] DEBUG: Syncing '$CURRENT_ITERATION_DIR' into '$DEST_DIR'..."
	
	# Rsync into staging dir
	run_step "Rsync data" rsync -aHAX --delete \
	    --stats --human-readable \
	    --temp-dir="$TEMP_DIR" \
	    "$CURRENT_ITERATION_DIR/" \
	    "$DEST_DIR"


	# Prepare mapping line
	MAPPING_LINE="$CURRENT_ITERATIONS_LABEL"$'\t'"$CURRENT_ITERATION_DIR"$'\t'"$DEST_DIR"

	# Append mapping only if it doesn't already exist
	if ! grep -Fqx "$MAPPING_LINE" "$MAPPING_FILE"; then
	    sudo bash -c "echo -e '$MAPPING_LINE' >> '$MAPPING_FILE'"
	fi

    done < "$INPUT_FILE"
) 200>"$LOCK_FILE"

# Sort the mapping file by the first column (label) and remove duplicates
sudo sort -t$'\t' -k1,1 -u "$MAPPING_FILE" -o "$MAPPING_FILE"

echo "=== Syncing directories finished at $(date) ==="
