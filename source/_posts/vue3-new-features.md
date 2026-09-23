---
title: Vue3 到底香在哪？大白话聊聊那些牛逼的新特性
date: 2020-09-22 14:20:45
tags:
  - Vue
  - Vue3
  - Composition API
categories: Vue
---

刚开始接触 Vue3 的时候，心里其实是在骂娘的：明明 Options API（就那种把 data、methods 分开写的方式）写得挺舒服的，非要搞个 Composition API 折腾人，代码全挤在一起像面条一样。

直到我后来接手了一个两千多行的祖传巨型组件，改个逻辑要在 data 里找变量、在 methods 里找方法、在 computed 里找计算，滚轮都搓冒烟了。我才突然悟了，原来 Vue3 的按逻辑组织代码这么爽。这篇就用大白话，聊聊 Vue3 那些让我用过就回不去的新特性。

<!-- more -->

## 1. 绝对的杀手锏：Composition API (组合式API)

如果用一句话概括就是：**把以前散落在各处的同一个功能的代码，全捏在了一起**。

搭配 Vue 3.2 之后出的 `<script setup>` 语法糖，写起来那叫一个行云流水：

```vue
<script setup>
// 再也不用写 export default 和让人头秃的 return 了！
import { ref, computed } from 'vue'

/* --- 比如这是一个点赞功能的代码，它们全凑在一起 --- */
const count = ref(0)
const doubled = computed(() => count.value * 2)

function increment() {
  count.value++
}
/* ------------------------------------------------ */

</script>

<template>
  <!-- 上面定义的变量，直接在这就能用 -->
  <button @click="increment">赞 {{ count }} (双倍 {{ doubled }})</button>
</template>
```

## 2. ref 和 reactive 怎么选？

Vue2 里的数据只要塞进 `data() {}` 里它就会自动更新，Vue3 需要你自己定义。
很多人一开始分不清这俩，其实我平时就一个粗暴的规矩：

- **基本类型**（数字、字符串、布尔值）：无脑用 `ref`。
- **对象或数组**（比如表单数据、列表）：无脑用 `reactive`。

```javascript
// ref 的坑：在 JS 里改值一定要加上 .value！但在模板里不用加
const age = ref(18)
age.value = 19 

// reactive 的好处：改起来就跟普通对象一样
const form = reactive({ name: '铁柱', sex: '男' })
form.name = '二妞' 
```

## 3. 告别 Vue2 的惊天大坑：响应式系统升级

在 Vue2 时代，有个被吐槽了无数次的问题：你直接往对象里塞一个新属性，或者通过索引改数组里的东西，页面死活不更新！还得去求助神仙方法 `this.$set()`。

因为 Vue2 底层用的是 `Object.defineProperty`，它太笨了。Vue3 换成了 ES6 的 `Proxy`（代理机制），这个可太聪明了，你干啥它都能看到。

```javascript
const user = reactive({ name: 'Tom' })

// Vue3 里随便搞，下面这三种骚操作，页面全能精准更新！
user.age = 20           // 动态塞新属性
delete user.name        // 删属性
list[0] = '新东西'      // 直接改数组索引
```

## 4. Teleport 传送门：写弹窗的神器

以前写弹窗最恶心的是，如果你的组件被好几层绝对定位（`position: relative`）或者隐藏（`overflow: hidden`）的父元素包着，弹窗的样式百分百要炸，死活出不来。

有了 `<Teleport>`（传送门），你可以把弹窗的 HTML 代码强行“送”到页面的最外层（比如 `body` 下），不管你组件嵌套得多深。

```vue
<template>
  <button @click="show = true">打开弹窗</button>

  <!-- 魔法指令：把里面的 DOM 原封不动搬到 body 标签最下面去 -->
  <Teleport to="body">
    <div class="modal" v-if="show">
      这是一个绝不被遮挡的无敌弹窗
    </div>
  </Teleport>
</template>
```

## 5. 组件支持多个根节点（Fragments）

这点真的是治好了我的强迫症。在 Vue2 里，`<template>` 下面死活只能有一个标签，经常为了过编译，在最外面套一个毫无意义的 `<div>`，导致 HTML 结构像洋葱一样。

Vue3 终于放开了这个限制，你想写几个并列的标签就写几个：

```vue
<!-- Vue3 里这样写完全没毛病 -->
<template>
  <header>网页头</header>
  <main>正文</main>
  <footer>网页脚</footer>
</template>
```

## 6. Composables：比 Mixins 舒服一万倍的复用方案

以前如果几个组件有一段公用逻辑，我们会写成 Mixin。但这玩意儿简直是毒瘤，变量是从哪来的根本找不到，还会引发命名冲突。

Vue3 的做法是把逻辑抽成一个个纯函数（习惯叫 `useXxx`）：

```javascript
// composables/useMouse.js (我把获取鼠标位置的逻辑抽出来了)
import { ref, onMounted } from 'vue'

export function useMouse() {
  const x = ref(0)
  const y = ref(0)
  
  onMounted(() => {
    window.addEventListener('mousemove', e => {
      x.value = e.pageX
      y.value = e.pageY
    })
  })
  
  // 谁用就把这俩变量扔给谁
  return { x, y }
}
```

别的组件想用，直接叫过来：
```vue
<script setup>
import { useMouse } from './useMouse'
// 清清爽爽，数据来源一目了然
const { x, y } = useMouse()
</script>
```

除此之外，Vue3 的打包体积更小（用不到的方法根本不打进去），速度更是快了一大截。所以，如果老板没有强迫你维护那些石器时代的 Vue2 老项目，赶紧上船 Vue3 吧，真香！
