# 光阴小栈 (Blog)

> 思念如马，自别离，未停蹄

本项目是基于 **Hexo** 静态博客框架与定制版 **NexT** 主题构建的个人技术博客。前端静态页面通过 GitHub Pages 和 Cloudflare Pages 双重/多路托管部署，评论与后端交互系统基于 Cloudflare Workers Serverless 架构。

---

## 🛠️ 技术架构

| 模块 | 技术选型 | 说明 |
| :--- | :--- | :--- |
| **博客框架** | [Hexo 4.x](https://hexo.io/) | 极速、强大的 Node.js 静态博客生成器 |
| **博客主题** | [Hexo Theme NexT (Pisces/Gemini)](https://github.com/theme-next/hexo-theme-next) | 高度定制的现代化简洁技术主题 |
| **静态托管** | **GitHub Pages** & **Cloudflare Pages** | GitHub 作为代码源与部署分支（`source` 源码分支 / `main` 静态产物分支），Cloudflare 提供全局 Anycast CDN 加速与 SSL |
| **评论与互动系统** | **Hitalk** (基于 Cloudflare Workers) | 轻量、无服务器的评论后端系统 |
| **评论管理后台** | [Hitalk Admin](https://hitalk-server.youhuabujianye.workers.dev/admin) | 用于审核、管理留言与评论数据的服务端管理面板 |

---

## 📂 项目分支与结构

- **`source` 分支**：存放博客源码、Markdown 文章、主题配置、资源文件等（平时开发与维护所在分支）。
- **`main` 分支**：由 Hexo 自动构建生成的纯静态页面分支（供 GitHub Pages / Cloudflare Pages 静态托管拉取）。

```text
├── _config.yml              # 站点全局配置文件
├── package.json             # 依赖与快捷命令
├── source/                  # 博客内容源文件
│   ├── _data/               # 数据文件（如友链 links.yml）
│   ├── _posts/              # Markdown 博文源文件
│   ├── about/               # 关于页面
│   ├── guestbook/           # 留言板页面
│   ├── links/               # 友情链接页面
│   └── sw.js                # Service Worker 离线缓存脚本
└── themes/
    └── next/                # NexT 主题源码与定制模板
        ├── _config.yml      # 主题配置文件
        └── layout/          # Swig 布局模板
```

---

## 🚀 常用命令

### 1. 本地开发与调试
```bash
# 安装依赖
npm install

# 启动本地开发预览服务器 (默认访问 http://localhost:4000)
npx hexo server
# 简写
npx hexo s
```

### 2. 构建与部署发布
```bash
# 一键清理、重新生成并推送到远程部署分支 (GitHub main)
npm run start

# 仅部署（不重新编译）
npm run deploy

# 手动清理与静态构建
npx hexo clean
npx hexo generate # 或简写 npx hexo g
```

### 3. 新建文章
```bash
# 创建一篇新的博文
npx hexo new "文章标题"
# 文章将生成在 source/_posts/文章标题.md
```

---

## 🌐 部署与服务说明

### 1. 静态托管与 CDN 加速
* **GitHub Pages**：通过 `hexo-deployer-git` 插件，将编译产物推送到 `git@github.com:daipenglcc/hexo.git` 的 `main` 分支。
* **Cloudflare Pages**：可直接关联 GitHub 仓库的 `main` 分支进行边缘部署，享受全球不限流量 CDN 与免费 SSL 证书。

### 2. 评论与交互后台
* **评论管理后台地址**：[https://hitalk-server.youhuabujianye.workers.dev/admin](https://hitalk-server.youhuabujianye.workers.dev/admin)
* 支持对文章评论、留言板留言进行管理、审核与删除。

---

## 📝 开源协议

本项目基于 [MIT](LICENSE) 协议开源。
