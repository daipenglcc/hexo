---
title: Vuex 终于退役了：Pinia 常用写法备忘
date: 2022-02-28 09:45:18
tags:
  - Vue
  - Pinia
  - 状态管理
categories: Vue
---

刚转到 Vue 3 那会儿，我还挣扎着继续用 Vuex 4，但写起 TS 类型来简直痛不欲生。后来尤大亲自推荐了 Pinia，试了一下发现，没了 Vuex 里那恶心的 `mutations`，代码写起来真是清爽太多了。

时间久了有些用法容易忘，这里把平时项目里最顺手的几种写法整理下来。

<!-- more -->

## 1. 为啥不用 Vuex 了？

简单来说，Pinia 最大的爽点有这几个：
- **没有 Mutations 了**：以前改个数据，得先写个 action，再去触发 mutation，现在直接写个函数改 state 就行。
- **TS 支持极好**：不用自己绞尽脑汁去定义什么大全局类型，它自动能推导出来。
- **没啥花里胡哨的模块嵌套**：以前那套带 namespace 的 module 让人头晕，现在就是一个文件一个 store，想互相用直接引。

## 2. 安装和挂载

标准的套路：

```bash
npm install pinia
```

去 `main.js` 里插进去：

```javascript
import { createApp } from 'vue'
import { createPinia } from 'pinia'
import App from './App.vue'

const app = createApp(App)
// 就加这一行
app.use(createPinia())
app.mount('#app')
```

## 3. 写法一：像写 Vuex 一样的 Option 风格

如果你怀念以前的写法，可以这样写：

```javascript
// stores/counter.js
import { defineStore } from 'pinia'

// 第一个参数 'counter' 是这个库的唯一 ID
export const useCounterStore = defineStore('counter', {
  // 状态放这
  state: () => ({
    count: 0
  }),

  // 计算属性放这
  getters: {
    doubleCount: (state) => state.count * 2
  },

  // 动作（同步异步都行）放这
  actions: {
    increment() {
      // 直接 this 拿到 state 改掉，爽！
      this.count++
    }
  }
})
```

## 4. 写法二：强烈推荐的 Setup 风格

这个跟 Vue3 的 `setup` 语法一脉相承，用熟了特别自然：

```javascript
// stores/user.js
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

export const useUserStore = defineStore('user', () => {
  // state 就是普通的 ref()
  const token = ref('')
  
  // getters 就是 computed()
  const isLogin = computed(() => token.value !== '')

  // actions 就是普通的 function
  async function login(username, pwd) {
    const res = await fetch('/api/login') // 假装请求
    token.value = 'abc123xxx'
  }

  // 别忘了 return 出去
  return { token, isLogin, login }
})
```

## 5. 组件里怎么用？

这也是个容易踩坑的地方，如果你直接把属性解构出来，它就失去响应式了（跟 `props` 一样）。

```vue
<script setup>
import { useUserStore } from '@/stores/user'
import { storeToRefs } from 'pinia'

const userStore = useUserStore()

// ❌ 错误示范：别这样搞，数据变了页面不会刷新的
// const { token, isLogin } = userStore

// ✅ 正确姿势 1：要解构，用 storeToRefs 包一下
const { token, isLogin } = storeToRefs(userStore)

// 方法（actions）不用包，直接解构出来用
const { login } = userStore
</script>

<template>
  <!-- ✅ 正确姿势 2：懒得解构，直接用 -->
  <p>是否登录：{{ userStore.isLogin }}</p>
  <button @click="userStore.login">登录</button>
</template>
```

## 6. 其他几个常用的小技巧

**批量改状态（$patch）**

如果要同时改好几个状态，直接用 `$patch` 性能会好一点（只触发一次视图更新）：

```javascript
const store = useCounterStore()

// 传对象
store.$patch({
  count: store.count + 1,
  name: '小明'
})

// 传函数（逻辑复杂点的时候好用）
store.$patch((state) => {
  state.count++
  state.items.push('苹果')
})
```

**本地存储持久化插件**

以前手写 `localStorage`，现在推荐装个插件 `pinia-plugin-persistedstate`，一行配置就能让页面刷新数据不掉。

```javascript
export const useSettingsStore = defineStore('settings', () => {
  const theme = ref('dark')
  return { theme }
}, {
  // 加上这个，这库里的数据自动存本地，美滋滋
  persist: true 
})
```

总体来说，Pinia 这个轮子确实好用，没什么上手难度，现在写 Vue3 没它感觉都不会写代码了。
