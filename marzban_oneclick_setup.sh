#!/bin/bash

# Clear screen
clear

# Show Banner
echo "------------------------------------------------------------"
echo -e "\e[1;36m"
cat << "EOF"
███████╗███╗   ███╗████████╗
╚══███╔╝████╗ ████║╚══██╔══╝
  ███╔╝ ██╔████╔██║   ██║   
 ███╔╝  ██║╚██╔╝██║   ██║   
███████╗██║ ╚═╝ ██║   ██║   
╚══════╝╚═╝     ╚═╝   ╚═╝   
EOF
echo -e "\e[0m"
echo "            Marzban One Line Setup"
echo "------------------------------------------------------------"

# Root User စစ်ဆေးခြင်း
if [[ $EUID -ne 0 ]]; then
    echo -e "\e[1;31mError: Root access ဖြင့် run ပေးပါ။ (sudo -i)\e[0m"
    exit 1
fi

# Necessary Package Check
echo "📦 Checking necessary packages..."
apt update && apt install -y curl socat wget sed psmisc

# Inputs
read -p "Enter Domain Name (e.g., mar.example.com): " DOMAIN
while [[ -z "$DOMAIN" ]]; do
    echo -e "\e[1;31mDomain Name မဖြစ်မနေ ထည့်ပေးရပါမည်!\e[0m"
    read -p "Enter Domain Name (e.g., mar.example.com): " DOMAIN
done

read -p "Enter Email for SSL (Press Enter for default): " EMAIL
[[ -z "$EMAIL" ]] && EMAIL="admin@${DOMAIN}"

read -p "Enter Telegram Bot Token: " BOT_TOKEN
read -p "Enter Telegram Admin ID: " ADMIN_ID
read -p "Enter Subscription Title: " SUB_TITLE
read -p "Create Admin Username: " ADMIN_USER
read -s -p "Create Admin Password: " ADMIN_PASS
echo -e "\n--------------------------------------------------"

echo "🚀 Installing Marzban..."
bash -c "$(curl -sL https://github.com/Gozargah/Marzban-scripts/raw/master/marzban.sh)" @ install

echo "🔐 Generating SSL Certificates..."
# essl.sh ကို download ဆွဲပြီး DOMAIN နှင့် EMAIL ကို တိုက်ရိုက် pass ပေးကာ run ခြင်း
curl -sL https://raw.githubusercontent.com/zinmyothan25/Marzban-Setup/refs/heads/main/essl.sh -o /tmp/essl.sh
chmod +x /tmp/essl.sh
bash /tmp/essl.sh "$DOMAIN" "$EMAIL"
rm -f /tmp/essl.sh

echo "🎨 Setting up Custom Template..."
mkdir -p /var/lib/marzban/templates/subscription/
wget -N -P /var/lib/marzban/templates/subscription/ https://raw.githubusercontent.com/zinmyothan25/template/main/index.html 2>/dev/null || true

ENV_FILE="/opt/marzban/.env"

update_env() {
    local key=$1
    local value=$2
    if grep -iqE "^#?\s*$key\s*=" "$ENV_FILE"; then
        sed -i "s|^#*\s*$key\s*=.*|$key = \"$value\"|gI" "$ENV_FILE"
    else
        echo "$key = \"$value\"" >> "$ENV_FILE"
    fi
}

echo "📝 Updating .env configuration..."
update_env "UVICORN_HOST" "0.0.0.0"
update_env "UVICORN_PORT" "8000"
update_env "UVICORN_SSL_CERTFILE" "/var/lib/marzban/certs/$DOMAIN/fullchain.pem"
update_env "UVICORN_SSL_KEYFILE" "/var/lib/marzban/certs/$DOMAIN/key.pem"
update_env "TELEGRAM_API_TOKEN" "$BOT_TOKEN"
update_env "TELEGRAM_ADMIN_ID" "$ADMIN_ID"
update_env "SUB_PROFILE_TITLE" "$SUB_TITLE"
update_env "XRAY_SUBSCRIPTION_URL_PREFIX" "https://$DOMAIN:8000"
update_env "CUSTOM_TEMPLATES_DIRECTORY" "/var/lib/marzban/templates/"
update_env "SUBSCRIPTION_PAGE_TEMPLATE" "subscription/index.html"

# Remove any old typo entries
sed -i "/^UNICORN_SSL_/d" "$ENV_FILE"

echo "🔄 Restarting Marzban to apply changes..."
marzban restart

# Wait for Marzban to wake up before creating admin
sleep 5

echo "👤 Creating Admin User..."
marzban cli admin create --username "$ADMIN_USER" --password "$ADMIN_PASS" --sudo || echo "Admin setup skipped."

echo "--------------------------------------------------"
echo -e "\e[1;32m✅ Setup အောင်မြင်စွာ ပြီးဆုံးပါပြီ!\e[0m"
echo "🌐 Dashboard: https://$DOMAIN:8000/dashboard"
echo "👤 Username: $ADMIN_USER"
echo "--------------------------------------------------"
