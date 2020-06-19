#/bin/bash
#---------------------------------------------------------------------
# Scriptname: backup_all_lxc.sh
# Description: Backup script for linux container with lxd
# Date: 19.06.2020
# Version: 0.1
#---------------------------------------------------------------------
echo "
  _     __   _______ 
 | |    \ \ / / ____|
 | |     \ V / |     
 | |      > <| |     
 | |____ / . \ |____ 
 |______/_/ \_\_____|
                    
"

APWD=$(pwd);

function errorAndQuit {
    echo "Exit now!"
    exit 1
}

function wait_bar () {
  for i in {1..10}
  do
    printf '= %.0s' {1..$i}
    sleep $1s
  done
}

#Edit the path to the backup directory
BACKUPDIR="/backup/data"


# ------------------------------------------------------------------------------------------
# Logging
#-------------------------------------------------------------------------------------------
#Those lines are for logging purposes
exec > >(tee -i ${APWD}/backup_lxc.log)
exec 2>&1
echo 
echo "Welcome to the backup script for lxc"
echo "========================================="
echo "Backup started..."
echo "========================================="


BACKUPDATE=$(date +"%m-%d-%y-%H-%M")
LXC=$(which lxc)
lxclist=$(lxc list --format csv -c n)

if [ ! -d $BACKUPDIR ];then
    mkdir -p $BACKUPDIR
    echo "[I] Backupdir is created"
fi
echo "[I] Start backup at $BACKUPDATE"
echo
for container in $lxclist
do
    echo "------------------------- Begin backup for $container -------------------------"

    if $LXC info $container > /dev/null 2>&1; then
        echo "[I] Container $container found, continuing.."
    else
        echo "[E] Container $container NOT found, exiting lxdbackup"
        continue
    fi

    #Create Snapshot
    echo "[I] Create snapshot"
    if $LXC snapshot $container $BACKUPDATE; then
        echo "[I] Succesfully created snaphot $BACKUPDATE on container $container"
    else
        echo "[E] Could not create snaphot $BACKUPDATE on container $container"
        errorAndQuit
    fi

    #Publish snapshot
    echo "[I] Snapshot pubplish"
    if $LXC publish --force $container/$BACKUPDATE --alias $container-backup-$BACKUPDATE; then
        echo "[I] Succesfully published an image of $container-backup-$BACKUPDATE"
    else
        echo "[E] Could not publish create image from $container-backup-$BACKUPDATE"
        errorAndQuit
    fi

    #exists backup dir with date as directoryname
    echo "[I] Create backup directory"
    if [ ! -d $BACKUPDIR/$BACKUPDATE ];then
        mkdir $BACKUPDIR/$BACKUPDATE
    fi
    #Export container as tar
    echo "[I] Create image, export as tar"
    if $LXC image export $container-backup-$BACKUPDATE $BACKUPDIR/$BACKUPDATE/$container; then
        echo "[I] Succesfully export $container-backup-$BACKUPDATE to $BACKUPDIR/$BACKUPDATE/$container"
        ls -all $BACKUPDIR/$BACKUPDATE/$container
    else
        echo "[E] Could not export $container-backup-$BACKUPDATE from container $container"
        errorAndQuit
    fi

    #delete image
    echo "[I] Clean image"
    if $LXC image delete $container-backup-$BACKUPDATE; then
        echo "[I] Succesfully delete temp image for $container"
    fi

    #delete snapshot
    echo "[I] Clean snapshot"
    if $LXC delete $container/$BACKUPDATE; then
        echo "[I] Succesfully delete temp snapshot for $container"
    fi

    #save the config file
    echo "[I] Backup config file"
    if [ -e /var/lib/lxd/containers/$container/backup.yaml ];then
        cp /var/lib/lxd/containers/$container/backup.yaml $BACKUPDIR/$BACKUPDATE/$container.yaml
        echo "[I] Backup config file success"
    fi
    echo "------------------------- backup $container end -------------------------"
done
BACKUPENDDATE=$(date +"%m-%d-%y-%H-%M")
echo "[I] Backup is done at $BACKUPENDDATE" 
