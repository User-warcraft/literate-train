#!/bin/bash
set -e

echo ">>> 清理..."
pkill -f cloudflared 2>/dev/null || true
sleep 1

echo ">>> 确保 Squid 运行..."
if ! pgrep squid >/dev/null; then
    if ! command -v squid >/dev/null 2>&1; then
        sudo apt update -qq && sudo apt install -y -qq squid
    fi
    printf 'http_port 3128\nacl all src 0.0.0.0/0\nhttp_access allow all\n' | sudo tee /etc/squid/squid.conf > /dev/null
    sudo service squid restart 2>/dev/null || true
fi
echo "Squid OK (3128)"

echo ">>> 启动 HTTP 隧道..."
./cloudflared tunnel --url tcp://localhost:3128 > /tmp/http_tunnel.log 2>&1 &
sleep 10

echo ">>> 提取地址..."
# 从日志里拿完整地址
ADDR=$(grep -oP 'tcp://\K[a-zA-Z0-9.-]+\.trycloudflare\.com:\d+' /tmp/http_tunnel.log 2>/dev/null | tail -1 || echo "")

echo ""
echo "============================================"
echo "  HTTP 代理地址"
echo "  ${ADDR:-未获取到}"
echo ""
echo "  如果上面为空，手动执行："
echo "  cat /tmp/http_tunnel.log | grep tcp://"
echo "============================================"
