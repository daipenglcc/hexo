---
title: Vue 组件传值太痛苦？这 6 种通信方式必须拿下
date: 2018-08-15 14:22:18
tags:
  - Vue
  - 组件通信
categories: Vue
---

刚开始学 Vue 的时候，觉得这框架啥都好，就是组件拆多了以后，数据传过来传过去太让人抓狂。父传子、子传父还能搞得清，碰到嵌套了三四层的组件要互通有无，直接就蒙圈了。

后来写业务写多了才发现，Vue 组件之间通信来来回回也就那么几种套路。我把平时写代码最常用的 6 种方式整理了出来，用熟了基本上就没有你传不到的数据。

<!-- more -->

## 1. 最稳妥的父子传话：Props / $emit

这是最基础、最不容易出 Bug 的方式，就像你给你儿子发生活费，他给你汇报成绩。

**父亲传给儿子 (Props)：**
```html
<!-- 父组件里 -->
<template>
  <!-- 直接绑在标签上扔进去 -->
  <child-component :money="1000" :msg="'好好学习'" />
</template>
```

```javascript
// 子组件里接收
export default {
  props: {
    money: { type: Number, default: 0 },
    msg: String
  }
}
```

**儿子报告给父亲 ($emit)：**
```javascript
// 子组件里遇到点啥事，大喊一声
this.$emit('needMoreMoney', 500)
```

```html
<!-- 父组件里在旁边听着 -->
<child-component @needMoreMoney="handleMoney" />
```

## 2. 父亲直接对儿子发号施令：$refs

如果你懒得搞各种事件绑定，想直接粗暴地调用子组件里的方法，用 `$refs` 最爽。

```html
<template>
  <!-- 先给儿子贴个标签 -->
  <child-component ref="myChild" />
  <button @click="doSomething">强行操作儿子</button>
</template>

<script>
export default {
  methods: {
    doSomething() {
      // 简单粗暴，直接调子组件身上的方法
      this.$refs.myChild.resetForm()
      // 甚至能直接改它的数据（虽然不推荐，但很爽）
      this.$refs.myChild.name = '铁柱'
    }
  }
}
</script>
```

## 3. 兄弟间传纸条：EventBus 事件总线

这招适合小型项目里，两个完全不搭噶的兄弟组件想要通信。建一个专门管收发信件的“邮局”。

先搞个空的 Vue 实例当邮局：
```javascript
// event-bus.js
import Vue from 'vue'
export const EventBus = new Vue()
```

```javascript
// 兄弟 A 发电报：
import { EventBus } from './event-bus'
EventBus.$emit('hello', '我是 A，你吃了吗？')
```

```javascript
// 兄弟 B 收电报：
import { EventBus } from './event-bus'
export default {
  created() {
    EventBus.$on('hello', (msg) => {
      console.log('收到：', msg)
    })
  },
  // ⚠️ 惊天大坑预警：页面销毁时一定要注销监听，不然内存直接原地爆炸
  beforeDestroy() {
    EventBus.$off('hello')
  }
}
```

## 4. 终极一波流大管家：Vuex

一旦项目大了，EventBus 满天飞，你根本找不到谁发了什么事件。这时候就得上 Vuex（或者现在的 Pinia）了，大家把要共享的钱全放在一个银行里，谁要用谁去取。

```javascript
// store/index.js (存钱)
export default new Vuex.Store({
  state: {
    userInfo: { name: '打工人' }
  },
  mutations: {
    changeName(state, newName) {
      state.userInfo.name = newName
    }
  }
})
```

```vue
<!-- 组件里直接用 (取钱) -->
<template>
  <p>{{ $store.state.userInfo.name }}</p>
  <button @click="$store.commit('changeName', '大老板')">改名</button>
</template>
```

## 5. 祖宗传家宝：provide / inject

这招在写公共组件或者组件库的时候特别管用！假设你有一个太爷爷组件，想直接传点东西给重孙子，如果一层一层写 props 那得累死。

```javascript
// 祖宗组件直接发话：
export default {
  provide() {
    return {
      themeColor: 'red' // 这玩意儿我全家都能用
    }
  }
}
```

```javascript
// 重孙子组件不管嵌套多深，直接认领：
export default {
  inject: ['themeColor'],
  created() {
    console.log(this.themeColor) // 拿到 red，美滋滋
  }
}
```

## 6. 原封不动地踢皮球：$attrs / $listeners

这个比较高级，通常用来二次封装组件。比如你想包装一个饿了么的 `<el-input>`，但是它身上有几十个属性和事件，你总不能在自己的组件里写几十个 props 去接吧？

```html
<!-- 我的组件 MyInput.vue -->
<template>
  <div>
    <label>酷炫输入框：</label>
    <!-- 神奇的一句代码，把外面传进来的属性和事件一股脑全扔给原生的 input -->
    <input v-bind="$attrs" v-on="$listeners" />
  </div>
</template>
```

基本上，掌握这 6 招，不管公司的 Vue 代码写得有多像俄罗斯套娃，你都能轻松把数据传得明明白白。
