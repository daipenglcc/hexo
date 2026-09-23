---
title: 前端折腾 Docker 部署的一些踩坑记录
date: 2020-06-15 16:45:30
tags:
  - Docker
  - 部署
  - DevOps
categories: DevOps
---

以前总觉得 Docker 是后端和运维搞的东西，前端也就是扔个静态资源包（dist）上服务器完事。但后来做的项目越来越杂，老是遇到测试环境和线上环境不一致导致跑不起来的问题，索性学着用 Docker 把前端也打包了。

这里简单整理一点前端常用的 Docker 操作，全当个备忘录。

<!-- more -->

## 1. 最基础的几个概念

说白了，其实就这三个词绕来绕去：
- **镜像（Image）**：你可以把它当成是个装好系统和软件的“安装包”。
- **容器（Container）**：把镜像跑起来，它就变成了一个“容器”，相当于一个轻量级的虚拟机。
- **Dockerfile**：自己写的一个配置脚本，告诉电脑怎么去一步步打包出这个镜像。

## 2. 常用命令备忘

平时用得最多的无非就是查、启、停、删。

```bash
# 拉取别人做好的镜像
docker pull nginx:latest
docker pull node:14-alpine  # alpine 结尾的代表是精简版，体积小很多

# 看看本地有哪些镜像
docker images

# 按照 Dockerfile 构建自己的镜像
docker build -t my-app:1.0 .  

# 跑起来！把本机的 8080 端口映射到容器的 80 端口
docker run -d -p 8080:80 --name my-nginx nginx

# 看看有哪些容器正在跑
docker ps
docker ps -a  # 连挂掉的也一起看

# 启停删
docker stop my-nginx
docker start my-nginx
docker rm my-nginx  # 删容器
docker rmi <image_id>  # 删镜像

# 出 bug 了，想进去看日志或者翻文件
docker logs -f my-nginx
docker exec -it my-nginx /bin/sh
```

## 3. 前端平时怎么写 Dockerfile

一般单页应用（Vue/React），最稳的办法就是搞分步构建。先用 Node 打包出静态文件，再丢给 Nginx 提供服务。

```dockerfile
# 第一步：找个有 node 的环境做打包
FROM node:14-alpine AS builder

WORKDIR /app

# 先拷 package.json，这是为了利用 docker 的缓存机制，省得每次都 npm install
COPY package.json package-lock.json ./
RUN npm ci

# 拷代码，打包
COPY . .
RUN npm run build

# 第二步：找个 nginx 把产物挂上去
FROM nginx:alpine

# 把上一步 /app/dist 里面的文件弄出来，放到 nginx 目录里
COPY --from=builder /app/dist /usr/share/nginx/html

# 如果你自己写了 nginx.conf，顺带替换一下
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

对应的 `nginx.conf` 顺手记一下，做单页路由刷新不 404 全靠它：

```nginx
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    # 核心：刷新时找不到文件就重定向到 index.html
    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

## 4. 前后端一起跑：Docker Compose

如果还有个 Node.js 后端，外加一个 MongoDB 数据库，总不能一个个敲命令跑。搞个 `docker-compose.yml` 比较实在。

```yaml
version: '3.8'

services:
  # 前端
  frontend:
    build: ./frontend
    ports:
      - "80:80"

  # 后端
  backend:
    build: ./backend
    ports:
      - "3000:3000"
    environment:
      - DB_URL=mongodb://mongo:27017/db
    depends_on:
      - mongo

  # 数据库直接拿现成的跑
  mongo:
    image: mongo:4.4
    ports:
      - "27017:27017"
```

写好后，在目录下敲一句 `docker-compose up -d`，全都跑起来了。想关掉就 `docker-compose down`，挺无脑的。

## 5. 几个小坑

1. **别忘了加 `.dockerignore`**：跟 Git 一样，千万记得把 `node_modules` 屏蔽掉，不然打包的时候把本地几十个 G 的包也拷进去，慢得让人怀疑人生。
2. **尽量用 `alpine` 结尾的镜像**：正常的 node 镜像动不动就快一个 G，换成 alpine 版本可能就一两百兆。
3. **留意层级缓存**：写 Dockerfile 的时候，把不常变的命令放前面（比如拷贝 `package.json`），常变的（比如拷贝源码）放后面，下次打包能快不少。

偶尔折腾一下，会发现用 Docker 统一部署环境后，"在我电脑上好好的怎么到服务器就挂了"这种事确实少了不少。
