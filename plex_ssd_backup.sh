#!/bin/bash

# variables
start_m=`date +%M`
start_s=`date +%S`
echo "Script start: $start_m:$start_s"

now=$(date +"%m_%d_%Y-%H_%M")
plex_library_dir="/mnt/disks/Plex_SSD_194051800713/plex/Library/"
backup_dir="/mnt/user/backup_share/plex"
fail_counter=0
num_backups_to_keep=3

# Stop the container
docker stop plex
echo "Stopping plex"

# wait 30 seconds
sleep 30

# Get the state of the docker
plex_running=`docker inspect -f '{{.State.Running}}' plex`
echo "Plex running: $plex_running"

# If the container is still running retry 5 times
while [ "$plex_running" = "true" ];
do
    fail_counter=$((fail_counter+1))
    docker stop plex
    echo "Stopping Plex attempt #$fail_counter"
    sleep 30
    plex_running=`docker inspect -f '{{.State.Running}}' plex`
    # Exit with an error code if the container won't stop
    # Restart plex and report a warning to the Unraid GUI
    if (($fail_counter == 5));
    then
        echo "Plex failed to stop. Restarting container and exiting"
        docker start plex
        /usr/local/emhttp/webGui/scripts/notify -i warning -s "Plex Backup failed. Failed to stop container for backup."
        exit 1
    fi
done

# Once the container is stopped, backup the Application Support directory and restart the container
# The tar command shows progress
if [ "$plex_running" = "false" ]
then
    echo "Compressing and backing up Plex"
    cd $plex_library_dir
    tar -czf - Application\ Support/ -P | pv -s $(du -sb Application\ Support/ | awk '{print $1}') | gzip > $backup_dir/plex_backup_$now.tar.gz
    echo "Starting Plex"
    docker start plex
fi

# Get the number of files in the backup directory
num_files=`ls $backup_dir/plex_backup_*.tar.gz | wc -l`
echo "Number of files in directory: $num_files"
# Get the full path of the oldest file in the directory
oldest_file=`ls -t $backup_dir/plex_backup_*.tar.gz | tail -1`
echo $oldest_file

# After the backup, if the number of files is larger than the number of backups we want to keep
# remove the oldest backup file
if (($num_files > $num_backups_to_keep));
then
    echo "Removing file: $oldest_file"
    rm $oldest_file
fi

end_m=`date +%M`
end_s=`date +%S`
echo "Script end: $end_m:$end_s"

runtime_m=$((end_m-start_m))
runtime_s=$((end_s-start_s))
echo "Script runtime: $runtime_m:$runtime_s"
# Push a notification to the Unraid GUI if the backup failed of passed
if [[ $? -eq 0 ]]; then
  /usr/local/emhttp/webGui/scripts/notify -i normal -s "Plex Backup completed in $runtime"
else
  /usr/local/emhttp/webGui/scripts/notify -i warning -s "Plex Backup failed. See log for more details."
fi
