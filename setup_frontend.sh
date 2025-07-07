#!/bin/bash

# ==============================================================================
# Qubic Frontend Installer & Verifier - Best-Practice Version (v19)
#
# This script installs, configures, and verifies the hm25-frontend, including
# dependencies. It provides detailed diagnostic feedback at each step.
#
# Changelog:
# - v19: Added step-by-step diagnostic verification and a final version report.
# - v18: Overrode the standard qubic-cli with the BANKONPYTHAI fork.
# ==============================================================================

# --- Script Configuration ---
INSTALL_DIR="/opt/qubic/hm25-frontend"
WEB_ROOT="/var/www/hm25"
NGINX_CONF_NAME="hm25"
FRONTEND_REPO_URL="https://github.com/icyblob/hm25-frontend"
NVM_VERSION="v0.39.1"

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
    log_info "Creating installation directory: ${INSTALL_DIR}"
    mkdir -p "${INSTALL_DIR}"
    cd "${INSTALL_DIR}"
}

function cleanup_on_error() {
    log_error "An error occurred. Installation failed."
    log_warn "Please check the output above for details."
    exit 1
}

function install_dependencies() {
    log_info "Updating package lists and installing system dependencies..."
    apt-get update >/dev/null
    apt-get install -y nginx git curl >/dev/null
    log_success "Nginx, Git, and cURL are installed."

    log_info "Verifying Nginx service status..."
    systemctl start nginx
    systemctl enable nginx
    if systemctl is-active --quiet nginx; then
        log_success "Nginx service is active."
    else
        log_error "Nginx service failed to start."
        exit 1
    fi
}

function clone_repo() {
    if [ -d "${INSTALL_DIR}/.git" ]; then
        log_warn "Frontend repository already exists. Pulling latest changes..."
        git pull
    else
        log_info "Cloning frontend repository..."
        git clone "${FRONTEND_REPO_URL}" "${INSTALL_DIR}"
    fi
    log_success "Frontend source code is up to date."
}

function setup_build_tools() {
    log_info "Setting up Node.js and PNPM environment..."
    
    export NVM_DIR="$HOME/.nvm"
    if [ ! -s "$NVM_DIR/nvm.sh" ]; then
        log_milestone "Installing NVM..."
        curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
    fi
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    log_success "NVM is configured for this session."
    
    log_milestone "Installing Node.js LTS version via NVM..."
    nvm install --lts >/dev/null
    nvm use --lts >/dev/null
    log_success "Node.js LTS is now the active version."

    export PNPM_HOME="$HOME/.local/share/pnpm"
    export PATH="$PNPM_HOME:$PATH"
    if ! command -v pnpm &> /dev/null; then
        log_milestone "Installing PNPM..."
        curl -fsSL https://get.pnpm.io/install.sh | sh - >/dev/null
    fi
    log_success "PNPM is configured and ready."
}

function build_frontend() {
    log_milestone "Building the frontend application..."
    
    # Ensure NVM and PNPM are available in this part of the script
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    export PNPM_HOME="$HOME/.local/share/pnpm"
    export PATH="$PNPM_HOME:$PATH"

    log_info "Installing project dependencies with PNPM (this may take a moment)..."
    pnpm install
    
    local host_ip
    host_ip=$(hostname -I | awk '{print $1}')
    log_info "Building with backend endpoint: http://${host_ip}"
    
    REACT_APP_HTTP_ENDPOINT="http://${host_ip}" pnpm build

    log_info "Verifying build output..."
    if [ -d "build" ] && [ -n "$(ls -A build)" ]; then
        log_success "Frontend application built successfully."
    else
        log_error "Build process failed: 'build' directory is empty or missing."
        exit 1
    fi
}

function deploy_to_nginx() {
    log_milestone "Deploying build artifacts to Nginx..."
    
    log_info "Preparing web root directory at ${WEB_ROOT}"
    mkdir -p "${WEB_ROOT}"
    
    log_info "Deploying new build files..."
    rm -rf "${WEB_ROOT:?}"/*
    mv build/* "${WEB_ROOT}/"
    
    log_info "Verifying file deployment..."
    if [ -n "$(ls -A ${WEB_ROOT})" ]; then
        log_success "Files successfully moved to ${WEB_ROOT}."
    else
        log_error "Deployment failed: Web root directory is empty."
        exit 1
    fi

    chown -R www-data:www-data "${WEB_ROOT}"
    chmod -R 755 "${WEB_ROOT}"
    log_success "File permissions set correctly."
    
    local host_ip
    host_ip=$(hostname -I | awk '{print $1}')
    
    log_info "Creating Nginx site configuration..."
    cat <<EOF > "/etc/nginx/sites-available/${NGINX_CONF_NAME}"
server {
    listen 8081;
    server_name ${host_ip};
    root ${WEB_ROOT};
    index index.html;
    location / {
        try_files \$uri \$uri/ /index.html;
    }
}
EOF
    log_success "Nginx config file created."

    ln -sf "/etc/nginx/sites-available/${NGINX_CONF_NAME}" "/etc/nginx/sites-enabled/"
    
    log_info "Testing Nginx configuration syntax..."
    if ! nginx -t; then
        log_error "Nginx configuration test failed. Please review the error messages."
        exit 1
    fi
    log_success "Nginx configuration is valid."
    
    log_info "Reloading Nginx service..."
    systemctl reload nginx
    log_success "Nginx deployment is complete."
}

function print_summary() {
    local host_ip=$(hostname -I | awk '{print $1}')
    # Source NVM one last time to get version info
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    export PNPM_HOME="$HOME/.local/share/pnpm"
    export PATH="$PNPM_HOME:$PATH"

    # Capture versions safely
    local nginx_ver=$(nginx -v 2>&1 | cut -d' ' -f3 || echo "Not Found")
    local nvm_ver=$(nvm --version 2>&1 || echo "Not Found")
    local node_ver=$(node -v 2>&1 || echo "Not Found")
    local pnpm_ver=$(pnpm -v 2>&1 || echo "Not Found")

    echo -e "\n${CYAN}=====================================================${NC}"
    echo -e "${GREEN}  ${ICON_ROCKET} Frontend Deployment Complete! ${ICON_ROCKET}  ${NC}"
    echo -e "${CYAN}=====================================================${NC}"
    echo
    echo -e "${ICON_DIAMOND} ${GREEN}Verified Component Versions:${NC}"
    echo -e "  ${ICON_CHECK} Nginx: ${YELLOW}${nginx_ver}${NC}"
    echo -e "  ${ICON_CHECK} NVM:   ${YELLOW}${nvm_ver}${NC}"
    echo -e "  ${ICON_CHECK} Node:  ${YELLOW}${node_ver}${NC}"
    echo -e "  ${ICON_CHECK} PNPM:  ${YELLOW}${pnpm_ver}${NC}"
    echo
    echo -e "${YELLOW}### ${ICON_ROCKET} YOUR FRONTEND IS LIVE ${ICON_ROCKET} ###${NC}"
    echo -e "${CYAN}  -> You can now access the application at:${NC}"
    echo -e "     ${GREEN}http://${host_ip}:8081${NC}"
    echo
}

# --- Main Execution ---
main() {
    check_root
    setup_environment
    install_dependencies
    clone_repo
    setup_build_tools
    build_frontend
    deploy_to_nginx
    print_summary
}

main "$@"
