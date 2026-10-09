#!/usr/bin/env bash

# အရောင်သတ်မှတ်ချက်များ
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
PLAIN='\033[0m'

# Root User စစ်ဆေးခြင်း
[[ $EUID -ne 0 ]] && echo -e "${RED}Error: Root access ဖြင့် run ပေးပါ။ (sudo -i)${PLAIN}" && exit 1

# Setup Script ဘက်မှ ပေးပို့လိုက်သော Argument ($1, $2) ကို အရင်စစ်ဆေးခြင်း
DOMAIN="$1"
EMAIL="$2"

# Argument မပါလာပါက အသုံးပြုသူထံမှ မေးမြန်းခြင်း
if [[ -z "$DOMAIN" ]]; then
    read -p "သင့်ရဲ့ Domain Name ကို ရိုက်ထည့်ပါ (eg. sub.example.com): " DOMAIN
    if [[ -z "$DOMAIN" ]]; then
        echo -e "${RED}Domain Name မဖြစ်မနေ ထည့်ပေးရပါမည်!${PLAIN}"
        exit 1
    fi
fi

if [[ -z "$EMAIL" ]]; then
    read -p "သင့်ရဲ့ Email ကို ရိုက်ထည့်ပါ (Enter နှိပ်လျှင် default သုံးပါမည်): " EMAIL
    [[ -z "$EMAIL" ]] && EMAIL="admin@${DOMAIN}"
fi

echo -e "\n${YELLOW}[1/4] လိုအပ်သော Packages များကို စစ်ဆေးတပ်ဆင်နေပါသည်...${PLAIN}"
apt update -y > /dev/null 2>&1
apt install -y curl socat cron > /dev/null 2>&1

echo -e "${YELLOW}[2/4] Port 80 သုံးနေသော Services များကို ခေတ္တရပ်တန့်နေပါသည်...${PLAIN}"
systemctl stop nginx > /dev/null 2>&1
systemctl stop apache2 > /dev/null 2>&1
fuser -k 80/tcp > /dev/null 2>&1

echo -e "${YELLOW}[3/4] acme.sh ကို တပ်ဆင်နေပါသည်...${PLAIN}"
curl -sL https://get.acme.sh | sh -s email="${EMAIL}"
~/.acme.sh/acme.sh --upgrade --auto-upgrade > /dev/null 2>&1

# Certificate output path ပြင်ဆင်ခြင်း (/etc/ssl နှင့် Marzban certs ဖိုဒါနှစ်ခုလုံး ဆောက်ပေးခြင်း)
SSL_DIR="/etc/ssl/${DOMAIN}"
MARZBAN_SSL_DIR="/var/lib/marzban/certs/${DOMAIN}"
mkdir -p "${SSL_DIR}"
mkdir -p "${MARZBAN_SSL_DIR}"

echo -e "${YELLOW}[4/4] Let's Encrypt SSL Certificate ကို ထုတ်ယူနေပါသည်...${PLAIN}"
~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
~/.acme.sh/acme.sh --issue -d "${DOMAIN}" --standalone --force

# Key နှင့် Cert ဖိုင်များကို /etc/ssl သို့ ထုတ်ယူပြီး Marzban ထဲသို့ တစ်ခါတည်း Link/Copy ထည့်သွင်းခြင်း
~/.acme.sh/acme.sh --install-cert -d "${DOMAIN}" \
    --key-file "${SSL_DIR}/private.key" \
    --fullchain-file "${SSL_DIR}/fullchain.cer" \
    --reloadcmd "cp ${SSL_DIR}/fullchain.cer ${MARZBAN_SSL_DIR}/fullchain.pem && cp ${SSL_DIR}/private.key ${MARZBAN_SSL_DIR}/key.pem && marzban restart > /dev/null 2>&1 || true"

# အောင်မြင်မှု ရှိမရှိ စစ်ဆေးပြီး Marzban Certs ထဲသို့ပါ ချက်ချင်း Copy ကူးထည့်ခြင်း
if [[ -f "${SSL_DIR}/fullchain.cer" && -f "${SSL_DIR}/private.key" ]]; then
    cp "${SSL_DIR}/fullchain.cer" "${MARZBAN_SSL_DIR}/fullchain.pem"
    cp "${SSL_DIR}/private.key" "${MARZBAN_SSL_DIR}/key.pem"

    echo -e "\n${GREEN}==============================================${PLAIN}"
    echo -e "${GREEN} SSL Certificate ရယူခြင်း အောင်မြင်ပါသည်!${PLAIN}"
    echo -e "${GREEN}==============================================${PLAIN}"
    echo -e "Cert File Path    : ${YELLOW}${MARZBAN_SSL_DIR}/fullchain.pem${PLAIN}"
    echo -e "Key File Path     : ${YELLOW}${MARZBAN_SSL_DIR}/key.pem${PLAIN}"
    echo -e "System Cert Path  : ${YELLOW}${SSL_DIR}/fullchain.cer${PLAIN}"
    echo -e "Auto-Renew        : ${GREEN}Enabled (acme cron job)${PLAIN}"
    echo -e "${GREEN}==============================================${PLAIN}\n"
else
    echo -e "\n${RED}SSL ထုတ်ယူခြင်း မအောင်မြင်ပါ။ Cloudflare DNS (Proxy Off/Grey Cloud ဖြစ်မဖြစ်) နှင့် Port 80 ဖွင့်ထားခြင်း ရှိမရှိ စစ်ဆေးပါ။${PLAIN}\n"
    exit 1
fi
