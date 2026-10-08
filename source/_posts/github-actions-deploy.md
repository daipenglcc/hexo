---
title: GitHub Actions 搞前端自动化部署，告别手动 scp
date: 2020-08-18 15:20:40
tags:
  - CI/CD
  - GitHub Actions
  - 自动化部署
categories: DevOps
---

以前项目部署的流程：本地 `npm run build`，然后用 scp 或者 FTP 把 dist 文件夹传到服务器上。遇到着急上线的时候一紧张还容易传错目录。后来了解了 GitHub Actions，发现配置其实不难，一次搞好之后 push 代码就自动构建部署了，省了不少麻烦事。

<!-- more -->

## 1. GitHub Actions 是啥

就是 GitHub 自带的 CI/CD 服务，在你的仓库里建个 `.github/workflows/xxx.yml` 文件，每次 push 或 PR 的时候 GitHub 会自动起一台虚拟机帮你跑这个脚本。

对个人项目和小团队来说免费额度完全够用。

## 2. 基本概念

几个概念先搞清楚：

- **Workflow**：一个自动化流程，对应一个 yml 文件
- **Job**：流程里的一组步骤，跑在同一台机器上
- **Step**：具体的一步操作（跑命令、用别人写好的 Action 等）
- **Trigger**：触发条件（push、PR、定时等）

## 3. 最简单的：构建并部署到 GitHub Pages

这个适合博客、文档站、纯前端项目。

```yaml
# .github/workflows/deploy.yml
name: 构建并部署

on:
  push:
    branches: [ main ]  # main 分支有 push 就触发

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest  # 用 Ubuntu 虚拟机

    steps:
      # 第一步：拉代码
      - name: 拉取代码
        uses: actions/checkout@v3

      # 第二步：装 Node.js
      - name: 安装 Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'  # 缓存 node_modules，下次快一点

      # 第三步：装依赖 + 构建
      - name: 安装依赖
        run: npm ci

      - name: 构建
        run: npm run build

      # 第四步：部署到 GitHub Pages
      - name: 部署到 Pages
        uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./dist
```

推代码到 main 分支，去仓库的 Actions 标签页就能看到它在跑了。跑完之后 dist 目录会被推到 `gh-pages` 分支，GitHub Pages 自动更新。

## 4. 部署到自己的服务器

如果是部署到自己的 VPS，一般用 SSH + rsync：

```yaml
name: 部署到服务器

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3
      
      - uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'

      - run: npm ci
      - run: npm run build

      # 通过 SSH 把 dist 同步到服务器
      - name: 部署到服务器
        uses: easingthemes/ssh-deploy@v4
        with:
          SSH_PRIVATE_KEY: ${{ secrets.SSH_PRIVATE_KEY }}
          REMOTE_HOST: ${{ secrets.SERVER_HOST }}
          REMOTE_USER: ${{ secrets.SERVER_USER }}
          SOURCE: 'dist/'
          TARGET: '/var/www/my-site/'
```

这里需要在仓库的 Settings → Secrets 里配置几个变量：

- `SSH_PRIVATE_KEY`：你服务器的 SSH 私钥
- `SERVER_HOST`：服务器 IP
- `SERVER_USER`：登录用户名（一般是 root 或者自定义的）

**注意：千万别把私钥直接写在 yml 文件里。** Secrets 里的变量在日志中会被自动脱敏。

## 5. 多环境部署

实际项目往往有测试环境和正式环境，可以用不同的分支触发不同的部署：

```yaml
name: 多环境部署

on:
  push:
    branches:
      - develop  # 推到 develop 分支 → 部署测试环境
      - main     # 推到 main 分支 → 部署正式环境

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'
      - run: npm ci

      # 根据分支决定环境
      - name: 构建测试环境
        if: github.ref == 'refs/heads/develop'
        run: npm run build:staging

      - name: 构建正式环境
        if: github.ref == 'refs/heads/main'
        run: npm run build:production

      - name: 部署到测试服务器
        if: github.ref == 'refs/heads/develop'
        uses: easingthemes/ssh-deploy@v4
        with:
          SSH_PRIVATE_KEY: ${{ secrets.SSH_PRIVATE_KEY }}
          REMOTE_HOST: ${{ secrets.STAGING_HOST }}
          REMOTE_USER: root
          SOURCE: 'dist/'
          TARGET: '/var/www/staging/'

      - name: 部署到正式服务器
        if: github.ref == 'refs/heads/main'
        uses: easingthemes/ssh-deploy@v4
        with:
          SSH_PRIVATE_KEY: ${{ secrets.SSH_PRIVATE_KEY }}
          REMOTE_HOST: ${{ secrets.PRODUCTION_HOST }}
          REMOTE_USER: root
          SOURCE: 'dist/'
          TARGET: '/var/www/production/'
```

## 6. 一些小技巧

### 缓存 node_modules 加速

`actions/setup-node@v3` 自带 cache 功能，第二次构建会快很多。也可以手动缓存：

```yaml
- name: 缓存依赖
  uses: actions/cache@v3
  with:
    path: node_modules
    key: ${{ runner.os }}-node-${{ hashFiles('package-lock.json') }}
```

### 构建失败发通知

可以在最后加一步，构建失败时发个钉钉或者企微通知：

```yaml
- name: 通知钉钉
  if: failure()
  uses: fifsky/dingtalk-action@master
  with:
    url: ${{ secrets.DINGTALK_WEBHOOK }}
    type: markdown
    content: |
      ### 🔴 构建失败
      - 分支: ${{ github.ref }}
      - 提交: ${{ github.event.head_commit.message }}
```

### 只在特定文件变更时触发

如果不想每次改个 README 都触发构建：

```yaml
on:
  push:
    branches: [ main ]
    paths:
      - 'src/**'
      - 'package.json'
      - 'vite.config.js'
```

搞完这些之后，写代码 → push → 自动构建部署，整个流程很丝滑。再也不用本地打包然后手动传服务器了，连半夜紧急修 bug 都轻松不少。
