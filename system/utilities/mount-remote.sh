#!/bin/bash

# Default mount point
MOUNT_POINT=${1:/mnt/windows-share}

# Check if the mount point directory exists
if [ ! -d "$MOUNT_POINT" ]; then
    echo "Error: Mount point $MOUNT_POINT does not exist."
    notify-send -t 15000 "Mount Remote" "Error: Mount point $MOUNT_POINT does not exist."
    exit 1
fi

# Check if the directory is already mounted
if ! mountpoint -q "$MOUNT_POINT"; then
    echo "Mounting $MOUNT_POINT..."
    if sudo mount -a; then
        echo "Successfully mounted $MOUNT_POINT."
        notify-send -t 15000 "Mount Remote" "$MOUNT_POINT has been successfully mounted."
    else
        echo "Error: Failed to mount $MOUNT_POINT."
        notify-send -t 15000 "Mount Remote" "Error: Failed to mount $MOUNT_POINT."
        exit 1
    fi
else
    echo "$MOUNT_POINT is already mounted."
    notify-send -t 15000 "Mount Remote" "$MOUNT_POINT is already mounted."
fi

# Navigate to the directory
if cd "$MOUNT_POINT"; then
    echo "Calculating disk usage..."
    # Get disk usage and available space
    USAGE_INFO=$(du -sh "$MOUNT_POINT" | awk '{print $1}')
    AVAIL_SPACE=$(df -h "$MOUNT_POINT" | awk 'NR==2 {print $4}')
    
    # Display the results
    echo "Disk usage: $USAGE_INFO, Available space: $AVAIL_SPACE"
    notify-send -t 15000 "Disk Usage for $MOUNT_POINT" "Used: $USAGE_INFO\nAvailable: $AVAIL_SPACE"
else
    echo "Error: Failed to change directory to $MOUNT_POINT."
    notify-send -t 15000 "Mount Remote" "Error: Failed to change directory to $MOUNT_POINT."
    exit 1
fi

