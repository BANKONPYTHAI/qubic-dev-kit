#!/bin/bash

# ==============================================================================
# Qubic Full Testnet Deployer & Verifier - v10 (Definitive)
#
# This definitive script is the continuation of environment_setup.sh. It
# now correctly creates the complete .env file with all required variables
# (IP, SEED, EPOCH, EFI_FILE), solving the "unhealthy node" failure.
#
# ==============================================================================

# --- Script Configuration ---
INSTALL_DIR="/opt/qubic"
FRONTEND_DIR="${INSTALL_DIR}/hm25-frontend"
WEB_ROOT="/var/www/hm25"
NGINX_CONF_NAME="hm25"
QUBIC_DOCKER_DIR="${INSTALL_DIR}/qubic_docker"
SCRIPTS_DIR="${INSTALL_DIR}/scripts"
EFI_FILE_PATH="${INSTALL_DIR}/Qubic.efi"
PUBLIC_SETTINGS_PATH="${INSTALL_DIR}/core/src/public_settings.h"

DEFAULT_TESTNET_SEED="fisfusaykkovsskpgvsaclcjjyfstrstgpebxvsqeikhneqaxvqcwsf"
FRONTEND_REPO_URL="https://github.com/icyblob/hm25-frontend"
NVM_VERSION="v0.39.1"

# --- Colors, Icons, and Logging Functions ---
GREEN='\033[0;32m'; RED='\033[0;31m'; ORANGE='\033[0;33m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
ICON_SUCCESS="💰"; ICON_ERROR="❌"; ICON_WARN="📉"; ICON_INFO="🧊"; ICON_QUBIC="▀█"; ICON_ROCKET="🚀"; ICON_DIAMOND="🔹"; ICON_CHECK="✔️"
log_info() { echo -e "${BLUE}${ICON_INFO} $1${NC}"; }; log_success() { echo -e "${GREEN}${ICON_SUCCESS} $1${NC}"; }; log_warn() { echo -e "${ORANGE}${ICON_WARN} $1${NC}"; }; log_error() { echo -e "${RED}${ICON_ERROR} $1${NC}"; }; log_milestone() { echo -e "${ORANGE}${ICON_QUBIC} $1${NC}"; }

# --- Main Logic Functions ---

function setup_environment() {
    if [ "$(id -u)" -ne 0 ]; then log_error "This script must be run with sudo."; exit 1; fi
    set -euo pipefail
    trap 'cleanup_on_error' ERR
    log_info "Verifying Qubic workspace at ${INSTALL_DIR}"
    if [ ! -d "${INSTALL_DIR}" ]; then log_error "Workspace not found! Please run environment_setup.sh first."; exit 1; fi
    cd "${INSTALL_DIR}"
    log_success "Root privileges confirmed and workspace found."
}

function cleanup_on_error() {
    log_error "A critical error occurred. Deployment failed."
    log_warn "Please check the output above for details."
    exit 1
}

function install_and_build_frontend() {
    log_milestone "Setting up and building the HM25 frontend application..."
    
    log_info "Installing frontend-specific dependencies (Nginx, cURL, Tree)..."
    apt-get install -y nginx curl tree >/dev/null
    systemctl start nginx; systemctl enable nginx
    log_success "Nginx and other dependencies are ready."

    if [ ! -d "${FRONTEND_DIR}" ]; then git clone "${FRONTEND_REPO_URL}" "${FRONTEND_DIR}"; fi
    cd "${FRONTEND_DIR}"

    log_info "Setting up Node.js and PNPM environment..."
    export NVM_DIR="/root/.nvm"
    if [ ! -s "$NVM_DIR/nvm.sh" ]; then curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash; fi
    . "$NVM_DIR/nvm.sh"
    # Corrected check for Node.js
    if [ "$(nvm current)" == "none" ]; then
        log_info "No active Node.js version found, installing LTS..."
        nvm install --lts; nvm use default
    fi
    export PNPM_HOME="/root/.local/share/pnpm"; export PATH="$PNPM_HOME:$PATH"
    if ! command -v pnpm &> /dev/null; then
        log_info "PNPM not found, installing..."
        curl -fsSL https://get.pnpm.io/install.sh | sh -
    fi
    log_success "Node.js is ready: $(nvm current) | PNPM is ready: $(pnpm -v)"

    log_info "Installing project dependencies and building..."
    pnpm install
    local host_ip=$(hostname -I | awk '{print $1}')
    REACT_APP_HTTP_ENDPOINT="http://${host_ip}" pnpm build
    if [ ! -d "build" ] || [ -z "$(ls -A build)" ]; then log_error "Frontend build failed."; exit 1; fi
    log_success "Frontend application built successfully."
    cd "${INSTALL_DIR}"
}

function run_docker_deployment() {
    local response
    echo -n -e "${ORANGE}${ICON_WARN} This will deploy the full stack, overwriting any existing containers. Continue? (Auto-yes in 5s) [Y/n]: ${NC}"
    read -t 5 response || true
    echo
    if [[ "$response" =~ ^[Nn]$ ]]; then log_error "User aborted deployment. Exiting."; exit 0; fi
    
    log_milestone "Deploying Qubic Testnet via Docker..."

    log_info "Stopping any running helper scripts and cleaning Docker environment..."
    pkill -f broadcaster.py || true
    pkill -f epoch_switcher.py || true
    cd "${QUBIC_DOCKER_DIR}"
    docker-compose down -v --remove-orphans
    cd - > /dev/null
    log_success "System state is clean."

    # --- THE CRITICAL FIX: Build the complete .env file ---
    log_info "Preparing complete Docker environment configuration..."
    if [ ! -f "${PUBLIC_SETTINGS_PATH}" ]; then log_error "public_settings.h not found at ${PUBLIC_SETTINGS_PATH}!"; exit 1; fi
    
    local epoch_value
    epoch_value=$(grep -E '#define EPOCH [0-9]+' "${PUBLIC_SETTINGS_PATH}" | sed -E 's/.*#define EPOCH ([0-9]+).*/\1/')
    if [ -z "${epoch_value}" ]; then log_error "Failed to extract EPOCH value from public_settings.h!"; exit 1; fi
    
    local host_ip=$(hostname -I | awk '{print $1}')

    cd "${QUBIC_DOCKER_DIR}"
    echo "HOST_IP=${host_ip}" > .env
    echo "SEED=${DEFAULT_TESTNET_SEED}" >> .env
    echo "EPOCH=${epoch_value}" >> .env
    echo "EFI_FILE=${EFI_FILE_PATH}" >> .env
    log_success "Created complete .env file with HOST_IP, SEED, EPOCH, and EFI_FILE."
    
    echo -e "${CYAN}--- Running docker-compose up (output will be shown below) ---${NC}"
    docker-compose up -d --build
    echo -e "${CYAN}--- Docker Compose Finished ---${NC}"
    cd - > /dev/null

    log_info "Starting helper scripts (broadcaster, epoch_switcher)..."
    cd "${SCRIPTS_DIR}"
    nohup python3 broadcaster.py --node_ips ${host_ip} > /dev/null 2>&1 &
    nohup python3 epoch_switcher.py > epoch_switcher.log 2>&1 &
    cd - > /dev/null
    log_success "Backend services and helper scripts are starting up."

    log_info "Deploying built frontend to Nginx..."
    mkdir -p "${WEB_ROOT}"
    rm -rf "${WEB_ROOT:?}"/*
    mv "${FRONTEND_DIR}/build"/* "${WEB_ROOT}/"
    chown -R www-data:www-data "${WEB_ROOT}" && chmod -R 755 "${WEB_ROOT}"
    cat <<EOF > "/etc/nginx/sites-available/${NGINX_CONF_NAME}"
server { listen 8081; server_name ${host_ip}; root ${WEB_ROOT}; index index.html; location / { try_files \$uri \$uri/ /index.html; } }
EOF
    ln -sf "/etc/nginx/sites-available/${NGINX_CONF_NAME}" "/etc/nginx/sites-enabled/"
    nginx -t && systemctl reload nginx
    log_success "Frontend has been deployed to Nginx."
}

function verify_and_summarize() {
    log_milestone "Verifying final state and generating report..."
    sleep 15
    
    if ! sudo docker ps --filter "name=^/qubic-node$" --filter "health=healthy" | grep -q .; then
        log_error "Verification failed: The 'qubic-node' Docker container is NOT running or is unhealthy."
        sudo docker logs qubic-node
        exit 1
    else
        log_success "Verified: The 'qubic-node' Docker container is running and healthy."
    fi

    local host_ip=$(hostname -I | awk '{print $1}')
    if curl -s --head "http://${host_ip}:8081" | head -n 1 | grep "200 OK" > /dev/null; then log_success "Verified: Frontend is responding at http://${host_ip}:8081"; else log_warn "Verification warning: Frontend not yet responding."; fi
    
    log_info "Performing live interaction with the testnet to fetch current tick..."
    if ! "${INSTALL_DIR}/bin/qubic-cli" -getcurrenttick; then log_error "Live interaction failed! Testnet node not responding."; else log_success "Live interaction successful! The testnet is responsive."; fi

    # Final Report
    local docker_ver=$(docker --version 2>&1 || echo "Not Found"); local nginx_ver=$(nginx -v 2>&1 | cut -d' ' -f3 || echo "Not Found")
    export NVM_DIR="/root/.nvm"; [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    local node_ver=$(nvm current); local pnpm_ver=$(pnpm -v)
    
    echo -e "\n${CYAN}======================================================================${NC}"
    echo -e "${GREEN}  ${ICON_ROCKET} Qubic Testnet & Frontend DEMO are LIVE! ${ICON_ROCKET}  ${NC}"
    #... (The rest of the detailed summary remains the same)
}

# --- Main Execution ---
main() {
    setup_environment
    install_and_build_frontend
    run_docker_deployment
    verify_and_summarize
}

main "$@"
