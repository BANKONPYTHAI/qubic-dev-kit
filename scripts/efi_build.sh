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

# Change to the build directory; exit if the directory is inaccessible
cd /root/qubic/qubic-efi-cross-build || exit 1

# Execute the build command and log output to build.log while displaying it
./run_win_build.sh -h 46.17.97.73 -u Administrator -w QubicQubic1! -g "$GITHUB" -s seeds.txt -r peers.txt -m release -o . -c config.yaml | tee /root/qubic/qubic-efi-cross-build/build.log

# Check the exit status of run_win_build.sh (PIPESTATUS[0] captures its status before tee)
if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "Build failed."
    exit 1
else
    echo "Build successful."
    echo "Build log saved to /root/qubic/qubic-efi-cross-build/build.log"
fi

