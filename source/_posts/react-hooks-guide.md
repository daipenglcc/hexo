---
title: React Hooks 入门与实践
date: 2019-03-12 10:15:42
tags:
  - React
  - Hooks
categories: React
---

React 16.8 正式引入了 Hooks，这是 React 近年来最具颠覆性的更新。Hooks 让函数组件也能拥有状态管理和生命周期能力，写法更简洁、逻辑复用更方便。本文从实际使用角度出发，梳理 React Hooks 的核心 API 和常见模式。

<!-- more -->

## 为什么需要 Hooks？

在 Hooks 之前，React 的状态逻辑只能写在 Class 组件中。这带来了几个问题：

- **逻辑复用困难**：复用有状态逻辑需要使用 HOC（高阶组件）或 Render Props，层层嵌套导致"嵌套地狱"
- **组件越来越复杂**：一个生命周期方法里塞满了不相关的逻辑，难以拆分
- **Class 的学习成本**：`this` 指向、`.bind()` 绑定、生命周期的执行顺序，对新手不友好

Hooks 的出现让函数组件成为了 React 开发的首选方式。

## 1. useState —— 状态管理

```jsx
import React, { useState } from 'react'

function Counter() {
  // 声明一个状态变量 count，初始值为 0
  const [count, setCount] = useState(0)

  return (
    <div>
      <p>你点击了 {count} 次</p>
      <button onClick={() => setCount(count + 1)}>+1</button>
      <button onClick={() => setCount(prev => prev - 1)}>-1</button>
      <button onClick={() => setCount(0)}>重置</button>
    </div>
  )
}
```

### 管理对象/数组状态

```jsx
function UserForm() {
  const [form, setForm] = useState({
    name: '',
    email: '',
    age: 0
  })

  const handleChange = (field, value) => {
    // 注意：必须展开旧状态，useState 不会自动合并
    setForm(prev => ({ ...prev, [field]: value }))
  }

  return (
    <div>
      <input
        value={form.name}
        onChange={e => handleChange('name', e.target.value)}
        placeholder="姓名"
      />
      <input
        value={form.email}
        onChange={e => handleChange('email', e.target.value)}
        placeholder="邮箱"
      />
    </div>
  )
}
```

## 2. useEffect —— 副作用处理

`useEffect` 统一处理了 Class 组件中 `componentDidMount`、`componentDidUpdate`、`componentWillUnmount` 三个生命周期：

```jsx
import React, { useState, useEffect } from 'react'

function UserProfile({ userId }) {
  const [user, setUser] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    // 组件挂载或 userId 变化时执行
    setLoading(true)

    fetch(`/api/users/${userId}`)
      .then(res => res.json())
      .then(data => {
        setUser(data)
        setLoading(false)
      })

    // 返回清除函数（组件卸载或依赖变化前执行）
    return () => {
      console.log('清除上一次的副作用')
    }
  }, [userId])  // 依赖数组：只有 userId 变化时才重新执行

  if (loading) return <p>加载中...</p>
  return <h2>{user?.name}</h2>
}
```

### 依赖数组的三种用法

```jsx
// 1. 每次渲染后都执行（不传依赖数组）
useEffect(() => {
  console.log('每次渲染都会执行')
})

// 2. 只在挂载时执行一次（空依赖数组）
useEffect(() => {
  console.log('仅挂载时执行一次')
  return () => console.log('组件卸载时执行')
}, [])

// 3. 依赖变化时执行（指定依赖）
useEffect(() => {
  console.log(`count 变为 ${count}`)
}, [count])
```

### 常见的 useEffect 场景

```jsx
// 事件监听
useEffect(() => {
  const handleResize = () => {
    setWindowWidth(window.innerWidth)
  }
  window.addEventListener('resize', handleResize)
  return () => window.removeEventListener('resize', handleResize)
}, [])

// 定时器
useEffect(() => {
  const timer = setInterval(() => {
    setSeconds(prev => prev + 1)
  }, 1000)
  return () => clearInterval(timer)
}, [])

// 修改页面标题
useEffect(() => {
  document.title = `(${unreadCount}) 消息中心`
}, [unreadCount])
```

## 3. useContext —— 跨组件传值

配合 `React.createContext` 使用，取代了 Consumer 组件的繁琐写法：

```jsx
import React, { createContext, useContext, useState } from 'react'

// 创建 Context
const ThemeContext = createContext()

// Provider 组件
function ThemeProvider({ children }) {
  const [theme, setTheme] = useState('light')

  const toggleTheme = () => {
    setTheme(prev => prev === 'light' ? 'dark' : 'light')
  }

  return (
    <ThemeContext.Provider value={{ theme, toggleTheme }}>
      {children}
    </ThemeContext.Provider>
  )
}

// 任意子组件中直接消费
function ThemeButton() {
  const { theme, toggleTheme } = useContext(ThemeContext)

  return (
    <button
      onClick={toggleTheme}
      style={{
        background: theme === 'dark' ? '#333' : '#fff',
        color: theme === 'dark' ? '#fff' : '#333'
      }}
    >
      当前主题: {theme}
    </button>
  )
}
```

## 4. useRef —— 引用与持久值

`useRef` 返回一个可变的 ref 对象，在组件整个生命周期内保持不变：

```jsx
function TextInput() {
  const inputRef = useRef(null)
  const renderCount = useRef(0)

  // 每次渲染计数（不会触发重新渲染）
  renderCount.current += 1

  const focusInput = () => {
    inputRef.current.focus()
  }

  return (
    <div>
      <input ref={inputRef} placeholder="点击按钮聚焦" />
      <button onClick={focusInput}>聚焦输入框</button>
      <p>渲染次数: {renderCount.current}</p>
    </div>
  )
}
```

## 5. useMemo 和 useCallback —— 性能优化

### useMemo：缓存计算结果

```jsx
function ProductList({ products, filter }) {
  // 只有 products 或 filter 变化时才重新计算
  const filteredProducts = useMemo(() => {
    console.log('执行过滤计算...')
    return products.filter(p =>
      p.name.toLowerCase().includes(filter.toLowerCase())
    )
  }, [products, filter])

  return (
    <ul>
      {filteredProducts.map(p => (
        <li key={p.id}>{p.name} - ¥{p.price}</li>
      ))}
    </ul>
  )
}
```

### useCallback：缓存函数引用

```jsx
function ParentComponent() {
  const [count, setCount] = useState(0)

  // 避免每次渲染都创建新函数，导致子组件不必要的重新渲染
  const handleClick = useCallback((id) => {
    console.log('处理点击:', id)
  }, [])  // 空依赖 = 函数引用永远不变

  return (
    <div>
      <p>{count}</p>
      <button onClick={() => setCount(c => c + 1)}>+1</button>
      <ChildComponent onClick={handleClick} />
    </div>
  )
}

// 配合 React.memo 使用效果最佳
const ChildComponent = React.memo(({ onClick }) => {
  console.log('子组件渲染')
  return <button onClick={() => onClick(1)}>子按钮</button>
})
```

## 6. 自定义 Hook —— 逻辑复用

自定义 Hook 是 Hooks 最强大的特性之一，以 `use` 开头的函数就是自定义 Hook：

```jsx
// hooks/useLocalStorage.js
function useLocalStorage(key, initialValue) {
  const [storedValue, setStoredValue] = useState(() => {
    try {
      const item = localStorage.getItem(key)
      return item ? JSON.parse(item) : initialValue
    } catch (error) {
      return initialValue
    }
  })

  const setValue = (value) => {
    const valueToStore = value instanceof Function ? value(storedValue) : value
    setStoredValue(valueToStore)
    localStorage.setItem(key, JSON.stringify(valueToStore))
  }

  return [storedValue, setValue]
}

// 使用
function Settings() {
  const [theme, setTheme] = useLocalStorage('theme', 'light')
  const [lang, setLang] = useLocalStorage('lang', 'zh-CN')
  // ...
}
```

```jsx
// hooks/useFetch.js - 通用数据请求 Hook
function useFetch(url) {
  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  useEffect(() => {
    let cancelled = false

    setLoading(true)
    fetch(url)
      .then(res => res.json())
      .then(json => {
        if (!cancelled) {
          setData(json)
          setLoading(false)
        }
      })
      .catch(err => {
        if (!cancelled) {
          setError(err)
          setLoading(false)
        }
      })

    return () => { cancelled = true }
  }, [url])

  return { data, loading, error }
}

// 使用
function ArticleList() {
  const { data, loading, error } = useFetch('/api/articles')

  if (loading) return <p>加载中...</p>
  if (error) return <p>加载失败: {error.message}</p>
  return <ul>{data.map(a => <li key={a.id}>{a.title}</li>)}</ul>
}
```

## Hooks 使用规则

使用 Hooks 必须遵守两条规则：

1. **只在函数组件的顶层调用**：不要在循环、条件语句或嵌套函数中调用 Hook
2. **只在 React 函数组件或自定义 Hook 中调用**：不要在普通 JavaScript 函数中调用

```jsx
// ❌ 错误用法
function Bad({ show }) {
  if (show) {
    const [value, setValue] = useState('')  // 不能在条件语句中
  }
}

// ✅ 正确用法
function Good({ show }) {
  const [value, setValue] = useState('')
  if (!show) return null
  return <input value={value} onChange={e => setValue(e.target.value)} />
}
```

Hooks 是 React 发展方向上的一次重大转变，掌握了这些核心 API，就能覆盖绝大多数 React 开发场景。
