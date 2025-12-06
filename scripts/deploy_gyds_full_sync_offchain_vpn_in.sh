#!/bin/bash
set -e

# Colors
GREEN="\e[32m"; YELLOW="\e[33m"; RED="\e[31m"; NC="\e[0m"

clear

echo -e "${GREEN}=== GYDS Full Sync + Off‑Chain + VPN Deployment ===${NC}"

#########################################
# 1. CHECK IF gyds-chain FOLDER EXISTS   #
#########################################

if [ -d "gyds-chain" ]; then
    echo -e "${YELLOW}gyds-chain folder already exists.${NC}"
    read -p "Do you want to update it? (y/n): " UPDATE

    if [[ "$UPDATE" =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}Updating existing gyds-chain...${NC}"
        cd gyds-chain
        git pull || { echo -e "${RED}Failed to update repository.${NC}"; exit 1; }
        cd ..
    else
        echo -e "${YELLOW}Skipping update and continuing...${NC}"
    fi
else
    echo -e "${GREEN}gyds-chain folder not found. Cloning fresh repo...${NC}"
    git clone https://your_repo_url_here/gyds-chain.git
fi

#########################################
# 2. SYSTEM UPDATE                       #
#########################################

echo -e "${GREEN}Updating system packages...${NC}"
sudo apt update -y && sudo apt upgrade -y

#########################################
# 3. INSTALL DEPENDENCIES               #
#########################################

echo -e "${GREEN}Installing build tools, curl, jq...${NC}"
sudo apt install -y build-essential curl jq wget ufw

#########################################
# 4. DOWNLOAD KERIO VPN CLIENT          #
#########################################

echo -e "${GREEN}Downloading Kerio VPN Client...${NC}"
wget -O kerio.deb "https://cdn.kerio.com/dwn/vpnclient.deb"  # Replace with correct URL
sudo dpkg -i kerio.deb || sudo apt --fix-broken install -y

read -p "Enter Kerio VPN Server (IP or domain): " KSERVER
read -p "Enter Kerio Username: " KUSER
read -s -p "Enter Kerio Password: " KPASS

echo

echo "$KPASS" | sudo /usr/sbin/kvpnc -s "$KSERVER" -u "$KUSER" --create-profile GYDSVPN --non-interactive
sudo /usr/sbin/kvpnc -c GYDSVPN

#########################################
# 5. FIREWALL RULES                     #
#########################################

echo -e "${GREEN}Configuring firewall...${NC}"
sudo ufw allow 22
sudo ufw allow 8545
sudo ufw allow 30303
sudo ufw --force enable

#########################################
# 6. FULL NODE BUILD + SYNC             #
#########################################

echo -e "${GREEN}Building full node...${NC}"
cd gyds-chain
make fullnode || { echo -e "${RED}Failed to build full node!${NC}"; exit 1; }


echo -e "${GREEN}Starting full node and waiting for sync...${NC}"
nohup ./build/bin/gyds --syncmode full --http --http.addr 0.0.0.0 --http.port 8545 > fullnode.log 2>&1 &
sleep 10

while true; do
    BLOCK=$(curl -s http://localhost:8545 | jq '.result | tonumber')
    if [[ "$BLOCK" -gt 100 ]]; then
        echo -e "${GREEN}Full node is synced. Current block: $BLOCK${NC}"
        break
    fi
    echo -e "${YELLOW}Waiting for full sync... Current block: $BLOCK${NC}"
    sleep 15
done

#########################################
# 7. OFF‑CHAIN DATA SYNC                #
#########################################

echo -e "${GREEN}Downloading TrustWallet off‑chain metadata...${NC}"
mkdir -p offchain
cd offchain
wget -q https://trustwallet-assets.s3.us-east-2.amazonaws.com/blockchains/ethereum/info/info.json
wget -q https://trustwallet-assets.s3.us-east-2.amazonaws.com/blockchains/ethereum/assets_logo.png
cd ..

#########################################
# 8. START LITE NODES AFTER SYNC        #
#########################################

echo -e "${GREEN}Starting lite node(s)...${NC}"
PORT=30310
RPC=8550

for i in {1..3}; do
    echo -e "${GREEN}Starting lite node $i on ports $PORT / $RPC ...${NC}"
    nohup ./build/bin/gyds --syncmode light --port $PORT --http --http.port $RPC > lite_$i.log 2>&1 &
    PORT=$((PORT+1))
    RPC=$((RPC+1))
done

#########################################
#  DONE                                 #
#########################################

echo -e "${GREEN}Deployment Finished Successfully!${NC}"
