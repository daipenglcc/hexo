---
title: 日常运维：Linux 常用命令备忘录
date: 2017-05-26 21:49:04
tags:
  - Linux
  - shell
categories: Linux
---

虽然平时主要写业务代码，但有时候出了线上问题，或者自己折腾个小服务器，总得去命令行里查个日志、杀个进程。Linux 命令太多根本记不全，这里把我自己最高频用到的一些烂笔头记下来，省得每次都去现搜。

<!-- more -->

## 1. 装包卸包 (Ubuntu / Debian 系)

```bash
sudo apt-get update              # 先同步下软件源，一般装软件前必敲
sudo apt-get upgrade             # 更新所有软件
sudo apt-get install <package>   # 装软件（比如 git, nginx）
sudo apt-get remove <package>    # 卸载
sudo apt-get autoremove          # 顺手清理下没人要的依赖包
```

## 2. Nginx 起停

折腾自己博客或者前台项目的时候最常用的：

```bash
sudo systemctl start nginx       # 起飞
sudo systemctl stop nginx        # 停掉
sudo systemctl restart nginx     # 重启（比较暴力）
sudo systemctl reload nginx      # 平滑重启（改了配置后一般用这个，不影响正在访问的人）
sudo nginx -t                    # 改完配置文件先测一下有没有手抖敲错
ps -ef | grep nginx              # 看看 nginx 到底在不在跑
```

顺便贴一个单页应用（SPA）最常见的 Nginx 兜底配置：

```nginx
server {
    listen 80 default_server;
    server_name example.com;

    root /var/www/html;
    index index.html;

    # 这个配置最关键，解决 Vue/React 前端路由刷新报 404 的问题
    location / {
        try_files $uri $uri/ /index.html;
    }

    # 静态资源缓存一下
    location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }
}
```

## 3. 查进程和端口

本地开发或者服务器经常遇到“端口被占用”这种恶心事，找犯人就靠这俩：

```bash
lsof -i :80                      # 看看 80 端口被谁占了
netstat -tunlp | grep :80        # 效果差不多

# 找个死循环或者僵尸进程杀掉
ps aux | grep node               # 搜一下 node 相关的进程
kill -9 <PID>                    # 拿着上面搜到的 PID，一枪崩了（-9 是强制）
killall node                     # 嫌麻烦直接团灭所有 node 进程
```

如果是服务器快卡死了，看一下资源：
```bash
df -h                            # 看看硬盘还剩多少空间
du -sh <文件夹>                  # 看看那个该死的 log 文件夹有多大
free -m                          # 看内存
top                              # 动态看 CPU 和内存情况，类似 Windows 的任务管理器
```

## 4. 改权限和压缩解压

遇到什么 "Permission denied"，最简单粗暴但也是最常用的解决方式：

```bash
chmod -R 755 /path/to/dir        # 给个 755 权限（自己能读写执行，别人只能读和执行）
chown -R www-data:www-data /dir  # 把文件夹的主人改成 www-data（部署网站常用）
```

传文件上服务器前，打包解包：

```bash
# tar.gz 最常见
tar -zcvf 打包后的名字.tar.gz /要打包的目录    # 压缩
tar -zxvf 压缩包.tar.gz -C /解压到哪里          # 解压

# zip 格式
zip -r 名字.zip 文件夹/
unzip 压缩包.zip -d /目录
```

## 5. 看点系统信息

```bash
hostname                         # 我在哪台机器上
hostnamectl set-hostname <新名>   # 给机器改个名
cat /etc/hosts                   # 看看本地的 DNS 解析规则
```

平时运维能把上面这些命令敲熟，应付日常 80% 的突发状况感觉也差不多够了。如果还要写复杂的 Shell 脚本，那就老老实实去查手册或者问 AI 吧。
