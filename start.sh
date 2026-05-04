#!/bin/bash

# ========== 清理旧进程 ==========
pkill -9 -f xray 2>/dev/null
pkill -9 -f cloudflared 2>/dev/null
pkill -9 -f squid 2>/dev/null
sleep 2

# ========== 1. VMess 代理 (Xray) ==========
echo "[1/2] 启动 VMess 代理..."

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

if ps aux | grep -q "[x]ray run"; then
    echo "✅ VMess 启动成功 (端口 8080)"
else
    echo "❌ VMess 启动失败"
fi

# ========== 2. HTTP 代理 (Squid) ==========
echo "[2/2] 启动 HTTP 代理..."

# 装 Squid（如果没装）
if ! command -v squid &>/dev/null; then
    sudo apt update -qq && sudo apt install squid -y -qq
fi

# 配置 Squid
sudo tee /etc/squid/squid.conf > /dev/null << 'SQUID_CONF'
http_port 3128
acl all src 0.0.0.0/0
http_access allow all
httpd_suppress_version_string on
coredump_dir /var/spool/squid
SQUID_CONF

sudo service squid restart
echo "✅ HTTP 代理启动成功 (端口 3128)"

# ========== 3. 启动两个隧道 ==========
echo "启动隧道..."

# 隧道1：VMess（http 模式）
nohup ./cloudflared tunnel --url http://localhost:8080 > /tmp/cf_vmess.log 2>&1 &
sleep 5

# 隧道2：HTTP 代理（tcp 模式）
nohup ./cloudflared tunnel --url tcp://localhost:3128 > /tmp/cf_http.log 2>&1 &
sleep 8

# ========== 4. 打印信息 ==========
echo ""
echo "=============================================="
echo "  VMess 代理"
echo "  地址: $(grep -oP 'https://\K[a-zA-Z0-9.-]+\.trycloudflare\.com' /tmp/cf_vmess.log 2>/dev/null || echo '获取中...')"
echo "  端口: 8080"
echo "  UUID: $UUID"
echo "=============================================="
echo ""
echo "=============================================="
echo "  HTTP 代理"
echo "  地址: $(grep -oP 'tcp://\K[a-zA-Z0-9.-]+\.trycloudflare\.com:\d+' /tmp/cf_http.log 2>/dev/null || echo '获取中...')"
echo "=============================================="
echo ""
