#!/bin/bash

# Clear screen
clear

# --- Banner Section ---
echo -e "\e[1;36m"
echo "      ███████╗███╗   ███╗████████╗"
echo "      ╚══███╔╝████╗ ████║╚══██╔══╝"
echo "        ███╔╝ ██╔████╔██║   ██║   "
echo "       ███╔╝  ██║╚██╔╝██║   ██║   "
echo "      ███████╗██║ ╚═╝ ██║   ██║   "
echo "      ╚══════╝╚═╝     ╚═╝   ╚═╝   "
echo -e "\e[0m"
echo "--------------------------------------------------"
echo -e "\e[1;33m  Installing Protocols:\e[0m"
echo "  🔹 VMess (WS TLS & TCP) - [Priority]"
echo "  🔹 VLESS (Reality & WS TLS)"
echo "  🔹 Trojan (TLS & TCP)"
echo "  🔹 Shadowsocks"
echo "--------------------------------------------------"

# --- Check Domain ---
DOMAIN=$(ls -1 /var/lib/marzban/certs/ 2>/dev/null | head -n 1)
if [ -z "$DOMAIN" ]; then
    echo -e "\e[1;31m❌ Error: Domain folder ရှာမတွေ့ပါ။ အရင်ဆုံး SSL setup လုပ်ထားဖို့ လိုပါတယ်။\e[0m"
    exit 1
else
    echo -e "\e[1;32m✅ Domain found: $DOMAIN\e[0m"
fi

echo "🔑 Keys ထုတ်နေပါတယ်..."

# --- Get Reality Keys ---
KEYS=$(docker exec marzban-marzban-1 xray x25519 2>/dev/null || docker exec marzban-1 xray x25519 2>/dev/null)

if [ -z "$KEYS" ]; then
    echo "🌐 Docker ထဲမှာ xray မရှိလို့ အပြင်ကနေ Download ဆွဲနေပါတယ်..."
    apt update && apt install unzip -y &>/dev/null
    curl -L -o /tmp/xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip &>/dev/null
    unzip -o /tmp/xray.zip xray -d /tmp/ &>/dev/null
    chmod +x /tmp/xray
    KEYS=$(/tmp/xray x25519)
fi

PRIV=$(echo "$KEYS" | grep "Private key" | cut -d ' ' -f 3)
PUB=$(echo "$KEYS" | grep "Public key" | cut -d ' ' -f 3)
SID=$(openssl rand -hex 4)

if [ -z "$PRIV" ]; then
    echo -e "\e[1;31m❌ Error: Reality Keys ထုတ်လို့ မရခဲ့ပါ။\e[0m"
    exit 1
fi

echo -e "\e[1;32m✅ Keys Generated Successfully.\e[0m"

# --- Create xray_config.json (VMess protocols moved to top) ---
cat <<EOF > /var/lib/marzban/xray_config.json
{
    "log": { "loglevel": "warning" },
    "routing": {
        "rules": [ { "type": "field", "ip": ["geoip:private"], "outboundTag": "BLOCK" } ]
    },
    "inbounds": [
        {
            "tag": "VMess WS TLS",
            "listen": "0.0.0.0",
            "port": 8443,
            "protocol": "vmess",
            "settings": { "clients": [] },
            "streamSettings": {
                "network": "ws", "security": "tls",
                "tlsSettings": {
                    "certificates": [{
                        "certificateFile": "/var/lib/marzban/certs/$DOMAIN/fullchain.pem",
                        "keyFile": "/var/lib/marzban/certs/$DOMAIN/privkey.pem"
                    }]
                },
                "wsSettings": { "path": "/vmess" }
            }
        },
        {
            "tag": "VMESS + TCP",
            "listen": "0.0.0.0",
            "port": 4427,
            "protocol": "vmess",
            "settings": { "clients": [] },
            "streamSettings": { "network": "tcp", "security": "none" },
            "sniffing": { "enabled": true, "destOverride": ["http", "tls"] }
        },
        {
            "tag": "VLESS WS TLS",
            "listen": "0.0.0.0",
            "port": 2083,
            "protocol": "vless",
            "settings": { "clients": [], "decryption": "none" },
            "streamSettings": {
                "network": "ws", "security": "tls",
                "tlsSettings": {
                    "certificates": [{
                        "certificateFile": "/var/lib/marzban/certs/$DOMAIN/fullchain.pem",
                        "keyFile": "/var/lib/marzban/certs/$DOMAIN/privkey.pem"
                    }]
                },
                "wsSettings": { "path": "/vless" }
            }
        },
        {
            "tag": "VLESS TLS",
            "listen": "0.0.0.0",
            "port": 9850,
            "protocol": "vless",
            "settings": { "clients": [], "decryption": "none" },
            "streamSettings": { "network": "tcp", "security": "none" },
            "sniffing": { "enabled": true, "destOverride": ["http", "tls"] }
        },
        {
            "tag": "VLESS REALITY",
            "listen": "0.0.0.0",
            "port": 443,
            "protocol": "vless",
            "settings": { "clients": [], "decryption": "none" },
            "streamSettings": {
                "network": "tcp", "security": "reality",
                "realitySettings": {
                    "show": false, "dest": "www.cloudflare.com:443", "xver": 0,
                    "serverNames": ["www.cloudflare.com", "$DOMAIN"],
                    "privateKey": "$PRIV",
                    "publicKey": "$PUB",
                    "shortIds": ["$SID"]
                }
            },
            "sniffing": { "enabled": true, "destOverride": ["http", "tls"] }
        },
        {
            "tag": "Trojan TLS",
            "listen": "0.0.0.0",
            "port": 2053,
            "protocol": "trojan",
            "settings": { "clients": [] },
            "streamSettings": {
                "network": "tcp", "security": "tls",
                "tlsSettings": {
                    "certificates": [{
                        "certificateFile": "/var/lib/marzban/certs/$DOMAIN/fullchain.pem",
                        "keyFile": "/var/lib/marzban/certs/$DOMAIN/privkey.pem"
                    }]
                }
            }
        },
        {
            "tag": "TROJAN + TCP",
            "listen": "0.0.0.0",
            "port": 9094,
            "protocol": "trojan",
            "settings": { "clients": [] },
            "streamSettings": { "network": "tcp", "security": "none" },
            "sniffing": { "enabled": true, "destOverride": ["http", "tls"] }
        },
        {
            "tag": "Shadowsocks TCP",
            "listen": "0.0.0.0",
            "port": 1080,
            "protocol": "shadowsocks",
            "settings": { "clients": [], "network": "tcp,udp" }
        }
    ],
    "outbounds": [
        { "protocol": "freedom", "tag": "DIRECT" },
        { "protocol": "blackhole", "tag": "BLOCK" }
    ]
}
EOF

echo "✅ JSON File Updated."
marzban restart

# Cleanup
rm -rf /tmp/xray.zip /tmp/xray 2>/dev/null

echo "--------------------------------------------------"
echo -e "\e[1;32m🔥 Protocols Configuration Complete (ZMT Edition) 🔥\e[0m"
echo "--------------------------------------------------"
