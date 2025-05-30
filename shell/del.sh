sudo systemctl stop sing-box
sudo systemctl disable sing-box
sudo rm -f /etc/systemd/system/sing-box.service
sudo rm -rf /etc/sing-box
sudo rm -f /usr/local/bin/sing-box
sudo systemctl daemon-reload
sudo iptables -D INPUT -p tcp --dport 10000:65535 -j ACCEPT 2>/dev/null || true
echo -e "\n✅ sing-box 已完全卸载并清除。"
