---
title: Vue.js 组件通信方式总结
date: 2018-08-15 14:22:18
tags:
  - Vue
  - 组件通信
categories: Vue
---

在 Vue.js 项目开发中，组件间的数据通信是绑定不开的核心问题。随着应用规模的增长，如何优雅地在组件之间传递数据、触发行为，直接决定了代码的可维护性。本文系统梳理了 Vue 2.x 中常用的组件通信方式及其适用场景。

<!-- more -->

## 1. Props / $emit（父子通信）

最基础也是最常用的通信方式：父组件通过 `props` 向子组件传递数据，子组件通过 `$emit` 向父组件发送事件。

### 父组件向子组件传值

```html
<!-- 父组件 -->
<template>
  <child-component :title="pageTitle" :count="itemCount" />
</template>

<script>
import ChildComponent from './ChildComponent.vue'

export default {
  components: { ChildComponent },
  data() {
    return {
      pageTitle: '文章列表',
      itemCount: 42
    }
  }
}
</script>
```

```html
<!-- 子组件 ChildComponent.vue -->
<template>
  <div>
    <h2>{{ title }}</h2>
    <span>共 {{ count }} 篇</span>
  </div>
</template>

<script>
export default {
  props: {
    title: {
      type: String,
      required: true
    },
    count: {
      type: Number,
      default: 0
    }
  }
}
</script>
```

### 子组件向父组件发送事件

```html
<!-- 子组件 -->
<template>
  <button @click="handleClick">提交</button>
</template>

<script>
export default {
  methods: {
    handleClick() {
      this.$emit('submit', { id: 1, name: '数据' })
    }
  }
}
</script>
```

```html
<!-- 父组件中监听 -->
<child-component @submit="onSubmit" />
```

## 2. $refs（父组件直接访问子组件）

通过 `ref` 属性给子组件注册引用，父组件可以直接调用子组件的方法或访问其数据：

```html
<template>
  <child-component ref="child" />
  <button @click="callChildMethod">调用子组件方法</button>
</template>

<script>
export default {
  methods: {
    callChildMethod() {
      // 直接调用子组件暴露的方法
      this.$refs.child.resetForm()
      // 也可以访问子组件的数据（但不推荐）
      console.log(this.$refs.child.innerData)
    }
  }
}
</script>
```

> **注意**：`$refs` 只在组件渲染完成后才填充，不要在模板或计算属性中使用它。

## 3. EventBus 事件总线（跨组件通信）

对于非父子关系的组件之间通信，可以创建一个空的 Vue 实例作为事件中心：

```javascript
// event-bus.js
import Vue from 'vue'
export const EventBus = new Vue()
```

```javascript
// 组件A - 发送事件
import { EventBus } from './event-bus'

export default {
  methods: {
    sendMessage() {
      EventBus.$emit('message-sent', {
        text: 'Hello from A',
        timestamp: Date.now()
      })
    }
  }
}
```

```javascript
// 组件B - 监听事件
import { EventBus } from './event-bus'

export default {
  created() {
    EventBus.$on('message-sent', this.handleMessage)
  },
  beforeDestroy() {
    // 务必在组件销毁前移除监听，防止内存泄漏
    EventBus.$off('message-sent', this.handleMessage)
  },
  methods: {
    handleMessage(payload) {
      console.log('收到消息:', payload.text)
    }
  }
}
```

> EventBus 适合小型项目中少量跨组件通信的场景。如果事件过多，建议改用 Vuex。

## 4. Vuex 状态管理（全局共享状态）

当应用中多个组件需要共享和响应同一份状态时，Vuex 是 Vue 官方推荐的状态管理方案：

```javascript
// store/index.js
import Vue from 'vue'
import Vuex from 'vuex'

Vue.use(Vuex)

export default new Vuex.Store({
  state: {
    userInfo: null,
    token: '',
    cartItems: []
  },
  getters: {
    cartCount: state => state.cartItems.length,
    isLoggedIn: state => !!state.token
  },
  mutations: {
    SET_USER(state, user) {
      state.userInfo = user
    },
    SET_TOKEN(state, token) {
      state.token = token
    },
    ADD_TO_CART(state, item) {
      state.cartItems.push(item)
    }
  },
  actions: {
    async login({ commit }, credentials) {
      const { data } = await axios.post('/api/login', credentials)
      commit('SET_TOKEN', data.token)
      commit('SET_USER', data.user)
    }
  }
})
```

```html
<!-- 在组件中使用 -->
<template>
  <div>
    <p>欢迎, {{ userInfo.name }}</p>
    <span>购物车: {{ cartCount }} 件</span>
  </div>
</template>

<script>
import { mapState, mapGetters } from 'vuex'

export default {
  computed: {
    ...mapState(['userInfo']),
    ...mapGetters(['cartCount'])
  }
}
</script>
```

## 5. provide / inject（跨层级传递）

当祖先组件需要向深层嵌套的后代组件传递数据时，逐层 props 显得冗余，`provide / inject` 可以跨越中间层级直接注入：

```javascript
// 祖先组件
export default {
  provide() {
    return {
      theme: this.currentTheme,
      appConfig: this.config
    }
  },
  data() {
    return {
      currentTheme: 'dark',
      config: { apiBase: 'https://api.example.com' }
    }
  }
}
```

```javascript
// 任意后代组件（无论嵌套多深）
export default {
  inject: ['theme', 'appConfig'],
  mounted() {
    console.log(this.theme)          // 'dark'
    console.log(this.appConfig.apiBase) // 'https://api.example.com'
  }
}
```

> **局限**：`provide / inject` 默认不是响应式的。如果需要响应式，可以传递一个响应式对象或使用 Vue.observable()。

## 6. $attrs / $listeners（组件透传）

在封装高阶组件或二次封装第三方 UI 组件时，`$attrs` 和 `$listeners` 可以将未被 props 声明接收的属性和事件透传到内部子组件：

```html
<!-- 封装的 BaseInput 组件 -->
<template>
  <div class="base-input">
    <label>{{ label }}</label>
    <input v-bind="$attrs" v-on="$listeners" />
  </div>
</template>

<script>
export default {
  inheritAttrs: false,  // 阻止属性自动挂载到根元素
  props: {
    label: String
  }
}
</script>
```

```html
<!-- 使用时，所有未声明的 props 和事件都会透传到 input 元素上 -->
<base-input
  label="用户名"
  placeholder="请输入用户名"
  maxlength="20"
  @input="onInput"
  @focus="onFocus"
/>
```

## 通信方式选择指南

| 场景 | 推荐方式 | 复杂度 |
| :--- | :--- | :---: |
| 父 → 子 单向数据传递 | `props` | ⭐ |
| 子 → 父 事件通知 | `$emit` | ⭐ |
| 父组件调用子组件方法 | `$refs` | ⭐⭐ |
| 兄弟组件 / 跨层级少量通信 | `EventBus` | ⭐⭐ |
| 全局共享 / 复杂状态管理 | `Vuex` | ⭐⭐⭐ |
| 祖先向深层后代注入配置 | `provide / inject` | ⭐⭐ |
| 高阶组件属性透传 | `$attrs / $listeners` | ⭐⭐ |

根据项目规模和实际需求，合理选择通信方式，可以让代码层次清晰、维护成本更低。
