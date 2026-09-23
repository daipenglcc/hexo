---
title: 用了一年 GitHub Copilot，聊聊怎么用最顺手
date: 2024-05-10 16:30:20
tags:
  - AI
  - GitHub Copilot
  - 效率工具
categories: AI
---

Copilot 刚出的时候觉得是个玩具，现在几乎每天敲代码都离不开了。比起在网页上跟 ChatGPT 聊天复制粘贴，它在编辑器里直接按 Tab 补全的感觉确实更连贯。

这篇算是我自己这两年摸索出来的一些常用姿势，整理一下当个备忘录。

<!-- more -->

## 1. 最基础的装配

我是用 VS Code，必备的就俩插件：
- **GitHub Copilot**：负责写代码时在光标后面疯狂提示，按 `Tab` 接受。
- **GitHub Copilot Chat**：侧边栏的一个对话框，遇到跑不通的代码可以直接把报错丢给它。

常用的几个快捷键（我是 macOS，Windows 把 Cmd 换成 Ctrl 就行）：
- `Tab`：写得不错，收了
- `Esc`：这写的什么鬼，关掉
- `Alt + ]`：换一个提示看看
- `Cmd + Shift + I`：直接唤出对话框提问

## 2. 也是最实用的：写注释让它干活

与其自己敲代码，不如把注释写明白点，让它去填空。

```typescript
// ❌ 以前这样写注释它可能看不懂你在干嘛：
// 处理用户数据

// ✅ 现在我会写得很啰嗦，当成跟人说话一样：
// 把后端接口拿到的用户列表，转成下面前端 Table 组件要的格式：
// 1. 把 created_at 时间戳转成 'YYYY-MM-DD'
// 2. 将 role 映射为中文（admin -> 管理员，user -> 普通用户）
// 3. 算出每个用户最后一次登录是几天前
```

写完这段注释，回车，它基本上就能把那个冗长的数据转换函数一字不差地写出来了。

## 3. 它是怎么猜懂我的

后来我发现，只要你把相关的文件打开放在旁边的标签页，它的提示就会变准很多。

比如你正在写一个接口函数：

```typescript
// 在顶部把用到的类型和工具引进来
import { prisma } from '@/lib/prisma'
import { ApiResponse } from '@/types/api'
import { formatDate } from '@/utils/date'

// 当你往下敲代码的时候，它就已经知道：
// - 你是用 Prisma 查库
// - 你的返回格式得包一层 ApiResponse
// - 遇到日期要用 formatDate
```

有时候如果你在旁边开着 `types.ts` 和控制器的文件，它甚至能顺着你刚才写的方法继续往下猜你要写啥。

## 4. 侧边栏 Chat 的几个花样

敲代码卡壳的时候，用侧边栏也是挺爽的。常用的几个斜杠命令：

```text
/explain 框选一段恶心的祖传代码，让它给你解释这到底是啥意思
/refactor 把一段嵌套了五层的 if-else 发给它，让它用策略模式重构一下
/tests 选中一个核心的工具函数，让它顺手把单元测试写了
/fix 遇到一长串红色的 TypeScript 报错看不懂，直接整个丢进去让它修
```

## 5. 个人觉得很爽的几个场景

### 批量复制粘贴的时候

写后端接口，很多时候代码长得差不多：

```typescript
// 当你手敲完第一个接口：
export async function getUsers(): Promise<ApiResponse<User[]>> {
  const res = await fetch('/api/users')
  return res.json()
}

// 只要你敲下 export async function get...
// 后面关于文章、评论的接口，只要按 Tab 就一直能补全下去
export async function getArticles(): Promise<ApiResponse<Article[]>> {
  const res = await fetch('/api/articles')
  return res.json()
}
```

### 写正则

正则这玩意儿过几个月就忘，现在我都直接用嘴写：

```typescript
// 把 markdown 里面的图片链接都扣出来，格式类似于 ![alt](url)
function extractImageUrls(markdown: string): string[] {
  // 这行正则我连脑子都不想动，直接按 Tab
  const regex = /!\[.*?\]\((.*?)(?:\s+".*?")?\)/g
  const urls: string[] = []
  let match
  while ((match = regex.exec(markdown)) !== null) {
    urls.push(match[1])
  }
  return urls
}
```

## 简单总结一下

1. **别全信**：大方向一般没问题，但边界条件（比如没考虑到 undefined、数组越界）还是得自己用肉眼扫一遍。
2. **小步走**：别指望写一句注释让它写个几十行的复杂逻辑，拆成小方法一点点生成比较靠谱。
3. **保持自己的代码规范**：你代码写得乱，它就会跟着乱写；你代码清爽，它生成的也就干净。本质上它就是个高级的复读机。

总的来说，这玩意儿确实能省不少体力活，没试过的强烈建议装上体验一下，挺顺手的。
