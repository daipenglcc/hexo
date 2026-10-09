---
title: 首屏加载加载过慢？我做的一些优化记录
date: 2020-03-25 16:20:18
tags:
  - 性能优化
  - Webpack
  - 前端
categories: 前端工程化
---

上个月项目上了一个大活动页，结果运营那边反馈说页面打开要四五秒才出内容，手机上更慢。拿 Lighthouse 一跑分，性能分只有三十几分，LCP 七八秒，看着都心慌。被逼着做了一轮优化，效果还不错，这里记录下过程。

<!-- more -->

## 1. 先定位问题在哪

优化之前最忌讳瞎猜，先用工具看看到底慢在哪里。

**Chrome DevTools - Network 面板：**
打开瀑布图一看，问题很明显：`vendor.js` 有 1.8MB，`app.js` 也有 600 多 KB，光下载这俩文件就好几秒。

**Lighthouse 报告：**
- FCP (First Contentful Paint): 3.2s
- LCP (Largest Contentful Paint): 7.8s
- 主要问题：JS 体积过大、阻塞渲染资源过多

**webpack-bundle-analyzer：**
这个插件特别好使，能可视化地看到每个模块占了多大体积。

```bash
npm install --save-dev webpack-bundle-analyzer
```

```javascript
// vue.config.js（Vue CLI 项目的情况下）
const BundleAnalyzerPlugin = require('webpack-bundle-analyzer').BundleAnalyzerPlugin

module.exports = {
  configureWebpack: {
    plugins: [
      new BundleAnalyzerPlugin()
    ]
  }
}
```

跑完 `npm run build` 会自动弹出一个页面，一眼就看到 echarts 占了 700 多 KB，moment.js 占了 200 多 KB，elementUI 全量引入了。

## 2. 减 JS 体积

这个是效果最明显的。

### 按需引入组件库

之前 ElementUI 是整个引进来的，改成按需引入后体积直接砍了 2/3：

```javascript
// 之前：全量引入
import ElementUI from 'element-ui'
Vue.use(ElementUI)

// 之后：按需引入（需要配合 babel-plugin-component）
import { Button, Table, Select, Message } from 'element-ui'
Vue.use(Button)
Vue.use(Table)
Vue.use(Select)
Vue.prototype.$message = Message
```

### 干掉 moment.js 的无用语言包

moment.js 大家都知道体积很离谱，一大半是各国语言包。如果只用中文，可以用 webpack 的 IgnorePlugin 排除掉：

```javascript
// vue.config.js
const webpack = require('webpack')

module.exports = {
  configureWebpack: {
    plugins: [
      new webpack.IgnorePlugin(/^\.\/locale$/, /moment$/)
    ]
  }
}
```

然后在代码里手动引入中文：

```javascript
import moment from 'moment'
import 'moment/locale/zh-cn'
```

光这一步 moment 就从 200 多 KB 缩到了 50 多 KB。不过说实话后来新项目我直接换 dayjs 了，体积才 2KB。

### echarts 按需引入

echarts 5 支持按需引入了，只引自己用的图表类型：

```javascript
import * as echarts from 'echarts/core'
import { BarChart, LineChart } from 'echarts/charts'
import { GridComponent, TooltipComponent, LegendComponent } from 'echarts/components'
import { CanvasRenderer } from 'echarts/renderers'

echarts.use([BarChart, LineChart, GridComponent, TooltipComponent, LegendComponent, CanvasRenderer])
```

## 3. 路由懒加载

SPA 如果不做路由懒加载，所有页面的代码全在一个包里，首屏加载当然慢。

```javascript
// 之前：全部 import 进来
import Home from '@/views/Home'
import About from '@/views/About'
import Dashboard from '@/views/Dashboard'

// 之后：动态 import，访问到对应页面才去加载
const routes = [
  { path: '/', component: () => import('@/views/Home') },
  { path: '/about', component: () => import('@/views/About') },
  { path: '/dashboard', component: () => import('@/views/Dashboard') },
]
```

Webpack 会自动把每个路由组件打成一个单独的 chunk，用户访问哪个页面才去加载哪个。

## 4. 图片优化

那个活动页有好几张大图，每张都是设计师直接给的 PNG，最大的一张 2MB 多。

**做了这几件事：**

1. 大图转 WebP 格式，体积直接砍一半以上
2. 用 `loading="lazy"` 让非首屏图片延迟加载
3. 给 `<img>` 加上明确的 `width` 和 `height`，避免布局偏移

```html
<!-- 首屏图片：不加 lazy，正常加载 -->
<img src="/hero-banner.webp" width="1200" height="400" alt="活动Banner">

<!-- 非首屏图片：加 lazy -->
<img src="/section2.webp" loading="lazy" width="800" height="300" alt="活动介绍">
```

## 5. Gzip / Brotli 压缩

这个需要服务器配合。在 Nginx 里开启 Gzip：

```nginx
gzip on;
gzip_types text/plain text/css application/json application/javascript text/xml;
gzip_min_length 1024;
gzip_comp_level 5;
```

开了 Gzip 之后，1.8MB 的 vendor.js 传输体积缩到了 400 多 KB。

如果还想更极致，可以在打包时预先生成 .gz 文件：

```bash
npm install --save-dev compression-webpack-plugin
```

```javascript
const CompressionPlugin = require('compression-webpack-plugin')

module.exports = {
  configureWebpack: {
    plugins: [
      new CompressionPlugin({
        algorithm: 'gzip',
        test: /\.(js|css|html)$/,
        threshold: 10240,  // 大于 10KB 才压缩
        minRatio: 0.8
      })
    ]
  }
}
```

## 6. 优化前后对比

做完这一轮下来效果还是明显的：

| 指标 | 优化前 | 优化后 |
|------|--------|--------|
| vendor.js | 1.8MB | 380KB |
| app.js | 620KB | 190KB |
| FCP | 3.2s | 1.1s |
| LCP | 7.8s | 2.4s |
| Lighthouse 性能分 | 34 | 78 |

最大的收获其实是两个：**按需引入**和**路由懒加载**，光这两步就能解决大部分首屏慢的问题。剩下的 Gzip、图片优化是锦上添花。

下次再搞性能优化应该先看看这篇，别又从头排查了。
