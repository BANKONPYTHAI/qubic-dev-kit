#!/bin/bash

# Check if the GitHub repository or branch is provided as an argument
if [ -z "$1" ]; then
    echo "Usage: $0 <github_repository_or_branch>"
    exit 1
fi

# Assign the first argument to the GITHUB variable
GITHUB=$1

# Inform the user that the compilation is starting
echo "Compiling Qubic.efi..."

# Check if the build directory exists; if not, clone the repository
if [ ! -d "/root/qubic/qubic-efi-cross-build" ]; then
    echo "Directory /root/qubic/qubic-efi-cross-build does not exist. Cloning repository..."
    sudo git clone https://github.com/icyblob/qubic-efi-cross-build.git /root/qubic/qubic-efi-cross-build
fi

# Change to the build directory; exit if the directory is inaccessible
cd /root/qubic/qubic-efi-cross-build || exit 1

# Extract branch from GitHub URL if it's a tree URL
if [[ "$GITHUB" == *"/tree/"* ]]; then
    BRANCH=$(echo "$GITHUB" | sed -E 's|.*tree/(.+)/?$|\1|')
    URL="https://github.com/qubic/core/blob/$BRANCH/src/public_settings.h"
else
    URL="$GITHUB"
fi

# Fetch the public_settings.h file content from the constructed URL
FILE_CONTENT=$(curl -s "$URL")

# Extract EPOCH value from the fetched content
EPOCH_VALUE=$(echo "$FILE_CONTENT" | grep -E '#define EPOCH [0-9]+' | sed -E 's/.*#define EPOCH ([0-9]+).*/\1/')

# Extract TICK value (assuming it's defined similarly in public_settings.h)
TICK_VALUE=$(echo "$FILE_CONTENT" | grep -E '#define TICK [0-9]+' | sed -E 's/.*#define TICK ([0-9]+).*/\1/')

# Check if both EPOCH and TICK values were successfully extracted
if [ -z "$EPOCH_VALUE" ] || [ -z "$TICK_VALUE" ]; then
    echo "Error: Failed to extract EPOCH or TICK value from $URL"
    exit 1
fi

# Display the detected values
echo "Detected EPOCH: $EPOCH_VALUE"
echo "Detected TICK: $TICK_VALUE"

# Modify config.yaml with the extracted EPOCH and TICK values
sudo sed -i "/^ *EPOCH: /s/[0-9]\+/$EPOCH_VALUE/" config.yaml
sudo sed -i "/^ *TICK: /s/[0-9]\+/$TICK_VALUE/" config.yaml

# Ensure run_win_build.sh is executable
sudo chmod +x run_win_build.sh

# Execute the build command and log output to build.log while displaying it
sudo ./run_win_build.sh -h 46.17.97.73 -u Administrator -w QubicQubic1! -g "$GITHUB" -s seeds.txt -r peers.txt -m release -o . -c config.yaml | sudo tee /root/qubic/qubic-efi-cross-build/build.log

# Check the exit status of run_win_build.sh (PIPESTATUS[0] captures its status before tee)
if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "Build failed."
    exit 1
else
    echo "Build successful."
    echo "Build log saved to /root/qubic/qubic-efi-cross-build/build.log"
fi
