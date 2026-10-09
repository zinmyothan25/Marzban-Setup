#!/usr/bin/env bash

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
PLAIN='\033[0m'

[[ $EUID -ne 0 ]] && echo -e "${RED}Error: Root access ဖြင့် run ပေးပါ။ (sudo -i)${PLAIN}" && exit 1

DOMAIN="$1"
EMAIL="$2"

if [[ -z "$DOMAIN" ]]; then
    read -p "Domain Name: " DOMAIN
    [[ -z "$DOMAIN" ]] && exit 1
fi

if [[ -z "$EMAIL" ]]; then
    read -p "Email: " EMAIL
    [[ -z "$EMAIL" ]] && EMAIL="admin@${DOMAIN}"
fi

echo -e "\n${YELLOW}[1/4] Packages များ စစ်ဆေးနေပါသည်...${PLAIN}"
apt update -y > /dev/null 2>&1
apt install -y curl socat cron > /dev/null 2>&1

echo -e "${YELLOW}[2/4] Port 80 ကို ရှင်းလင်းနေပါသည်...${PLAIN}"
systemctl stop nginx > /dev/null 2>&1
systemctl stop apache2 > /dev/null 2>&1
fuser -k 80/tcp > /dev/null 2>&1

echo -e "${YELLOW}[3/4] acme.sh တပ်ဆင်နေပါသည်...${PLAIN}"
curl -sL https://get.acme.sh | sh -s email="${EMAIL}" > /dev/null 2>&1
~/.acme.sh/acme.sh --upgrade --auto-upgrade > /dev/null 2>&1

SSL_DIR="/etc/ssl/${DOMAIN}"
MARZBAN_SSL_DIR="/var/lib/marzban/certs/${DOMAIN}"
mkdir -p "${SSL_DIR}"
mkdir -p "${MARZBAN_SSL_DIR}"

echo -e "${YELLOW}[4/4] SSL ထုတ်ယူနေပါသည်...${PLAIN}"
~/.acme.sh/acme.sh --set-default-ca --server letsencrypt > /dev/null 2>&1
~/.acme.sh/acme.sh --issue -d "${DOMAIN}" --standalone --force

# Install cert လုပ်ရာတွင် path နှစ်ခုလုံးသို့ သီးခြားချပေးပြီး reloadcmd တွင် restart command ကြီး မထည့်ပါနှင့်
~/.acme.sh/acme.sh --install-cert -d "${DOMAIN}" \
    --key-file "${SSL_DIR}/private.key" \
    --fullchain-file "${SSL_DIR}/fullchain.cer" \
    --reloadcmd "cp -f ${SSL_DIR}/fullchain.cer ${MARZBAN_SSL_DIR}/fullchain.pem && cp -f ${SSL_DIR}/private.key ${MARZBAN_SSL_DIR}/key.pem"

# သေချာစေရန် Marzban cert directory သို့ တိုက်ရိုက် copy ကူးထည့်ခြင်း
cp -f "${SSL_DIR}/fullchain.cer" "${MARZBAN_SSL_DIR}/fullchain.pem"
cp -f "${SSL_DIR}/private.key" "${MARZBAN_SSL_DIR}/key.pem"

if [[ -f "${MARZBAN_SSL_DIR}/fullchain.pem" && -f "${MARZBAN_SSL_DIR}/key.pem" ]]; then
    echo -e "\n${GREEN}SSL ရယူပြီးစီးပါပြီ!${PLAIN}\n"
else
    echo -e "\n${RED}SSL မအောင်မြင်ပါ။${PLAIN}\n"
    exit 1
fi
