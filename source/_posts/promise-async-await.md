---
title: 被回调地狱逼疯后：Promise 和 async/await 踩坑备忘
date: 2018-03-22 20:15:33
tags:
  - JavaScript
  - Promise
  - 异步编程
categories: JavaScript
---

写 Node 接口的时候，最开始啥也不懂，读个文件套个数据库查询再发个请求，三层回调嵌套下来代码就往右边飞了，缩进多到看不清哪个大括号是哪个的。后来被人安利了 Promise，再后来切到 async/await，世界终于清静了。这里记一下我在实际项目里踩过的坑和一些常用写法。

<!-- more -->

## 1. 先说说回调地狱有多恶心

大家应该都经历过这种代码：

```javascript
// 先登录，再拿用户信息，再拿订单列表……
login(username, password, function(err, token) {
  if (err) { console.error(err); return }
  getUserInfo(token, function(err, user) {
    if (err) { console.error(err); return }
    getOrders(user.id, function(err, orders) {
      if (err) { console.error(err); return }
      console.log(orders)
      // 还没完呢，如果还要查订单详情，继续套……
    })
  })
})
```

每次写完这种东西，自己过两周再看都得愣半天。

## 2. Promise 基本用法

Promise 说白了就是把"以后才能拿到的东西"先用一个对象包起来，想用结果的时候用 `.then()` 去拿。

```javascript
// 封装一个请求
function fetchUser(id) {
  return new Promise((resolve, reject) => {
    // 模拟网络请求
    setTimeout(() => {
      if (id) {
        resolve({ id, name: '张三' })
      } else {
        reject(new Error('id 不能为空'))
      }
    }, 1000)
  })
}

// 使用
fetchUser(1)
  .then(user => {
    console.log(user.name) // 张三
    return fetchOrders(user.id)
  })
  .then(orders => {
    console.log(orders)
  })
  .catch(err => {
    // 链条上任何一步出错都会跑到这里
    console.error('哪里出问题了:', err.message)
  })
```

比回调好看多了，至少代码不会一直往右边缩进。

## 3. 我踩过的几个坑

### 坑一：.then() 里忘了 return

这个是新手最容易中招的，.then() 里面如果调了另一个异步操作但没 return，后面的 .then() 拿到的就是 undefined。

```javascript
// ❌ 错误写法
fetchUser(1)
  .then(user => {
    fetchOrders(user.id) // 忘了 return！
  })
  .then(orders => {
    console.log(orders)  // undefined，因为上面没 return
  })

// ✅ 正确写法
fetchUser(1)
  .then(user => {
    return fetchOrders(user.id) // 记得 return
  })
  .then(orders => {
    console.log(orders)  // 正常拿到数据
  })
```

### 坑二：.catch() 的位置

.catch() 只能捕获它前面链条上的错误。如果 .catch() 后面还有 .then()，那个 .then() 还是会执行的。

```javascript
fetchUser(1)
  .then(user => {
    throw new Error('手动抛个错')
  })
  .catch(err => {
    console.error(err.message) // 捕获到了
    // 注意：这里没 throw 的话，下面的 then 还是会跑
  })
  .then(() => {
    console.log('我还是执行了') // 这行会打印！
  })
```

### 坑三：Promise.all 其中一个挂了全挂

并发请求的时候常用 `Promise.all()`，但只要有一个 reject，整个就进 catch 了，其他成功的结果也拿不到。

```javascript
// 三个请求只要挂一个，全部完蛋
Promise.all([
  fetch('/api/users'),
  fetch('/api/orders'),
  fetch('/api/products')  // 假设这个挂了
])
.then(([users, orders, products]) => {
  // 这里不会执行
})
.catch(err => {
  // 直接到这了，前两个成功的数据也没了
})
```

如果你想"挂了也无所谓，能拿多少拿多少"，用 `Promise.allSettled()`：

```javascript
Promise.allSettled([
  fetch('/api/users'),
  fetch('/api/orders'),
  fetch('/api/products')
])
.then(results => {
  // 每个结果都有 status 字段：'fulfilled' 或 'rejected'
  results.forEach(r => {
    if (r.status === 'fulfilled') {
      console.log('成功:', r.value)
    } else {
      console.log('失败:', r.reason)
    }
  })
})
```

## 4. async/await：写异步终于像写同步了

说实话我现在已经很少直接写 .then() 了，async/await 简直是解放双手。

```javascript
async function loadDashboard() {
  try {
    const user = await fetchUser(1)
    const orders = await fetchOrders(user.id)
    const stats = await fetchStats(user.id)
    
    return { user, orders, stats }
  } catch (err) {
    console.error('加载失败:', err.message)
    return null
  }
}
```

但要注意别犯一个低级错误——不必要的串行请求：

```javascript
// ❌ 这三个请求其实互不依赖，没必要一个等一个
async function loadPage() {
  const users = await fetchUsers()      // 等1秒
  const posts = await fetchPosts()      // 再等1秒
  const comments = await fetchComments() // 再等1秒
  // 总共等了3秒
}

// ✅ 没有依赖关系的请求应该并发
async function loadPage() {
  const [users, posts, comments] = await Promise.all([
    fetchUsers(),
    fetchPosts(),
    fetchComments()
  ])
  // 只等最慢的那一个，大概1秒多
}
```

## 5. 循环里用 await 要小心

在 for 循环里用 await 是没问题的，但在 forEach 里用就有坑了：

```javascript
// ❌ forEach 里的 await 不会等
const ids = [1, 2, 3]
ids.forEach(async (id) => {
  const user = await fetchUser(id)
  console.log(user)  // 这三个几乎同时打印，不是你想要的顺序执行
})
console.log('done')  // 这行比上面的先打印！

// ✅ 想顺序执行就用 for...of
for (const id of ids) {
  const user = await fetchUser(id)
  console.log(user)  // 一个一个来
}

// ✅ 想并发就用 Promise.all + map
const users = await Promise.all(
  ids.map(id => fetchUser(id))
)
```

这个坑我当时在处理批量上传文件的时候踩的，排查了好一会儿才发现是 forEach 的问题。

总的来说，日常写业务代码，基本就是 async/await + try/catch + Promise.all 这几板斧。够用了。
