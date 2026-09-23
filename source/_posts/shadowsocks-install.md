---
title: 自己动手搭梯子：Shadowsocks 服务端安装与调优
date: 2017-03-16 18:38:46
tags:
  - 科学上网
  - shadowsocks
categories: shadowsocks
---

买了个海外的 VPS，闲着也是闲着，干脆自己搭个 Shadowsocks（简称 ss）用来查查资料。虽然现在市面上一键安装脚本满天飞，但为了安全起见，也为了搞清楚它到底怎么跑的，我还是习惯自己手动走一遍流程。

顺便把 Linux 的网络内核参数调优也记下来了，不然遇到晚高峰，网速慢得能让人抓狂。

<!-- more -->

## 1. 撸起袖子装环境 (Ubuntu / Debian)

Shadowsocks 原本是 Python 写的，所以先把 Python 环境搞好就行：

```bash
# 先把系统包管理器更新一下
sudo apt-get update

# 装个 python3 和 pip
sudo apt-get install -y python3 python3-pip

# 这一句就装好了，极其简单
sudo pip3 install shadowsocks
```

## 2. 写个配置文件

它不会自动帮你搞配置，得自己新建个文件告诉它监听哪个端口、密码是啥。

```bash
sudo vim /etc/shadowsocks.json
```

我一般用这种最简单的**单端口配置**，自己一个人用够了：

```json
{
  "server": "0.0.0.0",
  "server_port": 8388,
  "local_address": "127.0.0.1",
  "local_port": 1080,
  "password": "密码搞复杂点_1234!",
  "timeout": 300,
  "method": "aes-256-gcm", 
  "fast_open": false
}
```
> `method` 加密方式我选了 `aes-256-gcm`，现在主流客户端都支持，而且速度和安全性平衡得不错。

如果想分享给室友或者同学，怕他们流量乱用想分开算，就搞个**多端口配置**：

```json
{
  "server": "0.0.0.0",
  "local_address": "127.0.0.1",
  "local_port": 1080,
  "port_password": {
    "8381": "室友A的密码",
    "8382": "室友B的密码"
  },
  "timeout": 300,
  "method": "aes-256-gcm",
  "fast_open": false
}
```

## 3. 把服务丢到后台跑（Systemd 托管）

总不能在终端里一直挂着吧。我们把它交给 Linux 自带的 `systemd` 管家，这样就算服务器重启，它也能自动跟着起来。

建个启动脚本：

```bash
sudo vim /etc/systemd/system/shadowsocks.service
```

往里面塞这几句咒语：

```ini
[Unit]
Description=Shadowsocks Server
After=network.target

[Service]
# 注意检查你的 ssserver 装在哪了，有时候在 /usr/bin/ 下面
ExecStart=/usr/local/bin/ssserver -c /etc/shadowsocks.json
Restart=always

[Install]
WantedBy=multi-user.target
```

然后就是一套丝滑的连招，把它跑起来：

```bash
sudo systemctl daemon-reload
sudo systemctl start shadowsocks     # 起飞
sudo systemctl enable shadowsocks    # 设为开机自启，不用管它了
```

## 4. 关键一步：Linux 内核网络优化

很多人装完测速发现看个 720P 都卡。因为 Linux 原生的 TCP 参数是给正常的网页服务器准备的，咱们用来搞数据转发，得给它“打点鸡血”，特别是要开启 BBR 加速。

打开系统内核配置文件：

```bash
sudo vim /etc/sysctl.d/local.conf
```

把下面这些优化参数全部复制进去：

```ini
# 把文件句柄和缓冲区开大，别那么抠搜
fs.file-max = 1024000
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.rmem_default = 65536
net.core.wmem_default = 65536
net.core.netdev_max_backlog = 4096
net.core.somaxconn = 4096

# TCP 连接复用，减少握手浪费的时间
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

# 核心魔法：开启 BBR 拥塞控制（Google 开源的黑科技，速度直接起飞）
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
```

写完保存，然后敲下面这句让它立即生效：

```bash
sudo sysctl --system
```

最后，千万记得去云服务器的后台把安全组/防火墙对应的端口（比如上面的 8388）打开。搞定这些，基本上在本地填好 IP 密码，就可以愉快地去外面看看世界了。
