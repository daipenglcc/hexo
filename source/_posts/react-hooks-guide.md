---
title: 彻底告别 Class 组件：React Hooks 常用姿势备忘
date: 2019-03-12 10:15:42
tags:
  - React
  - Hooks
categories: React
---

当年刚学 React 的时候，天天对着 Class 组件里的 `this.bind()` 和一堆长得要死、执行顺序玄学的生命周期函数发愁。后来 React 出了 Hooks，整个世界都清净了，再也不用去猜 `this` 到底指向谁了。

现在写新项目基本都是全盘函数式组件（Functional Component）。这里把最常用的几个 Hook 整理一下，方便自己抄代码。

<!-- more -->

## 1. useState：存数据的独苗

取代了以前的 `this.state`。

```jsx
import React, { useState } from 'react'

function Counter() {
  // 第一个变量是值，第二个是改值的方法。初始值设为 0
  const [count, setCount] = useState(0)

  return (
    <div>
      <p>点赞数：{count}</p>
      {/* 直接调方法，爽 */}
      <button onClick={() => setCount(count + 1)}>+1</button>
      
      {/* 如果依赖上一次的值，最好用回调函数写法，防坑 */}
      <button onClick={() => setCount(prev => prev - 1)}>-1</button>
    </div>
  )
}
```

**小坑提醒**：如果要存个大对象（比如表单），改的时候千万记得把原来的属性解构（`...prev`）塞回去，`useState` 不像以前那样会自动帮你合并对象了。

## 2. useEffect：缝合怪生命周期

这玩意儿统一把 `componentDidMount`、更新和卸载全缝合在一起了，主要用来发请求、绑事件。

```jsx
import React, { useState, useEffect } from 'react'

function UserProfile({ userId }) {
  const [user, setUser] = useState(null)

  useEffect(() => {
    // 这里相当于 componentDidMount (加载时) 和 componentDidUpdate (userId 变了)
    fetch(`/api/users/${userId}`)
      .then(res => res.json())
      .then(data => setUser(data))

    // 必须要 return 出去一个函数，这个就是组件销毁前要干的收尾工作（比如清定时器）
    return () => {
      console.log('打扫战场，撤退')
    }
  }, [userId])  
  // 👆 这里的数组叫依赖项，意思就是：只有 userId 变了，我才重新跑一次上面的代码。
  // 如果空着 []，那就是只在页面刚加载完跑一次。
  // 如果连数组都不写，那页面只要一刷新它就跑，很容易死循环死机！

  return <h2>{user?.name}</h2>
}
```

## 3. useContext：拯救 Props 嵌套地狱

组件嵌套太深，传个数据要穿过祖宗十八代，太累了。有了 Context，直接隔空传功：

```jsx
import React, { createContext, useContext, useState } from 'react'

// 先造个池子
const ThemeContext = createContext()

// 在最外层包一层
function App() {
  const [theme, setTheme] = useState('dark')
  return (
    <ThemeContext.Provider value={theme}>
      <Navbar />
    </ThemeContext.Provider>
  )
}

// 随便在下面哪一层，直接伸手掏就完事了
function Navbar() {
  const theme = useContext(ThemeContext)
  return <div className={`nav-${theme}`}>我是黑夜模式导航栏</div>
}
```

## 4. useRef：不管怎么刷都不变的值

有两个用处：一是绑定真实的 DOM（像以前的 `document.getElementById`），二是存一个无论组件怎么刷新，它的值都不会被重置的变量，而且**它变了不会触发页面刷新**。

```jsx
function TextInput() {
  const inputRef = useRef(null)
  const renderCount = useRef(0) // 存个数字

  // 页面每次刷新我偷偷加 1，但这不会引发页面再次刷新
  renderCount.current += 1

  const focusInput = () => {
    // 点按钮，让输入框光标闪烁
    inputRef.current.focus()
  }

  return (
    <div>
      <input ref={inputRef} placeholder="点下面按钮让我发光" />
      <button onClick={focusInput}>点我聚焦</button>
      <p>这破页面刷新了 {renderCount.current} 次</p>
    </div>
  )
}
```

## 5. useMemo & useCallback：性能优化的药膏

这两个只有在页面觉得卡的时候才需要加，没事干全加上反而会拖慢初始化速度。

### useMemo（用来记计算结果）

如果有个特别复杂的 for 循环计算，不想每次渲染页面都算一次：

```jsx
function ProductList({ products, filterWord }) {
  // 只有这两个变量变了，我才重新算。平时就拿上次算好的结果应付差事
  const filteredList = useMemo(() => {
    console.log('好累，开始狂算...')
    return products.filter(p => p.name.includes(filterWord))
  }, [products, filterWord])

  return <ul>...</ul>
}
```

### useCallback（用来记函数）

主要是配合 `React.memo`，防止每次刷新都生成一个新函数传给子组件，导致子组件无辜跟着刷新。

```jsx
// 只要依赖不变，这个函数在内存里的地址就永远一样
const handleClick = useCallback((id) => {
  console.log('处理点击:', id)
}, []) 
```

## 6. 自定义 Hook：最强装逼利器

把一堆逻辑抽出去写成一个 `useXxx` 的函数，代码立马变得清爽无比。比如我想自己封装个一键拿本地缓存的钩子：

```jsx
// hooks/useLocalStorage.js
function useLocalStorage(key, initialValue) {
  const [val, setVal] = useState(() => {
    const item = localStorage.getItem(key)
    return item ? JSON.parse(item) : initialValue
  })

  const setValue = (newValue) => {
    setVal(newValue)
    localStorage.setItem(key, JSON.stringify(newValue))
  }

  return [val, setValue]
}

// 别人用的时候：
function Settings() {
  // 跟 useState 长得一模一样，但它自己带了存本地的功能
  const [theme, setTheme] = useLocalStorage('theme', 'dark')
}
```

现在基本就靠着 `useState` 和 `useEffect` 这两把刷子走天下了。偶尔搞点自定义 Hook 骗骗代码行数，比以前 Class 组件清爽太多了。
