---
title: Node.js 事件循环：一张图搞清楚异步执行顺序
date: 2020-03-22 19:15:44
tags:
  - Node.js
  - 事件循环
  - 异步
  - JavaScript
categories: Node
---

面试的时候「说说 Node.js 的事件循环」是必考题，但我发现很多人（包括我自己）背了一堆 phase，遇到具体的代码顺序题还是答不对。根本原因是把 Node.js 事件循环和浏览器事件循环混着说了，两者有重要区别。

<!-- more -->

## 浏览器 vs Node.js 事件循环的区别

浏览器的事件循环相对简单：一个 call stack、一个 microtask queue（Promise、queueMicrotask）、一个 macrotask queue（setTimeout、setInterval、MessageChannel）。每次 macrotask 执行完，清空所有 microtask，然后下一个 macrotask。

Node.js 的事件循环复杂得多，基于 libuv，有明确的多个阶段（phases）：

```
   ┌───────────────────────────┐
┌─>│           timers          │  ← setTimeout, setInterval 回调
│  └─────────────┬─────────────┘
│  ┌─────────────┴─────────────┐
│  │     pending callbacks     │  ← I/O 错误回调
│  └─────────────┬─────────────┘
│  ┌─────────────┴─────────────┐
│  │       idle, prepare       │  ← 内部使用
│  └─────────────┬─────────────┘
│  ┌─────────────┴─────────────┐
│  │           poll            │  ← 获取新的 I/O 事件，执行 I/O 回调
│  └─────────────┬─────────────┘
│  ┌─────────────┴─────────────┐
│  │           check           │  ← setImmediate 回调
│  └─────────────┬─────────────┘
│  ┌─────────────┴─────────────┐
└──┤      close callbacks      │  ← socket.on('close') 之类
   └───────────────────────────┘
```

每个阶段有自己的回调队列，libuv 按顺序轮询各阶段，执行完当前阶段队列里的回调再进下一阶段。

**关键：process.nextTick 和 Promise（microtask）在每个阶段之间插队**。

## 执行顺序验证

来看一段经典题：

```javascript
setTimeout(() => console.log('timeout'), 0)
setImmediate(() => console.log('immediate'))
Promise.resolve().then(() => console.log('promise'))
process.nextTick(() => console.log('nextTick'))

console.log('sync')
```

执行顺序：

```
sync          ← 同步代码最先
nextTick      ← nextTick 优先于 Promise
promise       ← microtask
timeout       ← timers 阶段（但 timeout 0 有最小延迟）
immediate     ← check 阶段
```

为什么 `nextTick` 比 Promise 还早？Node.js 里 `nextTick` 队列和 microtask 队列是分开的，**nextTick 队列永远先于 microtask 队列清空**。

## setImmediate vs setTimeout(fn, 0) 的不确定性

在顶层（非 I/O 回调里）执行 `setTimeout(fn, 0)` 和 `setImmediate`，谁先执行是不确定的：

```javascript
// 在顶层，顺序不确定
setTimeout(() => console.log('timeout'), 0)
setImmediate(() => console.log('immediate'))
// 有时 timeout 先，有时 immediate 先
```

原因：`setTimeout(fn, 0)` 实际是 `setTimeout(fn, 1)`（最小精度），启动时如果 timers 阶段的计时器还没准备好，就会先走 poll → check 阶段执行 `setImmediate`；如果计时器准备好了，就先走 timers。进程启动时的微小时间差决定了结果。

但在 I/O 回调里，顺序是确定的，**setImmediate 一定先于 setTimeout**：

```javascript
const fs = require('fs')

fs.readFile(__filename, () => {
  // 此时处于 poll 阶段之后
  setTimeout(() => console.log('timeout'), 0)
  setImmediate(() => console.log('immediate'))
  // 永远是：immediate → timeout
})
```

从 poll 阶段出来，下一个是 check 阶段（setImmediate），然后才是下一轮循环的 timers 阶段。

## nextTick 滥用会导致饿死 I/O

`process.nextTick` 优先级太高，如果递归调用：

```javascript
function recursive() {
  process.nextTick(recursive)
}
recursive()
// 这会让事件循环永远停在 nextTick 队列，I/O 回调永远得不到执行
```

Node.js 的 `setImmediate` 就是为了解决这个问题而设计的——它等当前 I/O 事件处理完再执行，不会饿死其他 I/O。官方文档的建议是：能用 `setImmediate` 就别用 `nextTick`，除非真的需要在当前操作完成后、任何 I/O 之前立刻执行。

## 用 async/await 来思考

理解了事件循环，再看 `async/await` 里的 `.then` 时机就清晰了：

```javascript
async function main() {
  console.log('1')
  await Promise.resolve()  // 等价于 .then()，把后续代码放进 microtask
  console.log('3')         // microtask 里执行
}

main()
console.log('2')

// 输出：1 → 2 → 3
```

`await` 后面的代码相当于 `.then()` 的回调，推入 microtask 队列，等同步代码跑完再执行。

再复杂一点：

```javascript
async function foo() {
  console.log('foo start')
  await bar()
  console.log('foo end')
}

async function bar() {
  console.log('bar')
}

foo()
console.log('main')
```

输出：`foo start → bar → main → foo end`

`bar()` 是 async 函数，返回 Promise，`await bar()` 把 `console.log('foo end')` 推进 microtask，先继续执行同步的 `console.log('main')`，然后清 microtask 队列。

---

Node.js 事件循环比浏览器复杂，但核心逻辑是一样的：当前同步代码 → nextTick → microtask → 进入下一个事件循环阶段。把阶段顺序记牢，再套这个规则，大多数顺序题都能推出来。
