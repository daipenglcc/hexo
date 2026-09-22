---
title: 科学上网之shadowsocks 服务端安装
date: 2017-03-16 18:38:46
tags:
  - 科学上网
  - shadowsocks
categories: shadowsocks
---

记录 Linux 云服务器上 Shadowsocks 服务端的安装、多端口配置、系统网络内核调优以及开机服务托管方案。

<!-- more -->

## 1. 安装环境与依赖 (Ubuntu / Debian)

```bash
# 更新系统包管理器
sudo apt-get update

# 安装 Python3 及 pip
sudo apt-get install -y python3 python3-pip

# 安装 shadowsocks
sudo pip3 install shadowsocks
```

## 2. 配置文件说明

创建并编辑配置文件 `/etc/shadowsocks.json`：

```bash
sudo vim /etc/shadowsocks.json
```

### 单端口配置模式

```json
{
  "server": "0.0.0.0",
  "server_port": 8388,
  "local_address": "127.0.0.1",
  "local_port": 1080,
  "password": "your_secure_password",
  "timeout": 300,
  "method": "aes-256-gcm",
  "fast_open": false
}
```

### 多用户 / 多端口配置模式

```json
{
  "server": "0.0.0.0",
  "local_address": "127.0.0.1",
  "local_port": 1080,
  "port_password": {
    "8381": "password_user1",
    "8382": "password_user2"
  },
  "timeout": 300,
  "method": "aes-256-gcm",
  "fast_open": false
}
```

---

## 3. Linux 高并发与网络内核参数优化

编辑系统配置文件 `/etc/sysctl.d/local.conf`：

```bash
sudo vim /etc/sysctl.d/local.conf
```

添加以下内核网络调优配置：

```ini
# 最大文件句柄与缓冲区
fs.file-max = 1024000
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.rmem_default = 65536
net.core.wmem_default = 65536
net.core.netdev_max_backlog = 4096
net.core.somaxconn = 4096

# TCP 连接重用与超时控制
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.ip_local_port_range = 10000 65000
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_mtu_probing = 1

# 启用 BBR 拥塞控制算法（Linux 4.9+）
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
```

使配置立即生效：

```bash
sudo sysctl --system
```

---

## 4. 服务运行与 Systemd 托管

推荐使用 `systemd` 进行服务启停与开机自启管理：

新建服务描述文件 `/etc/systemd/system/shadowsocks.service`：

```ini
[Unit]
Description=Shadowsocks Server
After=network.target

[Service]
ExecStart=/usr/local/bin/ssserver -c /etc/shadowsocks.json
Restart=always

[Install]
WantedBy=multi-user.target
```

### 服务管理命令

```bash
sudo systemctl daemon-reload
sudo systemctl start shadowsocks     # 启动服务
sudo systemctl restart shadowsocks   # 重启服务
sudo systemctl status shadowsocks    # 查看运行状态
sudo systemctl enable shadowsocks    # 开启开机自启
```
