---
title: qiankun 微前端踩坑实录：把三个老项目塞一起
date: 2021-08-15 10:45:33
tags:
  - 微前端
  - qiankun
  - 前端架构
categories: 前端工程化
---

公司有三个后台管理系统，分别是 Vue 2、Vue 3 和一个 React 的。产品说要搞一个"统一工作台"，把这三个系统整合到一个入口下面，菜单统一管理。

最开始想的方案是 iframe 嵌入，简单粗暴，但体验实在太差：地址栏不同步、弹窗被 iframe 框住、跨域通信麻烦……后来选了蚂蚁的 qiankun 搞微前端，踩了不少坑，记录一下。

<!-- more -->

## 1. 微前端到底要干嘛

简单说就是：**一个主应用（基座）负责壳子和路由，子应用各自独立开发、独立部署，运行时动态加载到主应用里。**

好处很直接：
- 老项目不用重写，能直接接入
- 各子应用技术栈独立，Vue、React 混着来
- 子应用可以单独发版，不用整体打包

## 2. 主应用怎么搭

主应用其实就是个壳子，核心代码没多少。

```bash
npm install qiankun
```

```javascript
// main.js
import { registerMicroApps, start } from 'qiankun'

// 注册子应用
registerMicroApps([
  {
    name: 'vue2-admin',
    entry: '//localhost:8081',  // 子应用的地址
    container: '#subapp-container',  // 子应用挂载的 DOM 节点
    activeRule: '/vue2-admin',  // URL 匹配到这个前缀就加载这个子应用
  },
  {
    name: 'vue3-admin',
    entry: '//localhost:8082',
    container: '#subapp-container',
    activeRule: '/vue3-admin',
  },
  {
    name: 'react-admin',
    entry: '//localhost:8083',
    container: '#subapp-container',
    activeRule: '/react-admin',
  },
])

// 启动
start()
```

主应用的模板：

```html
<div id="app">
  <header>统一工作台导航</header>
  <aside>侧边菜单</aside>
  <!-- 子应用就渲染在这里 -->
  <main id="subapp-container"></main>
</div>
```

## 3. 子应用要改什么

子应用需要暴露三个生命周期函数给 qiankun 调用。以 Vue 2 项目为例：

```javascript
// src/main.js
import Vue from 'vue'
import App from './App.vue'
import router from './router'

let instance = null

function render(props = {}) {
  const { container } = props
  instance = new Vue({
    router,
    render: h => h(App),
  }).$mount(container ? container.querySelector('#app') : '#app')
}

// 如果不是被 qiankun 加载的，就正常启动（独立运行时）
if (!window.__POWERED_BY_QIANKUN__) {
  render()
}

// 这三个生命周期 qiankun 会去调
export async function bootstrap() {
  console.log('vue2-admin bootstraped')
}

export async function mount(props) {
  render(props)
}

export async function unmount() {
  instance.$destroy()
  instance.$el.innerHTML = ''
  instance = null
}
```

还要改一下打包配置，让子应用的入口以 UMD 格式导出：

```javascript
// vue.config.js
const { name } = require('./package.json')

module.exports = {
  devServer: {
    port: 8081,
    headers: {
      'Access-Control-Allow-Origin': '*',  // 跨域，必须加
    },
  },
  configureWebpack: {
    output: {
      library: `${name}`,
      libraryTarget: 'umd',
      jsonpFunction: `webpackJsonp_${name}`,
    },
  },
}
```

## 4. 踩坑记录

### 坑一：子应用静态资源 404

子应用的图片、字体等资源路径是相对路径的话，被主应用加载后就 404 了。因为路径变成了相对于主应用的域名。

**解决：** 在子应用入口动态设置 `publicPath`：

```javascript
// src/public-path.js（在 main.js 最顶部引入）
if (window.__POWERED_BY_QIANKUN__) {
  __webpack_public_path__ = window.__INJECTED_PUBLIC_PATH_BY_QIANKUN__
}
```

这一步必须在最开头做，忘了的话各种资源加载报错。

### 坑二：样式互相污染

这个最头疼。主应用用的 ElementUI，子应用也有 ElementUI，版本不同样式就打架了。最典型的是 `.el-dialog` 之类的全局样式互相覆盖。

我最后的方案是给子应用的样式加个前缀：

```javascript
// 主应用启动的时候
start({
  sandbox: {
    experimentalStyleIsolation: true  // 自动给子应用样式加个前缀
  }
})
```

但说实话这个方案不完美，有些通过 JS 动态插入 body 的弹窗（比如 Select 的下拉框）会跑到沙箱外面去，样式还是会丢。这种只能靠手动覆盖 CSS 来解决，比较恶心。

### 坑三：子应用路由基础路径

子应用独立运行的时候路由 base 是 `/`，但在 qiankun 下需要改成 `activeRule` 对应的前缀，不然路由跳转会乱。

```javascript
// router/index.js
const router = new VueRouter({
  mode: 'history',
  base: window.__POWERED_BY_QIANKUN__ ? '/vue2-admin/' : '/',
  routes
})
```

### 坑四：主子应用之间怎么通信

qiankun 自带的 `initGlobalState` 够用了，但别滥用，只传关键信息（比如用户信息、token）就行。

```javascript
// 主应用
import { initGlobalState } from 'qiankun'

const actions = initGlobalState({
  user: { name: '张三', token: 'xxx' }
})

// 子应用在 mount 时拿到 props
export async function mount(props) {
  props.onGlobalStateChange((state) => {
    console.log('全局状态变了:', state)
  })
  // 也可以修改
  props.setGlobalState({ user: { name: '李四' } })
  render(props)
}
```

## 5. 一些实际建议

- **主应用尽量做薄**，只管登录态、菜单、路由分发，业务逻辑全放子应用里
- **样式隔离没有完美方案**，能用 CSS Modules 或 BEM 命名的尽量用，比依赖沙箱靠谱
- **子应用要保持独立可运行**，开发调试的时候还是独立跑的多
- **公共依赖不一定要抽出来**，看起来省了点体积，但版本管理会变成噩梦

微前端这东西说到底是解决"组织问题"而不是"技术问题"。如果项目不大、团队不多，真没必要上。我们是因为三个系统实在合不到一起才不得已用的。
