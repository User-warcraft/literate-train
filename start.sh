#!/bin/bash
set -e

echo ">>> 清理旧进程..."
pkill -f xray 2>/dev/null || true
pkill -f cloudflared 2>/dev/null || true
sleep 2

echo ">>> 启动VMess..."
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
echo "✅ VMess 已启动"

echo ">>> 启动HTTP代理..."
if ! command -v squid >/dev/null 2>&1; then
    sudo apt update -qq && sudo apt install -y -qq squid
fi
printf 'http_port 3128\nacl all src 0.0.0.0/0\nhttp_access allow all\n' | sudo tee /etc/squid/squid.conf > /dev/null
sudo service squid restart 2>/dev/null || true
echo "✅ HTTP 代理已启动（本地端口3128）"

echo ">>> 建立隧道..."
./cloudflared tunnel --url http://localhost:8080 > /tmp/cf_vmess.log 2>&1 &
sleep 5
./cloudflared tunnel --url tcp://localhost:3128 > /tmp/cf_http.log 2>&1 &
sleep 8

echo ">>> 读取地址..."

# 等 metrics 就绪
for i in 1 2 3 4 5; do
  curl -s http://localhost:20241/metrics 2>/dev/null | grep -q tcp_ingress && break
  sleep 2
done

HTTP_INFO=$(curl -s http://localhost:20241/metrics 2>/dev/null | grep tcp_ingress | tail -1 || echo "")
HTTP_HOST=$(echo "$HTTP_INFO" | grep -oP 'hostname="\K[^"]+' || echo "")
HTTP_PORT=$(echo "$HTTP_INFO" | grep -oP 'port="\K[^"]+' || echo "")

VMESS_HOST=$(grep -oP 'https://\K[a-zA-Z0-9.-]+\.trycloudflare\.com' /tmp/cf_vmess.log 2>/dev/null | tail -1 || echo "")

echo ""
echo "============================================"
echo "  VMess 连接信息"
echo "  地址: ${VMESS_HOST:-未获取到}"
echo "  端口: 8080"
echo "  UUID: $UUID"
echo "  传输: ws, 路径: /"
echo "============================================"
echo ""
echo "============================================"
echo "  HTTP 代理连接信息"
echo "  服务器: ${HTTP_HOST:-未获取到}"
echo "  端口: ${HTTP_PORT:-未获取到}"
echo "============================================"
echo "服务启动完成。"
