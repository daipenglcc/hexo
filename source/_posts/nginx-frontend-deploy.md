---
title: 前端部署绕不开的 Nginx 配置备忘录
date: 2021-05-20 15:10:38
tags:
  - Nginx
  - 部署
  - 运维
categories: 运维
---

以前自己部署前端项目，总是在网上到处搜 Nginx 配置，复制过来能跑就不管了。后来踩的坑多了（比如 Vue 单页路由一刷新就 404，或者反向代理跨域调不通），干脆把自己最常用、最稳健的一套配置模板整理出来，以后新开服务器直接拿来套，省事。

<!-- more -->

## 1. 怎么装和起停

用不同的服务器命令稍微有点区别，我一般用 Ubuntu：

```bash
sudo apt install -y nginx
```

装完最常用的几个命令：

```bash
nginx -t                      # 改完配置必须敲这个，检查一下有没有少写分号
sudo nginx -s reload          # 平滑重启，别人还在访问也不会断掉，最常用
sudo systemctl start nginx    # 第一次启动
```

## 2. 部署单页应用（SPA）的标准模板

不管是 Vue、React 还是纯 HTML，基本上这一套就搞定了：

```nginx
# /etc/nginx/conf.d/my-app.conf
server {
    listen 80;
    server_name www.example.com; # 填你的域名

    # 你的 npm run build 打包出来的 dist 文件夹放哪了
    root /var/www/my-app/dist;
    index index.html;

    # 【核心】解决 Vue/React 路由刷新 404 的问题
    # 意思就是：找不到对应的文件或目录，就统统给我回退到 index.html 交给前端路由处理
    location / {
        try_files $uri $uri/ /index.html;
    }

    # 顺手把 css, js 缓存一下，优化下访问速度
    location ~* \.(?:css|js|png|jpg|jpeg|gif|ico)$ {
        expires 30d;
        add_header Cache-Control "public";
    }

    # 但是 index.html 千万不能缓存，不然你更新了代码用户也看不到
    location = /index.html {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }
}
```

## 3. 把后端接口代理一下（反向代理）

前端如果请求 `http://www.example.com/api/...`，咱们就用 Nginx 偷偷把它转给内部跑在 3000 端口的 Node.js 接口，顺便把跨域问题也解决了：

```nginx
server {
    listen 80;
    server_name www.example.com;

    # 前端静态文件照旧
    location / {
        root /var/www/my-app/dist;
        try_files $uri $uri/ /index.html;
    }

    # 把带有 /api/ 的请求，全部转给后端的 3000 端口
    location /api/ {
        proxy_pass http://127.0.0.1:3000/;
        
        # 把用户的真实 IP 传给后端，不然服务端拿到的永远是 127.0.0.1
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

## 4. 上 HTTPS（小绿锁）

现在没个 HTTPS 都不好意思拿出手，免费证书最省事的办法是用 `certbot`：

```bash
# 先装一下 certbot
sudo apt install certbot python3-certbot-nginx

# 然后直接跑这个，它会自动去读你的 nginx 配置帮你改好
sudo certbot --nginx -d example.com -d www.example.com
```

如果证书有了想自己配，大概长这样：

```nginx
# 强制把 80 端口（HTTP）跳转到 HTTPS
server {
    listen 80;
    server_name example.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name example.com;

    # 填你的证书路径
    ssl_certificate     /etc/nginx/ssl/example.com.pem;
    ssl_certificate_key /etc/nginx/ssl/example.com.key;

    # 后面的前端配置跟上面一模一样
    location / {
        root /var/www/dist;
        try_files $uri $uri/ /index.html;
    }
}
```

## 5. 开一下 Gzip 压缩（白嫖加载速度）

在主配置 `/etc/nginx/nginx.conf` 里的 `http` 块加几行代码，大文件能缩小好几倍，加载飞快：

```nginx
http {
    gzip on;
    gzip_min_length 1000;          # 小于 1KB 就别折腾了，压缩了可能更大
    gzip_comp_level 6;             # 压缩级别（1-9），6 是性价比最高的
    gzip_types text/plain text/css application/javascript application/json; # 只压文本类
}
```

基本上对于个人项目或者中小型公司的常规部署，这些配置闭着眼睛抄就够用了。如果出 bug 了（比如 403 / 502），多半是文件夹权限没给，或者后端接口自己先崩了，查一下 `error.log` 一般都能找到凶手。
