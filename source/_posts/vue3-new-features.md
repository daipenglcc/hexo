---
title: Vue 3 新特性全面解读
date: 2020-09-22 14:20:45
tags:
  - Vue
  - Vue3
  - Composition API
categories: Vue
---

Vue 3 于 2020 年 9 月 18 日正式发布（代号 "One Piece"），带来了全新的 Composition API、更好的 TypeScript 支持、性能大幅提升等重磅更新。本文从实际使用角度对 Vue 3 的核心新特性做一次全面解读。

<!-- more -->

## 1. Composition API

Vue 3 最核心的变化。相比 Options API 将逻辑按选项分散（data、methods、computed、watch），Composition API 允许按功能逻辑组织代码：

### setup() 函数

```vue
<template>
  <div>
    <p>计数: {{ count }}</p>
    <p>双倍: {{ doubled }}</p>
    <button @click="increment">+1</button>
  </div>
</template>

<script>
import { ref, computed, onMounted } from 'vue'

export default {
  setup() {
    // 响应式状态
    const count = ref(0)

    // 计算属性
    const doubled = computed(() => count.value * 2)

    // 方法
    function increment() {
      count.value++
    }

    // 生命周期
    onMounted(() => {
      console.log('组件已挂载')
    })

    // 必须返回模板中使用的数据和方法
    return { count, doubled, increment }
  }
}
</script>
```

### reactive vs ref

```javascript
import { ref, reactive, toRefs } from 'vue'

// ref —— 适合基本类型（也可用于对象）
const count = ref(0)
const name = ref('Tom')
console.log(count.value)   // 访问需要 .value
// 在 template 中自动解包，直接用 {{ count }}

// reactive —— 适合对象类型
const state = reactive({
  user: { name: 'Tom', age: 25 },
  articles: [],
  loading: false
})
console.log(state.user.name)  // 直接访问，无需 .value

// toRefs —— 解构 reactive 对象时保持响应性
const { user, loading } = toRefs(state)
```

## 2. `<script setup>` 语法糖

Vue 3.2 引入的 `<script setup>` 极大简化了 Composition API 的写法：

```vue
<script setup>
import { ref, computed, onMounted } from 'vue'
import MyComponent from './MyComponent.vue'

// 顶层变量自动暴露给模板，无需 return
const count = ref(0)
const doubled = computed(() => count.value * 2)

function increment() {
  count.value++
}

onMounted(() => {
  console.log('已挂载')
})

// 定义 Props
const props = defineProps({
  title: { type: String, required: true },
  size: { type: Number, default: 14 }
})

// 定义 Emits
const emit = defineEmits(['update', 'delete'])

function handleUpdate() {
  emit('update', { id: 1 })
}
</script>

<template>
  <div>
    <h2>{{ title }}</h2>
    <p>{{ count }} / {{ doubled }}</p>
    <button @click="increment">+1</button>
    <MyComponent />
  </div>
</template>
```

## 3. 响应式系统升级

Vue 3 用 `Proxy` 替换了 Vue 2 的 `Object.defineProperty`，带来了实质性的改进：

```javascript
import { reactive, watch, watchEffect } from 'vue'

const state = reactive({
  list: [1, 2, 3],
  nested: { deep: { value: 'hello' } }
})

// ✅ Vue 3 可以检测到的变化（Vue 2 做不到）
state.list[0] = 100          // 数组索引赋值
state.list.length = 0         // 修改数组长度
state.newProp = 'dynamic'    // 动态新增属性
delete state.newProp          // 删除属性

// watch —— 监听特定数据
watch(
  () => state.list.length,
  (newLen, oldLen) => {
    console.log(`列表长度: ${oldLen} → ${newLen}`)
  }
)

// watchEffect —— 自动收集依赖
watchEffect(() => {
  // 里面访问了哪些响应式数据，就自动监听哪些
  console.log(`当前列表: ${state.list.join(', ')}`)
})
```

## 4. Teleport 传送门

将组件的 DOM 渲染到指定的目标位置，非常适合弹窗、通知等场景：

```vue
<template>
  <button @click="showModal = true">打开弹窗</button>

  <!-- 将弹窗内容渲染到 body 下，而不是当前组件的 DOM 树中 -->
  <Teleport to="body">
    <div v-if="showModal" class="modal-overlay">
      <div class="modal-content">
        <h3>弹窗标题</h3>
        <p>弹窗内容区域</p>
        <button @click="showModal = false">关闭</button>
      </div>
    </div>
  </Teleport>
</template>

<script setup>
import { ref } from 'vue'
const showModal = ref(false)
</script>
```

## 5. Suspense 异步组件

`Suspense` 提供了优雅处理异步组件加载状态的能力：

```vue
<template>
  <Suspense>
    <!-- 异步组件加载完成后渲染 -->
    <template #default>
      <AsyncDashboard />
    </template>
    <!-- 加载过程中显示 -->
    <template #fallback>
      <div class="loading">
        <span>数据加载中...</span>
      </div>
    </template>
  </Suspense>
</template>

<script setup>
import { defineAsyncComponent } from 'vue'

const AsyncDashboard = defineAsyncComponent(() =>
  import('./Dashboard.vue')
)
</script>
```

```vue
<!-- Dashboard.vue —— 使用 async setup -->
<script setup>
const data = await fetch('/api/dashboard').then(r => r.json())
// setup 中可以直接 await，Suspense 会自动处理加载状态
</script>

<template>
  <div>{{ data.title }}</div>
</template>
```

## 6. 多根节点（Fragments）

Vue 3 组件模板不再强制要求单根节点：

```vue
<!-- Vue 2：必须有一个根元素 -->
<template>
  <div>
    <header>头部</header>
    <main>内容</main>
  </div>
</template>

<!-- Vue 3：支持多根节点 -->
<template>
  <header>头部</header>
  <main>内容</main>
  <footer>底部</footer>
</template>
```

## 7. 组合式函数（Composables）

Vue 3 的逻辑复用方式，替代了 Vue 2 的 Mixins：

```javascript
// composables/useMouse.js
import { ref, onMounted, onUnmounted } from 'vue'

export function useMouse() {
  const x = ref(0)
  const y = ref(0)

  function update(event) {
    x.value = event.pageX
    y.value = event.pageY
  }

  onMounted(() => window.addEventListener('mousemove', update))
  onUnmounted(() => window.removeEventListener('mousemove', update))

  return { x, y }
}
```

```javascript
// composables/useFetch.js
import { ref, watchEffect } from 'vue'

export function useFetch(url) {
  const data = ref(null)
  const error = ref(null)
  const loading = ref(true)

  watchEffect(async () => {
    loading.value = true
    error.value = null

    try {
      const res = await fetch(url.value || url)
      data.value = await res.json()
    } catch (e) {
      error.value = e
    } finally {
      loading.value = false
    }
  })

  return { data, error, loading }
}
```

```vue
<!-- 在组件中组合使用 -->
<script setup>
import { useMouse } from '@/composables/useMouse'
import { useFetch } from '@/composables/useFetch'

const { x, y } = useMouse()
const { data, loading } = useFetch('/api/articles')
</script>

<template>
  <p>鼠标位置: {{ x }}, {{ y }}</p>
  <div v-if="loading">加载中...</div>
  <ul v-else>
    <li v-for="item in data" :key="item.id">{{ item.title }}</li>
  </ul>
</template>
```

## Vue 2 vs Vue 3 快速对照

| 特性 | Vue 2 | Vue 3 |
| :--- | :--- | :--- |
| API 风格 | Options API | Composition API + Options API |
| 响应式实现 | Object.defineProperty | Proxy |
| 模板根节点 | 仅单根 | 支持多根 |
| 生命周期前缀 | beforeCreate / created | setup() 替代 |
| 逻辑复用 | Mixins / HOC | Composables |
| TypeScript | 需要装饰器 | 原生支持 |
| 性能 | 基准 | 快 ~2 倍 |
| 包体积 | ~20KB | ~10KB（Tree-shakable） |

Vue 3 在保持 Vue 的易用性同时，在性能、TypeScript 支持和大型项目架构能力上都有了质的飞跃。
