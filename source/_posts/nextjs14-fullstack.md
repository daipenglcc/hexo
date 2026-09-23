---
title: 折腾 Next.js 14：全栈开发踩坑与基础配置
date: 2024-01-22 09:15:40
tags:
  - Next.js
  - React
  - 全栈
categories: React
---

最近写点个人小项目，发现 Next.js 14 的 App Router 终于算是彻底稳了。以前搞前后端分离还得单独弄个 Node.js 服务端，现在直接把读写数据库的逻辑全塞进 Server Actions 里，一把梭的感觉确实爽。这篇就把基础的建站流程整理一下，当个脚手架备忘。

<!-- more -->

## 1. 一把梭建项目

我一般直接用下面这个命令，该带的 `TypeScript` 和 `Tailwind` 都带上了：

```bash
npx create-next-app@latest my-blog --typescript --tailwind --eslint --app --src-dir
cd my-blog
npm run dev
```

## 2. 那个让人又爱又恨的 App Router

Next.js 14 强制推 App Router，刚开始从 Pages 迁过来确实有点蒙。说白了，它就是靠文件夹名字来定路由：

```text
src/app/
├── layout.tsx          # 每一页都会套用的最外层壳子
├── page.tsx            # 就是你的首页 /
├── loading.tsx         # 还没加载出来时转圈圈的骨架屏
├── error.tsx           # 报错了显示的页面（不会直接白屏崩溃）
├── blog/
│   ├── page.tsx        # 对应 /blog
│   └── [slug]/
│       └── page.tsx    # 动态路由，对应 /blog/xxx
```

写个最简单的外壳（Layout）：

```tsx
// src/app/layout.tsx
import './globals.css'

export const metadata = {
  title: '光阴小栈',
  description: '随便写写技术'
}

export default function RootLayout({
  children
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="zh-CN">
      <body>
        <nav>导航栏在这</nav>
        {/* 你写的具体页面都会塞进这里 */}
        <main>{children}</main>
      </body>
    </html>
  )
}
```

## 3. 服务端组件 vs 客户端组件

这个是最容易搞混的。简单来说：
**默认全是服务端组件**。在服务端组件里，你不能用 `useState`，不能绑 `onClick`，但你可以直接读库！

```tsx
// 这是一个服务端组件，直接请求数据，不用写 useEffect！
// 这玩意在服务器跑完，发给浏览器的是纯 HTML，SEO 极好
async function ArticleList() {
  const res = await fetch('https://api.example.com/articles')
  const articles = await res.json()

  return (
    <ul>
      {articles.map((item: any) => (
        <li key={item.id}>{item.title}</li>
      ))}
    </ul>
  )
}
```

如果你的组件有个按钮需要点，或者要保存点状态，那就必须在文件最上面加一句 `'use client'`：

```tsx
'use client'  // 没这句直接报错

import { useState } from 'react'

export function LikeButton() {
  const [count, setCount] = useState(0)

  return (
    <button onClick={() => setCount(count + 1)}>
      点赞 {count}
    </button>
  )
}
```

## 4. 彻底抛弃 API 路由的 Server Actions

以前写个表单提交，还得专门去 `/api/` 下面建个路由，前端再去 fetch。现在用 Server Actions，简直不要太爽：

```tsx
// app/blog/new/page.tsx
import { redirect } from 'next/navigation'

export default function NewArticlePage() {
  
  // 这个函数只在服务器上跑，直接连数据库都没问题
  async function submitForm(formData: FormData) {
    'use server'  // 魔法指令

    const title = formData.get('title')
    
    // 假装我们在操作数据库
    console.log('保存到数据库:', title)

    // 保存完直接跳回列表页
    redirect('/blog')
  }

  return (
    // 原生表单直接绑个 action
    <form action={submitForm}>
      <input name="title" placeholder="文章标题" required />
      <button type="submit">发布</button>
    </form>
  )
}
```

## 5. 偶尔还是得写 API 的情况

如果是给小程序或者别人提供接口，还是得老老实实写 API 路由：

```typescript
// app/api/hello/route.ts
import { NextResponse } from 'next/server'

export async function GET() {
  return NextResponse.json({ message: '你好啊' })
}

export async function POST(request: Request) {
  const body = await request.json()
  return NextResponse.json({ received: body })
}
```

其实玩熟了之后发现，Next.js 的思路就是尽量把活丢给服务器干，浏览器只负责展示和少量交互。虽然一开始有点折腾，但配合 Vercel 一键部署，一个人搞定全栈小项目确实非常快。
