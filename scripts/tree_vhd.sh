#!/bin/bash

# Check if the VHD file path is provided as an argument
if [ -z "$1" ]; then
    echo "Usage: $0 <path_to_vhd>"
    exit 1
fi

# Define the VHD file path from the argument
VHD_FILE="$1"

# Define the mount point
MOUNT_POINT="/mnt/qubic"

# Ensure the mount point directory exists
sudo mkdir -p "$MOUNT_POINT"

# Set up a loop device for the VHD file
LOOP_DEVICE=$(sudo losetup -f --show --partscan "$VHD_FILE")
echo "VHD mounted on loop device: $LOOP_DEVICE"

# Mount the first partition of the VHD to the mount point
sudo mount "${LOOP_DEVICE}p1" "$MOUNT_POINT"

# Check if the tree command is available and list the contents
if command -v tree &> /dev/null; then
    echo "Listing directory structure with tree:"
    sudo tree "$MOUNT_POINT"
else
    echo "Error: tree command not found. Please install it (e.g., 'sudo apt install tree')."
    echo "Falling back to ls -R for directory listing:"
    sudo ls -R "$MOUNT_POINT"
fi

# Unmount the VHD partition
sudo umount "$MOUNT_POINT"

# Detach the loop device
sudo losetup -d "$LOOP_DEVICE"

echo "VHD inspection completed successfully."

