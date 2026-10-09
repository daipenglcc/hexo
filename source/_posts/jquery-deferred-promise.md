---
title: jQuery Deferred 对象：用好了能少写很多回调地狱
date: 2013-09-14 21:30:00
tags:
  - jQuery
  - JavaScript
  - 异步
categories: JavaScript
---

最近在做一个功能，要先请求用户信息，再根据用户 ID 请求权限列表，权限拿到了再初始化菜单。三个请求串联，最直觉的写法是嵌套 callback：

```javascript
$.ajax({ url: '/api/user', success: function(user) {
  $.ajax({ url: '/api/perms?uid=' + user.id, success: function(perms) {
    $.ajax({ url: '/api/menu', success: function(menu) {
      initMenu(menu, perms)
    }})
  }})
}})
```

三层嵌套，还没加错误处理，加上 error 回调再缩进两层，代码就基本没法看了。这个问题在 jQuery 1.5 引入 Deferred 对象之后其实有了很好的解法，但很多人用 jQuery 用了好几年，Deferred 根本没碰过。

<!-- more -->

## Deferred 是什么

`$.Deferred()` 是 jQuery 实现的一个 Promise/A 规范的变体（比标准 Promise 早很多年）。核心就是：把"异步操作的结果"和"处理结果的回调"解耦。

一个 Deferred 对象有两种状态转换：
- `resolve(value)` → 成功，触发注册的 `done` 回调
- `reject(reason)` → 失败，触发注册的 `fail` 回调

转换之后状态就锁定了，不能再变。

```javascript
function fetchUser(id) {
  var dfd = $.Deferred()

  $.ajax({
    url: '/api/user/' + id,
    success: function(data) {
      dfd.resolve(data)
    },
    error: function(xhr) {
      dfd.reject(xhr.status)
    }
  })

  // 返回 promise（只读的 deferred，外部只能 .done/.fail，不能 resolve/reject）
  return dfd.promise()
}
```

其实 `$.ajax` 本身从 1.5 开始就直接返回一个 Deferred 兼容的对象，所以上面这个 `fetchUser` 可以直接简化成：

```javascript
function fetchUser(id) {
  return $.ajax({ url: '/api/user/' + id })
}
```

## 链式调用解决嵌套问题

有了 `.then()`，原来的三层嵌套可以展平：

```javascript
fetchUser()
  .then(function(user) {
    return $.ajax({ url: '/api/perms?uid=' + user.id })
  })
  .then(function(perms) {
    return $.ajax({ url: '/api/menu' })
  })
  .then(function(menu) {
    initMenu(menu)
  })
  .fail(function(err) {
    showError('请求失败，请刷新重试')
  })
```

注意 `.then()` 里 return 的值会传给下一个 `.then()`，如果 return 的是一个 Deferred / Promise，链会等待它完成再继续。这是链式调用的关键机制。

## $.when：并行等多个请求

如果几个请求互不依赖，可以并行发，全部完成再处理：

```javascript
$.when(
  $.ajax('/api/user'),
  $.ajax('/api/config'),
  $.ajax('/api/notices')
).then(function(userRes, configRes, noticesRes) {
  // 三个请求的结果分别作为参数传进来
  // 每个 res 是个数组 [data, textStatus, jqXHR]
  var user    = userRes[0]
  var config  = configRes[0]
  var notices = noticesRes[0]

  initPage(user, config, notices)
}).fail(function() {
  // 任何一个失败就走这里
  showError('初始化失败')
})
```

比串行请求快多了，三个请求同时发。

## 用 Deferred 封装非 Ajax 的异步

这个是 Deferred 最容易被忽视的用法：它不只能配合 Ajax，任何异步操作都能包一层。

比如图片加载：

```javascript
function loadImage(src) {
  var dfd = $.Deferred()
  var img = new Image()
  img.onload  = function() { dfd.resolve(img) }
  img.onerror = function() { dfd.reject('图片加载失败: ' + src) }
  img.src = src
  return dfd.promise()
}

// 等多张图都加载完再渲染
$.when(
  loadImage('/imgs/banner.jpg'),
  loadImage('/imgs/logo.png')
).then(function(bannerImg, logoImg) {
  renderPage(bannerImg, logoImg)
})
```

再比如 localStorage 读取（有时候需要配合动画等 DOM 就绪的场景），甚至 Web Worker 的消息回传，都可以用 Deferred 包一层，统一成 Promise 接口处理。

## Deferred 和 Promise 的区别

Deferred 暴露了 `resolve` 和 `reject` 方法，可以从外部控制状态，这是比标准 Promise 更"危险"的地方——构造函数以外的代码也能 resolve/reject，容易出现状态被意外改变的问题。

标准 Promise（ES6）的设计做了约束：只有 `new Promise((resolve, reject) => {...})` 构造函数内部才能控制状态，外部拿到的只是 Promise 实例，只能 `.then()/.catch()`。

这就是为什么 ES6 Promise 出来之后，jQuery Deferred 就慢慢退出历史舞台了——前者设计上更安全，也是规范标准。不过在还没有 ES6 的年代，jQuery Deferred 已经是很优雅的异步解决方案了。

现在项目里 `async/await` 满天飞，再回头看 Deferred，有种看前辈解法的感觉。
