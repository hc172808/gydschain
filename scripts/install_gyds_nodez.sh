#!/bin/bash
################################################################################
# GYDS Node Installer (Full Node + Optional Lite Nodes)
# Filename: install_gyds_node.sh
# Mode:
#   Default → Full Node
#   Lite Nodes → ./install_gyds_node.sh --lite <count>
#
# Requirements:
#   Ubuntu 20+ recommended
#   Root privileges
#
# This script includes:
#   - VPN Installer (Kerio)
#   - Full Node Builder
#   - Lite Node Spawner
#   - Auto-update
#   - Root password rotation system
#   - Email notifications via SMTP
#   - TrustWallet assets sync
#   - System hardening
################################################################################

set -e

echo "========================================================="
echo "   GYDS NODE INSTALLER (Full Node + Optional Lite Nodes)"
echo "========================================================="

LITE_MODE=false
LITE_COUNT=0

# Parse arguments
if [[ "$1" == "--lite" ]]; then
    LITE_MODE=true
    LITE_COUNT=$2
    if [[ -z "$LITE_COUNT" ]]; then
        echo "ERROR: Missing lite node count."
        echo "Usage: ./install_gyds_node.sh --lite 3"
        exit 1
    fi
fi

INSTALL_DIR="/opt/gyds-chain"
CONFIG_DIR="/etc/gyds"
EMAIL_CONFIG="$CONFIG_DIR/admin_email_config.conf"

# Ensure config directory exists
mkdir -p $CONFIG_DIR

# Create email config if missing
if [[ ! -f "$EMAIL_CONFIG" ]]; then
    cat <<EOF > $EMAIL_CONFIG
# Email + Security Configuration
# Admin will edit this file manually after install

SMTP_ENABLED=false
SMTP_HOST=
SMTP_PORT=
SMTP_USER=
SMTP_PASS=
ADMIN_EMAIL=

# Root password rotation
ROTATE_ROOT_PASSWORD=false
ROTATION_INTERVAL_HOURS=4
EOF

    echo "Created SMTP & security config: $EMAIL_CONFIG"
fi

# Basic system checks
if [[ $EUID -ne 0 ]]; then
    echo "ERROR: This installer must be run as root."
    exit 1
fi

echo "[OK] Running as root..."

# Update system package index
echo "Updating system packages..."
apt update -y

echo "Preparing system dependencies..."
apt install -y curl wget unzip jq git ufw build-essential software-properties-common

mkdir -p $INSTALL_DIR

echo "========================================================="
echo " PART 1 COMPLETED — System prepared & config created"
echo "========================================================="

echo "========================================================="
echo " PART 2 — Installing Go 1.22 & Kerio VPN"
echo "========================================================="

GO_VERSION="1.22.0"
GO_TARBALL="go${GO_VERSION}.linux-amd64.tar.gz"
GO_URL="https://go.dev/dl/${GO_TARBALL}"

# Check if Go is already installed
if command -v go &> /dev/null; then
    INSTALLED_GO=$(go version | awk '{print $3}')
    echo "Go is already installed: $INSTALLED_GO"
else
    echo "Go not found. Installing Go ${GO_VERSION}..."
fi

# Install/upgrade Go
if [[ ! -f "/usr/local/${GO_TARBALL}" ]]; then
    echo "Downloading Go ${GO_VERSION}..."
    wget -q $GO_URL -O /tmp/${GO_TARBALL}
    rm -rf /usr/local/go
    tar -C /usr/local -xzf /tmp/${GO_TARBALL}
else
    echo "Local Go tarball found, installing..."
    rm -rf /usr/local/go
    tar -C /usr/local -xzf /usr/local/${GO_TARBALL}
fi

# Add Go to PATH
if ! grep -q "/usr/local/go/bin" ~/.bashrc; then
    echo "export PATH=\$PATH:/usr/local/go/bin" >> ~/.bashrc
fi
export PATH=$PATH:/usr/local/go/bin

echo "Go installation complete."
go version

################################################################################
# Kerio VPN Installation
################################################################################

echo "Installing Kerio VPN..."

KERIO_URL="https://cdn.kerio-download.example/kerio-control-vpnclient-linux-amd64.deb"

VPN_DEB="/tmp/kerio.deb"

if [[ ! -f "$VPN_DEB" ]]; then
    echo "Downloading Kerio VPN client..."
    wget -q -O $VPN_DEB "$KERIO_URL" || echo "[WARNING] Could not auto-download Kerio client."
fi

# Install Kerio
if [[ -f "$VPN_DEB" ]]; then
    dpkg -i $VPN_DEB || apt --fix-broken install -y
else
    echo "⚠ No Kerio installer downloaded. Admin must manually add Kerio client."
fi

# Create VPN config directory
VPN_DIR="/etc/kerio-vpn"
mkdir -p $VPN_DIR

# Placeholder config file
if [[ ! -f "$VPN_DIR/vpn.conf" ]]; then
    cat <<EOF > $VPN_DIR/vpn.conf
# Kerio VPN Login Settings
# Admin must edit these values:
VPN_SERVER=
VPN_USERNAME=
VPN_PASSWORD=
EOF
    echo "Created Kerio VPN config: $VPN_DIR/vpn.conf"
fi

echo "========================================================="
echo " PART 2 COMPLETED — Go + VPN installed"
echo "========================================================="
echo "========================================================="
echo " PART 3 — GYDS Repo Handler"
echo "========================================================="

REPO_URL="https://github.com/hc172808/gydschain.git"
REPO_DIR="$INSTALL_DIR"

# Check if repo folder exists
if [[ -d "$REPO_DIR/.git" ]]; then
    echo "GYDS repository already exists at $REPO_DIR"
    read -p "Do you want to UPDATE the repository? (y/n): " UPDATE_REPO

    if [[ "$UPDATE_REPO" == "y" ]]; then
        echo "Updating repository..."
        cd $REPO_DIR
        git reset --hard
        git pull --rebase
    else
        echo "Skipping update. Using existing source files."
    fi
else
    echo "Cloning GYDS repository..."
    git clone $REPO_URL $REPO_DIR
fi

echo "Ensuring required folder structure exists..."

mkdir -p $REPO_DIR/core
mkdir -p $REPO_DIR/defi
mkdir -p $REPO_DIR/rpc
mkdir -p $REPO_DIR/wallet
mkdir -p $REPO_DIR/tokens
mkdir -p $REPO_DIR/p2p
mkdir -p $REPO_DIR/cmd
mkdir -p $REPO_DIR/scripts
mkdir -p $REPO_DIR/trustwallet_assets

echo "Folder structure ready."

# Check go.mod compatibility
if grep -q "go 1.22" "$REPO_DIR/go.mod"; then
    echo "go.mod requires go 1.22 — OK."
else
    echo "Fixing go.mod version to 1.22..."
    sed -i 's/^go .*/go 1.22/' "$REPO_DIR/go.mod"
fi

echo "Fetching Go modules..."
cd $REPO_DIR
go mod tidy || echo "[WARNING] go mod tidy encountered version limits but continued."

echo "========================================================="
echo " PART 3 COMPLETED — Repo ready"
echo "========================================================="
