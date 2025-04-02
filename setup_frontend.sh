#!/bin/bash

# Update package list and install required packages
sudo apt update
sudo apt install -y nginx git curl

# Start and enable Nginx
sudo systemctl start nginx
sudo systemctl enable nginx

# Clone the frontend repository to a specific directory
sudo git clone https://github.com/icyblob/hm25-frontend /root/qubic/hm25-frontend
cd /root/qubic/hm25-frontend

# Install NVM (Node Version Manager)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
source ~/.bashrc

# Install the LTS version of Node.js
nvm install --lts
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Install PNPM (a package manager)
curl -fsSL https://get.pnpm.io/install.sh | sh -
source ~/.bashrc
export PNPM_HOME="/root/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"

# Verify PNPM installation
pnpm -v

# Install project dependencies
rm -rf node_modules
pnpm install

# Get the host's IP address dynamically
HOST_IP=$(hostname -I | awk '{print $1}')

# Build the frontend with the host's IP as the HTTP endpoint
REACT_APP_HTTP_ENDPOINT="http://$HOST_IP" pnpm build

# Create directory for web content and move build files
sudo mkdir -p /var/www/hm25
sudo mv build/* /var/www/hm25/
sudo cp -r /root/qubic/hm25-frontend/build/* /var/www/hm25/

# Set ownership and permissions for Nginx
sudo chown -R www-data:www-data /var/www/hm25
sudo chmod -R 755 /var/www/hm25

# Create Nginx configuration file with the host's IP
sudo bash -c "cat > /etc/nginx/sites-available/hm25" <<EOF
server {
    listen 8081;
    server_name $HOST_IP;

    root /var/www/hm25;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }
}
EOF

# Remove default Nginx site and enable the new configuration
sudo rm -f /etc/nginx/sites-enabled/default
[ -L /etc/nginx/sites-enabled/hm25 ] && sudo rm /etc/nginx/sites-enabled/hm25  # Remove existing link
sudo ln -s /etc/nginx/sites-available/hm25 /etc/nginx/sites-enabled/

# Test and reload Nginx configuration
sudo nginx -t
sudo systemctl reload nginx

# Ensure Nginx is running and enabled
sudo systemctl start nginx
sudo systemctl enable nginx
