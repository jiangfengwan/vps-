#!/bin/bash

# 检查并安装必要的软件
if ! command -v hysteria &> /dev/null
then
    echo "安装 Hysteria"
    # 替换为Hysteria的实际安装命令
    wget -O hysteria.tar.gz https://github.com/apernet/hysteria/releases/download/v1.2.3/hysteria-linux-amd64.tar.gz
    tar -zxvf hysteria.tar.gz
    mv hysteria /usr/local/bin/
    rm hysteria.tar.gz
fi

if ! command -v xray &> /dev/null
then
    echo "安装 Xray-core"
    # 替换为Xray-core的实际安装命令
    wget -O xray.zip https://github.com/XTLS/Xray-core/releases/download/v1.5.3/Xray-linux-64.zip
    unzip xray.zip
    mv xray /usr/local/bin/
    rm xray.zip
fi

# 生成UUID
REALITY_UUID=$(cat /proc/sys/kernel/random/uuid)

# 生成Reality的私钥和公钥
REALITY_KEYS=$(xray x25519)
REALITY_PRIVATE_KEY=$(echo "$REALITY_KEYS" | grep "Private key:" | awk '{print $3}')
REALITY_PUBLIC_KEY=$(echo "$REALITY_KEYS" | grep "Public key:" | awk '{print $3}')

# 提示用户输入必要信息
read -p "请输入Hysteria代理的认证密码: " HYSTERIA_PASSWORD
read -p "请输入Hysteria服务器的IP地址: " HYSTERIA_SERVER_IP
read -p "请输入Hysteria服务器的端口号 (默认2333): " HYSTERIA_SERVER_PORT
HYSTERIA_SERVER_PORT=${HYSTERIA_SERVER_PORT:-2333}
read -p "请输入Hysteria代理的上传速度 (Mbps): " HYSTERIA_UP_MBPS
read -p "请输入Hysteria代理的下载速度 (Mbps): " HYSTERIA_DOWN_MBPS

read -p "请输入Reality服务器的IP地址: " REALITY_SERVER_IP
read -p "请输入Reality服务器的端口号 (默认7898): " REALITY_SERVER_PORT
REALITY_SERVER_PORT=${REALITY_SERVER_PORT:-7898}
read -p "请输入Reality代理的SNI主机名: " REALITY_SNI

# 生成Hysteria配置文件
cat <<EOF > /etc/hysteria_config.json
{
  "listen": ":$HYSTERIA_SERVER_PORT",
  "cert": "/etc/letsencrypt/live/your-domain/fullchain.pem",
  "key": "/etc/letsencrypt/live/your-domain/privkey.pem",
  "up_mbps": $HYSTERIA_UP_MBPS,
  "down_mbps": $HYSTERIA_DOWN_MBPS,
  "obfs": "password",
  "auth": {
    "mode": "password",
    "config": {
      "password": "$HYSTERIA_PASSWORD"
    }
  }
}
EOF

# 生成Reality配置文件
cat <<EOF > /etc/reality_config.json
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": $REALITY_SERVER_PORT,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$REALITY_UUID",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "$REALITY_SNI:443",
          "serverNames": ["$REALITY_SNI"],
          "privateKey": "$REALITY_PRIVATE_KEY",
          "shortIds": ["123456"]
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF

# 创建服务文件并启动服务
cat <<EOF > /etc/systemd/system/hysteria.service
[Unit]
Description=Hysteria Service
After=network.target

[Service]
ExecStart=/usr/local/bin/hysteria -c /etc/hysteria_config.json
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF > /etc/systemd/system/xray.service
[Unit]
Description=Xray Service
After=network.target

[Service]
ExecStart=/usr/local/bin/xray -config /etc/reality_config.json
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# 重新加载 systemd 并启动服务
systemctl daemon-reload
systemctl enable hysteria
systemctl start hysteria
systemctl enable xray
systemctl start xray

echo "Hysteria 和 Reality 代理已启动"
echo "Reality UUID: $REALITY_UUID"
echo "Reality Public Key: $REALITY_PUBLIC_KEY"
