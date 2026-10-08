---
title: 受不了 Redux 了，试试 Zustand 吧
date: 2023-11-12 10:15:28
tags:
  - React
  - Zustand
  - 状态管理
categories: React
---

用 React 搞项目，状态管理一直是绕不开的话题。之前公司项目全是 Redux，action、reducer、dispatch 那一套写下来，一个简单的计数器功能都要写三四个文件。后来看到 Zustand 这个库，试了一下，代码量直接砍了 70%，而且上手特别快。

<!-- more -->

## 1. Redux 到底烦在哪

先说说为什么想换。Redux 的问题不是不好用，而是太"重"了。

比如要做一个最简单的用户信息管理：

```javascript
// Redux 写法（省略了 store 配置）

// 1. 定义 action types
const SET_USER = 'SET_USER'
const CLEAR_USER = 'CLEAR_USER'

// 2. 定义 action creators
const setUser = (user) => ({ type: SET_USER, payload: user })
const clearUser = () => ({ type: CLEAR_USER })

// 3. 定义 reducer
const userReducer = (state = null, action) => {
  switch (action.type) {
    case SET_USER:
      return action.payload
    case CLEAR_USER:
      return null
    default:
      return state
  }
}

// 4. 组件里用 useSelector + useDispatch
function Profile() {
  const user = useSelector(state => state.user)
  const dispatch = useDispatch()
  // dispatch(setUser({ name: '张三' }))
}
```

光一个用户信息就这么多代码，项目大了 action 文件满天飞，看着就头疼。

## 2. Zustand：一个函数搞定 Store

```bash
npm install zustand
```

同样的功能用 Zustand：

```javascript
import { create } from 'zustand'

// 就这么多，没了
const useUserStore = create((set) => ({
  user: null,
  setUser: (user) => set({ user }),
  clearUser: () => set({ user: null }),
}))

// 组件里用
function Profile() {
  const user = useUserStore((state) => state.user)
  const setUser = useUserStore((state) => state.setUser)
  // setUser({ name: '张三' })
}
```

对比一下代码量，差距一目了然。而且不需要 Provider 包裹根组件，直接 import 就能用。

## 3. 日常用到的几种写法

### 异步操作

```javascript
const usePostStore = create((set) => ({
  posts: [],
  loading: false,
  
  fetchPosts: async () => {
    set({ loading: true })
    try {
      const res = await fetch('/api/posts')
      const posts = await res.json()
      set({ posts, loading: false })
    } catch (err) {
      console.error('加载失败:', err)
      set({ loading: false })
    }
  },
}))
```

不需要什么 thunk 或者 saga，直接在 action 里写 async/await 就行。

### 获取当前状态

有时候在 action 里需要拿到当前 state 的值，用 `get`：

```javascript
const useCartStore = create((set, get) => ({
  items: [],
  
  addItem: (product) => {
    const { items } = get()
    const existing = items.find(item => item.id === product.id)
    
    if (existing) {
      set({
        items: items.map(item =>
          item.id === product.id
            ? { ...item, quantity: item.quantity + 1 }
            : item
        )
      })
    } else {
      set({ items: [...items, { ...product, quantity: 1 }] })
    }
  },
  
  totalPrice: () => {
    return get().items.reduce((sum, item) => sum + item.price * item.quantity, 0)
  },
}))
```

### 持久化（刷新不丢数据）

```bash
npm install zustand
# persist 中间件是内置的，不用额外装
```

```javascript
import { create } from 'zustand'
import { persist } from 'zustand/middleware'

const useSettingsStore = create(
  persist(
    (set) => ({
      theme: 'light',
      language: 'zh-CN',
      setTheme: (theme) => set({ theme }),
      setLanguage: (lang) => set({ language: lang }),
    }),
    {
      name: 'app-settings', // localStorage 的 key
    }
  )
)
```

这样数据会自动存到 localStorage，刷新页面也不丢。

### 拆分多个 Store

Zustand 天然就是按功能拆分的，一个 `create()` 就是一个独立的 store：

```javascript
// stores/useUserStore.js
export const useUserStore = create(/* ... */)

// stores/useCartStore.js
export const useCartStore = create(/* ... */)

// stores/useSettingsStore.js
export const useSettingsStore = create(/* ... */)
```

哪个组件需要哪个就 import 哪个，互不干扰。

## 4. 性能：只订阅你需要的

Zustand 默认就有性能优化。你从 store 里只取某个字段，其他字段变了不会触发重渲染：

```javascript
// ✅ 只有 user 变了才重渲染
const user = useUserStore((state) => state.user)

// ❌ 这样写的话 store 里任何东西变了都会重渲染
const store = useUserStore()
```

所以记得用选择器函数去取值，别整个 store 都拿过来。

## 5. 跟其他方案对比

| 特性 | Redux | Zustand | Jotai |
|------|-------|---------|-------|
| 代码量 | 多 | 少 | 更少 |
| 学习成本 | 高 | 低 | 低 |
| Provider | 需要 | 不需要 | 需要 |
| 中间件 | 丰富 | 够用 | 较少 |
| DevTools | 官方支持 | 有插件 | 有插件 |
| 适合场景 | 大型复杂项目 | 中小型项目 | 原子化状态 |

Jotai 也不错，走的是原子化状态的路线，适合状态比较分散的场景。但我个人觉得 Zustand 的心智模型更简单，就是一个对象存状态+方法，很直观。

## 6. 什么时候还得用 Redux

说了这么多 Zustand 的好，但 Redux 也不是完全没有存在的意义：

- 项目特别大、团队特别多，Redux 的严格规范反而是优点
- 需要用到 Redux 生态里的某些中间件（saga、observable 之类的）
- 已有大量 Redux 代码的老项目，迁移成本太高

不过对于新项目，尤其是中小规模的，我是真心推荐试试 Zustand。写起来舒服，维护也简单。
