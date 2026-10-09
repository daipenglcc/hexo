---
title: Web Components 实践记录：原生组件化到底能不能用了
date: 2026-05-10 15:40:22
tags:
  - Web Components
  - 前端架构
  - JavaScript
categories: 前端工程化
---

写前端这么多年，组件化一直是靠框架来做的——Vue 的 `.vue` 文件、React 的 JSX。但浏览器原生其实一直在推 Web Components 这套标准，包括 Custom Elements、Shadow DOM、HTML Templates。以前是兼容性不行加上用起来太原始，基本没人用。最近又看了一下，发现现在主流浏览器全都支持了，加上 Lit 这类轻量库的加持，感觉可用度比以前好了不少。花了几天配置与实践，记录一下。

<!-- more -->

## 1. Web Components 三件套

### Custom Elements：自定义标签

让你能在 HTML 里用自己定义的标签，比如 `<my-card>`。

```javascript
class MyCard extends HTMLElement {
  constructor() {
    super()
    this.innerHTML = `
      <div class="card">
        <h3>${this.getAttribute('title') || '默认标题'}</h3>
        <p><slot></slot></p>
      </div>
    `
  }
}

// 注册
customElements.define('my-card', MyCard)
```

```html
<!-- 使用 -->
<my-card title="Hello">这是卡片内容</my-card>
```

### Shadow DOM：样式隔离

这个是 Web Components 最值钱的特性——组件内部的样式不会泄漏出去，外部的样式也影响不到组件内部。

```javascript
class MyButton extends HTMLElement {
  constructor() {
    super()
    // 创建 Shadow DOM
    const shadow = this.attachShadow({ mode: 'open' })
    shadow.innerHTML = `
      <style>
        /* 这里的样式只在组件内部生效 */
        button {
          background: #4f46e5;
          color: white;
          border: none;
          padding: 8px 16px;
          border-radius: 6px;
          cursor: pointer;
          font-size: 14px;
        }
        button:hover {
          background: #4338ca;
        }
      </style>
      <button><slot>按钮</slot></button>
    `
  }
}

customElements.define('my-button', MyButton)
```

外面页面上的 `button { color: red }` 不会影响到这个组件，反过来也一样。真正的样式沙箱，比 CSS Modules 和 scoped 更彻底。

### HTML Templates：模板复用

```html
<template id="user-card-template">
  <style>
    .user-card { border: 1px solid #eee; padding: 16px; border-radius: 8px; }
    .user-card h4 { margin: 0 0 8px 0; }
  </style>
  <div class="user-card">
    <h4></h4>
    <p></p>
  </div>
</template>

<script>
class UserCard extends HTMLElement {
  constructor() {
    super()
    const shadow = this.attachShadow({ mode: 'open' })
    const template = document.getElementById('user-card-template')
    shadow.appendChild(template.content.cloneNode(true))
    
    shadow.querySelector('h4').textContent = this.getAttribute('name')
    shadow.querySelector('p').textContent = this.getAttribute('email')
  }
}
customElements.define('user-card', UserCard)
</script>
```

## 2. 原生写太累了，用 Lit

上面的代码写起来确实很原始，字符串拼 HTML、手动操作 DOM，跟写 jQuery 似的。所以有了 Lit 这个库，Google 维护的，专门用来写 Web Components，写法现代多了：

```bash
npm install lit
```

```javascript
import { LitElement, html, css } from 'lit'

class MyCounter extends LitElement {
  static properties = {
    count: { type: Number }
  }

  static styles = css`
    :host {
      display: block;
      font-family: sans-serif;
    }
    .counter {
      display: flex;
      align-items: center;
      gap: 12px;
    }
    button {
      background: #4f46e5;
      color: white;
      border: none;
      width: 36px;
      height: 36px;
      border-radius: 50%;
      font-size: 18px;
      cursor: pointer;
    }
    span {
      font-size: 24px;
      min-width: 40px;
      text-align: center;
    }
  `

  constructor() {
    super()
    this.count = 0
  }

  render() {
    return html`
      <div class="counter">
        <button @click=${() => this.count--}>-</button>
        <span>${this.count}</span>
        <button @click=${() => this.count++}>+</button>
      </div>
    `
  }
}

customElements.define('my-counter', MyCounter)
```

用 Lit 写出来的代码，响应式、模板、样式该有的都有，体验接近 Vue/React 了，但打出来的包特别小。

## 3. 跟 Vue/React 的关系

Web Components 跟框架并不是对立的，它们可以共存。

**在 Vue 里使用 Web Components：**

```vue
<template>
  <my-counter></my-counter>
</template>

<script setup>
// 引入 Web Component 的定义
import '../components/my-counter.js'
</script>
```

Vue 3 原生就支持 Custom Elements，不需要额外配置。

**在 React 里使用 Web Components：**

React 跟 Web Components 的适配一直有点小问题（事件绑定、属性传递等），不过 React 19 已经改善了很多。

```jsx
import '../components/my-counter.js'

function App() {
  return <my-counter count={5}></my-counter>
}
```

## 4. 什么场景适合用

我配置与实践下来觉得 Web Components 最适合这几个场景：

**跨框架共享组件：**
如果你公司有 Vue 项目也有 React 项目，公共组件用 Web Components 写就只用维护一份代码。这个可能是它最有价值的用法。

**设计系统 / 组件库：**
一些大厂（Google、Adobe、微软）的设计系统就是用 Web Components 做的。因为不绑定任何框架，谁都能用。

**嵌入第三方页面的小部件：**
比如一个客服聊天气泡、一个评论插件。用 Web Components + Shadow DOM，完全不用担心跟宿主页面的样式冲突。

**不太适合的场景：**
- 大型复杂应用还是框架好使，生态更成熟
- 需要大量状态管理和路由的 SPA

## 5. 我的看法

Web Components 的定位不是"替代 React/Vue"，而是"在框架之下提供一层标准化的组件能力"。

以前觉得这东西鸡肋，是因为浏览器支持不全、没有好用的工具库、写起来太原始。现在浏览器全面支持了，Lit 也足够好用了，在合适的场景里确实值得一试。

不过如果你就一个 Vue 项目或者就一个 React 项目，规范地用框架的组件就好，没必要为了"原生"而原生。技术选型永远是看场景的。
