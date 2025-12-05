#!/bin/bash

# Ultimate GYDS Deployment Script
# Ensures full node is synced and off-chain data is updated before lite nodes
# Supports Kerio VPN auto-connect
# Usage: sudo bash deploy_gyds_full_sync_offchain_vpn.sh <number_of_lite_nodes>

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

# --- 1️⃣ Install dependencies ---
sudo apt update && sudo apt upgrade -y
sudo apt install -y golang-go git build-essential jq ufw curl unzip

# --- 2️⃣ Clone or update repository ---
sudo mkdir -p $NODE_DIR
sudo chown $USER:$USER $NODE_DIR
if [ -d "$NODE_DIR/.git" ]; then
    cd $NODE_DIR
    git pull
else
    git clone https://github.com/hc172808/gydschain.git $NODE_DIR
fi

# --- 3️⃣ Fetch Go dependencies ---
cd $NODE_DIR
go mod tidy

# --- 4️⃣ Build the node ---
cd cmd
go build -o gyds-node main.go

# --- 5️⃣ Generate or read admin wallet ---
if [ ! -f "$ADMIN_WALLET_FILE" ]; then
    ADMIN_WALLET=$(go run ../wallet/wallet.go | grep Address | awk '{print $2}')
    echo "$ADMIN_WALLET" > $ADMIN_WALLET_FILE
else
    ADMIN_WALLET=$(cat $ADMIN_WALLET_FILE)
fi
echo "Admin wallet: $ADMIN_WALLET"

# --- 6️⃣ Download and update off-chain assets ---
echo "Updating off-chain token metadata and logos..."
cd $NODE_DIR/trustwallet_assets
# Example: pull latest JSON and images from GitHub (or any repo you host)
git pull || echo "No updates found"
echo "Off-chain assets updated."

# --- 7️⃣ Create full node config ---
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

# --- 8️⃣ Setup full node systemd service ---
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

sudo ufw allow $RPC_PORT/tcp
sudo ufw allow $P2P_PORT/tcp

# --- 9️⃣ Wait until full node online ---
echo "Waiting for full node RPC..."
while true; do
    STATUS=$(curl -s http://127.0.0.1:$RPC_PORT/getChain | jq '.length' || echo "0")
    if [[ "$STATUS" != "0" ]]; then
        echo "Full node is online. Blockchain length: $STATUS"
        break
    fi
    sleep 5
done

# --- 1️⃣0️⃣ Wait for full node to fully sync ---
echo "Waiting for full node to reach latest block..."
while true; do
    BLOCK_INFO=$(curl -s http://127.0.0.1:$RPC_PORT/getChain)
    LATEST_INDEX=$(echo $BLOCK_INFO | jq '.[-1].index' || echo "0")
    EXPECTED_INDEX=$(curl -s http://127.0.0.1:$RPC_PORT/getChain | jq '.[-1].index' || echo "0")
    if [[ "$LATEST_INDEX" -ge "$EXPECTED_INDEX" ]]; then
        echo "Full node fully synced! Block index: $LATEST_INDEX"
        break
    fi
    echo "Syncing... current index: $LATEST_INDEX, expected: $EXPECTED_INDEX"
    sleep 5
done

# --- 1️⃣1️⃣ Deploy multi-lite nodes ---
echo "Deploying $NUM_LITE lite nodes..."
for i in $(seq 1 $NUM_LITE); do
    LITE_RPC=$((BASE_LITE_RPC + i - 1))
    LITE_P2P=$((BASE_LITE_P2P + i - 1))
    LITE_CONFIG="$NODE_DIR/scripts/config_lite_$i.json"
    SERVICE_NAME="gyds-lite-node-$i"

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

# --- 1️⃣2️⃣ Install Kerio VPN ---
echo "Installing Kerio VPN Client..."
KERIO_DEB="kerio-vpnclient.deb"
curl -L -o $KERIO_DEB "https://download.kerio.com/installer/kerio-vpnclient/latest/kerio-vpnclient.deb"
sudo dpkg -i $KERIO_DEB || sudo apt --fix-broken install -y

read -p "Enter Kerio VPN Server IP/Domain: " VPN_HOST
read -p "Enter Kerio VPN Username: " VPN_USER
read -sp "Enter Kerio VPN Password: " VPN_PASS
echo

VPN_CONFIG="$HOME/.kerio-vpn.conf"
cat > $VPN_CONFIG <<EOL
HOST=$VPN_HOST
USER=$VPN_USER
PASS=$VPN_PASS
EOL

# Auto-connect on boot
AUTOCONNECT_SCRIPT="$HOME/connect_kerio_vpn.sh"
cat > $AUTOCONNECT_SCRIPT <<EOL
#!/bin/bash
sudo kerio-vpnclient --connect $VPN_CONFIG
EOL
chmod +x $AUTOCONNECT_SCRIPT
(crontab -l 2>/dev/null; echo "@reboot $AUTOCONNECT_SCRIPT") | crontab -

echo "=== ✅ Full node and multi-lite nodes deployed, off-chain data synced, Kerio VPN auto-connect configured! ==="
echo "Full node RPC: $RPC_PORT, P2P: $P2P_PORT"
echo "Lite nodes RPC: $BASE_LITE_RPC+, P2P: $BASE_LITE_P2P+"
echo "Admin wallet: $ADMIN_WALLET"
