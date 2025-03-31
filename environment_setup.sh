#!/bin/bash

# Check if the qubic-cli GitHub URL is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <qubic_cli_github_url>"
    echo "Example: $0 https://github.com/qubic/qubic-cli/tree/madrid-2025"
    exit 1
fi

# Extract branch name from the URL
BRANCH=$(echo "$1" | sed -E 's|.*/tree/(.*)|\1|')
if [ -z "$BRANCH" ]; then
    echo "Failed to extract branch name from $1"
    exit 1
fi

# Clone the Qubic development kit repository
git clone --recursive https://github.com/qubic/qubic-dev-kit /root/qubic

# Change to the qubic directory
cd /root/qubic

# Checkout the specified branch in qubic-cli
cd qubic-cli
git checkout "$BRANCH" || { echo "Failed to checkout branch $BRANCH"; exit 1; }
cd ..

# Copy necessary scripts to core-docker directory
cp scripts/deploy.sh scripts/cleanup.sh scripts/efi_build.sh scripts/tree_vhd.sh /root/qubic/core-docker
cp -r scripts/letsencrypt core-docker/

# Rename core-docker to qubic_docker
mv core-docker qubic_docker

# Update package list and install all required packages in one go
apt update
apt install -y freerdp2-x11 git cmake docker.io libxcb-cursor0 sshpass gcc-12 g++-12 dkms build-essential linux-headers-$(uname -r) gcc make perl curl

# Create mount point
mkdir /mnt/qubic

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

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/v2.26.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Build qubic-cli
cd /root/qubic/qubic-cli
mkdir -p build
cd build
cmake ..
make
cp qubic-cli /root/qubic/qubic_docker

# Build qlogging
cd /root/qubic/qlogging
mkdir -p build
cd build
cmake ..
make
cp qlogging /root/qubic/qubic_docker
