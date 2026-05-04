# 杀掉所有可能冲突的进程
pkill -9 -f xray 2>/dev/null
pkill -9 -f cloudflared 2>/dev/null
sleep 2

# 确认 8080 端口没被占用
lsof -i :8080 2>/dev/null || echo "8080 端口空闲"

# 重新生成配置文件
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

# 启动 Xray
nohup ./xray run -config config.json > xray.log 2>&1 &
sleep 3

# 检查启动状态
if ps aux | grep -q "[x]ray run"; then
    echo "✅ Xray 启动成功"
else
    echo "❌ Xray 启动失败，查看日志："
    tail -10 xray.log
fi

# 启动隧道
nohup ./cloudflared tunnel --url http://localhost:8080 > /tmp/cf.log 2>&1 &
sleep 8

echo "=============================="
echo "新地址: $(grep -oP 'https://\K[a-zA-Z0-9.-]+\.trycloudflare\.com' /tmp/cf.log 2>/dev/null || echo '等待中...')"
echo "UUID: $UUID"
echo "=============================="

while true; do
  echo "Keep alive: $(date)"
  sleep 60
done