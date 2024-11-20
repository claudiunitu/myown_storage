# USB Drive Backup Automation Script

This repository contains a Bash script to automate the backup process between two USB drives. 
The script mounts the drives, configures persistent mounting, and uses `rsync` to efficiently synchronize files. 
It also sets up a cron job for periodic backups.

---

## Features

- **Automatic Drive Detection**: Identifies USB drives by UUID.
- **Mount Point Management**: Ensures drives are mounted at specified locations.
- **Persistent Mounting**: Updates `/etc/fstab` for automatic mounting on reboot.
- **Backup Automation**: Uses `rsync` for incremental backups.
- **Error Handling**: Logs errors and checks available space before backing up.
- **Cron Integration**: Automatically schedules periodic backups.

---

## Requirements

- **Linux Environment**
- **Root Privileges** (`sudo` access)
- `blkid`, `rsync`, and `flock` utilities installed

---

## Usage
- Make sure you have two drives with exfat partions
- run ``
- Edit install.sh script with your Drive A and Drive B partitions UUIDs
- `sudo ./install.sh`
- Drive B will be periodically backed up to drive B
- Copy `current_dir_to_vault.sh` script to any folder you want to be copied to vault and execute it. The folder will be copied to vault.

## How to format drives to exfat

- Make sure you unmount any drives that need to be partitioned
- List devices and their file systems by using `sudo fdisk -l`
- Identify the device name you want to partition (ex. /dev/sdb)

- Create partition table: `sudo fdisk /dev/sdX`
- Run the `g` command to create GPT partition table
- Run the `n` command to create new partition and follow the instructions
- Run the `w` command to write the canges

- Run `sudo mkfs.exfat /dev/sdX1` to partition the device using exfat partition.

- Run `sudo exfatlabel /dev/sdX1 NEW_LABEL` to change the label when needed

- Run `sudo blkid` to view the changes