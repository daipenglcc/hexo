---
title: Hexo 最常用的几个命令
date: 2015-08-28 18:29:33
tags:
  - hexo
  - 光阴小栈
categories: Hexo
---
Hexo 提供了丰富的命令行工具，日常写作与博客管理最常用的核心命令如下：

<!-- more -->

## 1. 本地启动预览（hexo server）

```bash
hexo s
# 或者是完整命令：hexo server
# 可指定端口：hexo s -p 5000
```

- **说明**：启动本地开发服务器，默认访问地址为 `http://localhost:4000/`。
- **特性**：支持热重载，在修改文章内容或大部分主题文件后，保存并刷新浏览器即可实时预览。
- **注意**：修改站点根目录的 `_config.yml` 或主题配置后，通常需要重启本地服务方能生效。

## 2. 新建文章与页面（hexo new）

```bash
# 新建普通文章（标题含空格需加引号）
hexo new "我的第一篇博客"

# 新建独立自定义页面（如 about 页面，生成在 source/about/index.md）
hexo new page about
```

- **说明**：新建文章会根据 `scaffolds/post.md` 模板在 `source/_posts/` 下生成 `.md` 文件。
- **技巧**：独立页面生成后，其访问 URL 为 `域名/about/`，不会出现在首页文章流中。

## 3. 生成静态文件（hexo generate）

```bash
hexo g
# 完整命令：hexo generate
# 监听文件变动并实时编译：hexo g --watch
```

- **说明**：解析 Markdown、模板和静态资源，将编译后的所有网页静态文件输出到 `public/` 目录下。

## 4. 清理缓存（hexo clean）

```bash
hexo clean
```

- **说明**：清除 Hexo 数据库缓存文件 `db.json` 和生成的 `public/` 文件夹。
- **场景**：当文章更新后网页未发生变化、标签/分类混乱或页面渲染异常时，先执行 `hexo clean` 再重新编译通常能解决 90% 的问题。

## 5. 一键部署（hexo deploy）

```bash
hexo d
# 完整命令：hexo deploy
```

- **说明**：自动将 `public` 中的静态页面推送到 `_config.yml` 中配置的远程仓库（如 GitHub Pages、云服务器等）。

## 💡 常用组合命令

```bash
# 日常发布文章黄金流程：清理 -> 生成 -> 部署
hexo clean && hexo g && hexo d
```
