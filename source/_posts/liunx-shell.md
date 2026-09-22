---
title: Linux常用命令笔记
date: 2017-05-26 21:49:04
tags:
  - Linux
  - shell
categories: Linux
---

记录日常开发与服务器运维中高频实用的 `Linux` 命令与核心配置。

<!-- more -->

## 1. 软件安装与管理 (Ubuntu / Debian)

```bash
sudo apt-get update              # 更新软件包列表索引
sudo apt-get upgrade             # 升级已安装的所有软件包
sudo apt-get install <package>   # 安装指定软件包（如 git, nginx, curl）
sudo apt-get remove <package>    # 卸载指定软件包
sudo apt-get autoremove          # 自动清理不再需要的孤立依赖包
```

## 2. Nginx 服务管理与配置

### 服务管理

```bash
sudo systemctl start nginx       # 启动 Nginx
sudo systemctl stop nginx        # 停止 Nginx
sudo systemctl restart nginx     # 重启 Nginx
sudo systemctl reload nginx      # 平滑重载配置文件（不中断现有连接）
sudo nginx -t                    # 测试并检查 Nginx 配置文件语法是否正确
ps -ef | grep nginx              # 查看 Nginx 相关进程
```

### 基础 Nginx 配置示例

文件路径：`/etc/nginx/sites-available/default` 或 `/etc/nginx/conf.d/default.conf`

```nginx
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name example.com www.example.com;

    root /var/www/html;
    index index.html index.htm;

    location / {
        try_files $uri $uri/ /index.html =404;
    }

    # 静态资源缓存配置
    location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }

    error_page 404 /404.html;
    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        root /var/www/html;
    }
}
```

## 3. 常用系统与进程管理命令

```bash
# 端口与网络占用
lsof -i :80                      # 查看 80 端口被哪个进程占用
netstat -tunlp | grep :80        # 查看监听 80 端口的程序

# 进程管理
ps aux | grep node               # 查找指定程序的进程号 (PID)
kill -9 <PID>                    # 强制结束指定 PID 的进程
killall node                     # 结束所有同名进程

# 磁盘与内存查看
df -h                            # 查看磁盘各分区使用空间
du -sh <dir_name>                # 查看指定文件夹占用的总大小
free -m                          # 查看当前内存使用情况（以 MB 为单位）
top                              # 实时监控 CPU、内存占用及进程动态
```

## 4. 文件权限与归档解压

### 权限管理（chmod / chown）

```bash
chmod 755 filename               # 所有人可读可执行，仅属主可写
chmod -R 755 /path/to/dir        # 递归修改目录下所有文件的权限
chown -R www-data:www-data /var/www # 递归修改文件/目录的拥有者与用户组
```

> **权限数字含义**：`r` (读)=4，`w` (写)=2，`x` (执行)=1。
> 例如 `7 (4+2+1)` 为读写执行全部权限，`5 (4+1)` 为读与执行权限。

### 打包与解压（tar / zip）

```bash
# tar.gz 格式
tar -zcvf archive.tar.gz /path   # 打包并压缩指定目录
tar -zxvf archive.tar.gz         # 解压到当前目录
tar -zxvf archive.tar.gz -C /dir # 解压到指定目录

# zip 格式
zip -r archive.zip folder/       # 压缩为 zip 文件
unzip archive.zip -d /dir        # 解压 zip 文件到指定目录
```

## 5. Linux 用户与密码安全文件

系统用户信息主要保存在 `/etc/passwd` 和 `/etc/shadow`：

### `/etc/passwd` 结构解析

```text
root:x:0:0:root:/root:/bin/bash
```

1. **用户名**（如 `root`）
2. **密码占位符**（统一显示为 `x`，真实加密密码存放在 shadow 文件中）
3. **UID**（用户 ID，0 为 root，普通用户一般为 1000+）
4. **GID**（所属主组 ID）
5. **用户描述信息**
6. **用户主目录**（如 `/root` 或 `/home/username`）
7. **登录后默认 Shell**（如 `/bin/bash`）

## 6. 主机名与 Hosts 解析

```bash
hostname                         # 查看当前主机名
hostnamectl set-hostname <新名称> # 永久修改主机名（Systemd 标准命令）
cat /etc/hosts                   # 查看本地 DNS 解析映射表
```
