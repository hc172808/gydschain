#!/bin/bash
set -euo pipefail

# =======================================================
# LOGGING
# =======================================================
LOG_FILE="/var/log/gyds_deployment.log"
exec > >(tee -i "$LOG_FILE")
exec 2>&1

echo "==========================================================="
echo "🚀 GYDS Full Node Deployment — DYNAMIC SSL & VPN AUTO"
echo "==========================================================="

# =======================================================
# USER INPUT
# =======================================================
read -p "Enter Kerio VPN server (IP/domain): " KERIO_VPN_SERVER
read -p "Enter Kerio VPN username: " KERIO_VPN_USER
read -s -p "Enter Kerio VPN password: " KERIO_VPN_PASS
echo
read -p "Enter domain or public IP for HTTPS RPC (e.g., yourname.ddns.net or 123.45.67.89): " DOMAIN
read -p "Enter email for Let's Encrypt SSL (if using domain): " SSL_EMAIL

# =======================================================
# CONSTANTS
# =======================================================
NODE_DIR="/opt/gyds-chain"
BIN_NAME="gyds-chain"

RPC_PORT=8545
WS_PORT=8546
API_PORT=8080

BLOCK_TIME=120
CHAIN_ID=1337
TOTAL_SUPPLY=100000000000
ANNUAL_RELEASE=1000000

FOUNDER_GYDS_BALANCE=10000
FOUNDER_GYD_BALANCE=500

COINS=("GYDS" "GYD")
STABLECOIN="GYD"
PEG_CURRENCY="USD"
GYDS_START_PRICE=0.00001

SECONDS_PER_YEAR=$((365 * 24 * 60 * 60))
BLOCKS_PER_YEAR=$((SECONDS_PER_YEAR / BLOCK_TIME))
RELEASE_PER_BLOCK=$(awk "BEGIN {printf \"%.6f\", $ANNUAL_RELEASE / $BLOCKS_PER_YEAR}")

# =======================================================
# SYSTEM UPDATE & DEPENDENCIES
# =======================================================
echo "Updating system..."
sudo apt update -y && sudo apt upgrade -y
echo "Installing dependencies..."
sudo apt install -y git build-essential gcc jq curl wget ufw nginx \
    certbot python3-certbot-nginx golang-go unzip openssl

# =======================================================
# CLONE OR UPDATE REPO
# =======================================================
sudo mkdir -p "$NODE_DIR"
if [ -d "$NODE_DIR/.git" ]; then
    echo "Updating existing repo..."
    cd "$NODE_DIR"
    git reset --hard
    git pull
else
    echo "Cloning repository..."
    git clone https://github.com/hc172808/gydschain.git "$NODE_DIR"
fi
cd "$NODE_DIR"
go mod tidy

# =======================================================
# VERIFY CUSTOM BIP39
# =======================================================
if [ ! -f "$NODE_DIR/bip39/bip39.go" ]; then
    echo "❌ ERROR: Missing custom BIP39 at $NODE_DIR/bip39/bip39.go"
    exit 1
fi
echo "✅ Custom BIP39 found."

# =======================================================
# BUILD NODE
# =======================================================
cd "$NODE_DIR/cmd"
GO111MODULE=on go build -o "$BIN_NAME" .
echo "✅ Build complete: $NODE_DIR/cmd/$BIN_NAME"

# =======================================================
# WALLET GENERATION
# =======================================================
generate_wallet_value() {
    go run "$NODE_DIR/scripts/wallet_gen.go" "$1"
}

ADMIN_SEED=$(generate_wallet_value seed)
ADMIN_PRIV=$(generate_wallet_value priv)
ADMIN_ADDR=$(generate_wallet_value address)

FOUNDER_SEED=$(generate_wallet_value seed)
FOUNDER_PRIV=$(generate_wallet_value priv)
FOUNDER_ADDR=$(generate_wallet_value address)

echo "Admin wallet:   $ADMIN_ADDR"
echo "Founder wallet: $FOUNDER_ADDR"

# =======================================================
# CREATE CONFIG.JSON
# =======================================================
CONFIG_FILE="$NODE_DIR/scripts/config.json"
cat > "$CONFIG_FILE" <<EOF
{
  "ADMIN_WALLET": "$ADMIN_ADDR",
  "PRIVATE_KEY": "$ADMIN_PRIV",
  "SEED": "$ADMIN_SEED",
  "FOUNDER_WALLET": "$FOUNDER_ADDR",
  "FOUNDER_SEED": "$FOUNDER_SEED",
  "FOUNDER_PRIV": "$FOUNDER_PRIV",
  "FOUNDER_GYDS_BALANCE": $FOUNDER_GYDS_BALANCE,
  "FOUNDER_GYD_BALANCE": $FOUNDER_GYD_BALANCE,
  "RPC_PORT": $RPC_PORT,
  "WS_PORT": $WS_PORT,
  "API_PORT": $API_PORT,
  "BLOCK_TIME": $BLOCK_TIME,
  "ENABLE_MINING": true,
  "MAINNET": false,
  "TRUSTED_RPC_IP": "0.0.0.0",
  "VPN_SUBNET": "10.8.0.0/24",
  "CHAIN_ID": $CHAIN_ID,
  "COINS": ["GYDS","GYD"],
  "STABLECOIN": "$STABLECOIN",
  "PEG_CURRENCY": "$PEG_CURRENCY",
  "TOTAL_SUPPLY": $TOTAL_SUPPLY,
  "ANNUAL_RELEASE": $ANNUAL_RELEASE,
  "RELEASE_PER_BLOCK": $RELEASE_PER_BLOCK,
  "GYDS_START_PRICE": $GYDS_START_PRICE
}
EOF

# =======================================================
# AUTO-DETECT VPN IP
# =======================================================
VPN_IP=$(ip -o addr show | grep tun0 | awk '{print $4}' | cut -d/ -f1 || true)
if [ -z "$VPN_IP" ]; then
    echo "⚠️ VPN not detected. Node binds to 0.0.0.0"
    NODE_BIND_IP="0.0.0.0"
else
    echo "✅ VPN IP detected: $VPN_IP"
    NODE_BIND_IP="$VPN_IP"
fi

# =======================================================
# SYSTEMD SERVICE
# =======================================================
SERVICE_FILE="/etc/systemd/system/gyds.service"
sudo bash -c "cat > $SERVICE_FILE" <<EOF
[Unit]
Description=GYDS Blockchain Node
After=network.target

[Service]
User=root
WorkingDirectory=$NODE_DIR/cmd
ExecStart=$NODE_DIR/cmd/$BIN_NAME --config $NODE_DIR/scripts/config.json --rpcaddr $NODE_BIND_IP --wsaddr $NODE_BIND_IP
Restart=always
RestartSec=5
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable gyds.service
sudo systemctl restart gyds.service

# =======================================================
# FIREWALL RULES
# =======================================================
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow $RPC_PORT/tcp
sudo ufw allow $WS_PORT/tcp
# VPN subnet access
if [ "$NODE_BIND_IP" != "0.0.0.0" ]; then
    sudo ufw allow from 10.8.0.0/24 to any port $RPC_PORT proto tcp
    sudo ufw allow from 10.8.0.0/24 to any port $WS_PORT proto tcp
fi
sudo ufw --force enable

# =======================================================
# NGINX + SSL CONFIG
# =======================================================
NGINX_CONF="/etc/nginx/sites-available/gyds"
NGINX_ENABLED="/etc/nginx/sites-enabled/gyds"

if [[ "$DOMAIN" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "⚠️ Only IP detected. Using self-signed SSL."
    sudo openssl req -x509 -nodes -days 365 \
        -newkey rsa:2048 \
        -keyout /etc/ssl/private/gyds-selfsigned.key \
        -out /etc/ssl/certs/gyds-selfsigned.crt \
        -subj "/CN=$DOMAIN"

    sudo bash -c "cat > $NGINX_CONF" <<EOF
server {
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate /etc/ssl/certs/gyds-selfsigned.crt;
    ssl_certificate_key /etc/ssl/private/gyds-selfsigned.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {
        proxy_pass http://127.0.0.1:$RPC_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF
else
    sudo bash -c "cat > $NGINX_CONF" <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:$RPC_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF
    sudo ln -sf "$NGINX_CONF" "$NGINX_ENABLED"
    sudo nginx -t && sudo systemctl restart nginx
    sudo certbot --nginx -d "$DOMAIN" --email "$SSL_EMAIL" --agree-tos --non-interactive
fi

# =======================================================
# LOG ROTATION
# =======================================================
sudo bash -c "cat > /etc/logrotate.d/gyds" <<EOF
/var/log/gyds_deployment.log {
    weekly
    rotate 8
    compress
    missingok
}
EOF

# =======================================================
# CLEAR SENSITIVE VARIABLES
# =======================================================
KERIO_VPN_PASS=""
ADMIN_PRIV=""
FOUNDER_PRIV=""

# =======================================================
# DONE
# =======================================================
echo "==========================================================="
echo "🎉 GYDS Full Node Deployment COMPLETE"
echo "RPC URL (VPN/IP): http://$NODE_BIND_IP:$RPC_PORT"
echo "RPC URL (Domain/SSL): https://$DOMAIN"
echo "Admin Wallet:   $ADMIN_ADDR"
echo "Founder Wallet: $FOUNDER_ADDR"
echo "✅ Use MetaMask for VPN/IP access or Trust Wallet via domain + SSL."
echo "==========================================================="
