#!/bin/bash

# Ultimate GYDS Full + Multi-Lite Node Deployment Script with Kerio VPN
# Usage: sudo bash deploy_gyds_all_in_one.sh <number_of_lite_nodes>

set -e

if [ -z "$1" ]; then
    echo "Usage: sudo bash $0 <number_of_lite_nodes>"
    exit 1
fi

NUM_LITE=$1
NODE_DIR="/opt/gyds-chain"
FULL_SERVICE="gyds-full-node"
ADMIN_WALLET_FILE="$NODE_DIR/admin_wallet.txt"
BASE_LITE_RPC=8546
BASE_LITE_P2P=30304
RPC_PORT=8545
P2P_PORT=30303
CONFIG_FILE="$NODE_DIR/scripts/config.json"

echo "=== 1️⃣ Updating system packages ==="
sudo apt update && sudo apt upgrade -y

echo "=== 2️⃣ Installing dependencies ==="
sudo apt install -y golang-go git build-essential jq ufw curl

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
echo "$ADMIN_WALLET" > $ADMIN_WALLET_FILE
echo "Admin wallet generated: $ADMIN_WALLET"

echo "=== 8️⃣ Creating full node config.json ==="
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

echo "=== 9️⃣ Setting up full node systemd service ==="
FULL_SERVICE_FILE="/etc/systemd/system/$FULL_SERVICE.service"
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
sudo systemctl enable $FULL_SERVICE
sudo systemctl start $FULL_SERVICE

echo "=== 🔟 Configuring firewall for full node ==="
sudo ufw allow $RPC_PORT/tcp
sudo ufw allow $P2P_PORT/tcp

echo "=== 1️⃣1️⃣ Deploying $NUM_LITE lite nodes ==="
for i in $(seq 1 $NUM_LITE); do
    LITE_RPC=$((BASE_LITE_RPC + i - 1))
    LITE_P2P=$((BASE_LITE_P2P + i - 1))
    LITE_CONFIG="$NODE_DIR/scripts/config_lite_$i.json"
    SERVICE_NAME="gyds-lite-node-$i"

    echo "Configuring Lite Node $i -> RPC: $LITE_RPC, P2P: $LITE_P2P"

    cat > $LITE_CONFIG <<EOL
{
  "ADMIN_WALLET": "$ADMIN_WALLET",
  "RPC_PORT": $LITE_RPC,
  "BLOCK_TIME": 0,
  "ENABLE_MINING": false,
  "MAINNET": true,
  "TRUSTED_RPC_IP": "127.0.0.1",
  "VPN_SUBNET": "10.8.0.0/24"
}
EOL

    LITE_SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"
    sudo bash -c "cat > $LITE_SERVICE_FILE" <<EOL
[Unit]
Description=GYDS Lite Blockchain Node #$i
After=network.target

[Service]
Type=simple
User=$USER
ExecStart=$NODE_DIR/cmd/gyds-node -config $LITE_CONFIG
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOL

    sudo systemctl daemon-reload
    sudo systemctl enable $SERVICE_NAME
    sudo systemctl start $SERVICE_NAME

    sudo ufw allow $LITE_RPC/tcp
    sudo ufw allow $LITE_P2P/tcp

    echo "Lite Node $i deployed and running!"
done

echo "=== 1️⃣2️⃣ Installing Kerio VPN Client ==="
KERIO_DEB="kerio-vpnclient.deb"
curl -L -o $KERIO_DEB "https://download.kerio.com/installer/kerio-vpnclient/latest/kerio-vpnclient.deb"
sudo dpkg -i $KERIO_DEB || sudo apt --fix-broken install -y

echo "=== 1️⃣3️⃣ Configure Kerio VPN ==="
read -p "Enter Kerio VPN Server IP or Domain: " VPN_HOST
read -p "Enter Kerio VPN Username: " VPN_USER
read -sp "Enter Kerio VPN Password: " VPN_PASS
echo

# Create Kerio VPN config (placeholder)
VPN_CONFIG="$HOME/.kerio-vpn.conf"
cat > $VPN_CONFIG <<EOL
HOST=$VPN_HOST
USER=$VPN_USER
PASS=$VPN_PASS
EOL

echo "You can now connect your node to Kerio VPN using:"
echo "sudo kerio-vpnclient --connect $VPN_CONFIG"

echo "=== ✅ GYDS Full + Multi-Lite Nodes with Kerio VPN Deployment Complete! ==="
echo "Admin Wallet: $ADMIN_WALLET"
echo "Full Node Status: sudo systemctl status $FULL_SERVICE"
echo "Lite Nodes Status: sudo systemctl status gyds-lite-node-*"
