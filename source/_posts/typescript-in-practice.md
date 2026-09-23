---
title: TypeScript 入门到实践
date: 2020-02-18 09:30:15
tags:
  - TypeScript
  - JavaScript
categories: TypeScript
---

TypeScript 在 2020 年已经从"可选项"变成了前端项目的"标配"。越来越多的框架和库（Angular、Vue 3、Deno）将 TypeScript 作为第一优先级支持。本文从实际使用角度出发，系统整理 TypeScript 的核心类型系统和日常开发中最常用的特性。

<!-- more -->

## 1. 基础类型

```typescript
// 原始类型
let isDone: boolean = false
let count: number = 42
let username: string = 'Tom'
let nothing: null = null
let notDefined: undefined = undefined

// 数组
let numbers: number[] = [1, 2, 3]
let names: Array<string> = ['Tom', 'Jerry']

// 元组（固定长度和类型的数组）
let tuple: [string, number] = ['Tom', 25]

// 枚举
enum Status {
  Draft = 0,
  Published = 1,
  Archived = 2
}
let articleStatus: Status = Status.Published

// any 和 unknown
let flexible: any = '可以是任何类型'    // 跳过类型检查（尽量少用）
let safe: unknown = '更安全的 any'      // 使用前必须进行类型收窄

// void（函数无返回值）
function log(message: string): void {
  console.log(message)
}

// never（永远不会有返回值）
function throwError(msg: string): never {
  throw new Error(msg)
}
```

## 2. 接口（Interface）

接口是 TypeScript 最核心的概念之一，用于定义对象的结构：

```typescript
// 定义用户接口
interface User {
  id: number
  name: string
  email: string
  age?: number          // 可选属性
  readonly createdAt: string  // 只读属性
}

// 使用接口约束对象
const user: User = {
  id: 1,
  name: 'Tom',
  email: 'tom@example.com',
  createdAt: '2020-01-01'
}

// 接口继承
interface Admin extends User {
  permissions: string[]
  department: string
}

const admin: Admin = {
  id: 2,
  name: 'Admin',
  email: 'admin@example.com',
  createdAt: '2020-01-01',
  permissions: ['read', 'write', 'delete'],
  department: '技术部'
}
```

### 函数类型接口

```typescript
interface SearchFunc {
  (keyword: string, page: number): Promise<SearchResult[]>
}

interface ApiResponse<T> {
  code: number
  message: string
  data: T
}

// 使用
const searchArticles: SearchFunc = async (keyword, page) => {
  const res = await fetch(`/api/search?q=${keyword}&page=${page}`)
  return res.json()
}
```

## 3. 类型别名（Type）

`type` 和 `interface` 都能定义类型，各有适用场景：

```typescript
// 联合类型
type Status = 'loading' | 'success' | 'error'
type ID = string | number

// 交叉类型
type Timestamped = {
  createdAt: string
  updatedAt: string
}
type Article = {
  title: string
  content: string
} & Timestamped

// 条件选择
function processId(id: ID) {
  if (typeof id === 'string') {
    return id.toUpperCase()  // TypeScript 自动收窄为 string
  }
  return id.toFixed(2)       // 收窄为 number
}
```

> **经验法则**：定义对象结构优先用 `interface`（可扩展），定义联合类型、工具类型用 `type`。

## 4. 泛型（Generics）

泛型让代码具备类型安全的同时保持灵活性：

```typescript
// 泛型函数
function getFirst<T>(arr: T[]): T | undefined {
  return arr[0]
}

const firstNum = getFirst<number>([1, 2, 3])     // number | undefined
const firstStr = getFirst(['a', 'b', 'c'])        // string | undefined（自动推断）

// 泛型接口 —— API 响应封装
interface ApiResponse<T> {
  code: number
  message: string
  data: T
  timestamp: number
}

interface UserInfo {
  id: number
  name: string
  avatar: string
}

// 使用时指定具体类型
async function fetchUser(id: number): Promise<ApiResponse<UserInfo>> {
  const res = await fetch(`/api/users/${id}`)
  return res.json()
}

// 泛型约束
interface HasId {
  id: number
}

function findById<T extends HasId>(items: T[], id: number): T | undefined {
  return items.find(item => item.id === id)
}
```

## 5. 类型收窄与类型守卫

```typescript
// typeof 收窄
function format(value: string | number): string {
  if (typeof value === 'number') {
    return value.toFixed(2)
  }
  return value.trim()
}

// instanceof 收窄
function handleError(error: Error | string) {
  if (error instanceof Error) {
    console.log(error.message)
    console.log(error.stack)
  } else {
    console.log(error)
  }
}

// in 操作符收窄
interface Bird { fly(): void; layEggs(): void }
interface Fish { swim(): void; layEggs(): void }

function move(animal: Bird | Fish) {
  if ('fly' in animal) {
    animal.fly()
  } else {
    animal.swim()
  }
}

// 自定义类型守卫
function isString(value: unknown): value is string {
  return typeof value === 'string'
}

function process(input: unknown) {
  if (isString(input)) {
    console.log(input.toUpperCase())  // 确认是 string
  }
}
```

## 6. 常用工具类型

TypeScript 内置了大量工具类型，掌握这些可以减少重复定义：

```typescript
interface User {
  id: number
  name: string
  email: string
  age: number
  avatar: string
}

// Partial<T> —— 所有属性变为可选
type UpdateUserDto = Partial<User>
// 等同于 { id?: number; name?: string; email?: string; ... }

// Required<T> —— 所有属性变为必填
type StrictUser = Required<User>

// Pick<T, K> —— 选取部分属性
type UserBasic = Pick<User, 'id' | 'name' | 'avatar'>
// { id: number; name: string; avatar: string }

// Omit<T, K> —— 排除部分属性
type CreateUserDto = Omit<User, 'id'>
// { name: string; email: string; age: number; avatar: string }

// Record<K, V> —— 构造键值对类型
type PageConfig = Record<string, { title: string; path: string }>
const pages: PageConfig = {
  home: { title: '首页', path: '/' },
  about: { title: '关于', path: '/about' }
}

// Readonly<T> —— 所有属性变为只读
type FrozenUser = Readonly<User>
```

## 7. 在 Vue 项目中使用 TypeScript

```typescript
// Vue 2 + TypeScript（使用 vue-class-component）
import { Component, Prop, Vue } from 'vue-property-decorator'

@Component
export default class ArticleList extends Vue {
  @Prop({ required: true }) readonly category!: string

  articles: Article[] = []
  loading = false

  get filteredArticles(): Article[] {
    return this.articles.filter(a => a.category === this.category)
  }

  async mounted() {
    this.loading = true
    this.articles = await fetchArticles(this.category)
    this.loading = false
  }

  handleClick(article: Article): void {
    this.$router.push(`/article/${article.id}`)
  }
}
```

## 8. tsconfig.json 常用配置

```json
{
  "compilerOptions": {
    "target": "ES2018",
    "module": "ESNext",
    "moduleResolution": "node",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "outDir": "./dist",
    "baseUrl": ".",
    "paths": {
      "@/*": ["src/*"]
    }
  },
  "include": ["src/**/*.ts", "src/**/*.vue"],
  "exclude": ["node_modules", "dist"]
}
```

TypeScript 的学习曲线在初期会感到有些陡峭，但一旦习惯了类型思维，在编辑器的智能提示、重构安全性和团队协作中会感受到明显的收益。
