---
title: Vue 3 的 Composition API 究竟解决了什么问题
date: 2021-02-18 10:45:00
tags:
  - Vue3
  - Composition API
  - 前端架构
categories: Vue
---

Vue 3 正式发布几个月了，Composition API 是这次最大的改动。发布前社区里争议很大，很多人觉得"Options API 挺好的，为什么要变"，也有人说"这不就是把 React Hooks 抄过来了"。用了一段时间，有些感受想写下来。

<!-- more -->

## Options API 真正的问题在哪

Options API 本身没什么问题，对于中小型组件，按 `data / methods / computed / watch / lifecycle` 分类组织代码，直观好懂。

问题出在**大型组件**上。当一个组件要处理多个业务逻辑时，Options API 会把同一个功能的代码强制散落在不同 option 块里：

```javascript
// Options API 里处理"用户搜索"功能的代码
export default {
  data() {
    return {
      // 搜索相关
      searchKeyword: '',
      searchResults: [],
      searchLoading: false,
      
      // 分页相关（另一个功能）
      currentPage: 1,
      pageSize: 20,
      total: 0
    }
  },
  computed: {
    // 这里也混着搜索和分页的逻辑
    hasResults() { return this.searchResults.length > 0 },
    totalPages() { return Math.ceil(this.total / this.pageSize) }
  },
  watch: {
    searchKeyword(newVal) { this.handleSearch(newVal) },
    currentPage() { this.loadPage() }
  },
  methods: {
    handleSearch() { /* ... */ },
    loadPage() { /* ... */ },
    goToPage() { /* ... */ }
  }
}
```

当这个组件有五六个功能逻辑，每个功能的代码被割裂在 `data`、`computed`、`watch`、`methods` 四个地方，维护时要上下反复跳转。Vue 官方有张经典的图，同色代码属于同一个功能，Options API 里是彩色碎片，Composition API 里是连续的色块。

**逻辑复用**是另一个问题。Options API 复用逻辑靠 Mixin，而 Mixin 有几个臭名昭著的缺陷：

1. 属性来源不清晰——`this.xxx` 到底是自己的还是哪个 mixin 的？
2. 命名冲突——两个 mixin 都有 `data.loading`，直接覆盖，没有任何警告
3. 隐式依赖——mixin 之间互相依赖某个 data，但没有显式声明

## Composition API 的核心改变

```javascript
// Composition API：把"搜索"逻辑封装在一起
import { ref, computed, watch } from 'vue'
import { useDebounce } from '@/composables/useDebounce'

export function useSearch(fetchFn) {
  const keyword = ref('')
  const results = ref([])
  const loading = ref(false)

  const debouncedKeyword = useDebounce(keyword, 300)

  watch(debouncedKeyword, async (val) => {
    if (!val.trim()) {
      results.value = []
      return
    }
    loading.value = true
    try {
      results.value = await fetchFn(val)
    } finally {
      loading.value = false
    }
  })

  return { keyword, results, loading }
}
```

```javascript
// 组件里使用
import { useSearch } from '@/composables/useSearch'
import { usePagination } from '@/composables/usePagination'

export default {
  setup() {
    // 每个功能的数据和逻辑聚合在一起
    const { keyword, results, loading } = useSearch(api.searchUsers)
    const { currentPage, pageSize, total, goToPage } = usePagination()

    return { keyword, results, loading, currentPage, pageSize, total, goToPage }
  }
}
```

逻辑复用从 Mixin 变成了普通函数（composable），类型推导完美（TypeScript 直接受益），来源清晰，没有命名冲突问题。

## setup 的执行时机

`setup()` 在组件实例创建之前执行，比 `beforeCreate` 生命周期钩子还早，所以里面**没有 `this`**——准确说，`this` 是 `undefined`。

这意味着在 `setup` 里不能访问 `data`、`methods`、`computed`——它们还没初始化。但这不是问题，`setup` 本身就应该自给自足，自己用 `ref` 和 `reactive` 定义响应式数据。

生命周期钩子在 `setup` 里有对应的 `onXxx` 版本：

```javascript
import { onMounted, onUnmounted, onBeforeUpdate } from 'vue'

setup() {
  onMounted(() => {
    console.log('挂载完成')
  })

  onUnmounted(() => {
    // 清理副作用
  })
}
```

## ref vs reactive

这两个经常让人困惑：

```javascript
const count = ref(0)       // 基本类型必须用 ref，访问要 .value
const state = reactive({   // 对象可以用 reactive，像 Vue2 的 data
  name: '',
  list: []
})
```

`ref` 的值需要 `.value` 访问，在模板里 Vue 会自动解包，不需要写 `.value`。`reactive` 的对象里的属性直接访问，但整个对象不能解构——解构会丢失响应式：

```javascript
const state = reactive({ count: 0, name: 'vue' })

// ❌ 解构后 count 是普通 number，不是响应式的
const { count } = state

// ✅ 用 toRefs 保持响应式引用
const { count, name } = toRefs(state)
```

我个人的倾向：简单的标量用 `ref`，有关联的一组数据用 `reactive`，或者干脆全用 `ref` 统一风格，`toRefs(reactive({}))` 这个模式有点绕。

## Composition API 不是银弹

并非所有组件都适合用 Composition API：

- 简单组件：Options API 更直观，没必要非要换
- 团队都是 Vue 2 背景：迁移成本和认知成本要考虑
- 纯展示型组件：逻辑很少，两种写法没太大差别

Vue 3 保留了完整的 Options API，两者可以混用（虽然不推荐）。迁移不是必须的。

真正值得迁移的场景：大型组件、需要跨组件逻辑复用、TypeScript 项目。在这些场景下，Composition API 的优势才真正体现出来。

---

说"抄 React Hooks"是不准确的。机制上有相似之处，但 Vue 的响应式系统（Proxy）让 Composition API 不需要依赖数组，不会有 stale closure 问题，心智负担比 React Hooks 小。两者解决类似问题，但方式不同。
