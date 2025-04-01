#!/bin/bash

# This script deploys a Qubic setup by first cleaning up existing processes and containers,
# then preparing a virtual hard disk (VHD), starting a Docker container, and running additional services.
# It requires one argument:
# 1. The path to a prebuilt Qubic.efi file to use in the deployment.
# Optionally, a second argument '--no-frontend' can be provided to skip the frontend setup.

# Print a startup message
echo "Starting deploy script..."

# Check the number of arguments
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    echo "Usage: $0 [efi_file_path] [--no-frontend]"
    exit 1
fi

# Assign arguments to variables
EFI_FILE=$1
SKIP_FRONTEND=false

# Check if the second argument is '--no-frontend'
if [ "$#" -eq 2 ] && [ "$2" == "--no-frontend" ]; then
    SKIP_FRONTEND=true
fi

# Verify that the provided EFI file exists and is accessible
if [ ! -f "$EFI_FILE" ]; then
    echo "Error: EFI file not found at $EFI_FILE"
    exit 1
fi

# Cleanup: Step 1 - Kill the broadcaster.py process
echo "Killing broadcaster.py process..."
pkill -f broadcaster.py
[ $? -eq 0 ] && echo "broadcaster.py process killed successfully." || echo "Failed to kill broadcaster.py process or it was not running."

# Cleanup: Step 2 - Stop the Docker container running the qubic-docker image
echo "Finding and stopping the Docker container with image qubic-docker..."
CONTAINER_ID=$(docker ps --filter "ancestor=qubic-docker" -q)
if [ -z "$CONTAINER_ID" ]; then
    echo "No running container found with image qubic-docker."
else
    echo "Stopping container with ID: $CONTAINER_ID"
    docker stop "$CONTAINER_ID" && echo "Container $CONTAINER_ID stopped successfully." || echo "Failed to stop container $CONTAINER_ID."
fi

# Cleanup: Step 3 - Kill the epoch_switcher.py process
echo "Killing epoch_switcher.py process..."
pkill -f epoch_switcher.py
[ $? -eq 0 ] && echo "epoch_switcher.py process killed successfully." || echo "Failed to kill epoch_switcher.py process or it was not running."

# Cleanup: Step 4 - Run docker-compose down in /root/qubic/qubic-docker/
echo "Running docker-compose down in /root/qubic/qubic-docker/..."
if cd /root/qubic/qubic_docker/; then
    docker-compose down && echo "docker-compose down executed successfully." || echo "Failed to execute docker-compose down."
    cd - >/dev/null  # Return to previous directory silently
else
    echo "Directory /root/qubic/qubic-docker/ does not exist. Skipping docker-compose down."
fi

# Determine the path to public_settings.h in the core submodule
SCRIPT_DIR=$(dirname "$0")
PUBLIC_SETTINGS_FILE="$SCRIPT_DIR/../core/src/public_settings.h"

# **Check if the public_settings.h file exists**
if [ ! -f "$PUBLIC_SETTINGS_FILE" ]; then
    echo "Error: public_settings.h not found at $PUBLIC_SETTINGS_FILE"
    exit 1
fi

# Extract the EPOCH value from the local public_settings.h file
EPOCH_VALUE=$(grep -E '#define EPOCH [0-9]+' "$PUBLIC_SETTINGS_FILE" | sed -E 's/.*#define EPOCH ([0-9]+).*/\1/')

# Check if EPOCH_VALUE was successfully extracted
if [ -z "$EPOCH_VALUE" ]; then
    echo "Error: Failed to extract EPOCH value from $PUBLIC_SETTINGS_FILE"
    exit 1
fi

echo "Detected EPOCH: $EPOCH_VALUE"

# Step 1: Prepare the Virtual Hard Disk (VHD)
echo "Mounting VHD..."
LOOP_DEVICE=$(sudo losetup -f --show --partscan /root/qubic/qubic.vhd)
echo "VHD mounted on $LOOP_DEVICE"
MOUNT_POINT="/mnt/qubic"
sudo mount ${LOOP_DEVICE}p1 $MOUNT_POINT

# Clean up the VHD by removing all files and directories except the 'efi/' directory and 'spectrum.*' files
find $MOUNT_POINT -mindepth 1 -maxdepth 1 ! -name "efi" ! -name "spectrum.*" -exec sudo rm -rf {} +

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
cd /root/qubic/qubic_docker || exit 1
script -qc "./run.sh --epoch ${EPOCH_VALUE} --vhd /root/qubic/qubic.vhd --port 31841 --memory 116243 --cpus 14 --efi $EFI_FILE" /dev/null &

# Wait briefly to ensure the container starts
sleep 2

# Step 3: Run the broadcaster and epoch switcher scripts
echo "Waiting for the node to start up..."
sleep 2
cd /root/qubic/scripts/ || exit 1
python3 broadcaster.py
nohup python3 epoch_switcher.py > /root/qubic/scripts/epoch_switcher.log 2>&1 &

# Step 4: Start Docker Compose services for qubic-http and qubic-nodes
cd /root/qubic/qubic_docker/ || exit 1
export HOST_IP=$(hostname -I | awk '{print $1}')
echo "HOST_IP=$HOST_IP" > .env
docker-compose up -d

# Step 5: Handle frontend setup based on the flag
if [ "$SKIP_FRONTEND" = false ]; then
    echo "WARNING: This script will launch the HM25 frontend demo."
    echo "Make sure the core submodule at $SCRIPT_DIR/../core is checked out to the correct commit that contains your designated smart contract (SC)."
    echo "If you want to run your own frontend corresponding to your SC, modify this script accordingly."
    echo "The HM25 frontend demo works with the SC HM25 in the core submodule."
    echo ""
    echo "Setting up the frontend..."
    bash /root/qubic/setup_frontend.sh
else
    echo "Skipping frontend setup as per the '--no-frontend' flag."
fi

# Wait for services to initialize
sleep 5

# Assign the host IP to a variable for display purposes
IP=$HOST_IP

# Display deployment information for the user
echo "======================================================================================================================="
echo "Deployment completed successfully."
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "RPC is available at: http://$IP/v1/tick-info"
if [ "$SKIP_FRONTEND" = false ]; then
    echo "Demo App: http://$IP:8081"
fi
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
