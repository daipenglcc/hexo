---
title: 前端写单元测试？折腾了一下 Jest
date: 2019-12-08 11:25:40
tags:
  - Jest
  - 单元测试
  - JavaScript
categories: JavaScript
---

说实话，以前写业务代码从来不写测试。一来觉得浪费时间，二来压根不知道前端有啥好测的，页面长啥样一眼就看到了。直到有一次改了个公共工具函数，结果另一个模块调用的时候炸了，排查了一下午。后来组长说要不试试搞个单元测试，于是就上了 Jest。

<!-- more -->

## 1. 为啥选 Jest

当时也看了看 Mocha + Chai 那一套，但 Jest 的好处是开箱即用，不需要自己组合断言库、mock 库、覆盖率工具。装一个包搞定所有事情，对懒人来说太友好了。

```bash
npm install --save-dev jest
```

在 `package.json` 里加一行：

```json
{
  "scripts": {
    "test": "jest"
  }
}
```

## 2. 写第一个测试

Jest 默认会找 `__tests__/` 目录下的文件，或者文件名带 `.test.js` / `.spec.js` 后缀的文件。

假设有个工具函数：

```javascript
// utils/math.js
function add(a, b) {
  return a + b
}

function formatPrice(price) {
  if (typeof price !== 'number' || isNaN(price)) {
    return '¥0.00'
  }
  return '¥' + price.toFixed(2)
}

module.exports = { add, formatPrice }
```

测试代码：

```javascript
// utils/__tests__/math.test.js
const { add, formatPrice } = require('../math')

describe('math 工具函数', () => {
  // describe 就是分组，看报告的时候比较清晰

  test('add: 正常相加', () => {
    expect(add(1, 2)).toBe(3)
    expect(add(-1, 1)).toBe(0)
  })

  test('formatPrice: 正常格式化', () => {
    expect(formatPrice(99)).toBe('¥99.00')
    expect(formatPrice(0)).toBe('¥0.00')
    expect(formatPrice(19.9)).toBe('¥19.90')
  })

  test('formatPrice: 传入非数字', () => {
    expect(formatPrice('abc')).toBe('¥0.00')
    expect(formatPrice(undefined)).toBe('¥0.00')
    expect(formatPrice(NaN)).toBe('¥0.00')
  })
})
```

跑一下 `npm test`，终端里就能看到绿色的 PASS，很舒服。

## 3. 常用的几个断言

Jest 的断言（matcher）挺多的，但平时也就用这么几个：

```javascript
// 严格相等（基本类型用这个）
expect(1 + 1).toBe(2)

// 对象/数组用 toEqual（深度比较）
expect({ a: 1 }).toEqual({ a: 1 })

// 真假判断
expect(true).toBeTruthy()
expect(0).toBeFalsy()
expect(null).toBeNull()
expect(undefined).toBeUndefined()

// 包含关系
expect([1, 2, 3]).toContain(2)
expect('hello world').toMatch(/world/)

// 大于小于
expect(10).toBeGreaterThan(5)
expect(3).toBeLessThanOrEqual(3)

// 抛错
expect(() => { throw new Error('boom') }).toThrow('boom')
```

## 4. Mock：假装调了接口

测试的时候总不能真去调后端接口吧，这时候就要用 mock。

```javascript
// api/user.js
const axios = require('axios')

async function getUser(id) {
  const res = await axios.get(`/api/users/${id}`)
  return res.data
}

module.exports = { getUser }
```

```javascript
// api/__tests__/user.test.js
const axios = require('axios')
const { getUser } = require('../user')

// 让 jest 把 axios 整个模块都给 mock 掉
jest.mock('axios')

test('getUser 能正常返回数据', async () => {
  // 告诉 mock：当调 get 的时候，返回这个假数据
  axios.get.mockResolvedValue({
    data: { id: 1, name: '张三' }
  })

  const user = await getUser(1)
  expect(user.name).toBe('张三')
  // 还能验证它有没有用对的参数去调
  expect(axios.get).toHaveBeenCalledWith('/api/users/1')
})
```

刚开始用 mock 的时候觉得绕，后来理解了：mock 就是"用假的替换真的"，让测试不依赖外部环境。

## 5. 覆盖率报告

想看看自己到底测了多少代码，加个 `--coverage` 参数就行：

```bash
npx jest --coverage
```

跑完后会在终端输出一个表格，还会在项目下生成一个 `coverage/` 目录，里面有 HTML 格式的详细报告，打开就能看到哪些代码行被测到了，哪些没覆盖到。

不过说实话，追求 100% 覆盖率不太现实，也没必要。重点测那些核心的业务逻辑和经常被复用的工具函数就行了。UI 组件那种动不动就改的，测了也白测。

## 6. 我的一些使用心得

**适合测的：**
- 工具函数（格式化、校验、计算之类的）
- 数据转换逻辑（后端接口数据 → 页面要用的格式）
- 状态管理里的关键 mutation/action

**没必要测的：**
- 纯 UI 展示组件（样式变来变去，测不胜测）
- 简单的增删改查页面（直接看效果比写测试快）

写了几个月测试下来，最大的体会是：**写测试不是为了"测试"，而是逼你把代码写得更好**。当你发现一个函数很难测的时候，往往是因为它做了太多事情，或者依赖太多外部状态。为了好测而去拆解代码，反而让代码质量上去了。

这个算是意外收获吧。
