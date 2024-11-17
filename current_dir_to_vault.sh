CURRENT_DIR_PATH=$(pwd)
CURRENT_USER=$(whoami)
sudo flock -x -w 600 /var/lock/myown_storage_rsync.lock rsync -av --delete --temp-dir="/mnt/myown_storage_A/myown_storage_vault_temp" "$CURRENT_DIR_PATH" "/mnt/myown_storage_A/myown_storage_vault/users/$CURRENT_USER"
