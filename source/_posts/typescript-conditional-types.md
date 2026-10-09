---
title: TypeScript 高级类型：条件类型和 infer 到底怎么用
date: 2022-05-15 16:30:00
tags:
  - TypeScript
  - 类型编程
  - 泛型
categories: TypeScript
---

用 TypeScript 写业务代码一两年了，`interface`、`type`、泛型这些基础用得还算熟。但每次看到项目里 `infer`、`Exclude`、`ReturnType` 这些，还是有点迷。最近花时间系统学了一遍条件类型，记录一下理解过程。

<!-- more -->

## 条件类型的基本形式

条件类型的语法看起来就像三元表达式：

```typescript
type IsString<T> = T extends string ? 'yes' : 'no'

type A = IsString<string>  // 'yes'
type B = IsString<number>  // 'no'
```

`T extends U ? X : Y` 的意思是：如果 T 能赋值给 U（T 是 U 的子类型），结果就是 X，否则是 Y。

**联合类型会触发分发（distributive）：**

```typescript
type IsString<T> = T extends string ? 'yes' : 'no'

type C = IsString<string | number>
// 不是 'yes' | 'no'，条件类型对联合类型有分发行为
// 相当于 IsString<string> | IsString<number>
// = 'yes' | 'no'

// 如果不想分发，用 [] 包起来
type IsStringExact<T> = [T] extends [string] ? 'yes' : 'no'
type D = IsStringExact<string | number>  // 'no'（整体不 extends string）
```

## infer：在条件类型里提取类型

`infer` 关键字只能在条件类型的 `extends` 子句里用，作用是声明一个"待推断的类型变量"，让 TypeScript 去推断并捕获它：

```typescript
// 内置的 ReturnType 就是用 infer 实现的
type ReturnType<T> = T extends (...args: any[]) => infer R ? R : never
//                                                     ↑
//                                          infer R：如果 T 是函数类型，
//                                          把返回值类型捕获为 R

function fetchUser(id: number): Promise<User> { /* ... */ }

type FetchResult = ReturnType<typeof fetchUser>  // Promise<User>
```

再看几个常用例子：

**提取函数参数类型：**

```typescript
type Parameters<T> = T extends (...args: infer P) => any ? P : never

function createUser(name: string, age: number, role: 'admin' | 'user') {}

type CreateUserParams = Parameters<typeof createUser>
// [name: string, age: number, role: 'admin' | 'user']
```

**提取 Promise 包裹的类型：**

```typescript
type Awaited<T> = T extends Promise<infer U> ? Awaited<U> : T
// 递归处理 Promise<Promise<string>> 这种情况

type A = Awaited<Promise<string>>          // string
type B = Awaited<Promise<Promise<number>>> // number
```

（这个 `Awaited` 在 TypeScript 4.5 已经内置了）

**提取数组元素类型：**

```typescript
type ElementType<T> = T extends (infer Item)[] ? Item : never

type StrElement = ElementType<string[]>   // string
type NumElement = ElementType<number[]>   // number
```

## 几个常用的内置工具类型实现

理解了条件类型，很多内置工具类型就可以自己实现了：

```typescript
// Exclude：从 T 中去掉能赋值给 U 的类型
type Exclude<T, U> = T extends U ? never : T

type E = Exclude<'a' | 'b' | 'c', 'a' | 'b'>  // 'c'
// 分发：
// Exclude<'a', 'a'|'b'> = never
// Exclude<'b', 'a'|'b'> = never
// Exclude<'c', 'a'|'b'> = 'c'
// 合并 = 'c'

// Extract：取 T 和 U 的交集
type Extract<T, U> = T extends U ? T : never

// NonNullable：去掉 null 和 undefined
type NonNullable<T> = T extends null | undefined ? never : T
```

## 实际业务里能用上的场景

**提取接口所有 key 的值类型：**

```typescript
interface Config {
  host: string
  port: number
  debug: boolean
}

// 等价于 string | number | boolean
type ConfigValues = Config[keyof Config]
```

**过滤出对象里值为函数的 key：**

```typescript
type FunctionKeys<T> = {
  [K in keyof T]: T[K] extends Function ? K : never
}[keyof T]

interface Service {
  name: string
  fetchUser: () => Promise<User>
  saveUser: (user: User) => Promise<void>
  maxRetries: number
}

type Methods = FunctionKeys<Service>  // 'fetchUser' | 'saveUser'
```

**Deep Readonly：递归让所有嵌套属性只读：**

```typescript
type DeepReadonly<T> = {
  readonly [K in keyof T]: T[K] extends object ? DeepReadonly<T[K]> : T[K]
}

type State = DeepReadonly<{
  user: { name: string; age: number }
  settings: { theme: string }
}>
// State.user.name 是 readonly 的，不能直接赋值
```

## 类型编程和值编程的对应关系

很多人觉得类型体操太抽象，其实可以类比值层面的操作：

| 值层面 | 类型层面 |
|--------|----------|
| `if / else` | 条件类型 `T extends X ? A : B` |
| `typeof` | `keyof T`, `T[K]` |
| 函数参数 | 泛型 `<T>` |
| 模式匹配 | `infer` |
| 递归函数 | 递归类型别名 |
| 数组遍历 | 映射类型 `{ [K in keyof T]: ... }` |

把类型想成"在类型系统里跑的程序"，很多东西就看懂了。

---

条件类型和 `infer` 这套东西上手有点难，但掌握了之后能干的事多很多：写出更精确的类型约束，减少 `as any` 的使用，让 TypeScript 真正发挥出它的价值。
