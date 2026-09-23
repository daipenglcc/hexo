---
title: NPM 高频命令速查：除了 install 还有啥
date: 2017-05-10 03:25:24
tags:
  - npm
  - Node
categories: Node
---

写了这么久前端，天天敲 `npm i` 和 `npm run dev`。但有时候遇到点奇葩需求，比如要看看某个包在网上的最新版是多少，或者想换个镜像源，甚至是想把自己写的小工具发到 npm 上，往往还得去翻官方那堆长长的文档。

索性把自己平时偶尔会用到、但又死活记不全的命令整理出来，当个个人的速查表。

<!-- more -->

## 1. 查资料查版本

不知道某个包该装什么版本时最常用：

```bash
npm info <包名>          # 把这个包祖宗十八代的信息全查出来
npm info <包名> version  # 我就想看一眼线上最新版是多少
npm outdated            # 看看我项目里有哪些老古董包该更新了
```

查本地装了什么：
```bash
npm list --depth=0      # 只看第一层的依赖，不然会打印出一颗很长很长的依赖树把你淹没
npm list -g --depth=0   # 看看你电脑全局都装了什么乱七八糟的脚手架
```

## 2. 玩转 Install 

除了无脑 `npm i`，其实还有几个场景挺讲究的：

```bash
npm i vue@3.2.0         # 指名道姓装某个版本
npm i webpack -D        # 加个 -D (等于 --save-dev)，意思是开发时候用的工具，打包上线就扔了
npm i -g nodemon        # 装在全局，以后在哪个文件夹都能用这个命令

# 部署服务器的时候极其有用：
npm i --production      # 只装生产环境需要的包，省时间省空间
npm ci                  # 比 install 快，而且严格按照 package-lock.json 来装，防扯皮
```

## 3. npm 镜像源那点事

国内网络你懂的，连官方源有时候慢得让人怀疑人生：

```bash
# 看一下现在用的是啥源
npm config get registry

# 换成淘宝源（新版域名）
npm config set registry https://registry.npmmirror.com/

# 偶尔想切回官方源（比如你要发包的时候）
npm config set registry https://registry.npmjs.org/
```

> **小建议**：直接全局装个 `nrm` (`npm i -g nrm`)，切换镜像源跟切歌一样简单：`nrm use taobao`。

## 4. 本地写了个包想测试（npm link）

比如你自己写了个叫 `my-tool` 的包，还没发版，但你想在旁边的业务项目里试试水：

```bash
# 1. 先进你自己写的包里，打个标记
cd my-tool
npm link

# 2. 去业务项目里，把它拉过来用
cd ../my-web-project
npm link my-tool

# 3. 试完没问题了，解除绑定
npm unlink my-tool
```

## 5. 自己发包去 npm

如果有开源精神，或者想装装逼，发包其实特别简单：

```bash
# 1. 首先你得去 npm 官网注册个账号
# 2. 在命令行里登录
npm login

# 3. 每次发版前改下版本号（比如从 1.0.0 变成 1.0.1）
npm version patch

# 4. 发射！
npm publish
```

平时干活基本上也就这些了。遇到再偏门的命令，多半也是遇到了什么奇奇怪怪的工程化难题，到时候再 Google 也不迟。
