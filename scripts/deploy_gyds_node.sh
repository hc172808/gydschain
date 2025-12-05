#!/bin/bash

# Full GYDS Node Deployment Script
# Usage: sudo bash deploy_gyds_node.sh

set -e

NODE_DIR="/opt/gyds-chain"
SERVICE_NAME="gyds-node"
CONFIG_FILE="$NODE_DIR/scripts/config.json"
RPC_PORT=8545
P2P_PORT=30303

echo "=== 1️⃣ Updating system packages ==="
sudo apt update && sudo apt upgrade -y

echo "=== 2️⃣ Installing dependencies ==="
sudo apt install -y golang-go git build-essential jq ufw

echo "=== 3️⃣ Creating node directory ==="
sudo mkdir -p $NODE_DIR
sudo chown $USER:$USER $NODE_DIR

echo "=== 4️⃣ Cloning or updating GYDS repository ==="
if [ -d "$NODE_DIR/.git" ]; then
    cd $NODE_DIR
    git pull
else
    git clone https://github.com/hc172808/gydschain.git $NODE_DIR
fi

echo "=== 5️⃣ Fetching Go dependencies ==="
cd $NODE_DIR
go mod tidy

echo "=== 6️⃣ Building the node ==="
cd cmd
go build -o gyds-node main.go

echo "=== 7️⃣ Checking configuration file ==="
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Config file not found. Creating default config.json..."
    cat > $CONFIG_FILE <<EOL
{
  "ADMIN_WALLET": "YOUR_ADMIN_WALLET_ADDRESS",
  "RPC_PORT": $RPC_PORT,
  "BLOCK_TIME": 120,
  "ENABLE_MINING": true,
  "MAINNET": true,
  "TRUSTED_RPC_IP": "127.0.0.1",
  "VPN_SUBNET": "10.8.0.0/24"
}
EOL
    echo "Please edit $CONFIG_FILE and replace YOUR_ADMIN_WALLET_ADDRESS"
    exit 1
fi

echo "=== 8️⃣ Setting up systemd service ==="
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"
sudo bash -c "cat > $SERVICE_FILE" <<EOL
[Unit]
Description=GYDS Blockchain Node
After=network.target

[Service]
Type=simple
User=$USER
ExecStart=$NODE_DIR/cmd/gyds-node -config $CONFIG_FILE
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOL

sudo systemctl daemon-reload
sudo systemctl enable $SERVICE_NAME
sudo systemctl start $SERVICE_NAME

echo "=== 9️⃣ Configuring firewall ==="
sudo ufw allow $RPC_PORT/tcp
sudo ufw allow $P2P_PORT/tcp
sudo ufw --force enable

echo "=== ✅ GYDS Node Deployment Complete! ==="
echo "Check node status: sudo systemctl status $SERVICE_NAME"
echo "Edit config: $CONFIG_FILE"
