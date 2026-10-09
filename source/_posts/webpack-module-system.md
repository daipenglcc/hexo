---
title: Webpack 的模块系统：从 require 到 bundle 发生了什么
date: 2018-07-14 11:10:55
tags:
  - Webpack
  - 前端工程化
  - 模块化
  - 打包原理
categories: 前端工程化
---

用 Webpack 打包已经很熟了，但有天被问到"Webpack 是怎么把 CommonJS 模块打成一个 bundle 的"，居然答不上来。打开生产构建的 bundle 看了一眼，发现并不复杂，整理一下。

<!-- more -->

## 从一个最简单的例子开始

假设有两个文件：

```javascript
// math.js
exports.add = function(a, b) { return a + b }
exports.multiply = function(a, b) { return a * b }

// index.js
var math = require('./math')
console.log(math.add(1, 2))
```

Webpack 打包后（省略模板代码，保留核心逻辑），bundle 大概长这样：

```javascript
(function(modules) {
  // 模块缓存，避免同一个模块被执行多次
  var installedModules = {}

  // 核心：实现 require 函数
  function __webpack_require__(moduleId) {
    // 命中缓存直接返回
    if (installedModules[moduleId]) {
      return installedModules[moduleId].exports
    }

    // 创建新模块并缓存
    var module = installedModules[moduleId] = {
      id: moduleId,
      loaded: false,
      exports: {}
    }

    // 执行模块函数，传入 module.exports 和 require
    modules[moduleId].call(module.exports, module, module.exports, __webpack_require__)

    module.loaded = true
    return module.exports
  }

  // 从入口开始执行
  return __webpack_require__(0)

})({
  // 模块 0：index.js
  0: function(module, exports, require) {
    var math = require(1)  // moduleId 改成数字了
    console.log(math.add(1, 2))
  },
  // 模块 1：math.js
  1: function(module, exports, require) {
    exports.add = function(a, b) { return a + b }
    exports.multiply = function(a, b) { return a * b }
  }
})
```

关键点：
- 所有模块被放进一个 `{ moduleId: function }` 的对象
- Webpack 实现了自己的 `__webpack_require__`，模拟 Node.js 的 `require`
- 每个模块被包在一个函数里，模块内部的变量是私有的（函数作用域隔离）
- 模块只被执行一次，结果缓存在 `installedModules` 里

## ES Module 的处理方式

ES6 的 `import/export` 是静态的（编译时确定依赖关系），Webpack 在编译时把它们转成上面那套 `module.exports` 写法。

但 ES Module 有个特殊处理：导出的值是"实时绑定"的，不是值的拷贝。

```javascript
// counter.js
export let count = 0
export function increment() { count++ }

// main.js
import { count, increment } from './counter'
console.log(count)  // 0
increment()
console.log(count)  // 1  ← ES Module 能拿到最新值
```

Webpack 处理 `export` 时，会把导出值变成 getter：

```javascript
// 编译后的 counter 模块（简化）
Object.defineProperty(exports, '__esModule', { value: true })

var count = 0
function increment() { count++ }

// 通过 getter 访问，拿到的是当前值，不是初始值的拷贝
Object.defineProperty(exports, 'count', { get: function() { return count } })
exports.increment = increment
```

这样 `import { count }` 之后，每次访问 `count` 都通过 getter 拿当前值，实现了"实时绑定"。

## Tree Shaking 的前提

Tree Shaking（摇树，去掉未使用的 export）只对 ES Module 有效，对 CommonJS 无效，为什么？

**CommonJS 是动态的**：

```javascript
// 这种写法完全合法，但静态分析无法判断 require 的是什么
const mod = require(someVariable)
if (condition) {
  exports.foo = 'bar'
}
```

`require` 在运行时才解析，`exports` 可以动态赋值，静态分析根本无从下手。

**ES Module 是静态的**：

```javascript
// import/export 必须在顶层，不能在条件里
import { foo } from './utils'  // 编译时就确定了依赖
export const bar = 'baz'       // 导出在编译时确定
```

Webpack 在编译阶段分析模块的 import/export 图，标记哪些 export 被用到了，没用到的在打包时直接删掉（由 Terser 负责实际删除）。

这就是为什么写工具库要用 ES Module 格式（`.mjs` 或者 `package.json` 里的 `module` 字段），这样使用者 Webpack 才能 tree-shake 掉没用到的部分。

## Code Splitting：按需加载

Webpack 支持动态 `import()` 实现代码分割：

```javascript
// 点击按钮才加载这个模块
button.addEventListener('click', async () => {
  const { Chart } = await import('./chart.js')
  new Chart(container, data)
})
```

Webpack 看到动态 `import()` 后，会把 `chart.js` 及其依赖单独打成一个 chunk 文件。主 bundle 里只放一段异步加载逻辑：

```javascript
// Webpack 生成的异步加载代码（简化）
function loadChunk(chunkId) {
  return new Promise((resolve, reject) => {
    var script = document.createElement('script')
    script.src = __webpack_require__.p + 'chunk.' + chunkId + '.js'
    script.onload = resolve
    script.onerror = reject
    document.head.appendChild(script)
  })
}
```

chunk 文件加载完成后，通过 `webpackJsonp` 把模块注册到主 bundle 的模块表里，然后就可以正常 `require` 了。

这套机制是路由级别懒加载（`() => import('./views/About.vue')`）的底层实现。

## SplitChunksPlugin：公共模块提取

如果多个 chunk 都依赖了 `lodash`，如果每个 chunk 都打一份 lodash，用户加载两个 chunk 就下载了两次 lodash，浪费。

`SplitChunksPlugin` 默认配置会分析所有 chunk，把被多个 chunk 引用的模块提取成公共 chunk：

```javascript
// webpack.config.js
module.exports = {
  optimization: {
    splitChunks: {
      chunks: 'all',  // 对所有 chunk 生效（包括异步）
      cacheGroups: {
        // node_modules 里的模块单独打成 vendors chunk
        vendors: {
          test: /[\\/]node_modules[\\/]/,
          priority: -10
        },
        // 被两个以上 chunk 引用的模块提取出来
        common: {
          minChunks: 2,
          priority: -20,
          reuseExistingChunk: true
        }
      }
    }
  }
}
```

这样 `lodash` 只打包一次，用户浏览器缓存了之后，切换页面不用重新下载。

---

Webpack 本质上就是：实现一套运行时的模块系统，然后把所有模块的代码塞进去，从入口启动。理解了这个，看它生成的 bundle 就不会觉得神秘了。
