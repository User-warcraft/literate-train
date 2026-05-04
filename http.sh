# 1. 更新软件包列表并安装 Squid
sudo apt update && sudo apt install squid -y

# 2. 备份默认配置
sudo cp /etc/squid/squid.conf /etc/squid/squid.conf.bak

# 3. 创建新的配置文件
sudo tee /etc/squid/squid.conf > /dev/null << 'EOF'
# 配置代理监听端口
http_port 3128

# 定义基本访问控制列表 (ACL)
acl localnet src 0.0.0.1-0.255.255.255  # 过滤非公网路由段
acl localnet src 10.0.0.0/8             # RFC 1918 私有网络
acl localnet src 100.64.0.0/10          # RFC 6598 运营商级 NAT
acl localnet src 169.254.0.0/16         # RFC 3927 链路本地地址
acl localnet src 172.16.0.0/12          # RFC 1918 私有网络
acl localnet src 192.168.0.0/16         # RFC 1918 私有网络
acl localnet src fc00::/7               # RFC 4193 唯一本地地址
acl localnet src fe80::/10              # RFC 4291 链路本地地址

# 允许的端口
acl SSL_ports port 443      # HTTPS
acl Safe_ports port 80      # HTTP
acl Safe_ports port 21      # FTP
acl Safe_ports port 443     # HTTPS
acl Safe_ports port 70      # Gopher
acl Safe_ports port 210     # WAIS
acl Safe_ports port 1025-65535  # 未注册端口
acl Safe_ports port 280     # HTTP-MGMT
acl Safe_ports port 488     # GSS-HTTP
acl Safe_ports port 591     # 文件制作
acl Safe_ports port 777     # Multiling HTTP

# 关键访问控制规则
http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports
http_access allow localnet
http_access allow localhost
http_access deny all

# 常规设置
httpd_suppress_version_string on
coredump_dir /var/spool/squid

# 可选：设置基本认证 (推荐)
# 首先安装工具: sudo apt install apache2-utils -y
# 然后创建密码文件: sudo htpasswd -c /etc/squid/passwd your_username
# 最后在配置中添加:
# auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwd
# acl authenticated proxy_auth REQUIRED
# http_access allow authenticated
EOF

# 4. 重启 Squid 服务以应用配置
sudo service squid restart

# 5. 检查 Squid 状态
sudo service squid status

sudo netstat -tlnp | grep 3128

./cloudflared tunnel --url tcp://localhost:3128