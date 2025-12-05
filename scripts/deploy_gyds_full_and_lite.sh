#!/bin/bash

# Automated GYDS Full + Lite Node Deployment Script
# Usage: sudo bash deploy_gyds_full_and_lite.sh

set -e

NODE_DIR="/opt/gyds-chain"
SERVICE_FULL="gyds-full-node"
SERVICE_LITE="gyds-lite-node"
CONFIG_FILE="$NODE_DIR/scripts/config.json"
RPC_PORT=8545
P2P_PORT=30303
LITE_RPC_PORT=8546
LITE_P2P_PORT=30304

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

echo "=== 7️⃣ Generating admin wallet ==="
ADMIN_WALLET=$(go run ../wallet/wallet.go | grep Address | awk '{print $2}')
echo "Generated admin wallet: $ADMIN_WALLET"

echo "=== 8️⃣ Creating config.json ==="
cat > $CONFIG_FILE <<EOL
{
  "ADMIN_WALLET": "$ADMIN_WALLET",
  "RPC_PORT": $RPC_PORT,
  "BLOCK_TIME": 120,
  "ENABLE_MINING": true,
  "MAINNET": true,
  "TRUSTED_RPC_IP": "127.0.0.1",
  "VPN_SUBNET": "10.8.0.0/24"
}
EOL
echo "config.json created with admin wallet"

echo "=== 9️⃣ Setting up full node systemd service ==="
FULL_SERVICE_FILE="/etc/systemd/system/$SERVICE_FULL.service"
sudo bash -c "cat > $FULL_SERVICE_FILE" <<EOL
[Unit]
Description=GYDS Full Blockchain Node
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
sudo systemctl enable $SERVICE_FULL
sudo systemctl start $SERVICE_FULL

echo "=== 10️⃣ Setting up lite node systemd service ==="
LITE_CONFIG_FILE="$NODE_DIR/scripts/config_lite.json"
cat > $LITE_CONFIG_FILE <<EOL
{
  "ADMIN_WALLET": "$ADMIN_WALLET",
  "RPC_PORT": $LITE_RPC_PORT,
  "BLOCK_TIME": 0,
  "ENABLE_MINING": false,
  "MAINNET": true,
  "TRUSTED_RPC_IP": "127.0.0.1",
  "VPN_SUBNET": "10.8.0.0/24"
}
EOL

LITE_SERVICE_FILE="/etc/systemd/system/$SERVICE_LITE.service"
sudo bash -c "cat > $LITE_SERVICE_FILE" <<EOL
[Unit]
Description=GYDS Lite Blockchain Node
After=network.target

[Service]
Type=simple
User=$USER
ExecStart=$NODE_DIR/cmd/gyds-node -config $LITE_CONFIG_FILE
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOL

sudo systemctl daemon-reload
sudo systemctl enable $SERVICE_LITE
sudo systemctl start $SERVICE_LITE

echo "=== 11️⃣ Configuring firewall ==="
sudo ufw allow $RPC_PORT/tcp
sudo ufw allow $P2P_PORT/tcp
sudo ufw allow $LITE_RPC_PORT/tcp
sudo ufw allow $LITE_P2P_PORT/tcp
sudo ufw --force enable

echo "=== ✅ GYDS Full + Lite Nodes Deployment Complete! ==="
echo "Full Node Status: sudo systemctl status $SERVICE_FULL"
echo "Lite Node Status: sudo systemctl status $SERVICE_LITE"
echo "Admin Wallet: $ADMIN_WALLET"
