#!/bin/bash

set -e

# 安装目录
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/sing-box"
SERVICE_FILE="/etc/systemd/system/sing-box.service"

# 随机端口、UUID、Reality 密钥对
PORT=$((RANDOM % 55535 + 10000))
UUID=$(cat /proc/sys/kernel/random/uuid)
KEY_PAIR=$(sing-box generate reality-keypair)
PRIVATE_KEY=$(echo "$KEY_PAIR" | awk '/PrivateKey/ {print $2}')
PUBLIC_KEY=$(echo "$KEY_PAIR" | awk '/PublicKey/ {print $2}')
SNI="gateway.icloud.com"
SHORT_ID=$(openssl rand -hex 8)

# 下载并安装 sing-box 最新版本
install_singbox() {
  echo "[+] 安装 sing-box 最新版本..."
  ARCH="amd64"
  TEMP_DIR=$(mktemp -d)
  cd "$TEMP_DIR"
  LATEST_URL=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest \
    | grep "browser_download_url" \
    | grep "linux-$ARCH.tar.gz" \
    | cut -d '"' -f 4)
  curl -LO "$LATEST_URL"
  tar -xzf sing-box-*-linux-$ARCH.tar.gz
  install sing-box-*/sing-box "$INSTALL_DIR"
  mkdir -p "$CONFIG_DIR"
  rm -rf "$TEMP_DIR"
}

# 创建配置文件
generate_config() {
  cat > "$CONFIG_DIR/config.json" <<EOF
{
  "log": {
    "level": "info",
    "output": "console"
  },
  "inbounds": [
    {
      "type": "vless",
      "listen": "::",
      "listen_port": $PORT,
      "users": [
        {
          "uuid": "$UUID",
          "flow": ""
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "$SNI",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "$SNI",
            "server_port": 443
          },
          "private_key": "$PRIVATE_KEY",
          "short_id": ["$SHORT_ID"]
        }
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct"
    }
  ]
}
EOF
}

# 创建 systemd 服务
create_service() {
  cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=sing-box service
After=network.target

[Service]
ExecStart=$INSTALL_DIR/sing-box run -c $CONFIG_DIR/config.json
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reexec
  systemctl daemon-reload
  systemctl enable sing-box
  systemctl restart sing-box
}

# 开放端口（仅限使用 ufw/iptables）
open_port() {
  if command -v ufw >/dev/null; then
    ufw allow $PORT/tcp
  elif command -v iptables >/dev/null; then
    iptables -I INPUT -p tcp --dport $PORT -j ACCEPT
  fi
}

# 主流程
main() {
  install_singbox
  generate_config
  create_service
  open_port

  echo -e "\n✅ 安装完成！以下是连接信息：\n"
  echo "协议: VLESS Reality"
  echo "地址: $(curl -s https://ipinfo.io/ip)"
  echo "端口: $PORT"
  echo "UUID: $UUID"
  echo "公钥: $PUBLIC_KEY"
  echo "SNI: $SNI"
  echo "Short ID: $SHORT_ID"
  echo -e "\n📎 VLESS URI:\n"
  echo "vless://$UUID@$(curl -s https://ipinfo.io/ip):$PORT?encryption=none&flow=&security=reality&sni=$SNI&fp=chrome&pbk=$PUBLIC_KEY&sid=$SHORT_ID&type=tcp#vless-reality"
}

main
