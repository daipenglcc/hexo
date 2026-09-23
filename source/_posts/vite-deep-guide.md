---
title: 彻底扔掉 Webpack：Vite 踩坑与进阶指北
date: 2021-01-10 10:30:22
tags:
  - Vite
  - 前端工程化
categories: 前端工程化
---

当年天天对着 Webpack 动辄几十秒的冷启动发呆，喝了杯水回来还没转完。后来尤大出了 Vite，我抱着试一试的心态跑了一下，那“秒开”的速度简直感动得眼泪都要掉下来了。

现在我只要新开项目，无脑上 Vite，真的是用过就回不去。这里把我平时最常用的一套配置和踩过的坑总结一下，当个脚手架备忘录。

<!-- more -->

## 1. 为什么它能那么快？

说白了，以前的 Webpack 是个老实人，你只要一按启动，它非要把你整个项目的代码全打包一遍，才敢把页面给你看。项目越庞大，它越慢。

而 Vite 是个渣男（褒义），你刚点启动它就给你个空壳页面，然后你点进哪个页面，它才现场用浏览器的原生能力（ES Module）去编译那个页面的代码。**按需编译，不打包**，这速度能不快吗？

## 2. 三秒钟建个项目

最直接的起手式，一行命令，连模板都给你选好了：

```bash
# 我最常用的是 Vue 和 TS 的组合
npm create vite@latest my-app -- --template vue-ts

# 然后无脑三连
cd my-app
npm install
npm run dev
```

> **小坑提醒**：Vite 项目的入口文件 `index.html` 不在 `public` 文件夹里了，而是直接大摇大摆地躺在项目最外层的根目录下。

## 3. 把 vite.config.js 配得舒舒服服

新生成的配置文件太素了，我一般会加上别名、代理和自动导包插件，下面这个配置直接抄过去就能用：

```javascript
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import path from 'path'
import AutoImport from 'unplugin-auto-import/vite'
import Components from 'unplugin-vue-components/vite'

export default defineConfig({
  plugins: [
    vue(),
    // 自动导包神仙插件：以后写 ref, reactive 都不用在上面写 import 啦！
    AutoImport({ imports: ['vue', 'vue-router', 'pinia'] }),
    // UI 组件库也能自动按需导入（省去了一大堆 import 代码）
    Components({ /* 配置具体的 UI 库解析器 */ })
  ],

  // 路径别名：以后写 @/ 就会自动指向 src 目录，摆脱 ../../../ 的噩梦
  resolve: {
    alias: {
      '@': path.resolve(__dirname, 'src')
    }
  },

  // 开发服务器设置
  server: {
    port: 3000,
    open: true, // 启动自动帮你打开浏览器
    // 解决跨域的千古难题
    proxy: {
      '/api': {
        target: 'http://127.0.0.1:8080', // 你后台同事的电脑 IP
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api/, '')
      }
    }
  },

  // 打包优化（上线用的）
  build: {
    // 把比 4KB 小的图片直接转成 Base64 塞代码里，少发一次请求
    assetsInlineLimit: 4096,
    // 分包策略：把第三方库单独拆出去，免得每次更新业务代码用户都要重新下载全量包
    rollupOptions: {
      output: {
        manualChunks: {
          'vue-vendor': ['vue', 'vue-router', 'pinia'],
          'ui-vendor': ['element-plus']
        }
      }
    }
  }
})
```

## 4. 环境变量怎么搞？

以前写 Webpack 的时候，获取环境变量用的是 `process.env.XXX`。在 Vite 里这招不管用了，它有一套自己的规矩。

首先，在项目根目录建文件：
```bash
.env               # 所有人共用的
.env.development   # 开发时候用的（比如连本地测试库）
.env.production    # 上线时候用的（连正式库）
```

**⚠️ 极其关键的坑**：写在这些文件里的变量名，必须用 `VITE_` 开头，不然代码里死活读不到！

```text
# 这样写是对的
VITE_API_URL=http://localhost:8080/api

# 这样写你在代码里永远拿到的是 undefined
API_URL=http://localhost:8080/api 
```

在代码里拿出来用：
```javascript
// 名字变长了，不过习惯就好
const baseURL = import.meta.env.VITE_API_URL

// 判断现在是不是开发环境
if (import.meta.env.DEV) {
  console.log('我在本地玩泥巴')
}
```

## 5. 迁移老项目的痛点

如果你想把手里祖传的 Webpack 项目迁到 Vite，要有掉几根头发的心理准备。最核心要改的地方有几个：

1. **`index.html` 搬家**：从 `public` 挪到最外面，并且手动塞个 `<script type="module" src="/src/main.js"></script>` 进去。
2. **消灭所有 `require()`**：Vite 不认 CommonJS 这一套，遇到拿 `require` 导包、插图片的，全给我老老实实改成 `import`。
3. **环境变量替换**：全局搜索 `process.env`，全换成 `import.meta.env`。

总之，只要你不是那种历史包袱巨重、依赖了十几个 Webpack 专属插件的史前巨兽项目，我都强烈建议你早点转 Vite，那种丝滑的开发体验，真的是对自己生命的救赎。
