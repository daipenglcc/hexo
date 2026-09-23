---
title: ES6+ 常用新特性速查手册
date: 2018-11-20 09:45:33
tags:
  - ES6
  - JavaScript
categories: JavaScript
---

ES6（ECMAScript 2015）以及后续版本为 JavaScript 带来了大量现代化语法特性。这些特性在 2018 年的主流浏览器和 Node.js 中已经得到了良好支持。本文整理了日常开发中最高频使用的 ES6+ 特性，作为快速查阅手册。

<!-- more -->

## 1. let 和 const

`let` 和 `const` 取代 `var`，提供了块级作用域，解决了变量提升和作用域污染问题。

```javascript
// const 声明常量（引用不可变）
const API_BASE = 'https://api.example.com'
const config = { timeout: 3000 }
config.timeout = 5000  // ✅ 对象属性可修改
// config = {}         // ❌ 引用不可重新赋值

// let 声明可变变量，块级作用域
for (let i = 0; i < 5; i++) {
  setTimeout(() => console.log(i), 100)
}
// 输出: 0, 1, 2, 3, 4（而非 var 的 5, 5, 5, 5, 5）
```

## 2. 箭头函数

箭头函数语法更简洁，且不绑定自己的 `this`，而是从外层作用域继承：

```javascript
// 基础用法
const add = (a, b) => a + b
const square = x => x * x  // 单参数可省略括号
const getUser = () => ({ name: 'Tom', age: 25 })  // 返回对象需加括号

// this 绑定 —— 最实用的场景
const timer = {
  count: 0,
  start() {
    // 箭头函数继承外层 this，不再需要 const self = this
    setInterval(() => {
      this.count++
      console.log(this.count)
    }, 1000)
  }
}
```

## 3. 模板字符串

使用反引号包裹，支持多行文本和变量插值：

```javascript
const name = '光阴小栈'
const year = 2018

// 变量插值
const greeting = `欢迎来到 ${name}，现在是 ${year} 年`

// 多行字符串
const html = `
  <div class="card">
    <h2>${name}</h2>
    <p>创建于 ${year} 年</p>
  </div>
`

// 支持表达式
const message = `共 ${items.length} 篇文章，${items.length > 0 ? '快来看看' : '暂无内容'}`
```

## 4. 解构赋值

从数组或对象中快速提取值并赋给变量：

```javascript
// 对象解构
const user = { name: 'Tom', age: 25, role: 'admin' }
const { name, age, role = 'user' } = user

// 重命名
const { name: userName, age: userAge } = user

// 嵌套解构
const response = {
  data: {
    list: [1, 2, 3],
    pagination: { page: 1, total: 100 }
  }
}
const { data: { list, pagination: { total } } } = response

// 数组解构
const [first, second, ...rest] = [1, 2, 3, 4, 5]
// first = 1, second = 2, rest = [3, 4, 5]

// 交换变量
let a = 1, b = 2;
[a, b] = [b, a]

// 函数参数解构（Vue 组件中非常常见）
function createUser({ name, age, email = '' }) {
  return { name, age, email, createdAt: Date.now() }
}
```

## 5. 展开运算符与剩余参数

`...` 操作符在不同位置有不同含义：

```javascript
// 展开数组
const arr1 = [1, 2, 3]
const arr2 = [4, 5, 6]
const merged = [...arr1, ...arr2]  // [1, 2, 3, 4, 5, 6]

// 展开对象（ES2018）
const defaults = { theme: 'light', lang: 'zh-CN' }
const userSettings = { theme: 'dark', fontSize: 14 }
const config = { ...defaults, ...userSettings }
// { theme: 'dark', lang: 'zh-CN', fontSize: 14 }

// 剩余参数
function sum(...numbers) {
  return numbers.reduce((acc, n) => acc + n, 0)
}
sum(1, 2, 3, 4)  // 10

// 实际场景：React / Vue 中的 props 透传
const { className, ...restProps } = props
```

## 6. Promise 与 async/await

处理异步操作的现代方式：

```javascript
// Promise 基本使用
function fetchUser(id) {
  return new Promise((resolve, reject) => {
    setTimeout(() => {
      if (id > 0) {
        resolve({ id, name: `User_${id}` })
      } else {
        reject(new Error('无效的用户 ID'))
      }
    }, 1000)
  })
}

// Promise 链式调用
fetchUser(1)
  .then(user => fetchOrders(user.id))
  .then(orders => console.log(orders))
  .catch(err => console.error(err))

// async/await —— 更直观的异步写法（ES2017）
async function getUserOrders(userId) {
  try {
    const user = await fetchUser(userId)
    const orders = await fetchOrders(user.id)
    return orders
  } catch (error) {
    console.error('获取数据失败:', error.message)
    return []
  }
}

// 并行请求
async function loadDashboard() {
  const [users, posts, stats] = await Promise.all([
    fetch('/api/users').then(r => r.json()),
    fetch('/api/posts').then(r => r.json()),
    fetch('/api/stats').then(r => r.json())
  ])
  return { users, posts, stats }
}
```

## 7. 模块化 (import / export)

原生的模块系统，取代了 CommonJS 的 `require`：

```javascript
// utils.js - 命名导出
export const formatDate = (date) => {
  return new Date(date).toLocaleDateString('zh-CN')
}

export function debounce(fn, delay = 300) {
  let timer
  return function (...args) {
    clearTimeout(timer)
    timer = setTimeout(() => fn.apply(this, args), delay)
  }
}

// api.js - 默认导出
export default class ApiClient {
  constructor(baseURL) {
    this.baseURL = baseURL
  }
  async get(path) {
    const res = await fetch(`${this.baseURL}${path}`)
    return res.json()
  }
}

// main.js - 导入使用
import ApiClient from './api'
import { formatDate, debounce } from './utils'
```

## 8. 数组新方法

```javascript
const users = [
  { id: 1, name: 'Tom', age: 25, active: true },
  { id: 2, name: 'Jerry', age: 30, active: false },
  { id: 3, name: 'Alice', age: 22, active: true }
]

// find - 查找第一个满足条件的元素
const tom = users.find(u => u.name === 'Tom')

// findIndex - 查找索引
const index = users.findIndex(u => u.id === 2)

// filter - 过滤
const activeUsers = users.filter(u => u.active)

// map - 映射转换
const names = users.map(u => u.name)

// some / every - 存在性判断
const hasInactive = users.some(u => !u.active)     // true
const allActive = users.every(u => u.active)        // false

// reduce - 聚合计算
const totalAge = users.reduce((sum, u) => sum + u.age, 0)

// includes（ES2016）
const fruits = ['apple', 'banana', 'orange']
fruits.includes('banana')  // true
```

## 9. 对象增强写法

```javascript
const name = 'Tom'
const age = 25

// 属性简写
const user = { name, age }  // 等同于 { name: name, age: age }

// 方法简写
const utils = {
  formatDate(date) {    // 不再需要 formatDate: function(date)
    return new Date(date).toISOString()
  },
  // 计算属性名
  [`get${name}Info`]() {
    return { name, age }
  }
}

// Object.assign - 对象合并
const target = { a: 1 }
const result = Object.assign(target, { b: 2 }, { c: 3 })

// Object.keys / values / entries
const config = { host: 'localhost', port: 3000 }
Object.keys(config)     // ['host', 'port']
Object.values(config)   // ['localhost', 3000]
Object.entries(config)  // [['host', 'localhost'], ['port', 3000]]
```

## 10. 可选链与空值合并（ES2020）

这两个特性虽然是 ES2020 标准，但 2018 年在 Babel 转译下已可使用：

```javascript
// 可选链 ?.
const user = { profile: { address: { city: '北京' } } }
const city = user?.profile?.address?.city  // '北京'
const zip = user?.profile?.address?.zip    // undefined（不会报错）

// 空值合并 ??
const port = config.port ?? 3000      // 仅当 port 为 null/undefined 时取默认值
const title = input.title ?? '无标题'  // 0 和 '' 不会触发默认值（与 || 的区别）
```

## 小结

| 特性 | 用途 | 使用频率 |
| :--- | :--- | :---: |
| `let` / `const` | 块级作用域声明 | ⭐⭐⭐⭐⭐ |
| 箭头函数 | 简洁函数 + this 继承 | ⭐⭐⭐⭐⭐ |
| 解构赋值 | 快速提取值 | ⭐⭐⭐⭐⭐ |
| 模板字符串 | 字符串拼接 | ⭐⭐⭐⭐⭐ |
| `...` 展开运算符 | 数组/对象合并与拷贝 | ⭐⭐⭐⭐ |
| `async / await` | 异步流程控制 | ⭐⭐⭐⭐⭐ |
| `import / export` | 模块化 | ⭐⭐⭐⭐⭐ |
| 可选链 `?.` | 安全访问嵌套属性 | ⭐⭐⭐⭐ |

掌握这些特性，基本覆盖了日常 90% 以上的 ES6+ 使用场景。
