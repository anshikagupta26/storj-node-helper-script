#!/bin/bash

NC='\033[0m'
CYAN='\033[0;36m'

read -p "Enter your wallet address: " WALLET_ADDRESS
read -p "Enter your email address: " EMAIL_ADDRESS
read -p "Enter your IP address or DDNS name: " IP_ADDRESS_OR_DNS_NAME
read -p "How much storage are you willing to share? Example: 700GB   " HOW_MUCH_STORAGE_TO_SHARE_IN_GB
read -p "Where is your storage folder located? Example: /storj/  " STORAGE_PATH

if [[ $WALLET_ADDRESS != '' ]] && [[ $EMAIL_ADDRESS != '' ]] && [[ $IP_ADDRESS_OR_DNS_NAME != '' ]] && [[ $HOW_MUCH_STORAGE_TO_SHARE_IN_GB != '' ]] && [[ $STORAGE_PATH != '' ]]; then
        printf "You've entered: \n\n${CYAN}$WALLET_ADDRESS${NC}\n${CYAN}$EMAIL_ADDRESS${NC}\n${CYAN}$IP_ADDRESS_OR_DNS_NAME${NC}\n${CYAN}$HOW_MUCH_STORAGE_TO_SHARE_IN_GB${NC}\n${CYAN}${STORAGE_PATH}${NC}\n\nPress CTRL+C if this doesn't look right.\n" && read -p "Or just press enter to continue." && printf "\n\n"
elif [[ $WALLET_ADDRESS = '' ]] || [[ $EMAIL_ADDRESS = '' ]] || [[ $IP_ADDRESS_OR_DNS_NAME = '' ]] || [[ $HOW_MUCH_STORAGE_TO_SHARE_IN_GB = '' ]] || [[ $STORAGE_PATH = '' ]]; then
        printf "Mate, you can't run the script this way, please enter all variables.\n" && exit
fi

docker run -d --rm -e SETUP="true" \
    --mount type=bind,source="/root/.local/share/storj/identity/storagenode/",destination=/app/identity \
    --mount type=bind,source="${STORAGE_PATH}",destination=/app/config \
    --name storagenode storjlabs/storagenode:latest

sleep 15

cat << EOF | cat > /root/storj.sh
docker stop storagenode &> /dev/null
docker rm storagenode &> /dev/null
docker pull storjlabs/storagenode:latest
docker run -d --restart unless-stopped -p 61263:28967 -p 61263:14002 -e WALLET="${WALLET_ADDRESS}" -e EMAIL="${EMAIL_ADDRESS}" -e ADDRESS="${IP_ADDRESS_OR_DNS_NAME}:61263" -e BANDWIDTH="256TB" -e STORAGE="${HOW_MUCH_STORAGE_TO_SHARE_IN_GB}" --mount type=bind,source="/root/.local/share/storj/identity/storagenode/",destination=/app/identity --mount type=bind,source="${STORAGE_PATH}",destination=/app/config --name storagenode storjlabs/storagenode:latest

docker stop watchtower &> /dev/null
docker rm watchtower &> /dev/null
docker pull storjlabs/watchtower
docker run -d --restart=always --name watchtower -v /var/run/docker.sock:/var/run/docker.sock storjlabs/watchtower storagenode watchtower --stop-timeout 300s --interval 21600
EOF

chmod +x /root/storj.sh

if [[ $(grep '@reboot bash -c "/root/storj.sh"' /etc/crontab) != '@reboot bash -c "/root/storj.sh"' ]]; then
        echo '@reboot bash -c "/root/storj.sh"' >> /etc/crontab
fi

bash -c "/root/storj.sh"

IPADDR=$(ip a | grep "192\|10\|172" | awk '{print $2}' | awk '/^192|^10/' | sed 's/\/.*//')
printf "All done. Go and checkout your dashboard at: ${CYAN}http://${IPADDR}:14002${NC} \n"
