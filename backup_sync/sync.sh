#!/usr/bin/env bash
set -euo pipefail

# Path to your input file (label <tab> source_dir)

SCRIPT_DIR=$(dirname "$(realpath "$0")")
INPUT_FILE="$SCRIPT_DIR/backup_list.txt"

# Base target directory
TARGET_BASE="/mnt/myown_storage_A/myown_storage_vault/users/synced-backups"

# Temporary rsync staging directory
TEMP_DIR="/mnt/myown_storage_A/myown_storage_vault_temp"

# Lock file for flock
LOCK_FILE="/var/lock/myown_storage_rsync.lock"

# Mapping file
MAPPING_FILE="$TARGET_BASE/mapping.txt"

# Ensure mapping file exists
sudo mkdir -p "$(dirname "$MAPPING_FILE")"
sudo touch "$MAPPING_FILE"

while IFS=$'\t' read -r CURRENT_ITERATIONS_LABEL CURRENT_ITERATION_DIR; do
    # Skip empty lines or comments
    [[ -z "$CURRENT_ITERATIONS_LABEL" || "$CURRENT_ITERATION_DIR" =~ ^# ]] && continue

    # Check if source directory exists
    if [[ ! -d "$CURRENT_ITERATION_DIR" ]]; then
        echo "!!! WARNING: Source directory '$CURRENT_ITERATION_DIR' does not exist. Skipping."
        continue
    fi

    # Turn full path into safe directory name by replacing "/" with "_"
    SAFE_NAME=$(echo "$CURRENT_ITERATION_DIR" | sed 's#/#_#g; s#^_##')
    DEST_DIR="$TARGET_BASE/$CURRENT_ITERATIONS_LABEL/$SAFE_NAME"

    # Ensure destination directory exists
    sudo mkdir -p "$DEST_DIR"

    echo ">>> Syncing '$CURRENT_ITERATION_DIR' into '$DEST_DIR'..."

    sudo bash -c "
		flock -x -w 600 '$LOCK_FILE' rsync \
			--verbose \
			--times \
			--atimes \
			--open-noatime \
			--recursive \
			--delete \
			--temp-dir='$TEMP_DIR' \
			'$CURRENT_ITERATION_DIR'/ \
			'$DEST_DIR/'
		"

    # Prepare mapping line
    MAPPING_LINE="$CURRENT_ITERATIONS_LABEL"$'\t'"$CURRENT_ITERATION_DIR"$'\t'"$DEST_DIR"

    # Append mapping only if it doesn't already exist
    if ! grep -Fqx "$MAPPING_LINE" "$MAPPING_FILE"; then
        sudo bash -c "echo -e '$MAPPING_LINE' >> '$MAPPING_FILE'"
    fi

done < "$INPUT_FILE"

# Sort the mapping file by the first column (label) and remove duplicates
sudo sort -t$'\t' -k1,1 -u "$MAPPING_FILE" -o "$MAPPING_FILE"
