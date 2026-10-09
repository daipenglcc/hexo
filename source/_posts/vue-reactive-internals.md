---
title: Vue 响应式原理：Object.defineProperty 到底做了什么
date: 2016-04-10 20:05:44
tags:
  - Vue
  - JavaScript
  - 响应式
  - 源码
categories: Vue
---

用 Vue 一段时间了，一直有个问题没搞清楚：为什么改 `this.someObj.newProp = 'xxx'` 不触发视图更新，但改 `this.someArr.push()` 就会更新？为什么要用 `this.$set`？

带着这些问题去翻了 Vue 2 的源码，弄懂了响应式系统的基本原理，写篇记录。

<!-- more -->

## defineProperty 劫持

Vue 2 响应式的核心是 `Object.defineProperty`，它可以重定义对象某个属性的 getter 和 setter：

```javascript
let value = 'hello'
const obj = {}

Object.defineProperty(obj, 'name', {
  get() {
    console.log('有人读 name 了')
    return value
  },
  set(newVal) {
    console.log('有人改 name 了，新值是：', newVal)
    value = newVal
    // 在这里触发视图更新
  },
  enumerable: true,
  configurable: true
})

obj.name        // → "有人读 name 了"
obj.name = 'hi' // → "有人改 name 了，新值是：hi"
```

Vue 在初始化 data 的时候，会对 data 里每个属性都做这个操作，把 get/set 替换成自己的版本。

## Dep 和 Watcher：依赖收集

光有 setter 知道数据变了还不够，还要知道"哪些视图依赖了这个数据"，这样才能精确通知到位。

Vue 里用 **Dep（依赖管理器）** 和 **Watcher（观察者）** 来实现：

- 每个响应式属性有一个对应的 `Dep` 实例，维护一个 Watcher 列表
- 每个组件有一个 `Watcher`，负责执行 render 函数并在执行过程中"订阅"用到的数据

依赖收集发生在 **getter** 里：

```javascript
// 伪代码，简化版
class Dep {
  constructor() {
    this.subscribers = []
  }
  depend() {
    // Dep.target 是当前正在计算的 Watcher
    if (Dep.target) {
      this.subscribers.push(Dep.target)
    }
  }
  notify() {
    this.subscribers.forEach(watcher => watcher.update())
  }
}

function defineReactive(obj, key, val) {
  const dep = new Dep()
  
  Object.defineProperty(obj, key, {
    get() {
      dep.depend()  // 把当前 Watcher 记录到 dep 里
      return val
    },
    set(newVal) {
      if (newVal === val) return
      val = newVal
      dep.notify()  // 通知所有依赖这个数据的 Watcher 去更新
    }
  })
}
```

当组件渲染时，Vue 先设置 `Dep.target = 当前组件的Watcher`，然后执行 render 函数。render 函数读取 `this.xxx` 触发 getter，getter 里 `dep.depend()` 把这个 Watcher 记进去。render 执行完，`Dep.target = null`。

之后 `this.xxx = newVal` 触发 setter，setter 调 `dep.notify()`，通知所有订阅了这个 dep 的 Watcher 去重新 render。

## 为什么新增属性不响应

现在问题就很清楚了。`Object.defineProperty` 是针对**已存在的属性**做拦截。初始化时 Vue 遍历 data 里的每个属性，对每个属性调用 `defineReactive`。

如果你在初始化**之后**往对象上加新属性：

```javascript
// data() { return { user: { name: '张三' } } }
this.user.age = 25  // ❌ age 没有被 defineReactive 处理过，没有 getter/setter
```

Vue 根本不知道 `age` 被赋值了，自然不会更新视图。

`this.$set(this.user, 'age', 25)` 的源码大概是这样：

```javascript
function set(target, key, val) {
  // ... 数组情况单独处理
  
  // 如果 key 已经存在，直接赋值（会触发已有的 setter）
  if (key in target && !(key in Object.prototype)) {
    target[key] = val
    return val
  }
  
  // 新属性：手动调用 defineReactive 把它变成响应式
  const ob = target.__ob__  // Observer 实例
  defineReactive(ob.value, key, val)
  
  // 然后手动触发依赖更新，让依赖这个对象的 Watcher 重新渲染
  ob.dep.notify()
  return val
}
```

`$set` 本质上就是：补调 `defineReactive`，再手动触发一次更新通知。

## 数组为什么可以

数组也是对象，理论上也可以对每个 index 做 `defineProperty`，但 Vue 没这么做——主要原因是性能，数组可能有几千个元素，每个都 defineProperty 太重了。

Vue 的做法是**拦截数组的变异方法**（mutating methods）：

```javascript
const arrayProto = Array.prototype
const arrayMethods = Object.create(arrayProto)

// 这 7 个方法会改变原数组
;['push', 'pop', 'shift', 'unshift', 'splice', 'sort', 'reverse']
  .forEach(method => {
    const original = arrayProto[method]
    def(arrayMethods, method, function(...args) {
      const result = original.apply(this, args)
      const ob = this.__ob__
      
      // push/unshift/splice 可能插入新元素，要对新元素也做响应式处理
      let inserted
      switch (method) {
        case 'push':
        case 'unshift':
          inserted = args; break
        case 'splice':
          inserted = args.slice(2); break
      }
      if (inserted) ob.observeArray(inserted)
      
      // 通知更新
      ob.dep.notify()
      return result
    })
  })
```

所以 `this.list.push(item)` 能触发更新——push 方法被替换成了包含 `dep.notify()` 的版本。

但 `this.list[2] = newItem` 不能触发——直接下标赋值，绕过了拦截的方法，Vue 检测不到。同理 `this.list.length = 0` 也不行，要用 `this.list.splice(0)` 才行。

## Vue 3 为什么换成 Proxy

`Object.defineProperty` 的核心局限：

1. 只能拦截已有属性，新增/删除属性检测不到
2. 数组下标赋值检测不到
3. 对嵌套对象要递归地全部 defineProperty，初始化时有开销

`Proxy` 是在对象层面做拦截，而不是属性层面：

```javascript
const handler = {
  get(target, key, receiver) {
    track(target, key)  // 依赖收集
    const res = Reflect.get(target, key, receiver)
    // 如果结果是对象，返回它的 Proxy（懒处理，比 Vue2 的递归初始化快）
    return isObject(res) ? reactive(res) : res
  },
  set(target, key, value, receiver) {
    const result = Reflect.set(target, key, value, receiver)
    trigger(target, key)  // 触发更新
    return result
  },
  deleteProperty(target, key) {
    const result = Reflect.deleteProperty(target, key)
    trigger(target, key)
    return result
  }
}
```

新增属性、删除属性、数组下标赋值，都能被 `set`/`deleteProperty` 拦截到，Vue 2 那些限制全部消失了。另外 Vue 3 是懒代理（访问到嵌套对象时才 Proxy），而 Vue 2 是初始化就递归处理所有嵌套，所以 Vue 3 初始化更快。

理解了这些之后，Vue 的很多"奇怪行为"就都说得通了。
