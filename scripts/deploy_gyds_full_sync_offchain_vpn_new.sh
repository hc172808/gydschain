#!/bin/bash

# Ultimate GYDS Deployment Script (Final Version)
# Full node + multi-lite nodes + off-chain assets + Kerio VPN
# Includes automatic Go 1.22 install with local tarball check
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

echo "=== GYDS Full Deployment Script ==="

# --- 0️⃣ Install Go 1.22 if needed ---
GO_VERSION="1.22.10"
GO_TAR="go$GO_VERSION.linux-amd64.tar.gz"

NEED_INSTALL=false
if ! command -v go &>/dev/null; then
    NEED_INSTALL=true
else
    INSTALLED_VERSION=$(go version | awk '{print $3}' | cut -c3-)
    if [[ "$INSTALLED_VERSION" < "1.22" ]]; then
        NEED_INSTALL=true
    fi
fi

if [ "$NEED_INSTALL" = true ]; then
    echo "Installing Go $GO_VERSION..."
    sudo rm -rf /usr/local/go

    # Check for local tarball
    if [ -f "$GO_TAR" ]; then
        echo "Found local Go tarball: $GO_TAR"
    else
        echo "Downloading Go $GO_VERSION tarball..."
        wget https://go.dev/dl/$GO_TAR
    fi

    # Extract Go
    sudo tar -C /usr/local -xzf $GO_TAR

    # Add Go to PATH
    export PATH=$PATH:/usr/local/go/bin
    if ! grep -q "/usr/local/go/bin" ~/.bashrc; then
        echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
    fi

    echo "Go $GO_VERSION installed."
else
    echo "Go version $(go version) is sufficient."
fi

# --- 1️⃣ Install system dependencies ---
sudo apt update && sudo apt upgrade -y
sudo apt install -y git build-essential jq ufw curl unzip

# --- 2️⃣ Prepare GYDS directory ---
sudo mkdir -p $NODE_DIR
sudo chown $USER:$USER $NODE_DIR

# --- 3️⃣ Clone or update repository ---
if [ -d "$NODE_DIR/.git" ]; then
    echo "GYDS folder exists."
    read -p "Do you want to update the repository (git pull)? (y/n): " UPDATE
    if [ "$UPDATE" == "y" ]; then
        cd $NODE_DIR
        git pull
    else
        echo "Skipping git pull."
    fi
else
    echo "Cloning GYDS repository via HTTPS..."
    git clone https://github.com/hc172808/gydschain.git $NODE_DIR
fi

# --- 4️⃣ Fetch Go dependencies ---
cd $NODE_DIR
go mod tidy

# --- 5️⃣ Build node ---
cd cmd
go build -o gyds-node main.go

# --- 6️⃣ Admin wallet ---
if [ ! -f "$ADMIN_WALLET_FILE" ]; then
    ADMIN_WALLET=$(go run ../wallet/wallet.go | grep Address | awk '{print $2}')
    echo "$ADMIN_WALLET" > $ADMIN_WALLET_FILE
else
    ADMIN_WALLET=$(cat $ADMIN_WALLET_FILE)
fi
echo "Admin wallet: $ADMIN_WALLET"

# --- 7️⃣ Update off-chain assets ---
echo "Updating off-chain assets…"
if [ -d "$NODE_DIR/trustwallet_assets" ]; then
    cd $NODE_DIR/trustwallet_assets
    git pull || echo "No updates found."
else
    mkdir -p $NODE_DIR/trustwallet_assets
fi

# --- 8️⃣ Create full node config ---
mkdir -p $NODE_DIR/scripts
cat > $CONFIG_FILE <<EOL
{
  "ADMIN_WALLET": "$ADMIN_WALLET",
  "RPC_PORT": $RPC_PORT,
  "BLOCK_TIME": 120,
  "ENABLE_MINING": true,
  "MAINNET": true,
  "TRUSTED_RPC_IP": "127.0.0.1",
  "VPN_SUBNET": "10.8.0.0/24",
  "COINS": ["GYDS", "GYD"]
}
EOL

# --- 9️⃣ Full node systemd service ---
FULL_SERVICE_FILE="/etc/systemd/system/$FULL_SERVICE.service"
sudo bash -c "cat > $FULL_SERVICE_FILE" <<EOL
[Unit]
Description=GYDS Full Blockchain Node
After=network.target

[Service]
Type=simple
User=$USER
ExecStart=$NODE_DIR/cmd/gyds-node -config $CONFIG_FILE
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOL

sudo systemctl daemon-reload
sudo systemctl enable $FULL_SERVICE
sudo systemctl restart $FULL_SERVICE

sudo ufw allow $RPC_PORT/tcp
sudo ufw allow $P2P_PORT/tcp

# --- 🔟 Wait for full node RPC ---
echo "Waiting for full node to come online…"
while true; do
    STATUS=$(curl -s http://127.0.0.1:$RPC_PORT/getChain | jq '. | length' 2>/dev/null || echo "0")
    if [[ "$STATUS" != "0" ]]; then
        echo "Full node online. Chain length: $STATUS"
        break
    fi
    sleep 5
done

# --- 1️⃣1️⃣ Wait for full sync ---
echo "Waiting for full node to fully sync…"
while true; do
    CURRENT=$(curl -s http://127.0.0.1:$RPC_PORT/getChain | jq '.[-1].index' 2>/dev/null || echo "0")
    EXPECTED=$CURRENT
    if [[ "$CURRENT" -ge "$EXPECTED" ]]; then
        echo "Full node synced. Block index: $CURRENT"
        break
    fi
    echo "Syncing... current: $CURRENT expected: $EXPECTED"
    sleep 5
done

# --- 1️⃣2️⃣ Deploy lite nodes ---
echo "Deploying $NUM_LITE lite nodes…"
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
  "VPN_SUBNET": "10.8.0.0/24",
  "COINS": ["GYDS", "GYD"]
}
EOL

    LITE_SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"
    sudo bash -c "cat > $LITE_SERVICE_FILE" <<EOL
[Unit]
Description=GYDS Lite Node #$i
After=network.target

[Service]
Type=simple
User=$USER
ExecStart=$NODE_DIR/cmd/gyds-node -config $LITE_CONFIG
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOL

    sudo systemctl daemon-reload
    sudo systemctl enable $SERVICE_NAME
    sudo systemctl restart $SERVICE_NAME

    sudo ufw allow $LITE_RPC/tcp
    sudo ufw allow $LITE_P2P/tcp

    echo "Lite node $i running on RPC $LITE_RPC"
done

# --- 1️⃣3️⃣ Install Kerio VPN ---
echo "Installing Kerio VPN Client…"
KERIO_DEB="kerio-vpnclient.deb"
curl -L -o $KERIO_DEB "https://download.kerio.com/installer/kerio-vpnclient/latest/kerio-vpnclient.deb"
sudo dpkg -i $KERIO_DEB || sudo apt --fix-broken install -y

read -p "Kerio Server (IP/Domain): " VPN_HOST
read -p "Kerio Username: " VPN_USER
read -sp "Kerio Password: " VPN_PASS
echo

VPN_CONFIG="$HOME/.kerio-vpn.conf"
cat > $VPN_CONFIG <<EOL
HOST=$VPN_HOST
USER=$VPN_USER
PASS=$VPN_PASS
EOL

AUTOCONNECT="$HOME/connect_kerio_vpn.sh"
cat > $AUTOCONNECT <<EOL
#!/bin/bash
echo "$VPN_PASS" | sudo -S kerio-vpnclient --connect $VPN_HOST --user $VPN_USER --password $VPN_PASS
EOL

chmod +x $AUTOCONNECT
(crontab -l 2>/dev/null; echo "@reboot $AUTOCONNECT") | crontab -

echo "=== ✅ GYDS Deployment Complete ==="
echo "Full Node RPC: $RPC_PORT"
echo "Lite nodes RPC: $BASE_LITE_RPC+"
echo "Admin Wallet: $ADMIN_WALLET"
