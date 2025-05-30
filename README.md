# free-node
将你闲置的VPS节点上传作为公益节点，同时也可以仅使用他人的公益节点

---

# 运行

`curl -fsSL https://raw.githubusercontent.com/afoim/free-node/refs/heads/main/shell/run.sh | bash`

## 手动提交节点示例CURL
`curl --location 'https://vps-node.afo.im/add' \
--header 'Content-Type: text/plain' \
--data 'vless://你的链接'`

# 卸载

`curl -fsSL https://raw.githubusercontent.com/afoim/free-node/refs/heads/main/shell/del.sh | bash`

# 使用节点

访问： https://vps-node.afo.im/clash.yaml
