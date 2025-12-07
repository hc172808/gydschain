#!/bin/bash
set -e

echo "=============================================="
echo "🚀 GYDS FULL AUTO DEPLOYMENT (Full + Lite + VPN + Security)"
echo "=============================================="

###############################################################
#                      USER INPUT
###############################################################

read -p "Enter Kerio VPN server (IP or domain): " KERIO_VPN_SERVER
read -p "Enter Kerio VPN username: " KERIO_VPN_USER
read -p "Enter Kerio VPN password: " KERIO_VPN_PASS
read -p "Enter trusted IP for RPC (e.g. 127.0.0.1): " TRUSTED_RPC_IP

echo "------------------------------------------"
echo "📧 SMTP Email Settings (for root password rotation)"
echo "------------------------------------------"
read -p "SMTP Host: " SMTP_HOST
read -p "SMTP Port (587): " SMTP_PORT
read -p "SMTP Username: " SMTP_USER
read -sp "SMTP Password: " SMTP_PASS
echo ""
read -p "Admin Email to receive passwords: " ADMIN_EMAIL


###############################################################
#                         PREPARE
###############################################################

echo "------------------------------------------"
echo "🔧 Preparing secure directory at /opt/gyds-secure/"
mkdir -p /opt/gyds-secure
chmod 700 /opt/gyds-secure

echo "📦 Writing email + rotation config..."
cat <<EOF >/opt/gyds-secure/rotation.conf
SMTP_HOST="$SMTP_HOST"
SMTP_PORT="$SMTP_PORT"
SMTP_USER="$SMTP_USER"
SMTP_PASS="$SMTP_PASS"
ADMIN_EMAIL="$ADMIN_EMAIL"
ROTATION_ENABLED="true"
EOF
chmod 600 /opt/gyds-secure/rotation.conf


###############################################################
#              SYSTEM UPDATE & REQUIRED PACKAGES
###############################################################

echo "------------------------------------------"
echo "🔄 Updating System..."
apt update -y && apt upgrade -y

echo "------------------------------------------"
echo "🔍 Checking Dependencies..."
apt install -y git jq build-essential wget curl unzip openssl msmtp


###############################################################
#                    INSTALL GO 1.18
###############################################################

echo "------------------------------------------"
echo "📦 Installing Go 1.18.10"
rm -rf /usr/local/go
wget https://go.dev/dl/go1.18.10.linux-amd64.tar.gz -O /tmp/go.tar.gz
tar -C /usr/local -xzf /tmp/go.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
export PATH=$PATH:/usr/local/go/bin

echo "✔ Go installed:"
go version


###############################################################
#                     INSTALL KERIO VPN
###############################################################

echo "------------------------------------------"
echo "🔍 Installing Kerio VPN Client..."

KERIO_URL="https://mirror.mahanserver.net/Kerio/KERIO%20PRODUCTS%20AND%20DOCUMENTATION/Kerio%20Control/9.3.4/kerio-control-vpnclient-9.3.4-3795-linux-amd64.deb"

wget -O /tmp/kerio.deb "$KERIO_URL"
dpkg -i /tmp/kerio.deb || apt --fix-broken install -y


###############################################################
#                  CREATE KERIO AUTO-LOGIN
###############################################################

echo "------------------------------------------"
echo "🔧 Configuring Kerio Autologin"

cat <<EOF >/etc/kerio-autologin.conf
SERVER="$KERIO_VPN_SERVER"
USERNAME="$KERIO_VPN_USER"
PASSWORD="$KERIO_VPN_PASS"
EOF
chmod 600 /etc/kerio-autologin.conf

cat <<EOF >/etc/systemd/system/kerio-vpn.service
[Unit]
Description=Kerio VPN Auto Connect
After=network.target

[Service]
Type=simple
ExecStart=/usr/sbin/kvpnc -s $KERIO_VPN_SERVER -u $KERIO_VPN_USER -p $KERIO_VPN_PASS
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kerio-vpn
systemctl start kerio-vpn


###############################################################
#               KERIO WATCHDOG AUTO-RECONNECT
###############################################################

echo "------------------------------------------"
echo "🔧 Creating Kerio Watchdog"

cat <<'EOF' >/usr/local/bin/kerio-watchdog.sh
#!/bin/bash
LOG="/var/log/kerio-watchdog.log"

while true; do
    if ! pgrep kvpnc >/dev/null; then
        echo "$(date) — Kerio down → restarting" >> $LOG
        systemctl restart kerio-vpn
    fi
    sleep 30
done
EOF

chmod +x /usr/local/bin/kerio-watchdog.sh

cat <<EOF >/etc/systemd/system/kerio-watchdog.service
[Unit]
Description=Kerio VPN Auto-Reconnect Watchdog
After=kerio-vpn.service

[Service]
ExecStart=/usr/local/bin/kerio-watchdog.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl enable kerio-watchdog
systemctl start kerio-watchdog


###############################################################
#                CLONE OR UPDATE GYDS CHAIN
###############################################################

echo "------------------------------------------"
echo "📦 Setting up GYDS Chain repo..."

if [ -d "/opt/gyds-chain/.git" ]; then
    cd /opt/gyds-chain
    git reset --hard
    git pull
else
    git clone https://github.com/hc172808/gydschain.git /opt/gyds-chain
fi


###############################################################
#               FIX GO VERSION IN go.mod
###############################################################

echo "------------------------------------------"
echo "✏ Updating go.mod to Go 1.18"
sed -i 's/go 1\.22/go 1.18/' /opt/gyds-chain/go.mod


###############################################################
#              SYNC TRUSTWALLET OFF-CHAIN ASSETS
###############################################################

echo "------------------------------------------"
echo "📦 Syncing TrustWallet assets..."

ASSET_DIR="/opt/gyds-chain/trustwallet_assets"
mkdir -p $ASSET_DIR

FILES=("gyds.json" "gyd.json" "gyds.png" "gyd.png")
BASE_URL="https://raw.githubusercontent.com/hc172808/gydschain/main/trustwallet_assets"

for f in "${FILES[@]}"; do
    wget -q $BASE_URL/$f -O $ASSET_DIR/$f
done


###############################################################
#                     BUILD GYDS NODE
###############################################################

echo "------------------------------------------"
echo "🔨 Building GYDS Node..."

cd /opt/gyds-chain
go mod tidy
cd cmd
go build -o gyds-node main.go


###############################################################
#                     FULL NODE SERVICE
###############################################################

cat <<EOF >/etc/systemd/system/gyds-fullnode.service
[Unit]
Description=GYDS Full Node
After=network.target kerio-vpn.service

[Service]
User=root
WorkingDirectory=/opt/gyds-chain
ExecStart=/opt/gyds-chain/cmd/gyds-node --fullnode
Restart=always
RestartSec=5
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF


###############################################################
#             SYNC GATE FOR LITE NODES
###############################################################

cat <<'EOF' >/usr/local/bin/gyds-wait-sync.sh
#!/bin/bash
RPC="http://127.0.0.1:8545"
TARGET_BLOCKS=10
while true; do
    HEIGHT=$(curl -s $RPC/getChain | jq '.length')
    if [ -n "$HEIGHT" ] && [ "$HEIGHT" -ge "$TARGET_BLOCKS" ]; then exit 0; fi
    sleep 10
done
EOF

chmod +x /usr/local/bin/gyds-wait-sync.sh


###############################################################
#                   LITE NODE TEMPLATE
###############################################################

cat <<EOF >/etc/systemd/system/gyds-litenode@.service
[Unit]
Description=GYDS Lite Node %i
After=network.target kerio-vpn.service gyds-fullnode.service

[Service]
User=root
ExecStartPre=/usr/local/bin/gyds-wait-sync.sh
WorkingDirectory=/opt/gyds-chain
ExecStart=/opt/gyds-chain/cmd/gyds-node --litenode --port=$((8600 + %i))
Restart=always
RestartSec=4
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF


###############################################################
#                     FIREWALL RULES
###############################################################

echo "------------------------------------------"
echo "🛡 Configuring firewall..."
ufw allow 1194/tcp
ufw allow 1194/udp
ufw allow from $TRUSTED_RPC_IP to any port 8545
ufw allow 8600:8700/tcp
ufw --force enable


###############################################################
#                   LOG ROTATION
###############################################################

mkdir -p /var/log/gyds

cat <<EOF >/etc/logrotate.d/gyds
/var/log/gyds/*.log {
    weekly
    rotate 8
    compress
    missingok
    notifempty
    copytruncate
}
EOF


###############################################################
#         ROOT PASSWORD ROTATION SERVICE (EVERY 4 HOURS)
###############################################################

echo "------------------------------------------"
echo "🔐 Installing Root Password Rotation System..."

cat <<'EOF' >/usr/local/bin/rootpass-rotate.sh
#!/bin/bash
CONF="/opt/gyds-secure/rotation.conf"
source $CONF

if [ "$ROTATION_ENABLED" != "true" ]; then
    exit 0
fi

NEWPASS=$(openssl rand -base64 18)

echo "root:$NEWPASS" | chpasswd

echo -e "Subject: [GYDS SERVER] NEW ROOT PASSWORD\n\nNew root password: $NEWPASS" \
 | msmtp --host=$SMTP_HOST --port=$SMTP_PORT --auth=on --user=$SMTP_USER --password=$SMTP_PASS --tls=on $ADMIN_EMAIL
EOF

chmod +x /usr/local/bin/rootpass-rotate.sh

cat <<EOF >/etc/systemd/system/rootpass-rotate.service
[Unit]
Description=Rotate Root Password & Email to Admin

[Service]
Type=oneshot
ExecStart=/usr/local/bin/rootpass-rotate.sh
EOF

cat <<EOF >/etc/systemd/system/rootpass-rotate.timer
[Unit]
Description=Run root password rotation every 4 hours

[Timer]
OnBootSec=10min
OnUnitActiveSec=4h
Unit=rootpass-rotate.service

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable rootpass-rotate.timer
systemctl start rootpass-rotate.timer


###############################################################
#               START FULL NODE
###############################################################

systemctl enable gyds-fullnode
systemctl start gyds-fullnode

sleep 4
systemctl status gyds-fullnode --no-pager


###############################################################
#                        DONE
###############################################################

echo "=============================================="
echo "🎉 GYDS FULL DEPLOYMENT COMPLETED SUCCESSFULLY"
echo "=============================================="
echo "Start lite nodes with:"
echo "systemctl enable --now gyds-litenode@1"
echo "systemctl enable --now gyds-litenode@2"
echo "systemctl enable --now gyds-litenode@3"
echo "=============================================="
