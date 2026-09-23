---
title: Vite 从入门到深度使用
date: 2021-01-10 10:30:22
tags:
  - Vite
  - 前端工程化
categories: 前端工程化
---

Vite 是由 Vue 的作者尤雨溪开发的下一代前端构建工具。它利用浏览器原生 ES Module 和 esbuild 实现了极速的开发服务器启动和热更新，彻底改变了前端开发体验。相比 Webpack 动辄几十秒的冷启动，Vite 的"秒开"体验让人用过就回不去了。

<!-- more -->

## 为什么选择 Vite？

传统的打包工具（如 Webpack）在开发模式下需要先把所有模块打包成 bundle 再启动服务器，项目越大启动越慢。Vite 换了一种思路：

1. **开发环境**：直接利用浏览器原生 ESM，按需编译，不打包
2. **生产环境**：使用 Rollup 进行高效打包

```
传统方式:  源码 → [打包整个应用] → 启动服务器 → 等几十秒...
Vite 方式: 源码 → 启动服务器（毫秒级）→ 浏览器按需请求模块 → 即时编译
```

## 1. 快速上手

```bash
# 创建项目（支持多种模板）
npm create vite@latest my-project -- --template vue
npm create vite@latest my-react-app -- --template react-ts
npm create vite@latest my-vanilla-app -- --template vanilla

# 进入项目并启动
cd my-project
npm install
npm run dev    # 感受一下秒开的快感
```

支持的模板：`vanilla`、`vue`、`vue-ts`、`react`、`react-ts`、`preact`、`lit`、`svelte`

## 2. 项目结构

```
my-project/
├── index.html          # 入口 HTML（在项目根目录！）
├── package.json
├── vite.config.js      # Vite 配置文件
├── src/
│   ├── main.js         # 应用入口
│   ├── App.vue
│   ├── assets/         # 静态资源
│   └── components/
└── public/             # 不经过构建的静态文件
```

> 与 Webpack 不同，`index.html` 在 Vite 中是入口文件，而不是放在 public 目录中。

## 3. vite.config.js 配置详解

```javascript
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import path from 'path'

export default defineConfig({
  // 插件
  plugins: [vue()],

  // 路径别名
  resolve: {
    alias: {
      '@': path.resolve(__dirname, 'src'),
      '@components': path.resolve(__dirname, 'src/components'),
      '@utils': path.resolve(__dirname, 'src/utils')
    }
  },

  // 开发服务器
  server: {
    port: 3000,
    open: true,        // 自动打开浏览器
    host: '0.0.0.0',   // 局域网可访问
    // API 代理
    proxy: {
      '/api': {
        target: 'http://localhost:8080',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api/, '')
      }
    }
  },

  // 构建配置
  build: {
    outDir: 'dist',
    sourcemap: false,
    // 分包策略
    rollupOptions: {
      output: {
        chunkFileNames: 'js/[name]-[hash].js',
        entryFileNames: 'js/[name]-[hash].js',
        assetFileNames: '[ext]/[name]-[hash].[ext]',
        manualChunks: {
          // 将 vue 相关库单独打包
          'vue-vendor': ['vue', 'vue-router', 'pinia'],
          // 将 UI 库单独打包
          'ui-vendor': ['element-plus']
        }
      }
    },
    // 小于 4KB 的资源内联为 base64
    assetsInlineLimit: 4096,
    // 启用 CSS 代码拆分
    cssCodeSplit: true
  },

  // CSS 预处理器配置
  css: {
    preprocessorOptions: {
      scss: {
        additionalData: `@import "@/styles/variables.scss";`
      },
      less: {
        javascriptEnabled: true
      }
    }
  },

  // 环境变量前缀
  envPrefix: 'APP_'
})
```

## 4. 环境变量

Vite 使用 `.env` 文件管理环境变量：

```bash
# .env                 # 所有环境
APP_TITLE=光阴小栈

# .env.development     # 开发环境
APP_API_BASE=http://localhost:8080/api

# .env.production      # 生产环境
APP_API_BASE=https://api.vueweb.cn
```

```javascript
// 在代码中使用（必须以 VITE_ 或自定义前缀开头）
console.log(import.meta.env.APP_TITLE)
console.log(import.meta.env.APP_API_BASE)
console.log(import.meta.env.MODE)  // 'development' 或 'production'
console.log(import.meta.env.DEV)   // boolean
console.log(import.meta.env.PROD)  // boolean
```

## 5. 静态资源处理

```javascript
// 直接导入 —— 返回解析后的 URL
import logo from '@/assets/logo.png'
// logo = '/src/assets/logo.png'（开发时）
// logo = '/assets/logo-a1b2c3.png'（构建后带 hash）

// 显式 URL 导入
import workletUrl from './shader.js?url'

// 导入为字符串
import shaderCode from './shader.glsl?raw'

// 导入为 Web Worker
import Worker from './worker.js?worker'
const worker = new Worker()
```

```html
<!-- 模板中使用 -->
<template>
  <img :src="logo" alt="Logo" />

  <!-- public 目录下的文件直接用绝对路径 -->
  <img src="/favicon.ico" alt="Favicon" />
</template>
```

## 6. 热更新（HMR）

Vite 的 HMR 速度极快，无论项目多大都能保持毫秒级更新：

```javascript
// 自定义模块的 HMR 处理
if (import.meta.hot) {
  import.meta.hot.accept('./module.js', (newModule) => {
    // 模块更新时的回调
    console.log('模块已更新', newModule)
  })

  // 清理副作用
  import.meta.hot.dispose(() => {
    clearInterval(timer)
  })
}
```

## 7. 常用插件

```bash
npm i -D @vitejs/plugin-vue          # Vue 3 SFC 支持
npm i -D @vitejs/plugin-vue-jsx      # Vue JSX 支持
npm i -D @vitejs/plugin-legacy       # 传统浏览器兼容
npm i -D vite-plugin-compression     # Gzip / Brotli 压缩
npm i -D unplugin-auto-import        # API 自动导入
npm i -D unplugin-vue-components     # 组件自动注册
```

```javascript
// vite.config.js
import legacy from '@vitejs/plugin-legacy'
import AutoImport from 'unplugin-auto-import/vite'
import Components from 'unplugin-vue-components/vite'
import { ElementPlusResolver } from 'unplugin-vue-components/resolvers'

export default defineConfig({
  plugins: [
    vue(),
    // 传统浏览器支持
    legacy({
      targets: ['defaults', 'not IE 11']
    }),
    // 自动导入 Vue API（ref、computed 等不用手动 import）
    AutoImport({
      imports: ['vue', 'vue-router', 'pinia'],
      resolvers: [ElementPlusResolver()]
    }),
    // 组件自动注册
    Components({
      resolvers: [ElementPlusResolver()]
    })
  ]
})
```

## 8. 从 Webpack 迁移到 Vite

| Webpack 概念 | Vite 对应 |
| :--- | :--- |
| `webpack.config.js` | `vite.config.js` |
| `webpack-dev-server` | 内置开发服务器 |
| `HtmlWebpackPlugin` | 不需要，`index.html` 就是入口 |
| `require()` | `import` |
| `process.env` | `import.meta.env` |
| `file-loader / url-loader` | 内置静态资源处理 |
| `DefinePlugin` | `define` 配置项 |
| `devServer.proxy` | `server.proxy` |

迁移的核心步骤：
1. 把 `index.html` 移到项目根目录，添加 `<script type="module" src="/src/main.js"></script>`
2. 将 `require` 改为 `import`
3. 将 `process.env` 改为 `import.meta.env`
4. 安装对应的 Vite 插件替代 Webpack loader

Vite 代表了前端构建工具的未来方向，已经成为 Vue、Svelte 等框架的默认推荐构建方案。
