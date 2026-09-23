---
title: Pinia 状态管理完全指南
date: 2022-02-28 09:45:18
tags:
  - Vue
  - Pinia
  - 状态管理
categories: Vue
---

Pinia 已经成为 Vue 官方推荐的状态管理方案，替代了 Vuex 的地位。相比 Vuex，Pinia 去掉了冗余的 mutations，完美支持 TypeScript，API 设计更符合 Composition API 风格。本文系统介绍 Pinia 的核心用法和最佳实践。

<!-- more -->

## 为什么从 Vuex 迁移到 Pinia？

| 特性 | Vuex 4 | Pinia |
| :--- | :--- | :--- |
| Vue 3 支持 | ✅ | ✅ |
| TypeScript 支持 | 一般（需要额外类型声明） | 原生支持，类型自动推断 |
| Mutations | 需要 mutations 修改状态 | 直接修改，无需 mutations |
| Modules | 嵌套模块，命名空间 | 扁平化 Store，互相引用 |
| 代码体积 | ~1KB | ~1KB |
| DevTools | ✅ | ✅ |

## 1. 安装与初始化

```bash
npm install pinia
```

```javascript
// main.js
import { createApp } from 'vue'
import { createPinia } from 'pinia'
import App from './App.vue'

const app = createApp(App)
app.use(createPinia())
app.mount('#app')
```

## 2. 定义 Store

### Option Store 风格（类似 Vuex）

```javascript
// stores/counter.js
import { defineStore } from 'pinia'

export const useCounterStore = defineStore('counter', {
  state: () => ({
    count: 0,
    name: '计数器'
  }),

  getters: {
    doubleCount: (state) => state.count * 2,
    // getter 中访问其他 getter
    doubleCountPlusOne() {
      return this.doubleCount + 1
    }
  },

  actions: {
    increment() {
      this.count++
    },
    async fetchCount() {
      const res = await fetch('/api/count')
      const data = await res.json()
      this.count = data.count
    }
  }
})
```

### Setup Store 风格（推荐，更灵活）

```javascript
// stores/user.js
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

export const useUserStore = defineStore('user', () => {
  // state —— ref()
  const userInfo = ref(null)
  const token = ref(localStorage.getItem('token') || '')
  const loading = ref(false)

  // getters —— computed()
  const isLoggedIn = computed(() => !!token.value)
  const userName = computed(() => userInfo.value?.name || '游客')

  // actions —— 普通函数
  async function login(credentials) {
    loading.value = true
    try {
      const res = await fetch('/api/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(credentials)
      })
      const data = await res.json()

      token.value = data.token
      userInfo.value = data.user
      localStorage.setItem('token', data.token)
    } finally {
      loading.value = false
    }
  }

  function logout() {
    token.value = ''
    userInfo.value = null
    localStorage.removeItem('token')
  }

  return {
    userInfo, token, loading,
    isLoggedIn, userName,
    login, logout
  }
})
```

## 3. 在组件中使用

```vue
<script setup>
import { useUserStore } from '@/stores/user'
import { useCounterStore } from '@/stores/counter'
import { storeToRefs } from 'pinia'

const userStore = useUserStore()
const counterStore = useCounterStore()

// ❌ 直接解构会丢失响应性
// const { isLoggedIn, userName } = userStore

// ✅ 使用 storeToRefs 保持响应性
const { isLoggedIn, userName, loading } = storeToRefs(userStore)
// actions 可以直接解构
const { login, logout } = userStore

async function handleLogin() {
  await login({ username: 'tom', password: '123456' })
}
</script>

<template>
  <div>
    <div v-if="isLoggedIn">
      <p>欢迎, {{ userName }}</p>
      <p>计数: {{ counterStore.count }} / 双倍: {{ counterStore.doubleCount }}</p>
      <button @click="counterStore.increment()">+1</button>
      <button @click="logout">退出</button>
    </div>
    <div v-else>
      <button @click="handleLogin" :disabled="loading">
        {{ loading ? '登录中...' : '登录' }}
      </button>
    </div>
  </div>
</template>
```

## 4. 修改状态的多种方式

```javascript
const store = useCounterStore()

// 方式一：直接修改
store.count++

// 方式二：$patch 批量修改（适合同时更新多个属性）
store.$patch({
  count: store.count + 1,
  name: '新名称'
})

// 方式三：$patch 函数形式（适合复杂逻辑）
store.$patch((state) => {
  state.count++
  state.name = `计数器-${state.count}`
})

// 方式四：调用 action
store.increment()

// 重置为初始值
store.$reset()
```

## 5. Store 之间互相引用

```javascript
// stores/cart.js
import { defineStore } from 'pinia'
import { useUserStore } from './user'

export const useCartStore = defineStore('cart', () => {
  const items = ref([])

  const totalPrice = computed(() =>
    items.value.reduce((sum, item) => sum + item.price * item.quantity, 0)
  )

  async function checkout() {
    const userStore = useUserStore()

    if (!userStore.isLoggedIn) {
      throw new Error('请先登录')
    }

    await fetch('/api/orders', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${userStore.token}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ items: items.value })
    })

    items.value = []
  }

  return { items, totalPrice, checkout }
})
```

## 6. 数据持久化插件

```bash
npm install pinia-plugin-persistedstate
```

```javascript
// main.js
import { createPinia } from 'pinia'
import piniaPluginPersistedstate from 'pinia-plugin-persistedstate'

const pinia = createPinia()
pinia.use(piniaPluginPersistedstate)
```

```javascript
// stores/settings.js
export const useSettingsStore = defineStore('settings', () => {
  const theme = ref('light')
  const language = ref('zh-CN')
  const fontSize = ref(14)

  return { theme, language, fontSize }
}, {
  // 开启持久化，默认存储到 localStorage
  persist: {
    key: 'app-settings',
    paths: ['theme', 'language'],  // 只持久化指定字段
    storage: localStorage
  }
})
```

## 7. 监听状态变化

```javascript
const store = useUserStore()

// 监听整个 store 的变化
store.$subscribe((mutation, state) => {
  console.log('状态变化类型:', mutation.type)   // 'direct' | 'patch object' | 'patch function'
  console.log('变更事件:', mutation.events)
  console.log('store ID:', mutation.storeId)

  // 每次状态变化自动保存到 localStorage
  localStorage.setItem('user-state', JSON.stringify(state))
})

// 监听 action 执行
store.$onAction(({ name, args, after, onError }) => {
  const startTime = Date.now()
  console.log(`Action "${name}" 开始执行，参数:`, args)

  after((result) => {
    console.log(`Action "${name}" 执行成功，耗时 ${Date.now() - startTime}ms`)
  })

  onError((error) => {
    console.error(`Action "${name}" 执行失败:`, error)
  })
})
```

Pinia 的设计简洁而强大，是 Vue 3 项目状态管理的最佳选择。
