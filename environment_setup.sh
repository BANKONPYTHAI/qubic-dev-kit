#!/bin/bash

# Check if the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root."
    exit 1
fi

# Handle the qubic-cli GitHub URL argument
if [ $# -eq 0 ]; then
    echo "Warning: No qubic-cli URL provided. You should use a URL like https://github.com/qubic/qubic-cli/tree/madrid-2025."
    echo "Using default branch 'main'."
    BRANCH="main"
else
    # Extract branch name from the provided URL
    BRANCH=$(echo "$1" | sed -E 's|.*/tree/(.*)|\1|')
    if [ -z "$BRANCH" ]; then
        echo "Failed to extract branch name from $1. Please provide a valid URL like https://github.com/qubic/qubic-cli/tree/madrid-2025."
        echo "Using default branch 'main'."
        BRANCH="main"
    fi
fi

# Clone the Qubic development kit repository
git clone --recursive https://github.com/qubic/qubic-dev-kit /root/qubic

# Change to the qubic directory
cd /root/qubic

# Copy necessary scripts to core-docker directory
cp scripts/deploy.sh scripts/cleanup.sh scripts/efi_build.sh scripts/tree_vhd.sh /root/qubic/core-docker
cp -r scripts/letsencrypt core-docker/

# Rename core-docker to qubic_docker
mv core-docker qubic_docker

# Update package list and install required packages
apt update
apt install -y freerdp2-x11 git cmake docker.io libxcb-cursor0 sshpass gcc-12 g++-12 dkms build-essential linux-headers-$(uname -r) gcc make perl curl

# Create mount point
mkdir /mnt/qubic

# Check if VirtualBox is installed and its version
DESIRED_VBOX_VERSION="7.1.4"
VBOX_INSTALLED_VERSION=$(VBoxManage --version 2>/dev/null | cut -d 'r' -f 1)

if [ -n "$VBOX_INSTALLED_VERSION" ]; then
    if [ "$VBOX_INSTALLED_VERSION" == "$DESIRED_VBOX_VERSION" ]; then
        echo "VirtualBox version $DESIRED_VBOX_VERSION is already installed. Skipping installation."
    else
        echo "VirtualBox version $VBOX_INSTALLED_VERSION is installed, but version $DESIRED_VBOX_VERSION is required."
        echo "Please uninstall the current version of VirtualBox and rerun this script."
        exit 1
    fi
else
    # Download and install VirtualBox
    wget https://download.virtualbox.org/virtualbox/7.1.4/virtualbox-7.1_7.1.4-165100~Ubuntu~jammy_amd64.deb
    wget https://download.virtualbox.org/virtualbox/7.1.4/Oracle_VirtualBox_Extension_Pack-7.1.4.vbox-extpack
    dpkg -i virtualbox-7.1_7.1.4-165100~Ubuntu~jammy_amd64.deb
    apt --fix-broken install -y

    # Install VirtualBox Extension Pack with auto license acceptance
    VBoxManage extpack install Oracle_VirtualBox_Extension_Pack-7.1.4.vbox-extpack --accept-license=eb31505e56e9b4d0fbca139104da41ac6f6b98f8e78968bdf01b1f3da3c4f9ae

    # Remove VirtualBox kernel modules and reconfigure
    modprobe -r vboxnetflt vboxnetadp vboxpci vboxdrv
    /sbin/vboxconfig
fi

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/v2.26.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Build qubic-cli with the specified branch
cd /root/qubic/qubic-cli || { echo "Failed to change to qubic-cli directory"; exit 1; }
git checkout "$BRANCH" || { echo "Failed to checkout branch $BRANCH"; exit 1; }
mkdir -p build
cd build
cmake ..
make
cp qubic-cli /root/qubic/qubic_docker

# Build qlogging (no branch specification required)
cd /root/qubic/qlogging
mkdir -p build
cd build
cmake ..
make
cp qlogging /root/qubic/qubic_docker
