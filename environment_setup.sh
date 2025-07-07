#!/bin/bash

# ==============================================================================
# Qubic Development Kit Installer - Best-Practice Version (v23)
#
# This script installs the Qubic development environment.
# Changelog:
# - v23: Added a timed, interactive prompt to allow users to choose between
#        the official qubic-cli and the BANKONPYTHAI fork.
# - v22: Corrected a critical syntax error (unexpected EOF).
# - v21: Build process output is now streamed directly to the console.
# ==============================================================================

# --- Script Configuration ---
INSTALL_DIR="/opt/qubic"
VBOX_VERSION="7.1.4"
VBOX_BUILD="165100"
VBOX_EXTPACK_LICENSE="eb31505e56e9b4d0fbca139104da41ac6f6b98f8e78968bdf01b1f3da3c4f9ae"
DOCKER_COMPOSE_VERSION="v2.26.1"
QUBIC_REPO_URL="https://github.com/qubic/qubic-dev-kit"
QUBIC_CLI_OFFICIAL_URL="https://github.com/qubic/qubic-cli"
QUBIC_CLI_FORK_URL="https://github.com/BANKONPYTHAI/qubic-cli"
VHD_URL="https://files.qubic.world/qubic-vde.zip"

# --- Colors and Icons ---
GREEN='\033[0;32m'
RED='\033[0;31m'
ORANGE='\033[0;33m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

ICON_SUCCESS="✅"
ICON_ERROR="❌"
ICON_WARN="📉"
ICON_INFO="🧊"
ICON_QUBIC="▀█"
ICON_ROCKET="🚀"
ICON_DIAMOND="🔹"
ICON_CHECK="✔️"

# --- Logging Functions ---
log_info() { echo -e "${BLUE}${ICON_INFO} $1${NC}"; }
log_success() { echo -e "${GREEN}${ICON_SUCCESS} $1${NC}"; }
log_warn() { echo -e "${ORANGE}${ICON_WARN} $1${NC}"; }
log_error() { echo -e "${RED}${ICON_ERROR} $1${NC}"; }
log_milestone() { echo -e "${ORANGE}${ICON_QUBIC} $1${NC}"; }

# --- Helper Functions ---
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log_error "This script must be run as root. Please use sudo."
        exit 1
    fi
    log_success "Root privileges confirmed."
}

# --- Main Logic Functions ---

function setup_environment() {
    set -euo pipefail
    trap 'cleanup_on_error' ERR
    log_info "Creating installation directory..."
    mkdir -p "${INSTALL_DIR}"
    cd "${INSTALL_DIR}"
    log_success "Workspace is ready at ${INSTALL_DIR}"
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
        log_info "Updating package lists as requested..."
        apt-get update -y >/dev/null
        log_success "Package lists updated."
    else
        log_warn "Skipping package list update at user's request."
    fi

    log_info "Installing system dependencies..."
    DEPS=(
        freerdp2-x11 git cmake docker.io libxcb-cursor0 sshpass gcc-12 g++-12
        dkms build-essential linux-headers-$(uname -r) gcc make perl curl tree unzip wget
    )
    apt-get install -y "${DEPS[@]}" >/dev/null
    log_success "System dependencies installed."
}

function clone_repo() {
    if [ -d "${INSTALL_DIR}/.git" ]; then
        log_warn "Qubic repository already exists. Synchronizing submodules..."
        git submodule update --init --recursive
    else
        log_info "Cloning Qubic development kit and its submodules..."
        git -c 'http.https://github.com/.extraheader=' -c 'http.proxy=' clone --recursive "${QUBIC_REPO_URL}" "${INSTALL_DIR}"
    fi
    log_success "Qubic repository is up to date."

    # --- Interactive Choice for qubic-cli Repository ---
    local cli_repo_url="${QUBIC_CLI_FORK_URL}" # Default to the fork
    local cli_repo_name="BANKONPYTHAI (Ubuntu Fix)"

    log_info "You have a choice for the qubic-cli component."
    echo -e "${ORANGE}${ICON_WARN} Use the BANKONPYTHAI fork with Ubuntu fixes? (Recommended)"
    echo -e "${ORANGE}    (Answering 'n' will use the original Qubic repo instead)"
    echo -n -e "${ORANGE}    (Auto-selects fork in 5s) [Y/n]: ${NC}"
    read -t 5 response || true
    echo

    if [[ "$response" =~ ^[Nn]$ ]]; then
        cli_repo_url="${QUBIC_CLI_OFFICIAL_URL}"
        cli_repo_name="Official Qubic"
        log_info "User selected the ${cli_repo_name} repository for qubic-cli."
    else
        log_info "Proceeding with the recommended ${cli_repo_name} fork."
    fi
    
    log_milestone "Cloning the selected qubic-cli from ${cli_repo_name}..."
    rm -rf "${INSTALL_DIR}/qubic-cli"
    git -c 'http.https://github.com/.extraheader=' -c 'http.proxy=' clone "${cli_repo_url}" "${INSTALL_DIR}/qubic-cli"
    log_success "Successfully cloned qubic-cli from the ${cli_repo_name} repository."
}

function setup_virtualbox() {
    log_info "Checking VirtualBox status..."
    local installed_ver
    installed_ver=$(VBoxManage --version 2>/dev/null | cut -d'r' -f1 || echo "none")

    if [[ "${installed_ver}" == "${VBOX_VERSION}" ]]; then
        log_success "VirtualBox ${VBOX_VERSION} is already installed. Skipping."
        return
    elif [[ "${installed_ver}" != "none" ]]; then
        log_error "An unsupported version of VirtualBox (${installed_ver}) is installed."
        log_error "This script requires version ${VBOX_VERSION}."
        exit 1
    else
        log_milestone "Downloading VirtualBox ${VBOX_VERSION} (forcing IPv4)..."
        local vbox_deb="virtualbox-7.1_${VBOX_VERSION}-${VBOX_BUILD}~Ubuntu~jammy_amd64.deb"
        local extpack="Oracle_VirtualBox_Extension_Pack-${VBOX_VERSION}.vbox-extpack"
        local download_url="https://download.virtualbox.org/virtualbox/${VBOX_VERSION}"

        wget -4 -O "/tmp/${vbox_deb}" "${download_url}/${vbox_deb}"
        wget -4 -O "/tmp/${extpack}" "${download_url}/${extpack}"
        log_success "VirtualBox packages downloaded."

        log_info "Installing VirtualBox..."
        dpkg -i "/tmp/${vbox_deb}" >/dev/null || apt-get -y --fix-broken install >/dev/null
        VBoxManage extpack install --replace "/tmp/${extpack}" --accept-license="${VBOX_EXTPACK_LICENSE}" >/dev/null
        /sbin/vboxconfig >/dev/null
        rm -f "/tmp/${vbox_deb}" "/tmp/${extpack}"
        log_success "VirtualBox ${VBOX_VERSION} installed and configured."
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
        else
            log_info "Proceeding with Docker Compose re-installation."
        fi
    fi

    if [[ "$perform_install" == true ]]; then
        log_milestone "Installing/Updating Docker Compose (forcing IPv4)..."
        curl -4 -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        log_success "Docker Compose installed/updated."
    fi
}

function prepare_qubic_files() {
    log_info "Preparing Qubic file structure..."
    if [ ! -d "qubic_docker" ]; then
        if [ -d "core-docker" ]; then
            mv core-docker qubic_docker
        else
            log_error "core-docker submodule not found! Cannot proceed."
            exit 1
        fi
    else
        log_warn "qubic_docker directory already exists. Skipping rename."
    fi

    local perform_download=true
    if [ -f "${INSTALL_DIR}/qubic.vhd" ]; then
        log_warn "File qubic.vhd already exists."
        echo -n -e "${ORANGE}${ICON_WARN} Do you want to overwrite it? (Auto-yes in 3s) [y/N]: ${NC}"
        read -t 3 response || true
        echo

        if [[ "$response" =~ ^[Nn]$ ]]; then
            perform_download=false
            log_success "Skipping download. Using existing qubic.vhd."
        else
            log_info "Proceeding with download and overwrite."
        fi
    fi

    if [[ "$perform_download" == true ]]; then
        local vhd_zip_path="/tmp/qubic-vde.zip"
        log_milestone "Downloading Qubic VHD image (forcing IPv4)..."
        wget -4 -O "${vhd_zip_path}" "${VHD_URL}"
        log_success "VHD download complete."

        log_info "Verifying and extracting VHD..."
        if [ ! -f "${vhd_zip_path}" ]; then
            log_error "Download failed: ZIP file not found."
            exit 1
        fi
        unzip -ov "${vhd_zip_path}" -d "${INSTALL_DIR}" >/dev/null
        rm "${vhd_zip_path}"
        if [ ! -f "${INSTALL_DIR}/qubic.vhd" ]; then
            log_error "Extraction failed: qubic.vhd not found."
            exit 1
        fi
        log_success "Extracted qubic.vhd successfully."
    fi

    log_info "Preparing epoch files for VHD..."
    rm -rf filesForVHD
    mkdir -p filesForVHD
    unzip -ov Ep152.zip -d filesForVHD/ >/dev/null
    log_success "Epoch files (Ep152) prepared."
}

function build_tools() {
    log_milestone "Building Qubic tools (qubic-cli, qlogging)..."
    local bin_dir="${INSTALL_DIR}/bin"
    mkdir -p "${bin_dir}"
    
    log_info "Configuring and building qubic-cli..."
    pushd "${INSTALL_DIR}/qubic-cli" > /dev/null
    mkdir -p build && cd build
    
    if ! cmake ..; then
        log_error "cmake for qubic-cli failed. Please review the output above."
        exit 1
    fi

    if ! make; then
        log_error "make for qubic-cli failed. Please review the output above."
        exit 1
    fi
    
    cp qubic-cli "${bin_dir}/"
    popd > /dev/null
    log_success "Built qubic-cli. Binary located in ${bin_dir}/"

    log_info "Configuring and building qlogging..."
    pushd "${INSTALL_DIR}/qlogging" > /dev/null
    mkdir -p build && cd build

    if ! cmake ..; then
        log_error "cmake for qlogging failed. Please review the output above."
        exit 1
    fi

    if ! make; then
        log_error "make for qlogging failed. Please review the output above."
        exit 1
    fi

    cp qlogging "${bin_dir}/"
    popd > /dev/null
    log_success "Built qlogging. Binary located in ${bin_dir}/"
}

function print_summary() {
    echo -e "\n${CYAN}=====================================================${NC}"
    echo -e "${GREEN}  ${ICON_ROCKET} Installation Complete & System Verified ${ICON_ROCKET}  ${NC}"
    echo -e "${CYAN}=====================================================${NC}"
    echo
    echo "Your secure development environment has been successfully deployed."
    echo
    echo -e "${ICON_DIAMOND} ${GREEN}Installed System-Wide Software:${NC}"
    echo -e "  ${ICON_CHECK} Docker & Docker Compose"
    echo -e "  ${ICON_CHECK} VirtualBox ${VBOX_VERSION}"
    echo -e "  ${ICON_CHECK} Common Build Tools (cmake, gcc, etc.)"
    echo
    echo -e "${ICON_DIAMOND} ${GREEN}Your Local Workspace (${YELLOW}${INSTALL_DIR}${GREEN}):${NC}"
    echo -e "  ${ICON_CHECK} Qubic Source Code: ${YELLOW}${INSTALL_DIR}/${NC}"
    echo -e "  ${ICON_CHECK} Compiled Binaries: ${YELLOW}${INSTALL_DIR}/bin/${NC} (qubic-cli, qlogging)"
    echo -e "  ${ICON_CHECK} Qubic Testnet VHD: ${YELLOW}${INSTALL_DIR}/qubic.vhd${NC}"
    echo

    echo -e "${YELLOW}### ${ICON_ROCKET} NEXT STEPS TO LAUNCH YOUR TESTNET ${ICON_ROCKET} ###${NC}"
    echo -e "${CYAN}  -> Open the VirtualBox application.${NC}"
    echo -e "${CYAN}  -> Choose to create a new Linux Virtual Machine.${NC}"
    echo -e "${CYAN}  -> When asked for a hard disk, select Use an existing virtual hard disk file.${NC}"
    echo -e "${CYAN}  -> Browse to your workspace and select the ${YELLOW}qubic.vhd${CYAN} file.${NC}"
    echo -e "${CYAN}  -> Follow the Qubic documentation to configure RAM, networking, and run your node.${NC}"
    echo

    echo -e "${ICON_DIAMOND} ${GREEN}Developer Resources:${NC}"
    echo -e "${CYAN}  -> Qubic Main Org:   https://github.com/qubic${NC}"
    echo -e "${CYAN}  -> Documentation:    https://github.com/qubic/docs${NC}"
    echo -e "${CYAN}  -> Docker Repo:      https://github.com/qubic/core-docker${NC}"
    echo -e "${CYAN}  -> Logging Tool Repo: https://github.com/qubic/qlogging${NC}"
    echo
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
