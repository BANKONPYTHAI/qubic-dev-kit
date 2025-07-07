#!/bin/bash

# ==============================================================================
# Qubic Development Kit Installer - Best-Practice Version (v14)
#
# This script installs the Qubic development environment.
# Changelog:
# - v14: Confirmed all warnings and prompts use the 📉 icon.
#        Adjusted the final success message to display 7 rockets.
# - v13: Introduced 📉 warning icon and repurposed ₿ for milestones.
# ==============================================================================

# --- Script Configuration ---
INSTALL_DIR="/opt/qubic"
VBOX_VERSION="7.1.4"
VBOX_BUILD="165100"
VBOX_EXTPACK_LICENSE="eb31505e56e9b4d0fbca139104da41ac6f6b98f8e78968bdf01b1f3da3c4f9ae"
DOCKER_COMPOSE_VERSION="v2.26.1"
QUBIC_REPO_URL="https://github.com/qubic/qubic-dev-kit"
VHD_URL="https://files.qubic.world/qubic-vde.zip"

# --- Colors and Icons ---
GREEN='\033[0;32m'
RED='\033[0;31m'
ORANGE='\033[0;33m'          # Bitcoin/Warning Orange
SOLANA_YELLOW='\033[1;33m'   # Solana Yellow
BLUE='\033[0;34m'
NC='\033[0m' # No Color

ICON_SUCCESS="✅"
ICON_ERROR="❌"
ICON_WARN="📉"
ICON_INFO="🧊"
ICON_BITCOIN="₿"
ICON_SOLANA="☀️"
ICON_ROCKET="🚀"

# --- Logging Functions ---
log_info() { echo -e "${BLUE}${ICON_INFO} $1${NC}"; }
log_success() { echo -e "${GREEN}${ICON_SUCCESS} $1${NC}"; }
log_warn() { echo -e "${ORANGE}${ICON_WARN} $1${NC}"; }
log_error() { echo -e "${RED}${ICON_ERROR} $1${NC}"; }
log_milestone() { echo -e "${ORANGE}${ICON_BITCOIN} $1${NC}"; }

# --- Summary Log ---
SUMMARY_LOG=()
add_to_summary() { SUMMARY_LOG+=("$1"); }

# --- Helper Functions ---
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log_error "This script must be run as root. Please use sudo."
        exit 1
    fi
    log_success "Root privileges confirmed."
    add_to_summary "Ran script with required root privileges."
}

# --- Main Logic Functions ---

function setup_environment() {
    set -euo pipefail
    trap 'cleanup_on_error' ERR
    log_info "Creating installation directory: ${INSTALL_DIR}"
    mkdir -p "${INSTALL_DIR}"
    cd "${INSTALL_DIR}"
    add_to_summary "Created installation directory at ${INSTALL_DIR}."
}

function cleanup_on_error() {
    log_error "An error occurred. Installation failed."
    log_warn "Please check the output above for details."
    exit 1
}

function install_dependencies() {
    local response
    echo -n -e "${BLUE}${ICON_INFO} Refresh package lists with 'apt-get update'? (Recommended) [Y/n]: ${NC}"
    read response

    if [[ -z "$response" || "$response" =~ ^[Yy]$ ]]; then
        log_info "Updating package lists as requested (errors will be shown)..."
        apt-get update -y >/dev/null
        log_success "Package lists updated."
        add_to_summary "Updated APT package lists."
    else
        log_warn "Skipping package list update at user's request."
        log_warn "Dependency installation may fail if local package lists are stale."
        add_to_summary "Skipped APT package list update (user choice)."
    fi

    log_info "Installing system dependencies..."
    DEPS=(
        freerdp2-x11 git cmake docker.io libxcb-cursor0 sshpass gcc-12 g++-12
        dkms build-essential linux-headers-$(uname -r) gcc make perl curl tree unzip wget
    )
    apt-get install -y "${DEPS[@]}"
    log_success "System dependencies installed."
    add_to_summary "Installed required system packages (git, docker, wget, etc.)."
}

function clone_repo() {
    if [ -d "${INSTALL_DIR}/.git" ]; then
        log_warn "Qubic repository already exists."
        log_info "Verifying and initializing submodules to ensure they are present..."
        git submodule update --init --recursive
        log_success "Submodules are up to date."
    else
        log_info "Cloning Qubic development kit and all submodules..."
        git -c 'http.https://github.com/.extraheader=' -c 'http.proxy=' clone --recursive "${QUBIC_REPO_URL}" "${INSTALL_DIR}"
        log_success "Qubic repository cloned successfully."
    fi
    add_to_summary "Ensured Qubic repository and all submodules are present."
}

function setup_virtualbox() {
    log_info "Checking VirtualBox status..."
    local installed_ver
    installed_ver=$(VBoxManage --version 2>/dev/null | cut -d'r' -f1 || echo "none")

    if [[ "${installed_ver}" == "${VBOX_VERSION}" ]]; then
        log_success "VirtualBox ${VBOX_VERSION} is already installed. Skipping."
        add_to_summary "VirtualBox ${VBOX_VERSION} was already installed."
        return
    elif [[ "${installed_ver}" != "none" ]]; then
        log_error "An unsupported version of VirtualBox (${installed_ver}) is installed."
        log_error "This script requires version ${VBOX_VERSION}."
        log_error "Please uninstall the current version and re-run the script."
        exit 1
    else
        log_milestone "Downloading VirtualBox ${VBOX_VERSION} (forcing IPv4)..."
        local vbox_deb="virtualbox-7.1_${VBOX_VERSION}-${VBOX_BUILD}~Ubuntu~jammy_amd64.deb"
        local extpack="Oracle_VirtualBox_Extension_Pack-${VBOX_VERSION}.vbox-extpack"
        local download_url="https://download.virtualbox.org/virtualbox/${VBOX_VERSION}"

        wget -4 --progress=bar:force:noscroll -O "/tmp/${vbox_deb}" "${download_url}/${vbox_deb}" 2>&1
        wget -4 --progress=bar:force:noscroll -O "/tmp/${extpack}" "${download_url}/${extpack}" 2>&1
        log_success "VirtualBox packages downloaded."

        log_info "Installing VirtualBox..."
        dpkg -i "/tmp/${vbox_deb}" || apt-get -y --fix-broken install
        log_success "VirtualBox installed."

        log_info "Installing VirtualBox Extension Pack..."
        VBoxManage extpack install --replace "/tmp/${extpack}" --accept-license="${VBOX_EXTPACK_LICENSE}"
        log_success "VirtualBox Extension Pack installed."

        log_info "Configuring VirtualBox kernel modules..."
        /sbin/vboxconfig
        log_success "VirtualBox configured."

        rm -f "/tmp/${vbox_deb}" "/tmp/${extpack}"
        add_to_summary "Installed and configured VirtualBox ${VBOX_VERSION} with Extension Pack."
    fi
}

function install_docker_compose() {
    local perform_install=true
    if command -v docker-compose &> /dev/null; then
        log_warn "Docker Compose is already installed."
        echo -n -e "${ORANGE}${ICON_WARN} Do you want to re-install/update it? (Auto-yes in 3s) [y/N]: ${NC}"
        read -t 3 response || true
        echo

        if [[ "$response" =~ ^[Nn]$ ]]; then
            perform_install=false
            log_success "Skipping Docker Compose re-installation."
            add_to_summary "Skipped Docker Compose re-installation (user choice)."
        else
            log_info "Proceeding with Docker Compose re-installation."
        fi
    fi

    if [[ "$perform_install" == true ]]; then
        log_milestone "Installing/Updating Docker Compose (forcing IPv4)..."
        curl -4 -sL "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        log_success "Docker Compose installed/updated."
        add_to_summary "Installed/Updated Docker Compose ${DOCKER_COMPOSE_VERSION}."
    fi
}

function prepare_qubic_files() {
    log_info "Preparing Qubic file structure..."
    if [ ! -d "qubic_docker" ]; then
        if [ -d "core-docker" ]; then
            log_info "First run: Renaming 'core-docker' to 'qubic_docker'..."
            mv core-docker qubic_docker
            log_success "Organized Docker-related files."
            add_to_summary "Organized Docker-related files into 'qubic_docker'."
        else
            log_error "'core-docker' submodule not found! Cannot proceed. Try re-cloning."
            exit 1
        fi
    else
        log_warn "'qubic_docker' directory already exists. Skipping rename."
        add_to_summary "Skipped Docker file organization (already complete)."
    fi

    local perform_download=true
    if [ -f "${INSTALL_DIR}/qubic.vhd" ]; then
        log_warn "File 'qubic.vhd' already exists."
        echo -n -e "${ORANGE}${ICON_WARN} Do you want to overwrite it? (Auto-yes in 3s) [y/N]: ${NC}"
        read -t 3 response || true
        echo

        if [[ "$response" =~ ^[Nn]$ ]]; then
            log_success "Skipping download. Using existing 'qubic.vhd'."
            add_to_summary "Skipped VHD download (user choice, file exists)."
            perform_download=false
        else
            log_info "Proceeding with download and overwrite."
        fi
    fi

    if [[ "$perform_download" == true ]]; then
        local vhd_zip_path="/tmp/qubic-vde.zip"
        log_milestone "Downloading Qubic VHD image (forcing IPv4)..."
        wget -4 --progress=bar:force:noscroll -O "${vhd_zip_path}" "${VHD_URL}" 2>&1
        log_success "VHD download complete."

        log_info "Verifying and extracting VHD..."
        if [ ! -f "${vhd_zip_path}" ]; then
            log_error "Download failed: ZIP file not found at ${vhd_zip_path}."
            exit 1
        fi
        unzip -o "${vhd_zip_path}" -d "${INSTALL_DIR}"
        rm "${vhd_zip_path}"
        if [ ! -f "${INSTALL_DIR}/qubic.vhd" ]; then
            log_error "Extraction failed: qubic.vhd not found after unzipping."
            log_warn "The downloaded ZIP file may be corrupt or have unexpected contents."
            exit 1
        fi
        log_success "Overwrote/Extracted qubic.vhd successfully."
        add_to_summary "Downloaded and extracted the Qubic VHD image."
    fi

    log_info "Preparing epoch files for VHD..."
    rm -rf filesForVHD
    mkdir -p filesForVHD
    unzip -o Ep152.zip -d filesForVHD/
    log_success "Epoch files (Ep152) prepared."
    add_to_summary "Prepared VHD epoch files."
}

function build_tools() {
    log_milestone "Building Qubic tools (qubic-cli, qlogging)..."
    
    pushd "${INSTALL_DIR}/qubic-cli" > /dev/null
    log_info "Building qubic-cli..."
    mkdir -p build && cd build
    cmake .. > /dev/null && make > /dev/null
    cp qubic-cli "${INSTALL_DIR}/qubic_docker/"
    cp qubic-cli "${INSTALL_DIR}/scripts/"
    popd > /dev/null
    log_success "Built 'qubic-cli'."

    pushd "${INSTALL_DIR}/qlogging" > /dev/null
    log_info "Building qlogging..."
    mkdir -p build && cd build
    cmake .. > /dev/null && make > /dev/null
    cp qlogging "${INSTALL_DIR}/qubic_docker/"
    cp qlogging "${INSTALL_DIR}/scripts/"
    popd > /dev/null
    log_success "Built 'qlogging'."
    add_to_summary "Compiled and deployed 'qubic-cli' and 'qlogging' tools."
}

function print_summary() {
    echo -e "\n\n${GREEN}===================================================${NC}"
    echo -e "${GREEN}${ICON_ROCKET}               Installation to the Moon!              ${ICON_ROCKET}${NC}"
    echo -e "${GREEN}===================================================${NC}\n"
    echo -e "${BLUE}${ICON_INFO} Summary of actions performed:${NC}"
    for item in "${SUMMARY_LOG[@]}"; do
        echo -e "  ${GREEN}▪${NC} ${item}"
    done
    echo -e "\n${ICON_SOLANA} The Qubic environment is installed in: ${SOLANA_YELLOW}${INSTALL_DIR}${NC}"
    echo -e "${ICON_INFO} You can now proceed with running the Qubic services."
    echo -e "\n${GREEN}${ICON_ROCKET} ${ICON_ROCKET} ${ICON_ROCKET} ${ICON_ROCKET} ${ICON_ROCKET} ${ICON_ROCKET} ${ICON_ROCKET}${NC}\n"
}

# --- Main Execution ---
main() {
    check_root
    setup_environment
    install_dependencies
    clone_repo
    setup_virtualbox
    install_docker_compose
    prepare_qubic_files
    build_tools
    print_summary
}

main "$@"
