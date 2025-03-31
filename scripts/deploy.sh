#!/bin/bash

# This script deploys a Qubic setup by preparing a virtual hard disk (VHD), starting a Docker container,
# and running additional services. It requires two arguments:
# 1. A GitHub URL to fetch the EPOCH value from the Qubic core repository.
# 2. The path to a prebuilt Qubic.efi file to use in the deployment.

# Print a startup message
echo "Starting deploy script..."

# Check if exactly two arguments are provided: GitHub URL and EFI file path
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 [github] [efi_file_path]"
    exit 1
fi

# Assign arguments to variables
GITHUB=$1
EFI_FILE=$2

# Verify that the provided EFI file exists and is accessible
if [ ! -f "$EFI_FILE" ]; then
    echo "Error: EFI file not found at $EFI_FILE"
    exit 1
fi

# Extract the branch from the GitHub URL if it contains "/tree/" (e.g., .../tree/main)
if [[ "$GITHUB" == *"/tree/"* ]]; then
    BRANCH=$(echo "$GITHUB" | sed -E 's|.*tree/(.+)/?$|\1|')
    URL="https://github.com/qubic/core/blob/$BRANCH/src/public_settings.h"
else
    URL="$GITHUB"
fi

# Fetch the EPOCH value from the specified GitHub URL by parsing the public_settings.h file
EPOCH_VALUE=$(curl -s "$URL" | grep -E '#define EPOCH [0-9]+' | sed -E 's/.*#define EPOCH ([0-9]+).*/\1/')

# Check if EPOCH_VALUE was successfully extracted
if [ -z "$EPOCH_VALUE" ]; then
    echo "Error: Failed to extract EPOCH value."
    echo "Check the file: $URL"
    exit 1
fi

echo "Detected EPOCH: $EPOCH_VALUE"

# Step 1: Prepare the Virtual Hard Disk (VHD)
echo "Mounting VHD..."
# Set up a loop device for the VHD file and display its path
LOOP_DEVICE=$(sudo losetup -f --show --partscan /root/qubic/qubic.vhd)
echo "VHD mounted on $LOOP_DEVICE"
MOUNT_POINT="/mnt/qubic"
# Mount the first partition of the VHD to the mount point
sudo mount ${LOOP_DEVICE}p1 $MOUNT_POINT

# Clean up the VHD by removing all files and directories except the 'efi/' directory
find $MOUNT_POINT -mindepth 1 -maxdepth 1 ! -name "efi" -exec sudo rm -rf {} +

# Copy new files from /root/filesForVHD/ into the VHD
sudo cp -r /root/filesForVHD/* $MOUNT_POINT/

# Rename files in the VHD that end with a number to use the current EPOCH value
for file in $MOUNT_POINT/*.*; do
    if [[ $file =~ (.*)\.[0-9]+$ ]]; then
        sudo mv "$file" "${BASH_REMATCH[1]}.$EPOCH_VALUE"
    fi
done

# Unmount the VHD and detach the loop device
cd /
sudo umount $MOUNT_POINT
sudo losetup -d $LOOP_DEVICE
echo "VHD preparation completed."

# Step 2: Start the Docker container
echo "Starting Docker container..."
# Change to the Docker directory or exit if it fails
cd /root/qubic/qubic_docker || exit 1
# Run the container with the specified parameters, including the prebuilt EFI file path
script -qc "./run.sh --epoch ${EPOCH_VALUE} --vhd /root/qubic/qubic.vhd --port 31841 --memory 116243 --cpus 14 --efi $EFI_FILE" /dev/null &

# Wait briefly to ensure the container starts
sleep 2

# Step 3: Run the broadcaster and epoch switcher scripts
echo "Waiting for the node to start up..."
sleep 2
# Change to the scripts directory or exit if it fails
cd /root/qubic/scripts/ || exit 1
# Run broadcaster.py in the foreground (assumes it completes or is intended to block briefly)
python3 broadcaster.py
# Run epoch_switcher.py in the background, redirecting output to a log file
nohup python3 epoch_switcher.py > /root/qubic/scripts/epoch_switcher.log 2>&1 &

# Step 4: Start Docker Compose services for qubic-http and qubic-nodes
cd /root/qubic/qubic_docker/ || exit 1
# Export the host IP address to a variable and save it to a .env file for Docker Compose
export HOST_IP=$(hostname -I | awk '{print $1}')
echo "HOST_IP=$HOST_IP" > .env
# Start the Docker Compose services in detached mode
docker-compose up -d

# Step 5: Run the frontend setup script
echo "Setting up the frontend..."
bash /root/qubic/setup_frontend.sh

# Wait for services to initialize
sleep 5

# Assign the host IP to a variable for display purposes
IP=$HOST_IP

# Display deployment information for the user
echo "======================================================================================================================="
echo "Deployment completed successfully."
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "RPC is available at: http://$IP/v1/tick-info"
echo "Demo App: http://$IP:8081"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "To connect to the testnet via qubic-cli, use:"
echo "_______________________"
echo "|                     |"
echo "| IP: $IP |"
echo "| Port: 31841         |"
echo "|_____________________|"
echo "Example commands:"
cd /root/qubic/scripts || exit 1
echo "./qubic-cli -nodeip $IP -nodeport 31841 -getcurrenttick"
echo "Response:"
./qubic-cli -nodeip $IP -nodeport 31841 -getcurrenttick

echo "./qubic-cli -nodeip $IP -nodeport 31841 -getbalance WEVWZOHASCHODGRVRFKZCGUDGHEDWCAZIZXWBUHZEAMNVHKZPOIZKUEHNQSJ"
echo "Response:"
./qubic-cli -nodeip $IP -nodeport 31841 -getbalance WEVWZOHASCHODGRVRFKZCGUDGHEDWCAZIZXWBUHZEAMNVHKZPOIZKUEHNQSJ
echo "======================================================================================================================="
