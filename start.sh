#!/bin/bash
set -e

echo ">>> 清理..."
pkill -f xray 2>/dev/null || true
pkill -f cloudflared 2>/dev/null || true
sleep 2

echo ">>> Xray..."
cd /workspaces/codespaces-blank/xray
UUID=$(cat uuid.txt)
cat > config.json << EOF
{
  "inbounds": [{
    "port": 8080,
    "listen": "0.0.0.0",
    "protocol": "vmess",
    "settings": {"clients": [{"id": "$UUID", "alterId": 0}]},
    "streamSettings": {"network": "ws", "wsSettings": {"path": "/"}}
  }],
  "outbounds": [{"protocol": "freedom", "settings": {}}]
}
EOF

nohup ./xray run -config config.json > xray.log 2>&1 &
sleep 3
echo "VMess OK"

echo ">>> Squid..."
if ! command -v squid >/dev/null 2>&1; then
    sudo apt update -qq && sudo apt install -y -qq squid
fi
printf 'http_port 3128\nacl all src 0.0.0.0/0\nhttp_access allow all\n' | sudo tee /etc/squid/squid.conf > /dev/null
sudo service squid restart 2>/dev/null || true
echo "Squid OK"

echo ">>> 隧道..."
./cloudflared tunnel --url http://localhost:8080 > /tmp/cf_vmess.log 2>&1 &
sleep 5
./cloudflared tunnel --url tcp://localhost:3128 > /tmp/cf_http.log 2>&1 &
sleep 8

echo ""
echo "===================="
echo "VMess:"
grep -oP 'https://\K[a-zA-Z0-9.-]+\.trycloudflare\.com' /tmp/cf_vmess.log 2>/dev/null | tail -1 || echo "稍等..."
echo ""
echo "HTTP:"
grep -oP 'tcp://\K[a-zA-Z0-9.-]+\.trycloudflare\.com:\d+' /tmp/cf_http.log 2>/dev/null | tail -1 || echo "稍等..."
echo ""
echo "UUID: $UUID"
echo "===================="
echo "DONE"
