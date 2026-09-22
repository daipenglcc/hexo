---
title: NPM 学习笔记整理
date: 2017-05-10 03:25:24
tags:
  - npm
  - Node
categories: Node
---

`npm`（Node Package Manager）之于 `Node.js` ，就像 `pip` 之于 `Python` ， `composer` 之于 `PHP` 。
它是 Node.js 官方提供的包管理工具，集成了包的发布、下载、依赖版本控制与自动化脚本管理。

<!-- more -->

## 1. 什么是 NPM

`npm` 随 Node.js 一同安装，主要解决 Node.js 模块生态与项目工程化管理问题：
- 从 npm 官方仓库下载第三方开源库到本地使用；
- 下载并安装 CLI 命令行工具（如 `eslint`, `typescript`, `vite`）；
- 将自己编写的开源模块发布并托管到 npm 社区供全球开发者使用。

## 2. 安装与更新

`npm` 在安装 Node.js 时会自动安装。若需升级到最新版本：

```bash
# macOS / Linux 全局更新 npm
npm install -g npm@latest

# 查看版本及全局配置
npm -v
npm config list
```

## 3. 常用操作命令

### 初始化项目（npm init）

```bash
npm init     # 交互式引导生成 package.json
npm init -y  # 跳过所有问答，直接生成默认的 package.json
```

### 搜索与信息查询

```bash
npm search <package_name>      # 搜索模块
npm info <package_name>        # 查看模块的详细元信息（如版本号、主页、维护者）
npm info <package_name> version# 快速查看模块的最新线上版本
```

### 安装模块（npm install）

`npm install` 可以简写为 `npm i`：

```bash
# 1. 本地安装生产依赖（默认写入 dependencies）
npm i lodash
npm i lodash --save            # 显式写入 dependencies（简写 -S）

# 2. 本地安装开发依赖（写入 devDependencies）
npm i webpack --save-dev       # 显式写入 devDependencies（简写 -D）

# 3. 全局安装 CLI 工具
npm i -g nodemon

# 4. 安装指定版本
npm i vue@3.2.45
npm i react@latest

# 5. 仅安装生产环境依赖（适用于生产部署服务器）
npm i --production
# 或通过环境变量
NODE_ENV=production npm i
```

#### 本地模式 vs 全局模式

| 模式 | 安装路径 | 代码中可 `require`/`import` | 是否注册到系统 PATH | 适用场景 |
| :--- | :--- | :---: | :---: | :--- |
| **本地安装** | 当前项目 `./node_modules` | ✅ 是 | ❌ 否（项目内生效） | 业务依赖库（Vue, React, Lodash） |
| **全局安装** | 系统全局目录 | ❌ 否 | ✅ 是 | CLI 脚手架工具（pm2, nrm, yarn） |

### 卸载与更新依赖

```bash
npm uninstall <package_name>   # 卸载依赖并从 package.json 移除
npm update <package_name>      # 升级依赖到符合 semver 约束的最新版
npm outdated                   # 检查项目中哪些依赖包已有新版本
```

### 查看已安装的依赖（npm list）

```bash
npm list                       # 树状展示当前项目的所有依赖
npm list --depth=0             # 仅展示顶层直接依赖（推荐，避免冗长）
npm list -g --depth=0          # 查看全局安装的一级模块
```

## 4. 依赖管理详解（dependencies vs devDependencies）

在 `package.json` 中，最关键的两个依赖字段：

```json
{
  "name": "my-app",
  "version": "1.0.0",
  "dependencies": {
    "axios": "^1.2.0"
  },
  "devDependencies": {
    "eslint": "^8.28.0",
    "vite": "^4.0.0"
  }
}
```

- **`dependencies`（生产依赖）**：项目上线在浏览器或服务器运行时必须依赖的代码库。
- **`devDependencies`（开发依赖）**：仅在本地开发、编译打包、代码校验或单元测试时使用的工具包，在打包成产物上线后并不运行。

## 5. 脚本运行（npm run）

`package.json` 的 `scripts` 字段用于定义自动化执行脚本：

```json
{
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "lint": "eslint . --ext .js,.vue",
    "test": "vitest"
  }
}
```

- 运行脚本：`npm run <script-name>`（例如 `npm run dev`）。
- **特例简写**：`npm start` 和 `npm test` 可以省略中间的 `run`。
- **串行与并行执行**：
  - `&&`：串行执行，前一个成功后才执行后一个（如 `"build": "npm run lint && vite build"`）。
  - `&`：并行同时执行两个任务。

### 脚本生命周期钩子（pre / post）

npm 会在执行特定脚本前后自动触发 `pre<script>` 和 `post<script>` 钩子：

```json
{
  "scripts": {
    "prebuild": "npm run lint",
    "build": "vite build",
    "postbuild": "echo 'Build completed!'"
  }
}
```
*执行 `npm run build` 时，会按顺序自动执行 `prebuild` -> `build` -> `postbuild`。*

## 6. 本地软链接调试（npm link）

在开发本地 npm 包或公共基础库时，无需反复发布即可在另一个业务项目中实时调试：

```bash
# 1. 在公共库项目根目录下执行，注册为全局软链接
cd my-components
npm link

# 2. 在使用该组件库的业务项目根目录下关联
cd my-web-app
npm link my-components

# 3. 调试结束后解除软链接
npm unlink my-components
```

## 7. 发布属于自己的 npm 包

1. **注册账号**：前往 [npmjs.com](https://www.npmjs.com/) 注册个人账号。
2. **终端登录**：
   ```bash
   npm login
   npm whoami   # 检查当前登录的用户名
   ```
3. **完善 `package.json`**：确保 `name` 具备唯一性且未被占用，声明 `version` 与 `main` 入口。
4. **发布上线**：
   ```bash
   npm publish
   ```
5. **版本迭代更新**：
   ```bash
   npm version patch  # 自动更新补丁版本号（1.0.0 -> 1.0.1）
   npm publish
   ```





