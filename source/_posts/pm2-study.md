---
title: 记一下 pm2 常用配置及命令
tags:
  - pm2
categories:
  - Node
date: 2018-05-13 16:45:46
---

`PM2` 是 Node.js 应用程序的生产级进程管理器，内置了负载均衡、自动重启、性能监控、日志管理等强大功能，操作轻量且极其高效。本文整理了 PM2 的常用操作、核心启动参数以及生产环境生态配置文件（`ecosystem.config.js`）的最佳实践。

<!-- more -->

## 1. 全局安装

```bash
npm install -g pm2
# 或使用 yarn
yarn global add pm2
```

## 2. 核心常用命令

```bash
# 启动应用
pm2 start app.js               # 启动应用
pm2 start app.js --name my-app # 启动并命名为 my-app

# 进程查看与监控
pm2 list                       # 列出所有由 PM2 管理的进程
pm2 status                     # 查看进程简要状态（同 list）
pm2 monit                      # 终端仪表盘，实时监控 CPU / 内存占用
pm2 show <id|name>             # 查看指定进程的完整详情（含路径、日志位置、环境等）

# 日志查看
pm2 logs                       # 查看所有应用的实时聚合日志
pm2 logs <id|name>             # 查看指定应用的日志
pm2 logs --lines 200           # 查看最后 200 行日志
pm2 flush                      # 清空所有日志文件

# 进程管理与控制
pm2 restart <id|name>          # 重启指定应用
pm2 reload <id|name>           # 【推荐】零停机热重载（仅对集群模式 cluster 生效）
pm2 stop <id|name>             # 停止指定应用
pm2 delete <id|name>           # 删除指定应用
pm2 restart all                # 重启所有应用
pm2 stop all                   # 停止所有应用
pm2 delete all                 # 删除所有应用

# 开机自启
pm2 startup                    # 生成开机自启系统脚本（根据输出提示复制执行）
pm2 save                       # 保存当前运行的应用列表，重启后自动恢复
```

## 3. 命令行常用参数

```bash
pm2 start app.js -i max        # 启用 Cluster 集群模式，并根据 CPU 核心数自动最大化实例
pm2 start app.js --watch       # 监听目录文件变动，自动重启应用（适合开发环境）
pm2 start app.js --ignore-watch="node_modules logs" # 忽略监听指定目录
pm2 start app.js -o ./logs/out.log -e ./logs/err.log # 指定标准输出与错误日志文件路径
pm2 start app.js --max-memory-restart 300M # 内存超过 300MB 时自动重启，防止内存泄漏
```

## 4. 生产环境 Ecosystem 配置文件

在实际项目中，官方推荐使用 JS 格式的配置文件来统一管理环境变量、集群与自动化部署。

### 生成配置文件

```bash
pm2 init simple  # 生成 ecosystem.config.js 模板
```

### `ecosystem.config.js` 示例

```javascript
module.exports = {
  apps: [
    {
      name: 'my-node-app',
      script: './bin/www',
      instances: 'max',            // 集群模式实例数，也可指定具体数字如 2
      exec_mode: 'cluster',        // 运行模式：fork 或 cluster
      autorestart: true,           // 进程崩溃时自动重启
      watch: false,                // 生产环境通常建议关闭文件监听
      max_memory_restart: '500M',  // 限制内存占用上限
      env: {
        NODE_ENV: 'development',
        PORT: 3000
      },
      env_production: {
        NODE_ENV: 'production',
        PORT: 8080
      },
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      error_file: './logs/err.log',
      out_file: './logs/out.log',
      merge_logs: true
    }
  ],

  // 自动化发布部署配置（可选）
  deploy: {
    production: {
      user: 'deploy',
      host: ['192.168.1.100'],
      ref: 'origin/main',
      repo: 'git@github.com:your_username/your_repo.git',
      path: '/var/www/my-node-app',
      'post-deploy': 'npm install && pm2 reload ecosystem.config.js --env production'
    }
  }
};
```

### 使用配置文件启动与管理

```bash
# 以开发环境变量启动
pm2 start ecosystem.config.js

# 以生产环境变量启动
pm2 start ecosystem.config.js --env production

# 热重载配置
pm2 reload ecosystem.config.js --env production
```
