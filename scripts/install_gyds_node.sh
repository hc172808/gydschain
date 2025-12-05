#!/bin/bash

# GYDS Node Installer Script
# Usage: sudo bash install_gyds_node.sh

set -e

NODE_DIR="/opt/gyds-chain"
SERVICE_NAME="gyds-node"

echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y

echo "Installing dependencies..."
sudo apt install -y golang-go jq git build-essential ufw

echo "Creating node directory..."
sudo mkdir -p $NODE_DIR
sudo chown $USER:$USER $NODE_DIR

echo "Cloning GYDS repository..."
git clone https://github.com/hc172808/gydschain.git $NODE_DIR || (cd $NODE_DIR && git pull)

echo "Fetching Go dependencies..."
cd $NODE_DIR
go mod tidy

echo "Building node..."
cd cmd
go build -o gyds-node main.go

echo "Setting up systemd service..."
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"
sudo bash -c "cat > $SERVICE_FILE" <<EOL
[Unit]
Description=GYDS Blockchain Node
After=network.target

[Service]
Type=simple
User=$USER
ExecStart=$NODE_DIR/cmd/gyds-node
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOL

echo "Reloading systemd..."
sudo systemctl daemon-reload
sudo systemctl enable $SERVICE_NAME
sudo systemctl start $SERVICE_NAME

echo "Configuring firewall..."
sudo ufw allow 8545/tcp   # RPC port
sudo ufw allow 30303/tcp  # P2P port
sudo ufw --force enable

echo "GYDS node installation complete!"
echo "Check status: sudo systemctl status $SERVICE_NAME"
