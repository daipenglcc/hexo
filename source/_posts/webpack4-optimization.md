---
title: Webpack 4 性能优化实战指南
date: 2019-07-08 15:30:22
tags:
  - Webpack
  - 性能优化
  - 前端工程化
categories: 前端工程化
---

Webpack 作为前端构建的事实标准，在处理大型项目时常常面临构建速度慢、产出体积大的问题。本文结合 Webpack 4 的实际项目经验，从构建速度和产出优化两个维度，整理了一套可落地的性能优化方案。

<!-- more -->

## 一、构建速度优化

### 1. 缩小文件搜索范围

```javascript
// webpack.config.js
module.exports = {
  resolve: {
    // 指定扩展名，减少文件查找
    extensions: ['.js', '.vue', '.json'],
    // 设置别名，避免层层 ../
    alias: {
      '@': path.resolve(__dirname, 'src'),
      '@components': path.resolve(__dirname, 'src/components')
    },
    // 指定模块查找目录，避免向上递归搜索
    modules: [path.resolve(__dirname, 'node_modules')]
  },
  module: {
    rules: [
      {
        test: /\.js$/,
        use: 'babel-loader',
        // 明确排除 node_modules，大幅减少编译文件量
        exclude: /node_modules/,
        // 或者用 include 指定只编译 src 目录
        include: path.resolve(__dirname, 'src')
      }
    ],
    // 对已知不含 import/require 的大型库跳过解析
    noParse: /jquery|lodash/
  }
}
```

### 2. 使用 DllPlugin 预编译第三方库

将不经常变动的第三方库（Vue、React、Lodash 等）预先打包成 DLL 文件，后续构建直接引用，不再重复编译：

```javascript
// webpack.dll.config.js
const webpack = require('webpack')
const path = require('path')

module.exports = {
  entry: {
    vendor: ['vue', 'vue-router', 'vuex', 'axios', 'element-ui']
  },
  output: {
    path: path.resolve(__dirname, 'dll'),
    filename: '[name].dll.js',
    library: '[name]_library'
  },
  plugins: [
    new webpack.DllPlugin({
      name: '[name]_library',
      path: path.resolve(__dirname, 'dll/[name].manifest.json')
    })
  ]
}
```

```javascript
// webpack.config.js 中引用
plugins: [
  new webpack.DllReferencePlugin({
    manifest: require('./dll/vendor.manifest.json')
  })
]
```

### 3. 开启多进程编译

利用 `thread-loader` 或 `HappyPack` 将 Loader 的执行并行化：

```javascript
module: {
  rules: [
    {
      test: /\.js$/,
      use: [
        {
          loader: 'thread-loader',
          options: {
            workers: 3  // 开启 3 个 worker 进程
          }
        },
        'babel-loader'
      ],
      exclude: /node_modules/
    }
  ]
}
```

### 4. 利用缓存加速二次构建

```javascript
module: {
  rules: [
    {
      test: /\.js$/,
      use: [
        {
          loader: 'babel-loader',
          options: {
            // 开启 Babel 编译缓存
            cacheDirectory: true
          }
        }
      ]
    }
  ]
},
plugins: [
  // 模块标识符缓存
  new webpack.HashedModuleIdsPlugin()
]
```

## 二、产出体积优化

### 1. Tree Shaking（摇树优化）

Webpack 4 在 `production` 模式下默认开启 Tree Shaking，但需要确保代码满足条件：

```javascript
// ✅ 使用 ES Module 的命名导出（可以 Tree Shaking）
export function formatDate(date) { /* ... */ }
export function formatMoney(num) { /* ... */ }

// ❌ 使用 CommonJS（无法 Tree Shaking）
module.exports = { formatDate, formatMoney }
```

```javascript
// package.json 中标记无副作用
{
  "sideEffects": [
    "*.css",
    "*.less"
  ]
}
```

### 2. Code Splitting（代码分割）

```javascript
// webpack.config.js
optimization: {
  splitChunks: {
    chunks: 'all',
    cacheGroups: {
      // 第三方库单独打包
      vendor: {
        name: 'vendor',
        test: /[\\/]node_modules[\\/]/,
        priority: 10,
        chunks: 'initial'
      },
      // 公共模块提取
      common: {
        name: 'common',
        minChunks: 2,
        priority: 5,
        reuseExistingChunk: true
      }
    }
  }
}
```

### 3. 路由懒加载

按需加载路由组件，首屏只加载必要的代码：

```javascript
// Vue Router 懒加载
const routes = [
  {
    path: '/',
    component: () => import(/* webpackChunkName: "home" */ '@/views/Home.vue')
  },
  {
    path: '/about',
    component: () => import(/* webpackChunkName: "about" */ '@/views/About.vue')
  },
  {
    path: '/dashboard',
    component: () => import(/* webpackChunkName: "dashboard" */ '@/views/Dashboard.vue')
  }
]

// React 路由懒加载
const Home = React.lazy(() => import('./pages/Home'))
const About = React.lazy(() => import('./pages/About'))
```

### 4. 压缩与混淆

```javascript
const TerserPlugin = require('terser-webpack-plugin')
const OptimizeCSSAssetsPlugin = require('optimize-css-assets-webpack-plugin')

module.exports = {
  optimization: {
    minimizer: [
      // JS 压缩
      new TerserPlugin({
        parallel: true,         // 多进程压缩
        cache: true,            // 开启缓存
        terserOptions: {
          compress: {
            drop_console: true, // 移除 console.log
            drop_debugger: true
          }
        }
      }),
      // CSS 压缩
      new OptimizeCSSAssetsPlugin()
    ]
  }
}
```

### 5. 图片与静态资源优化

```javascript
module: {
  rules: [
    {
      test: /\.(png|jpe?g|gif|svg)$/,
      use: [
        {
          loader: 'url-loader',
          options: {
            limit: 8192,  // 8KB 以下转为 base64 内联
            name: 'images/[name].[hash:8].[ext]'
          }
        },
        {
          loader: 'image-webpack-loader',
          options: {
            mozjpeg: { quality: 65 },
            pngquant: { quality: [0.65, 0.9] },
            gifsicle: { interlaced: false }
          }
        }
      ]
    }
  ]
}
```

## 三、分析工具

优化前先用工具分析瓶颈在哪：

```bash
# 安装分析插件
npm i -D webpack-bundle-analyzer speed-measure-webpack-plugin
```

```javascript
const BundleAnalyzerPlugin = require('webpack-bundle-analyzer').BundleAnalyzerPlugin
const SpeedMeasurePlugin = require('speed-measure-webpack-plugin')
const smp = new SpeedMeasurePlugin()

// 使用 SpeedMeasurePlugin 包裹配置，查看各 Loader/Plugin 耗时
module.exports = smp.wrap({
  plugins: [
    // 生成可视化体积报告
    new BundleAnalyzerPlugin({
      analyzerMode: 'static',
      reportFilename: 'bundle-report.html'
    })
  ]
})
```

## 优化效果对比

在一个中型 Vue 项目（约 200 个组件）中实测优化前后：

| 指标 | 优化前 | 优化后 | 提升 |
| :--- | :---: | :---: | :---: |
| 冷启动构建 | 68s | 23s | ↓ 66% |
| 热更新 | 3.2s | 0.8s | ↓ 75% |
| 产出体积 | 2.8MB | 890KB | ↓ 68% |
| 首屏加载 | 4.5s | 1.8s | ↓ 60% |

构建优化是个持续的过程，关键是先用分析工具找到瓶颈，再针对性地应用上述策略。
