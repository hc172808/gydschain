#!/bin/bash
set -euo pipefail

# Upload TrustWallet Assets Script (SAFE / READ-ONLY)
# Usage: bash upload_trustwallet_assets.sh [target-dir]

SOURCE_DIR="$(cd "$(dirname "$0")/../trustwallet_assets" && pwd)"
TARGET_DIR="${1:-/opt/gyds-node/assets/trustwallet}"
TMP_DIR="/tmp/trustwallet-assets"
REPO_URL="https://github.com/trustwallet/assets.git"

echo "📦 Syncing TrustWallet assets (read-only)..."

# Prevent git from ever prompting
export GIT_TERMINAL_PROMPT=0

rm -rf "$TMP_DIR"
git clone --depth=1 "$REPO_URL" "$TMP_DIR"

mkdir -p "$TARGET_DIR"

echo "📁 Copying GYDS / GYD assets..."

# Copy ONLY your project assets
cp -v "$SOURCE_DIR"/*.png "$TARGET_DIR/" 2>/dev/null || true
cp -v "$SOURCE_DIR"/*.json "$TARGET_DIR/" 2>/dev/null || true

echo "🧹 Cleaning up..."
rm -rf "$TMP_DIR"

echo "✅ TrustWallet assets synced locally"
