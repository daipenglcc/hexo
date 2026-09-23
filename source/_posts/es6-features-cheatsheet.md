---
title: 平时写代码常用的 ES6+ 语法小结
date: 2018-11-20 09:45:33
tags:
  - ES6
  - JavaScript
categories: JavaScript
---

虽然 ES6 出来已经很多年了，但平时写业务代码，翻来覆去用的其实也就那么几个特性。整理这篇算是给自己当个速查备忘录，全是日常搬砖比较实用的东西。

<!-- more -->

## 1. let 和 const

自从有了这俩，基本就不怎么写 `var` 了，块级作用域确实省了挺多麻烦。

```javascript
// 声明基本不动的常量，或者引用地址不变的对象
const API_BASE = 'https://api.example.com'
const config = { timeout: 3000 }
config.timeout = 5000  // 对象里的属性还是可以改的

// let 一般用在循环或者需要重新赋值的地方
for (let i = 0; i < 5; i++) {
  setTimeout(() => console.log(i), 100)
}
// 打印出来是 0 到 4，不再是一堆 5
```

## 2. 箭头函数

写法简短，最主要是不用再写 `const self = this` 这种恶心的代码了。

```javascript
// 简单写法
const add = (a, b) => a + b
const getUser = () => ({ name: 'Tom', age: 25 })  // 直接返回对象记得加括号

// 处理 this 的情况最常用
const timer = {
  count: 0,
  start() {
    // 这里箭头函数的 this 直接继承了外面的
    setInterval(() => {
      this.count++
      console.log(this.count)
    }, 1000)
  }
}
```

## 3. 模板字符串

以前拿加号拼字符串拼得头晕，现在用反引号舒服多了。

```javascript
const name = '光阴小栈'
const year = 2018

// 塞变量
const greeting = `欢迎来到 ${name}，现在是 ${year} 年`

// 多行 HTML 也能直接写
const html = `
  <div class="card">
    <h2>${name}</h2>
    <p>创建于 ${year} 年</p>
  </div>
`
```

## 4. 解构赋值

从后台拿到一大坨接口数据的时候，用这个提取字段最方便。

```javascript
const user = { name: 'Tom', age: 25, role: 'admin' }
const { name, age, role = 'user' } = user  // 还能顺手给个默认值

// 嵌套解构，比如拿接口返回的数据
const response = {
  data: {
    list: [1, 2, 3],
    pagination: { total: 100 }
  }
}
const { data: { list, pagination: { total } } } = response

// 数组解构偶尔也会用，比如换变量值
let a = 1, b = 2;
[a, b] = [b, a]
```

## 5. 展开运算符 (...)

平时合并对象、合并数组、透传 props 基本离不开它。

```javascript
// 拼数组
const arr1 = [1, 2, 3]
const arr2 = [4, 5, 6]
const merged = [...arr1, ...arr2]

// 拼配置项（后面同名的会覆盖前面的）
const defaults = { theme: 'light', lang: 'zh-CN' }
const userSettings = { theme: 'dark', fontSize: 14 }
const config = { ...defaults, ...userSettings }
```

## 6. async / await

处理请求再也不用写一堆 `.then()` 链式调用了，代码看起来像同步的一样。

```javascript
async function getUserOrders(userId) {
  try {
    const user = await fetchUser(userId)
    const orders = await fetchOrders(user.id)
    return orders
  } catch (error) {
    // 包个 try-catch 处理报错
    console.error('获取数据失败:', error)
    return []
  }
}

// 并行发请求也常用
async function loadDashboard() {
  const [users, posts] = await Promise.all([
    fetch('/api/users').then(r => r.json()),
    fetch('/api/posts').then(r => r.json())
  ])
  return { users, posts }
}
```

## 7. 数组的一些常用方法

循环遍历基本告别 `for` 循环，用几个内置方法写得更少。

```javascript
const users = [
  { id: 1, name: 'Tom', age: 25, active: true },
  { id: 2, name: 'Jerry', age: 30, active: false }
]

// 找特定那一个
const tom = users.find(u => u.name === 'Tom')

// 过滤一下
const activeUsers = users.filter(u => u.active)

// 转换格式
const names = users.map(u => u.name)

// 看下有没有满足条件的
const hasInactive = users.some(u => !u.active)
```

## 8. 可选链 (?.) 和 空值合并 (??)

虽然是后来版本的东西，但确实极大地减少了 `Cannot read property of undefined` 这种低级报错。

```javascript
const user = { profile: {} }

// 以前得一层层判断，现在一个问号搞定
const city = user?.profile?.address?.city  // 取不到就是 undefined，不会报错挂掉

// 给默认值，?? 只认 null 和 undefined，跟 || 把 0 当成 false 相比更安全
const port = config.port ?? 3000
```

基本上，掌握这些东西，看绝大多数的前端代码都没什么障碍了。不够的时候再回头去翻文档就行。
