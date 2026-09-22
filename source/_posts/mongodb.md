---
title: MongoDB安装笔记
date: 2017-03-23 16:25:11
tags:
  - MongoDB
  - NoSQL
categories: MongoDB
---

`MongoDB` 是一个跨平台的、面向文档存储的分布式 NoSQL 数据库，具备高性能、高可用与弹性横向扩展能力。其数据存储格式为 BSON（类似 JSON 的二进制格式），非常契合现代 Web 及 Node.js 应用开发。

<!--more-->

## 1. 各平台安装指南

### ① macOS（推荐 Homebrew）

```bash
# 添加官方 MongoDB Homebrew Tap
brew tap mongodb/brew

# 安装 MongoDB 社区版服务
brew install mongodb-community

# 启动与停止后台服务
brew services start mongodb-community
brew services stop mongodb-community
```

### ② Linux (Ubuntu / Debian)

```bash
# 1. 导入官方 GPG 公钥并添加官方源
sudo apt-get install -y gnupg curl
curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
   sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor

# 添加软件源
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list

# 2. 安装并启动服务
sudo apt-get update
sudo apt-get install -y mongodb-org
sudo systemctl start mongod
sudo systemctl enable mongod # 开机自启
```

### ③ Docker 快速运行（跨平台最推荐）

```bash
# 拉取并运行 MongoDB 容器
docker run -d \
  --name my-mongo \
  -p 27017:27017 \
  -v ~/mongo-data:/data/db \
  mongo:latest
```

### ④ Windows 安装

- 前往 [MongoDB 官方下载中心](https://www.mongodb.com/try/download/community) 下载 `.msi` 安装包。
- 运行安装向导，勾选 **"Install MongoD as a Service"**（自动配置为 Windows 系统服务），一路点击 Next 即可完成。

---

## 2. 数据库启动与连接

### 默认端口与数据目录

- 默认监听端口：`27017`
- 默认数据目录：Linux/macOS 为 `/data/db` 或 `/var/lib/mongodb`

### 客户端连接

在终端中直接运行 MongoDB 交互式 Shell：

```bash
# 连接本地数据库（旧版为 mongo，新版推荐 mongosh）
mongosh
```
