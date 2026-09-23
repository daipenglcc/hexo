---
title: Docker 入门与前端部署实践
date: 2020-06-15 16:45:30
tags:
  - Docker
  - 部署
  - DevOps
categories: DevOps
---

Docker 已经成为现代应用部署的标准方案。对于前端开发者来说，掌握 Docker 不仅能让项目交付更规范，也能和后端、运维团队更好地协作。本文整理了 Docker 的核心概念、常用命令，以及前端项目的容器化部署实践。

<!-- more -->

## 1. 核心概念

- **镜像（Image）**：一个只读的模板，包含运行应用所需的代码、运行时、库和配置。可以理解为"应用的安装包"
- **容器（Container）**：镜像的运行实例，是一个轻量级的隔离环境。可以理解为"正在运行的应用"
- **Dockerfile**：构建镜像的脚本文件，定义了从基础镜像到最终应用镜像的每一步操作
- **Docker Hub**：官方的镜像仓库，类似 npm registry

> 类比理解：镜像是"类"，容器是"实例"；Dockerfile 是"构造函数"。

## 2. 安装与配置

```bash
# macOS 安装（推荐 Docker Desktop）
brew install --cask docker

# 验证安装
docker --version
docker-compose --version

# 配置国内镜像加速（Docker Desktop → Preferences → Docker Engine）
{
  "registry-mirrors": [
    "https://mirror.ccs.tencentyun.com",
    "https://registry.docker-cn.com"
  ]
}
```

## 3. 常用命令速查

### 镜像操作

```bash
# 拉取镜像
docker pull nginx:latest
docker pull node:14-alpine     # alpine 版本体积更小

# 查看本地镜像
docker images

# 构建镜像
docker build -t my-app:1.0 .   # -t 指定 名称:标签
docker build -t my-app:1.0 -f Dockerfile.prod .  # 指定 Dockerfile

# 删除镜像
docker rmi <image_id>
docker image prune             # 清理悬空镜像
```

### 容器操作

```bash
# 运行容器
docker run -d -p 8080:80 --name my-nginx nginx
# -d: 后台运行
# -p: 端口映射（宿主机:容器内）
# --name: 容器命名

# 查看运行中的容器
docker ps
docker ps -a                   # 包含已停止的容器

# 容器管理
docker stop my-nginx           # 停止
docker start my-nginx          # 启动
docker restart my-nginx        # 重启
docker rm my-nginx             # 删除（需先停止）
docker rm -f my-nginx          # 强制删除

# 进入容器内部
docker exec -it my-nginx /bin/sh

# 查看容器日志
docker logs my-nginx
docker logs -f my-nginx        # 实时跟踪日志
docker logs --tail 100 my-nginx # 最后 100 行
```

## 4. 前端项目 Dockerfile 编写

### 基础版：Nginx 部署 SPA 应用

```dockerfile
# 阶段一：构建
FROM node:14-alpine AS builder

WORKDIR /app

# 先复制 package 文件，利用 Docker 缓存层
COPY package.json package-lock.json ./
RUN npm ci --production=false

# 复制源代码并构建
COPY . .
RUN npm run build

# 阶段二：生产镜像
FROM nginx:alpine

# 复制构建产物到 Nginx 目录
COPY --from=builder /app/dist /usr/share/nginx/html

# 复制自定义 Nginx 配置
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

### Nginx 配置（SPA 路由支持）

```nginx
# nginx.conf
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    # SPA 路由 —— 所有路径都返回 index.html
    location / {
        try_files $uri $uri/ /index.html;
    }

    # 静态资源长缓存
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff2?)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # API 反向代理
    location /api/ {
        proxy_pass http://backend:3000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # 开启 gzip
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml;
    gzip_min_length 1000;
}
```

### Node.js 服务端 Dockerfile

```dockerfile
FROM node:14-alpine

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --production

COPY . .

EXPOSE 3000

# 使用非 root 用户运行（安全实践）
RUN addgroup -g 1001 -S appgroup && \
    adduser -S appuser -u 1001 -G appgroup
USER appuser

CMD ["node", "server.js"]
```

## 5. Docker Compose 多服务编排

在实际项目中，通常需要同时运行前端、后端、数据库等多个服务：

```yaml
# docker-compose.yml
version: '3.8'

services:
  # 前端
  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    ports:
      - "80:80"
    depends_on:
      - backend
    networks:
      - app-network

  # 后端 API
  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - MONGO_URI=mongodb://mongo:27017/myapp
    depends_on:
      - mongo
    networks:
      - app-network

  # 数据库
  mongo:
    image: mongo:4.4
    ports:
      - "27017:27017"
    volumes:
      - mongo-data:/data/db
    networks:
      - app-network

volumes:
  mongo-data:

networks:
  app-network:
    driver: bridge
```

```bash
# Docker Compose 常用命令
docker-compose up -d           # 后台启动所有服务
docker-compose down            # 停止并移除所有容器
docker-compose logs -f         # 查看所有服务日志
docker-compose build           # 重新构建镜像
docker-compose ps              # 查看服务状态
docker-compose exec backend sh # 进入指定服务容器
```

## 6. .dockerignore 文件

和 `.gitignore` 类似，排除不需要复制到镜像中的文件：

```
node_modules
dist
.git
.gitignore
*.md
.env.local
.vscode
.DS_Store
```

## 7. 常用优化技巧

### 镜像体积优化

```bash
# 基础镜像选择对比
node:14          → ~900MB
node:14-slim     → ~200MB
node:14-alpine   → ~110MB   ← 推荐
```

### 构建缓存优化

```dockerfile
# ❌ 不好的写法：每次源码改动都会重新 npm install
COPY . .
RUN npm install
RUN npm run build

# ✅ 优化写法：package.json 没变就复用 npm install 缓存层
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build
```

Docker 是前端走向全栈和 DevOps 的重要一步，掌握基础的容器化技能，在团队协作和项目交付中都会更加从容。
