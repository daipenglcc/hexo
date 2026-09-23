---
title: Node.js 必备：PM2 常用保活命令备忘
tags:
  - pm2
categories:
  - Node
date: 2018-05-13 16:45:46
---

以前刚搞 Node.js 的时候，写完接口直接在服务器敲个 `node app.js` 就算上线了。结果 ssh 终端一关，或者代码抛个异常没接住，服务当场就挂了。后来老老实实切到了 PM2，它能帮你一直在后台盯着进程，挂了自动重启，算是彻底告别了半夜起来修接口的噩梦。

这里整理点我平时用的操作和配置文件写法。

<!-- more -->

## 1. 怎么装

一般直接全局装，省事：

```bash
npm install -g pm2
```

## 2. 最常用的几个命令

平时基本上就在敲这几个：

```bash
# 最无脑的启动方式
pm2 start app.js               # 启动应用
pm2 start app.js --name api    # 顺便给进程起个名字，以后好找

# 看看现在有哪些服务在跑
pm2 list                       # 这个敲得最多，看大表哥
pm2 monit                      # 终端里看个比较骚的监控面板，看 CPU 内存

# 查日志（比自己去翻 log 文件爽多了）
pm2 logs                       # 看所有应用的日志
pm2 logs api                   # 只看那个叫 api 的应用的日志
pm2 flush                      # 日志太多了看不清，全清空掉

# 起停重启
pm2 restart api                # 重启
pm2 reload api                 # 【强烈推荐】这个叫平滑重启，不会让正在访问的用户断掉
pm2 stop api                   # 停掉
pm2 delete api                 # 彻底删掉，不想管了
```

## 3. 服务器重启了怎么办？

这是个痛点，服务器万一断电重启了，PM2 进程也会没。所以一般装完后会配个开机自启：

```bash
# 第一步：它会生成一行命令给你，你复制粘贴回车运行一下
pm2 startup

# 第二步：把你现在的进程保存下来
pm2 save
```
以后服务器怎么重启，之前的进程都会自动恢复。

## 4. 进阶玩法：配置文件

如果你的项目比较正规，需要传很多环境变量（比如告诉代码现在是线上环境还是测试环境），用命令行敲太长了。官方推荐搞个 `ecosystem.config.js` 文件。

直接敲 `pm2 init simple` 就能生成个模板，我一般会改造成下面这样：

```javascript
module.exports = {
  apps: [
    {
      name: 'my-node-app',
      script: './app.js',
      
      // 让它自己看服务器有几个 CPU 核心，能开几个开几个，榨干性能
      instances: 'max',            
      exec_mode: 'cluster',        
      
      // 挂了自动重启
      autorestart: true,           
      
      // 防止代码有内存泄漏，超过 500M 强制让它重启一下
      max_memory_restart: '500M',  
      
      // 日志输出的位置
      error_file: './logs/err.log',
      out_file: './logs/out.log',
      
      // 测试环境的环境变量
      env: {
        NODE_ENV: 'development',
        PORT: 3000
      },
      // 线上环境的环境变量
      env_production: {
        NODE_ENV: 'production',
        PORT: 8080
      }
    }
  ]
};
```

弄好这个文件后，启动就很优雅了：

```bash
# 测试环境启动
pm2 start ecosystem.config.js

# 线上环境启动（自动走 env_production 里的配置）
pm2 start ecosystem.config.js --env production
```

这玩意儿可以说是写 Node 服务端的标配了，简单粗暴不出错。
