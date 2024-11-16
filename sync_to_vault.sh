# Configuration Section
MOUNT_POINT_A="/mnt/myown_storage_A"  # Mount point for USB Drive A (e.g., /mnt/usbA)
LOG_FILE="/var/log/myown_storage_backup.log"  # Log file for cron job logs
SYNC_TO_VAULT="/usr/local/bin/myown_storage_sync_to_vault-list.txt"


# Create the Sync to Vault script at the specified path
echo "Writing Sync to Vault list of directories $SYNC_TO_VAULT"

if [[ ! "$SYNC_TO_VAULT" ]]; then
  echo "Creating Vault Temp Dir"
  sudo tee "$SYNC_TO_VAULT" > /dev/null <<EOL
# Create a list of directories which should be synced to the vault 
# when the backup script cronjob is running 

# Each line represents a directory or file absolute path 

# Do not add a trailing slash at the end of the path as this signifies 
# that you want to transfer only the contents rather than including also the directory

# The entire path will be recreated at the destination

# /home/myuser/Documents

EOL
	sudo chmod 777 "$SYNC_TO_VAULT"
fi



# Run rsync to vault
echo "Starting sync to vault from list \$SYNC_TO_VAULT at \$(date)" >> "\$LOG_FILE"

# Create Vault Temp Dir if it Does Not Exist
if [[ ! -d "\$MOUNT_POINT_A/myown_storage_vault_temp" ]]; then
  echo "Creating Vault Temp Dir"
  sudo mkdir -p "\$MOUNT_POINT_A/myown_storage_vault_temp"
  sudo chmod 777 "\$MOUNT_POINT_A/myown_storage_vault_temp"
fi
# Create Vault Dir if it Does Not Exist
if [[ ! -d "\$MOUNT_POINT_A/myown_storage_vault" ]]; then
  echo "Creating Vault Backup Dir"
  sudo mkdir -p "\$MOUNT_POINT_A/myown_storage_vault"
  sudo chmod 777 "\$MOUNT_POINT_A/myown_storage_vault"
fi

# use flock in combination with rsync to prevent other processes to 
# interfere with the source while sync is in progress
# also wait only 600s (10 min) then exit
sudo flock -x -w 600 /var/lock/myown_storage_rsync.lock rsync -av --delete --temp-dir="\$MOUNT_POINT_A/myown_storage_vault_temp" --recursive --files-from=\$SYNC_TO_VAULT / "\$MOUNT_POINT_A/myown_storage_vault" >> "\$LOG_FILE" 2>&1

if [ \$? -ne 0 ]; then
  echo "Sync to Vault failed. Failed to acquire lock or run rsync." >> "\$LOG_FILE"
else
  echo "Sync to Vault completed successfully at \$(date)" >> "\$LOG_FILE"
