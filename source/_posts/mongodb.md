---
title: 各个平台上怎么最快装个 MongoDB
date: 2017-03-23 16:25:11
tags:
  - MongoDB
  - NoSQL
categories: MongoDB
---

平时写全栈小项目，MongoDB 算是个万金油选择，BSON 格式直接跟 Node.js 对接非常顺手。不过每次换个新电脑或者搞个新云服务器，总得去重新查怎么装这玩意。官方文档写的有点太长了，所以在这里把我觉得最省事儿的几种安装方式记下来当个备忘。

<!--more-->

## 1. 怎么装最快？

### ① macOS（认准 Homebrew）

用 Mac 开发的话基本无脑 brew 就行了，没啥好折腾的：

```bash
# 先把官方的库加上
brew tap mongodb/brew

# 下载安装
brew install mongodb-community

# 这俩命令控制后台起停
brew services start mongodb-community
brew services stop mongodb-community
```

### ② Linux (Ubuntu / Debian 服务器上)

买了个云服务器要搭环境的话，一般这么敲：

```bash
# 1. 拿一下官方的签名钥匙
sudo apt-get install -y gnupg curl
curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
   sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor

# 把源地址写进去
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list

# 2. 跑安装
sudo apt-get update
sudo apt-get install -y mongodb-org

# 起飞，顺便弄个开机自启
sudo systemctl start mongod
sudo systemctl enable mongod 
```

### ③ 终极偷懒法：用 Docker （推荐）

管你什么系统，只要电脑上有 Docker，一句命令解决战斗，还不用担心搞脏系统环境：

```bash
# 把宿主机 27017 端口映射出来，顺带把数据存在家目录下面，免得容器一删数据全飞了
docker run -d \
  --name my-mongo \
  -p 27017:27017 \
  -v ~/mongo-data:/data/db \
  mongo:latest
```

### ④ Windows 平台

Windows 就老老实实去 [MongoDB 官方下载中心](https://www.mongodb.com/try/download/community) 下那个 `.msi` 安装包。
安装的时候有个选项叫 **"Install MongoD as a Service"**（就是当成系统服务后台运行），一定要打上勾，一路下一步就行。

## 2. 怎么连上去？

服务起好了之后，你需要知道这俩：

- 默认监听的端口：`27017`
- 默认存数据的文件夹：如果是实体安装，一般在 Linux/Mac 的 `/data/db` 里头。

要进去敲代码测试的话，打开终端输入：

```bash
# 老版本敲 mongo，新版本改成这个了
mongosh
```

进去之后随便敲个 `show dbs` 试试水，如果没报错，那就是妥了，可以开始干活了。
