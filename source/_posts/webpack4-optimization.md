---
title: 老项目抢救指南：Webpack 4 到底还能怎么优化
date: 2019-07-08 15:30:22
tags:
  - Webpack
  - 性能优化
  - 前端工程化
categories: 前端工程化
---

虽然现在满世界都在吹 Vite 甚至 Rspack 有多快，但现实往往是骨感的：手里还有好几个祖传的 Webpack 4 老项目要维护，因为历史包袱太重根本没法升版本。

以前每次按个保存（Ctrl+S），我都得去倒杯茶等它那十几秒的热更新转完，简直是折磨。上个月实在受不了了，抽了两个周末把项目底朝天优化了一遍，冷启动和热更新的速度总算降到了能忍受的几秒钟。把这次“抢救”用到的一些管用的招数记下来，以后留着给其他项目续命。

<!-- more -->

## 一、咋让它打包快一点？

### 1. 别让它像无头苍蝇一样乱找

Webpack 慢的一个大原因是它在遍历文件。告诉它明确的搜寻范围，别去扫描那些几万个文件的 `node_modules`。

```javascript
// webpack.config.js
module.exports = {
  module: {
    rules: [
      {
        test: /\.js$/,
        use: 'babel-loader',
        // 这一句很关键，把 node_modules 排除掉，速度提升巨大！
        exclude: /node_modules/,
        // 或者更狠一点，只让它管 src 下面的文件
        include: path.resolve(__dirname, 'src')
      }
    ]
  }
}
```

### 2. 第三方大块头预先打包（DllPlugin）

像 Vue、React、Echarts 这些包巨大无比，偏偏它们又是一万年不更新的。每次写业务代码都让 Webpack 重新编译它们一遍，纯属浪费生命。

用 `DllPlugin` 把它们单独打成一个包，以后就直接拿来用：

```javascript
// 单独搞个 webpack.dll.config.js，运行一次就行
module.exports = {
  entry: {
    // 把这些死胖子全扔进去
    vendor: ['vue', 'vue-router', 'vuex', 'axios']
  },
  plugins: [
    new webpack.DllPlugin({
      name: '[name]_library',
      path: path.resolve(__dirname, 'dll/[name].manifest.json')
    })
  ]
}
```

然后在普通的配置里引用这个 `manifest.json`，构建速度肉眼可见地变快。

### 3. 给 Webpack 加点多线程魔法

Webpack 默认是单线程干活的，咱们可以装个 `thread-loader`，利用电脑的多核 CPU 让它并行干活。

```javascript
module: {
  rules: [
    {
      test: /\.js$/,
      use: [
        {
          loader: 'thread-loader',
          options: { workers: 3 } // 开 3 个小弟帮忙打工
        },
        'babel-loader'
      ]
    }
  ]
}
```
> **踩坑提醒**：如果你的项目特别小就别搞这个了，开子线程的开销比打包本身还费时间。

## 二、咋让打包出来的文件小一点？

产出文件太大，用户打开网页就得转半天圈圈。

### 1. 拆包策略（Code Splitting）

别把所有代码全揉成一个几 MB 的 `app.js`。把公共包单独拎出来。

```javascript
optimization: {
  splitChunks: {
    chunks: 'all',
    cacheGroups: {
      // 第三方包单独拆成 vendor.js
      vendor: {
        name: 'vendor',
        test: /[\\/]node_modules[\\/]/,
        priority: 10
      },
      // 业务里大家都在用的公共代码也拆出来
      common: {
        name: 'common',
        minChunks: 2, // 只要被引用过两次就拆走
        priority: 5
      }
    }
  }
}
```

### 2. 路由必须懒加载

一进首页就把管理后台的所有页面代码全下载下来，这就是耍流氓。一定要配路由按需加载。

```javascript
// 在 Vue 路由表里这么写，它就会被拆成独立的文件
const routes = [
  {
    path: '/about',
    // 神奇的魔法注释，指定打包出来的文件名
    component: () => import(/* webpackChunkName: "about_page" */ '@/views/About.vue')
  }
]
```

### 3. 把图片压成干尸

小图片根本没必要发 HTTP 请求，直接转成 Base64 塞进代码里。大图片用插件强行压缩质量。

```javascript
module: {
  rules: [
    {
      test: /\.(png|jpe?g|gif|svg)$/,
      use: [
        {
          loader: 'url-loader',
          options: {
            limit: 8192,  // 小于 8KB 的图片，直接转 Base64！
            name: 'img/[name].[hash:8].[ext]'
          }
        }
      ]
    }
  ]
}
```

## 三、怎么知道哪里慢？

千万别瞎优化，找个“温度计”测一下。我最爱用 `webpack-bundle-analyzer`，它会生成一张五颜六色的图，那个方块面积最大，就说明那个包最占空间，一抓一个准。

```bash
# 跑完这句，自动在浏览器打开分析报告
npm install webpack-bundle-analyzer -D
```

```javascript
const BundleAnalyzerPlugin = require('webpack-bundle-analyzer').BundleAnalyzerPlugin

plugins: [
  // 找出那个让打包变肥的罪魁祸首
  new BundleAnalyzerPlugin()
]
```

这套组合拳打下来，我那个破项目冷启动从快一分钟多降到了 20 秒左右，热更新进到了两秒内，产物体积缩水了一半。虽然比不上新一代工具，但起码能让我心情舒畅地活到下班了。
