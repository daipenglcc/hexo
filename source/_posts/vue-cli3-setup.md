---
title: Vue CLI 3 搭项目的一些配置踩坑
date: 2019-05-18 15:40:18
tags:
  - Vue
  - Vue CLI
  - 前端工程化
categories: Vue
---

最近公司新项目用 Vue CLI 3 搭建（之前一直停留在 CLI 2 的 webpack template），升级过来后发现变化还挺大。配置文件从 `build/` 目录一大堆文件变成了一个 `vue.config.js`，看着简洁了但第一次上手还是得翻文档。这里把我搭项目过程中折腾过的配置记一下。

<!-- more -->

## 1. 安装和创建项目

```bash
# 先全局装好 CLI
npm install -g @vue/cli

# 创建项目
vue create my-project
```

创建的时候它会让你选预设，可以选默认的（babel + eslint），也可以手动选功能。我一般手动选，把 Router、Vuex、CSS 预处理器、Linter 都勾上。

有一个要注意的：它会问你 "Use history mode for router?"，如果你项目部署在子路径下（比如 `example.com/app/`），选 Yes 的话后续 Nginx 配置会折腾一阵子。不清楚的先选 No 用 hash 模式比较省心。

## 2. vue.config.js 常用配置

CLI 3 把 webpack 配置封装了，想改的话需要在根目录建 `vue.config.js`。这个文件默认是不存在的，得自己创建。

我项目里大概是这样：

```javascript
const path = require('path')

module.exports = {
  // 部署在子目录的话改这里，比如 '/app/'
  publicPath: process.env.NODE_ENV === 'production' ? '/app/' : '/',

  // 打包输出目录
  outputDir: 'dist',

  // 放 static 资源的目录
  assetsDir: 'static',

  // 生产环境不需要 source map，关掉能加快打包速度
  productionSourceMap: false,

  // 开发服务器配置
  devServer: {
    port: 8888,
    open: true,  // 启动自动打开浏览器
    
    // 代理后端接口，解决本地跨域
    proxy: {
      '/api': {
        target: 'http://localhost:3000',
        changeOrigin: true,
        pathRewrite: {
          '^/api': ''  // 把请求里的 /api 前缀去掉
        }
      }
    }
  },

  // 要改 webpack 配置的话在这里
  configureWebpack: {
    resolve: {
      alias: {
        '@': path.resolve(__dirname, 'src'),
        '@components': path.resolve(__dirname, 'src/components'),
        '@views': path.resolve(__dirname, 'src/views'),
      }
    }
  }
}
```

## 3. 踩过的坑

### 坑一：环境变量怎么搞

以前 CLI 2 是自己在 `config/` 下建 `dev.env.js` 和 `prod.env.js`，CLI 3 改成了 `.env` 文件的方式。

在项目根目录下建这些文件：

```bash
.env              # 所有环境都会加载
.env.development  # npm run serve 的时候加载
.env.production   # npm run build 的时候加载
```

写法：

```bash
# .env.development
VUE_APP_BASE_API = 'http://localhost:3000/api'
VUE_APP_TITLE = '管理后台(开发)'
```

```bash
# .env.production
VUE_APP_BASE_API = 'https://api.example.com'
VUE_APP_TITLE = '管理后台'
```

**注意：变量名必须以 `VUE_APP_` 开头**，不然代码里 `process.env.xxx` 取不到。这个坑我踩了两回才记住。

代码里这样用：

```javascript
const api = process.env.VUE_APP_BASE_API
document.title = process.env.VUE_APP_TITLE
```

### 坑二：打包后页面白屏

打完包丢到服务器上，页面一片白，控制台报一堆资源 404。十有八九是 `publicPath` 没配对。

如果你的项目部署在域名根目录就写 `'/'`，部署在子路径就写那个路径，比如 `'/admin/'`。我有次部署在二级目录结果忘了改，排查了半天才反应过来是这个问题。

### 坑三：CSS 预处理器全局变量

项目里用 Sass 的话，经常需要在每个组件里用到一些全局的变量和 mixin，但不想每个 `.vue` 文件里都手动 `@import` 一遍。

```javascript
// vue.config.js
module.exports = {
  css: {
    loaderOptions: {
      sass: {
        // CLI 3 早期版本用 data，后来改成了 prependData，再后来又变成 additionalData
        // 看你装的 sass-loader 版本
        additionalData: `
          @import "@/styles/variables.scss";
          @import "@/styles/mixins.scss";
        `
      }
    }
  }
}
```

这个配置项名字改了好几次，每次升级 sass-loader 都得去查一下，有点烦。

### 坑四：externals 排除大包

打包体积太大的时候，把 Vue、ElementUI 这种大库用 CDN 引入，不打进 bundle 里：

```javascript
// vue.config.js
module.exports = {
  configureWebpack: {
    externals: {
      'vue': 'Vue',
      'element-ui': 'ELEMENT',
      'axios': 'axios'
    }
  }
}
```

然后在 `public/index.html` 里引 CDN：

```html
<script src="https://cdn.jsdelivr.net/npm/vue@2.6.10/dist/vue.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/element-ui@2.13.0/lib/index.js"></script>
```

这一招下来打包体积能减不少。

## 4. 目录结构

我一般会按这个结构组织代码，写了几个项目下来觉得还算顺手：

```
src/
├── api/          # 按模块拆分的接口请求
├── assets/       # 图片、字体之类的静态资源
├── components/   # 公共组件
├── router/       # 路由配置
├── store/        # Vuex 状态管理
├── styles/       # 全局样式、变量、mixin
├── utils/        # 工具函数（request.js, auth.js 之类）
├── views/        # 页面级组件
├── App.vue
└── main.js
```

其实没什么标准答案，项目规模不大的时候怎么舒服怎么来，等大了再慢慢拆。

CLI 3 总体来说比 2 好用不少，至少不用面对 `build/` 下面那一堆 webpack 配置文件了。虽然灵活性上有些限制，但提供的 `configureWebpack` 和 `chainWebpack` 也够日常折腾了。
