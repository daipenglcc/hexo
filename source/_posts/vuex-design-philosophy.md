---
title: Vuex 的设计哲学：单向数据流和时间旅行调试是怎么来的
date: 2016-10-08 22:40:30
tags:
  - Vue
  - Vuex
  - Flux
  - 状态管理
categories: Vue
---

Vuex 0.x / 1.x 刚出来那会儿（2015 年底），整个中文社区几乎没有什么资料，只能啃官方文档和 Flux 相关的文章。用了一段时间，觉得 Vuex 的设计有很多值得深想的地方，不只是"把共享状态放一起"那么简单。

<!-- more -->

## 为什么要单向数据流

先讲问题背景。组件化之前，大型 jQuery 项目里，状态（数据）散落在 DOM 属性、全局变量、localStorage 各处，一个按钮点击会触发十几处 DOM 修改，出了 bug 根本不知道数据是从哪里被谁改的。

React 团队 2014 年提出 Flux 架构，核心思想是：**数据必须单向流动，只能从 Store 流向 View，View 不能直接改 Store**。

```
Action → Dispatcher → Store → View → (用户操作) → Action → ...
```

这个约束强制数据变更只有一条路，任何状态变化都有迹可查。Vuex 把这个思想搬进了 Vue 的世界。

## Vuex 的核心约束：mutation 必须同步

Vuex 里修改 state 有两种方式：

- `commit mutation`（同步）
- `dispatch action`（可以异步，但最终还是要 commit mutation）

为什么 mutation 必须同步？

因为 Vue DevTools 要实现"时间旅行"调试：记录每一次 mutation 前后的 state 快照，可以点某一条历史记录让 state 回滚到那个时间点。

这个功能的前提是 mutation 必须是纯函数——输入相同，输出相同，没有副作用。如果 mutation 里有异步操作，"执行 mutation" 和 "state 改变" 就不在同一个时间点，DevTools 无法准确记录 snapshot，时间旅行就失效了。

所以 mutation 才有这个强制约束：只能做同步的状态变更，异步逻辑全放 action。

## 依赖收集如何接入 Vuex

Vuex 的 state 是响应式的，这是怎么做到的？

Vuex 内部创建了一个 Vue 实例，把 state 存在这个 Vue 实例的 `data` 里：

```javascript
// 简化版 Vuex 源码
class Store {
  constructor(options) {
    // 利用 Vue 的响应式系统
    this._vm = new Vue({
      data: {
        $$state: options.state
      }
    })
  }

  get state() {
    return this._vm._data.$$state
  }
}
```

这样 state 里每个属性都被 Vue 的 `Object.defineProperty` 包了一层，任何组件读取 `store.state.xxx` 都会触发依赖收集，state 变化会自动驱动组件重渲染。

Getters 也是类似，被实现成 Vue 实例的 `computed` 属性：

```javascript
const computed = {}
Object.keys(getters).forEach(key => {
  computed[key] = () => getters[key](store.state, store.getters)
})

this._vm = new Vue({
  data: { $$state: state },
  computed  // getter → Vue computed，自动缓存
})
```

所以 getter 的缓存能力，实际上是 Vue computed 的缓存在背后支撑的。

## namespaced 为什么要显式声明

模块化之后，如果不开 `namespaced: true`，所有模块的 mutation 和 action 名字都在全局命名空间里，`commit('SET_LOADING')` 会把所有模块里叫这个名字的 mutation 都触发一遍。

这是个反直觉的设计，但 Vuex 团队是有意为之的：在某些场景里，你确实希望一个 action 能跨模块触发，`namespaced` 给了你选择权。

开启 `namespaced` 之后，模块内的 mutation/action/getter 都会被加上模块路径前缀：

```javascript
// modules/cart.js
export default {
  namespaced: true,
  mutations: {
    ADD_ITEM(state, item) { ... }
  }
}

// 外部调用要带命名空间
store.commit('cart/ADD_ITEM', product)
```

这个设计和 Vuex 的"模块路径是字符串"息息相关，调试时 DevTools 里能看到完整路径，定位问题方便。

## Vuex 和 Pinia 的本质区别

Pinia 是 Vuex 5 的精神继承者（实际上 Vuex 5 已经放弃了，Pinia 就是官方推荐的替代）。

最大的架构差异：Pinia 去掉了 mutation。

```javascript
// Pinia
const useCartStore = defineStore('cart', {
  state: () => ({ items: [] }),
  actions: {
    async addItem(product) {
      // action 直接改 state，不需要 commit mutation
      this.items.push(product)
      await api.syncCart(this.items)
    }
  }
})
```

Pinia 认为，在有了 Vue DevTools 的 Timeline 功能之后，"记录每次 mutation" 的方式已经不是追踪状态变化的唯一手段，不需要强制同步 mutation 这个约束了。同时 TypeScript 的类型推导在没有 mutation 的情况下更好实现。

这是 API 设计哲学的转变，不是说 Vuex 的设计错了，是 trade-off 的选择不同。

---

回过头看，Vuex 把 Flux 的思想移植到 Vue 体系，同时巧妙地复用了 Vue 自身的响应式系统，这个设计很漂亮。代价是有些模板代码，但换来了完整的可追踪性。理解了它的设计意图，再用起来就不觉得繁琐了。
