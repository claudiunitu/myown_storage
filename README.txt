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
- Make sure you have two drives with ext4 partions
- run ``
- Edit install.sh script with your Drive A and Drive B partitions UUIDs
- `sudo ./install.sh`
- Drive B will be periodically backed up to drive B
- Copy `current_dir_to_vault.sh` script to any folder you want to be copied to vault and execute it. The folder will be copied to vault.

## How to format drives to ext4

- Make sure you unmount any drives that need to be partitioned
- List devices and their file systems by using `sudo fdisk -l`
- Identify the device name you want to partition (ex. /dev/sdb)

- Create partition table: `sudo fdisk /dev/sdX`
- Run the `g` command to create GPT partition table
- Run the `n` command to create new partition and follow the instructions
- Run the `w` command to write the canges

- Run `mkfs -t ext4 /dev/sdxN` to partition the device using ext4 partition.

- #Run `sudo e2label /dev/sda1 NEW_LABEL` to change the label when needed

- Run `sudo blkid` to view the changes


## User and file permission management

### add new user
sudo useradd myuser

### change the user id and group primary id to a more predictible one
usermod -u 2001 myuser

groupmod -g 2001 myuser

### create password for the user to be able to login
sudo passwd myuser

### add public view group
sudo groupadd publicrwx

### change the group id to a more predictible one
groupmod -g 3001 publicview

### add user to publicrwx secondary group
sudo usermod -aG publicrwx myuser

### add user to multiple secondary groups
sudo usermod -aG group1,group2,group3 myuser

### Delete a group
groupdel publicrwx

### Create a New User and Assign primary and secondary Groups in One Command
sudo useradd -g jane -G wheel,developers jane

### use ACL to set granular permissions to files / directories (ACL extends / overrides the default chmod)

#### remove chmod unnecessary permissions
sudo chmod 700 ./directories

#### use ACL to set the right permissions to directories for specific users or groups of users

setfacl -R -m u:myuser:rwx /myuserdir  

setfacl -R -d -m u:myuser:rwx /myuserdir  


setfacl -R -m g:publicrwx:rwx /publicshared

setfacl -R -d -m g:publicrwx:rwx /publicshared   


setfacl -m o::---  /mydir # restrict other

setfacl -m -d o::---  /mydir # restrict other

setfacl -m m::rwx /mydir # modify the mask to rwx since this might be initialized to --- and interfering with group permissions


------------------------------------------

### Permissions cheat sheet

Octal digit		Permission(s) granted		Symbolic

0				None						[u/g/o]-rwx

1				Execute only				[u/g/o]=x

2				Write only					[u/g/o]=w

3				Write and execute only		[u/g/o]=wx

4				Read permission only		[u/g/o]=r

5				Read and execute only		[u/g/o]=rx

6				Read and write only			[u/g/o]=rw

7				All permissions				[u/g/o]=rwx


## Set specific user permission to files and directories


### check if the mounted device supports ACL (Access Control Lists)
sudo tune2fs -l /dev/sdb1 | grep "Default mount options"


### set granular permissions for a file/directory

setfacl -d -R -m u:userA:rw /mydir  # User-specific permissions (default for newer files)
setfacl -R -m u:userA:rw /mydir  # User-specific permissions

setfacl -d -R -m g:groupA:rw myfile  # Group-specific permissions (default for newer files)
setfacl -R -m g:groupA:rw myfile  # Group-specific permissions

setfacl -d -R -m o:rx myfile # Other-specific permissions (default for newer files)
setfacl -R -m o:rx myfile # Other-specific permissions


### remove permissions set by setfacl

setfacl -R -b myfile               # This removes all ACL entries and restores the file / directory to the default chmod permissions.

setfacl -R -x u:userA myfile       # Remove ACL for userA

setfacl -R -x g:groupA myfile      # Remove ACL for groupA

setfacl -R -x o myfile             # Remove ACL for "others"





