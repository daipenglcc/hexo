---
title: 浏览器缓存机制详解：强缓存、协商缓存和 Service Worker
date: 2017-05-20 15:30:10
tags:
  - HTTP
  - 缓存
  - 性能优化
  - Service Worker
categories: 性能优化
---

最近在做性能优化，把缓存这块系统研究了一遍。发现很多人对"浏览器缓存"的理解停留在"设置 Expires 头"这个层面，实际上浏览器缓存有完整的分层体系，搞清楚了才能做对决策。

<!-- more -->

## 缓存的层级

从请求触发到拿到数据，浏览器会依次检查：

```
内存缓存 (Memory Cache)
  → Service Worker Cache
    → 磁盘缓存 (Disk Cache / HTTP Cache)
      → 推送缓存 (Push Cache，HTTP/2)
        → 网络请求
```

大部分人熟悉的是"磁盘缓存"这层，也就是 HTTP 缓存，由响应头控制。

## 强缓存（不请求服务器）

命中强缓存时，浏览器直接从本地取数据，不发任何请求给服务器，状态码显示 `200 (from disk cache)` 或 `200 (from memory cache)`。

控制强缓存的两个响应头：

**Cache-Control**（优先级更高）

```
Cache-Control: max-age=31536000, public
```

- `max-age=N`：资源在 N 秒内有效，从响应时间算起
- `public`：响应可被 CDN、代理等中间节点缓存
- `private`：只能被用户浏览器缓存，不能被共享缓存
- `no-cache`：**不是"不缓存"**，而是"每次使用缓存前先和服务器验证"（走协商缓存）
- `no-store`：真正的"不缓存"，每次都下载新的
- `immutable`：资源内容永远不变，浏览器连协商缓存请求都不发（Chrome 支持）

**Expires**（老写法，已不推荐）

```
Expires: Wed, 20 May 2018 06:00:00 GMT
```

是绝对时间，依赖客户端时钟，时区或时间不对就乱了。`Cache-Control` 存在时，`Expires` 被忽略。

## 协商缓存（服务器决定用不用缓存）

强缓存过期后，浏览器会发请求问服务器"资源有没有变"。服务器说没变就返回 `304 Not Modified`，浏览器用本地缓存；服务器说变了就返回 `200` 加新内容。

两套机制：

**Last-Modified / If-Modified-Since**

服务器首次响应带：
```
Last-Modified: Mon, 20 May 2017 12:00:00 GMT
```

浏览器再次请求时带：
```
If-Modified-Since: Mon, 20 May 2017 12:00:00 GMT
```

服务器比较文件修改时间，没变就 304。

**问题**：精度是秒级。同一秒内修改文件，`Last-Modified` 不变，服务器认为没变，但实际变了。

**ETag / If-None-Match**（优先级更高）

服务器首次响应带文件的"指纹"：
```
ETag: "abc123def456"
```

浏览器再次请求：
```
If-None-Match: "abc123def456"
```

ETag 一般是文件内容的哈希值，内容变了 ETag 必然变，比 `Last-Modified` 更准确。

**两者都存在时，`ETag / If-None-Match` 优先**。

## 实际的缓存策略

不是所有资源都用同一套策略，要分类：

**HTML 文件**
```
Cache-Control: no-cache
```
每次请求都到服务器验证一下，保证用户拿到的入口 HTML 是最新的。

**JS/CSS/图片（带 hash 文件名）**
```
Cache-Control: max-age=31536000, immutable
```
文件名里带内容 hash（如 `app.3f2a9b.js`），内容变了文件名也变，老文件不会被访问到，所以可以设一年的强缓存 + `immutable`，命中率最高。

这就是 Webpack、Vite 生产构建默认对 chunk 加 contenthash 的原因。

## Service Worker Cache：可编程的缓存层

Service Worker 是跑在独立线程里的 JS 文件，可以拦截所有网络请求，实现完全自定义的缓存策略。

```javascript
// sw.js

const CACHE_NAME = 'v1'
const STATIC_ASSETS = [
  '/',
  '/index.html',
  '/app.css',
  '/app.js'
]

// 安装阶段：预缓存静态资源
self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => cache.addAll(STATIC_ASSETS))
  )
})

// 激活阶段：清理旧版本缓存
self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(keys =>
      Promise.all(
        keys.filter(key => key !== CACHE_NAME)
            .map(key => caches.delete(key))
      )
    )
  )
})

// 拦截请求：Cache First 策略
self.addEventListener('fetch', event => {
  event.respondWith(
    caches.match(event.request).then(cached => {
      if (cached) return cached  // 有缓存直接用
      
      // 没缓存就请求，请求回来存一份
      return fetch(event.request).then(response => {
        const responseClone = response.clone()
        caches.open(CACHE_NAME)
          .then(cache => cache.put(event.request, responseClone))
        return response
      })
    })
  )
})
```

Service Worker 几种常见缓存策略：

- **Cache First**：先查缓存，有就用缓存，没有再请求。适合不常变的静态资源
- **Network First**：先请求，成功就更新缓存，失败了用缓存兜底。适合接口数据
- **Stale While Revalidate**：先返回缓存的旧数据，同时后台发请求更新缓存。适合允许短暂旧数据的场景

Service Worker 的核心价值在于：可以做离线可用（PWA）。即使网断了，用户也能看到上次缓存的页面，不是白屏。

## 一个容易踩的坑：no-cache 不等于 no-store

```
Cache-Control: no-cache   → 每次用缓存前先验证，304 了就用缓存
Cache-Control: no-store   → 完全不缓存，每次都下载
```

想禁用缓存用 `no-store`，想强制每次验证用 `no-cache`。名字起得很容易混淆。

还有 `Cache-Control: max-age=0` 和 `no-cache` 效果类似（强缓存立即失效，后续走协商缓存），但不完全等价——部分老浏览器/代理行为有差异。

## 总结

做缓存策略的思路：入口 HTML 不强缓存 + 静态资源文件名带 hash 长期强缓存，这两条基本就能覆盖大多数场景。Service Worker 是锦上添花，做 PWA 或者对离线体验有要求的时候再引入。
