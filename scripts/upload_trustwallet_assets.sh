#!/bin/bash

# Upload TrustWallet Assets Script
# Usage: bash upload_trustwallet_assets.sh

set -e

ASSETS_DIR="./trustwallet_assets"
REPO_URL="git clone --depth=1 https://github.com/trustwallet/assets.git /tmp/trustwallet-assets

TMP_DIR="/tmp/trustwallet-assets"

echo "Cloning GitHub repository..."
rm -rf $TMP_DIR
git clone $REPO_URL $TMP_DIR

echo "Copying assets..."
cp $ASSETS_DIR/*.png $TMP_DIR/
cp $ASSETS_DIR/*.json $TMP_DIR/

cd $TMP_DIR

echo "Adding files to Git..."
git add .
git commit -m "Update GYDS/GYD logos and metadata"
git push origin main

echo "Assets uploaded successfully!"
