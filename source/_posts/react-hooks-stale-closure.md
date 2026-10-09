---
title: React Hooks 的闭包陷阱：stale closure 问题彻底搞清楚
date: 2019-11-03 20:30:25
tags:
  - React
  - Hooks
  - JavaScript
  - 闭包
categories: React
---

React 16.8 发布 Hooks 大概一年了，用得越顺手越容易踩到一个坑：**stale closure（过期闭包）**。写了一个看起来正确的代码，但跑起来状态不对，打断点发现读到的是旧值。这个问题本质上不是 React 的 bug，而是 JavaScript 闭包的工作机制。

<!-- more -->

## 先复现问题

写一个每秒打印 count 的定时器：

```jsx
function Counter() {
  const [count, setCount] = useState(0)

  useEffect(() => {
    const timer = setInterval(() => {
      console.log('当前 count：', count)  // 永远打印 0
    }, 1000)
    return () => clearInterval(timer)
  }, [])  // 空依赖，只执行一次

  return <button onClick={() => setCount(c => c + 1)}>点我 {count}</button>
}
```

点几次按钮，按钮上的数字在增加，但控制台一直打印 `当前 count：0`。

## 为什么会这样

关键在于 `useEffect` 的回调是在**第一次渲染时**执行的，那个时候 `count` 是 `0`。`setInterval` 的回调函数通过闭包捕获了那个时刻的 `count`——值是 `0`，并且这个 `count` 变量永远不会更新，因为它是第一次渲染时那个函数作用域里的值。

之后每次 `setCount` 触发重渲染，React 会调用 Counter 函数，创建**新的** `count` 变量（值是最新的），但旧的 `setInterval` 回调里捕获的仍然是旧的 `count`。

可以把每次渲染想象成一个快照：

```
第1次渲染：count_1 = 0, effect 里的 count 引用的是 count_1
第2次渲染：count_2 = 1, 但 setInterval 还在用 count_1
第3次渲染：count_3 = 2, setInterval 还在用 count_1
```

## 解法一：在依赖数组里加上 count

```jsx
useEffect(() => {
  const timer = setInterval(() => {
    console.log('当前 count：', count)  // 现在能拿到最新值
  }, 1000)
  return () => clearInterval(timer)
}, [count])  // count 变化时重新执行 effect，清掉旧定时器，建新的
```

每次 `count` 变化，effect 重新执行，新的 `setInterval` 闭包捕获了最新的 `count`。

缺点：`count` 每变一次，定时器就销毁重建一次，不够优雅。

## 解法二：useRef 存可变值

```jsx
function Counter() {
  const [count, setCount] = useState(0)
  const countRef = useRef(count)  // ref 不会触发重渲染，但值是可变的

  // 每次渲染同步 ref
  useEffect(() => {
    countRef.current = count
  })

  useEffect(() => {
    const timer = setInterval(() => {
      // 读 ref.current，永远是最新值
      console.log('当前 count：', countRef.current)
    }, 1000)
    return () => clearInterval(timer)
  }, [])  // 定时器只建一次

  return <button onClick={() => setCount(c => c + 1)}>点我 {count}</button>
}
```

`useRef` 返回的对象在整个组件生命周期里是同一个引用，`.current` 是可变的。闭包里读 `countRef.current`，每次读的时候才取值，所以永远是最新的。

这个模式还可以封装成自定义 hook：

```javascript
function useLatest(value) {
  const ref = useRef(value)
  useEffect(() => {
    ref.current = value
  })
  return ref
}

// 用起来
const countRef = useLatest(count)
```

## 解法三：函数式更新（针对 setState 的特殊场景）

如果在定时器里只是要累加，不需要"读当前 count"，用 setState 的函数式更新就够了：

```jsx
useEffect(() => {
  const timer = setInterval(() => {
    // 不直接用 count，而是拿到最新 state 再 +1
    setCount(prevCount => prevCount + 1)
  }, 1000)
  return () => clearInterval(timer)
}, [])
```

`setCount(prev => prev + 1)` 里的 `prev` 是 React 保证的最新 state，和闭包无关。

## useCallback 的同类问题

这个坑在 `useCallback` 里很常见：

```jsx
// ❌ 每次 userId 变化，回调不会更新（因为 useCallback 缓存了旧版本）
const fetchData = useCallback(async () => {
  const data = await api.getUser(userId)  // userId 可能是过期的旧值
  setUserData(data)
}, [])  // 忘记加依赖

// ✅ 正确做法：把依赖加进去
const fetchData = useCallback(async () => {
  const data = await api.getUser(userId)
  setUserData(data)
}, [userId])  // userId 变了，fetchData 重新生成
```

## ESLint 插件救场

手动维护 `useEffect` / `useCallback` 的依赖数组很容易漏，推荐装 `eslint-plugin-react-hooks`：

```bash
npm install --save-dev eslint-plugin-react-hooks
```

```json
// .eslintrc
{
  "plugins": ["react-hooks"],
  "rules": {
    "react-hooks/rules-of-hooks": "error",
    "react-hooks/exhaustive-deps": "warn"  // 依赖数组不完整时发警告
  }
}
```

这个 lint 规则能静态分析 effect 里用到了哪些外部变量，自动检测缺失的依赖，能拦住大部分 stale closure 问题。

## 根本原因

React Hooks 的心智模型需要转变：**每次渲染都是独立的，有自己的 props、state、事件处理函数和 effect**。闭包里的值是"渲染时的快照"，不是"永远实时的当前值"。

接受了这个模型，stale closure 就不是坑了，而是符合预期的行为。需要打破这个规则的地方，用 `ref` 显式保存可变引用。
