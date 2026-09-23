---
title: Nginx 配置详解与前端部署最佳实践
date: 2021-05-20 15:10:38
tags:
  - Nginx
  - 部署
  - 运维
categories: 运维
---

Nginx 是前端部署绕不开的核心组件。不论是简单的静态站点托管，还是复杂的反向代理、负载均衡和 HTTPS 证书配置，都离不开 Nginx 的身影。本文从前端开发者的实际需求出发，系统整理 Nginx 的安装、核心配置、常见场景和性能调优。

<!-- more -->

## 1. 安装与基础命令

```bash
# CentOS / RHEL
sudo yum install -y nginx

# Ubuntu / Debian
sudo apt install -y nginx

# macOS
brew install nginx
```

```bash
# 常用管理命令
nginx                         # 启动
nginx -s stop                 # 快速停止
nginx -s quit                 # 优雅停止（处理完当前请求后退出）
nginx -s reload               # 热重载配置（不中断服务）
nginx -t                      # 测试配置文件语法是否正确
nginx -V                      # 查看版本和编译参数

# systemd 管理
sudo systemctl start nginx
sudo systemctl enable nginx    # 开机自启
sudo systemctl status nginx
```

## 2. 配置文件结构

Nginx 的主配置文件通常在 `/etc/nginx/nginx.conf`：

```nginx
# 全局配置
worker_processes auto;         # 工作进程数，auto 自动匹配 CPU 核心
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;   # 每个进程最大连接数
    use epoll;                 # Linux 高性能事件模型
}

http {
    include       mime.types;
    default_type  application/octet-stream;

    # 日志格式
    log_format main '$remote_addr - $remote_user [$time_local] '
                    '"$request" $status $body_bytes_sent '
                    '"$http_referer" "$http_user_agent"';
    access_log /var/log/nginx/access.log main;

    sendfile        on;
    tcp_nopush      on;
    keepalive_timeout 65;

    # 引入各站点配置
    include /etc/nginx/conf.d/*.conf;
}
```

## 3. 静态站点部署（SPA 应用）

最常见的前端部署场景：

```nginx
# /etc/nginx/conf.d/my-app.conf
server {
    listen 80;
    server_name www.vueweb.cn vueweb.cn;
    root /var/www/my-app/dist;
    index index.html;

    # SPA 路由支持 —— 最重要的配置
    location / {
        try_files $uri $uri/ /index.html;
    }

    # 静态资源缓存策略
    # 带 hash 的文件（如 app.a1b2c3.js）设置长期缓存
    location ~* \.(?:css|js)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # 图片和字体缓存
    location ~* \.(?:png|jpg|jpeg|gif|ico|svg|woff2?|ttf|eot)$ {
        expires 30d;
        add_header Cache-Control "public";
    }

    # index.html 不缓存（确保用户获取最新版本）
    location = /index.html {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }
}
```

## 4. 反向代理

将 API 请求转发到后端服务：

```nginx
server {
    listen 80;
    server_name www.vueweb.cn;

    # 前端静态文件
    location / {
        root /var/www/my-app/dist;
        try_files $uri $uri/ /index.html;
    }

    # API 反向代理到 Node.js 后端
    location /api/ {
        proxy_pass http://127.0.0.1:3000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # 超时设置
        proxy_connect_timeout 60s;
        proxy_read_timeout 120s;
        proxy_send_timeout 60s;
    }

    # WebSocket 代理
    location /ws/ {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
    }
}
```

## 5. HTTPS 配置

```nginx
# HTTP 强制跳转 HTTPS
server {
    listen 80;
    server_name www.vueweb.cn vueweb.cn;
    return 301 https://$server_name$request_uri;
}

# HTTPS 主配置
server {
    listen 443 ssl http2;
    server_name www.vueweb.cn;

    # SSL 证书
    ssl_certificate     /etc/nginx/ssl/vueweb.cn.pem;
    ssl_certificate_key /etc/nginx/ssl/vueweb.cn.key;

    # SSL 优化配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # HSTS（强制浏览器使用 HTTPS）
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    root /var/www/my-app/dist;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

### Let's Encrypt 免费证书

```bash
# 安装 Certbot
sudo apt install certbot python3-certbot-nginx

# 自动申请证书并配置 Nginx
sudo certbot --nginx -d vueweb.cn -d www.vueweb.cn

# 证书自动续期（certbot 会自动添加定时任务）
sudo certbot renew --dry-run
```

## 6. Gzip 压缩

```nginx
http {
    # 开启 Gzip
    gzip on;
    gzip_vary on;
    gzip_min_length 1000;          # 小于 1KB 不压缩
    gzip_comp_level 6;              # 压缩级别 1-9
    gzip_proxied any;
    gzip_types
        text/plain
        text/css
        text/javascript
        application/javascript
        application/json
        application/xml
        image/svg+xml;

    # 对已有 .gz 文件直接返回（配合 Vite/Webpack 预压缩）
    gzip_static on;
}
```

## 7. 负载均衡

当后端有多台服务器时：

```nginx
upstream backend_servers {
    # 加权轮询
    server 192.168.1.101:3000 weight=3;
    server 192.168.1.102:3000 weight=2;
    server 192.168.1.103:3000 weight=1;

    # 备用服务器（主服务器全挂时启用）
    server 192.168.1.104:3000 backup;

    # 健康检查
    # server 192.168.1.105:3000 max_fails=3 fail_timeout=30s;
}

server {
    listen 80;
    server_name api.vueweb.cn;

    location / {
        proxy_pass http://backend_servers;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

## 8. 安全配置

```nginx
server {
    # 隐藏 Nginx 版本号
    server_tokens off;

    # 防止点击劫持
    add_header X-Frame-Options "SAMEORIGIN" always;

    # XSS 防护
    add_header X-XSS-Protection "1; mode=block" always;

    # 阻止 MIME 类型嗅探
    add_header X-Content-Type-Options "nosniff" always;

    # 禁止访问隐藏文件（.git, .env 等）
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    # 限制请求体大小（防止大文件上传攻击）
    client_max_body_size 10m;
}
```

## 9. 常见问题排查

```bash
# 查看错误日志
tail -f /var/log/nginx/error.log

# 测试配置文件
nginx -t

# 查看 Nginx 进程
ps aux | grep nginx

# 查看端口占用
lsof -i :80
netstat -tlnp | grep 80
```

| 错误 | 常见原因 | 解决方案 |
| :--- | :--- | :--- |
| 403 Forbidden | 目录权限不足 | `chmod -R 755` + 检查 `user` 配置 |
| 502 Bad Gateway | 后端服务未启动 | 检查 `proxy_pass` 目标是否正常 |
| 504 Gateway Timeout | 后端响应超时 | 增大 `proxy_read_timeout` |
| 404 刷新页面 | SPA 路由未配置 | 添加 `try_files $uri /index.html` |

Nginx 的配置灵活且强大，掌握上述常用场景基本能覆盖大多数前端部署需求。
