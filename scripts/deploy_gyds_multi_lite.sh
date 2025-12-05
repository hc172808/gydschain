#!/bin/bash

# Automated Multi-Lite Node Deployment Script
# Usage: sudo bash deploy_gyds_multi_lite.sh <number_of_lite_nodes>

set -e

if [ -z "$1" ]; then
    echo "Usage: sudo bash $0 <number_of_lite_nodes>"
    exit 1
fi

NUM_LITE=$1
NODE_DIR="/opt/gyds-chain"
ADMIN_WALLET_FILE="$NODE_DIR/admin_wallet.txt"
BASE_RPC_PORT=8546
BASE_P2P_PORT=30304

echo "=== 1️⃣ Reading admin wallet ==="
if [ ! -f "$ADMIN_WALLET_FILE" ]; then
    echo "Admin wallet not found. Generate it first using deploy_gyds_full_and_lite.sh"
    exit 1
fi
ADMIN_WALLET=$(cat $ADMIN_WALLET_FILE)
echo "Using admin wallet: $ADMIN_WALLET"

echo "=== 2️⃣ Deploying $NUM_LITE lite nodes ==="
for i in $(seq 1 $NUM_LITE); do
    RPC_PORT=$((BASE_RPC_PORT + i - 1))
    P2P_PORT=$((BASE_P2P_PORT + i - 1))
    CONFIG_FILE="$NODE_DIR/scripts/config_lite_$i.json"
    SERVICE_NAME="gyds-lite-node-$i"

    echo "Configuring Lite Node $i -> RPC: $RPC_PORT, P2P: $P2P_PORT"

    # Create config file
    cat > $CONFIG_FILE <<EOL
{
  "ADMIN_WALLET": "$ADMIN_WALLET",
  "RPC_PORT": $RPC_PORT,
  "BLOCK_TIME": 0,
  "ENABLE_MINING": false,
  "MAINNET": true,
  "TRUSTED_RPC_IP": "127.0.0.1",
  "VPN_SUBNET": "10.8.0.0/24"
}
EOL

    # Create systemd service
    SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"
    sudo bash -c "cat > $SERVICE_FILE" <<EOL
[Unit]
Description=GYDS Lite Blockchain Node #$i
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

    # Firewall
    sudo ufw allow $RPC_PORT/tcp
    sudo ufw allow $P2P_PORT/tcp

    echo "Lite Node $i deployed and running!"
done

echo "=== ✅ All $NUM_LITE lite nodes deployed successfully! ==="
