#!/bin/bash
now=$(date +"%m_%d_%Y-%H_%M")
fail_counter=0

# Stop the container
docker stop plex
echo "Stopping plex\n"

# wait 30 seconds
sleep 30

# Get the state of the docker
plex_running=`docker inspect -f '{{.State.Running}}' plex`
echo "Plex running: $plex_running\n"

# If the docker is still running retry stopping it
while [ "$plex_running" = "true" ];
do
    fail_counter=$((fail_counter+1))
    docker stop plex
    echo "Stopping Plex attempt #$fail_counter"
    sleep 30
    plex_running=`docker inspect -f '{{.State.Running}}' plex`
    if (($fail_counter = 5))
    then
        echo "Plex failed to stop. Restarting container and exiting"
        docker start plex
        /usr/local/emhttp/webGui/scripts/notify -i warning -s "Plex Backup failed"
        exit 1
    fi
done

if [ "$plex_running" = "false" ]
then
    echo "Compressing and backing up Plex"
    tar -czvf /mnt/user/backup_share/plex/plex_backup_$now.tar.gz /mnt/disks/Plex_SSD_194051800713/plex/Library/Application\ Support/
    echo "Starting Plex"
    docker start plex
fi

num_files=`ls /mnt/user/backup_share/plex/plex_backup_*.tar.gz | wc -l`
echo "Number of files in directory: $num_files"
oldest_file=`ls -t /mnt/user/backup_share/plex/plex_backup_*.tar.gz | tail -1`
echo $oldest_file

if (($num_files > 2));
then
    echo "Removing file: $oldest_file"
    rm $oldest_file
fi

if [[ $? -eq 0 ]]; then
  /usr/local/emhttp/webGui/scripts/notify -i normal -s "Plex Backup completed"
else
  /usr/local/emhttp/webGui/scripts/notify -i warning -s "Plex Backup failed"
fi
