---
title: 被 TypeScript 毒打后的常用类型套路备忘
date: 2020-02-18 09:30:15
tags:
  - TypeScript
  - JavaScript
categories: TypeScript
---

最开始接触 TypeScript 的时候，觉得这玩意儿完全就是给自己找罪受。明明写个 JS 五分钟搞定，非要我花半小时去写类型，报错了还满屏幕飙红，最后实在受不了，满篇都是 `any`。

后来项目越做越大，隔了两个月再回来看自己写的代码，要不是有 TS 的智能提示，我连那个对象里到底有哪些字段都想不起来了。被毒打久了才发现，**强类型一时爽，一直重构一直爽**。这里总结了一些平时写业务最常用的类型定义套路，当个个人的速查字典。

<!-- more -->

## 1. 别啥都写 any 了，来点基础的

老把 `any` 当救命稻草，那还不如写回 JS 呢。其实基础的类型就那么几个：

```typescript
let isDone: boolean = false
let count: number = 42
let username: string = 'Tom'

// 数组的两种写法（看自己喜好，我偏好第一种少敲字）
let list: number[] = [1, 2, 3]
let names: Array<string> = ['Tom', 'Jerry']

// 这俩兄弟平时不多见，比如有个方法连返回值都没有，那就是 void
function log(message: string): void {
  console.log(message)
}

// 实在不知道啥类型，用 unknown 别用 any
let safe: unknown = '我是卧底' 
// any 会让编译器闭眼，unknown 会强制你用之前先用 typeof 查一下户口
```

## 2. 对象该怎么约束（Interface vs Type）

我们写前端，最多的就是接后端传过来的 JSON 对象，定义它们的结构通常有两种写法：`interface` 和 `type`。

### 个人习惯用 Interface 定义后台数据格式
因为 `interface` 可以像类一样继承，写起来比较清爽：

```typescript
// 定规矩
interface User {
  id: number
  name: string
  avatar?: string         // 加上 ? 表示这玩意不一定有（可选）
  readonly createdAt: string  // 只读，改了就报错
}

// 比如后台加了个管理员身份，直接继承再补充就行
interface Admin extends User {
  permissions: string[]
}

const boss: Admin = {
  id: 1,
  name: '老板',
  createdAt: '2020-01-01',
  permissions: ['踢人', '删库']
}
```

### 用 Type 玩花活（联合类型）
碰到那些不确定的类型，比如一个 ID 可能是字符串也可能是数字，就得用 `type` 的联合类型了：

```typescript
type ID = string | number
type Status = 'loading' | 'success' | 'error' // 这个写 UI 组件状态特别爽，输入直接有提示
```

## 3. 让人头秃的泛型（Generics）

泛型就是类型里的“变量”。当你写个通用方法，不知道别人会传什么进来，但你又想原封不动地返回相同的类型，就用泛型 `<T>`。

最经典的就是我们封 Axios 接口返回格式的时候：

```typescript
// 包装一个通用的接口响应壳子
interface ApiResponse<T> {
  code: number
  message: string
  data: T    // 核心数据丢在这里，由外面决定是啥
}

// 定义一个具体的文章结构
interface Article {
  id: number
  title: string
}

// 调接口的时候，顺便把类型塞进去
async function getArticle(id: number): Promise<ApiResponse<Article>> {
  const res = await fetch(`/api/articles/${id}`)
  return res.json()
}

// 这样拿到手的数据点进去，直接就能提示 data.title
```

## 4. 几个自带的逆天工具包

TS 其实内置了很多“快捷指令”，能帮你少写几百行重复的 `interface`。这也是我最喜欢的功能：

假设我们有个很胖的原始对象：
```typescript
interface User {
  id: number
  name: string
  email: string
  age: number
}
```

**场景 1：我只想在列表里展示几个字段**
用 `Pick` 抠出来：
```typescript
type UserListVO = Pick<User, 'id' | 'name'>
// 结果就只剩：{ id: number; name: string }
```

**场景 2：新增用户的时候，后台还没给 ID，没法传**
用 `Omit` 踢出去：
```typescript
type CreateUserForm = Omit<User, 'id'>
// 结果就是：{ name: string; email: string; age: number }
```

**场景 3：表单更新，用户想改哪个字段就传哪个，不强制传**
用 `Partial` 全变成可选的（加个 `?`）：
```typescript
type UpdateUserDto = Partial<User>
// 结果就是：{ id?: number; name?: string; email?: string; age?: number }
```

## 5. 项目根目录的 tsconfig.json 怎么配

自己搭脚手架经常不知道那个配置文件填啥，我平时基本上就抄这一套：

```json
{
  "compilerOptions": {
    "target": "ES2018",               // 编译成的 JS 版本
    "module": "ESNext",
    "strict": true,                   // 这个必须开，不开 TS 等于白写
    "esModuleInterop": true,
    "skipLibCheck": true,             // 不去检查 node_modules 里的类型报错，不然烦死
    "resolveJsonModule": true,        // 允许 import 一个 json 文件
    "paths": {
      "@/*": ["src/*"]                // 配一下别名，搭配 webpack/vite 的别名用
    }
  },
  "include": ["src/**/*.ts", "src/**/*.vue"],
  "exclude": ["node_modules", "dist"]
}
```

其实用久了你就会发现，写 TS 就是在一门心思给程序写文档，只不过这个文档不仅给人看，机器还能帮你检查语法。前期痛苦几天，后期爽得飞起。
