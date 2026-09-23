---
title: 用 Next.js 14 构建全栈应用实践
date: 2024-01-22 09:15:40
tags:
  - Next.js
  - React
  - 全栈
categories: React
---

Next.js 14 带来了 App Router 的全面稳定、Server Actions、部分预渲染（PPR）等重磅特性，进一步巩固了其 React 全栈框架的地位。本文以搭建一个博客应用为例，记录 Next.js 14 全栈开发的核心知识点和实践经验。

<!-- more -->

## 1. 创建项目

```bash
npx create-next-app@latest my-blog --typescript --tailwind --eslint --app --src-dir
cd my-blog
npm run dev
```

## 2. App Router 路由系统

Next.js 14 使用基于文件系统的路由，App Router 以 `app/` 目录为根：

```
src/app/
├── layout.tsx          # 根布局（全局 Layout）
├── page.tsx            # 首页 /
├── loading.tsx         # 加载状态 UI
├── error.tsx           # 错误边界 UI
├── not-found.tsx       # 404 页面
├── blog/
│   ├── page.tsx        # /blog
│   └── [slug]/
│       ├── page.tsx    # /blog/:slug（动态路由）
│       └── loading.tsx
├── api/
│   └── articles/
│       └── route.ts    # API 路由 /api/articles
└── (auth)/             # 路由组（不影响 URL）
    ├── login/
    │   └── page.tsx    # /login
    └── register/
        └── page.tsx    # /register
```

### 布局组件

```tsx
// src/app/layout.tsx
import type { Metadata } from 'next'
import { Inter } from 'next/font/google'
import './globals.css'

const inter = Inter({ subsets: ['latin'] })

export const metadata: Metadata = {
  title: {
    template: '%s | 光阴小栈',
    default: '光阴小栈'
  },
  description: '一个技术博客'
}

export default function RootLayout({
  children
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="zh-CN">
      <body className={inter.className}>
        <nav className="navbar">
          {/* 导航栏 */}
        </nav>
        <main>{children}</main>
        <footer>
          {/* 页脚 */}
        </footer>
      </body>
    </html>
  )
}
```

## 3. 服务端组件 vs 客户端组件

Next.js 14 默认所有组件都是**服务端组件（Server Components）**：

```tsx
// 服务端组件（默认）—— 可以直接读数据库、调用 API
// ✅ 在服务器执行，不会打包到客户端 JS
async function ArticleList() {
  // 直接在组件中获取数据（无需 useEffect）
  const articles = await fetch('https://api.example.com/articles', {
    next: { revalidate: 60 }  // ISR：60秒后重新验证
  }).then(r => r.json())

  return (
    <ul>
      {articles.map((article: any) => (
        <li key={article.id}>
          <h3>{article.title}</h3>
          <p>{article.summary}</p>
        </li>
      ))}
    </ul>
  )
}
```

```tsx
// 客户端组件 —— 需要交互、状态、浏览器 API 时使用
'use client'  // 必须在文件顶部声明

import { useState } from 'react'

export function LikeButton({ articleId }: { articleId: string }) {
  const [liked, setLiked] = useState(false)
  const [count, setCount] = useState(0)

  const handleLike = async () => {
    setLiked(!liked)
    setCount(prev => liked ? prev - 1 : prev + 1)
    await fetch(`/api/articles/${articleId}/like`, { method: 'POST' })
  }

  return (
    <button onClick={handleLike}>
      {liked ? '❤️' : '🤍'} {count}
    </button>
  )
}
```

### 如何选择？

| 需求 | 使用 |
| :--- | :--- |
| 数据获取、数据库查询 | 服务端组件 |
| 访问后端资源 | 服务端组件 |
| 敏感信息（API Key 等） | 服务端组件 |
| 事件监听（onClick 等） | 客户端组件 |
| useState / useEffect | 客户端组件 |
| 浏览器 API（localStorage 等） | 客户端组件 |

## 4. Server Actions

Next.js 14 的 Server Actions 让表单处理变得极其简洁，无需手动创建 API 路由：

```tsx
// app/blog/new/page.tsx
import { redirect } from 'next/navigation'
import { revalidatePath } from 'next/cache'

export default function NewArticlePage() {
  async function createArticle(formData: FormData) {
    'use server'  // 标记为 Server Action

    const title = formData.get('title') as string
    const content = formData.get('content') as string

    // 直接操作数据库（这段代码只在服务端运行）
    await db.article.create({
      data: { title, content, published: true }
    })

    // 重新验证缓存
    revalidatePath('/blog')
    // 重定向
    redirect('/blog')
  }

  return (
    <form action={createArticle}>
      <input name="title" placeholder="文章标题" required />
      <textarea name="content" placeholder="文章内容" required />
      <button type="submit">发布文章</button>
    </form>
  )
}
```

## 5. 数据获取策略

```tsx
// 1. 静态数据（构建时获取，SSG）
async function StaticPage() {
  const data = await fetch('https://api.example.com/data', {
    cache: 'force-cache'  // 默认行为
  })
  return <div>{/* ... */}</div>
}

// 2. 动态数据（每次请求都获取，SSR）
async function DynamicPage() {
  const data = await fetch('https://api.example.com/data', {
    cache: 'no-store'
  })
  return <div>{/* ... */}</div>
}

// 3. 增量静态再生（ISR）
async function ISRPage() {
  const data = await fetch('https://api.example.com/data', {
    next: { revalidate: 60 }  // 60秒后重新验证
  })
  return <div>{/* ... */}</div>
}
```

## 6. API 路由

```typescript
// app/api/articles/route.ts
import { NextRequest, NextResponse } from 'next/server'

export async function GET(request: NextRequest) {
  const searchParams = request.nextUrl.searchParams
  const page = Number(searchParams.get('page')) || 1
  const limit = Number(searchParams.get('limit')) || 10

  const articles = await db.article.findMany({
    skip: (page - 1) * limit,
    take: limit,
    orderBy: { createdAt: 'desc' }
  })

  return NextResponse.json({
    data: articles,
    page,
    limit
  })
}

export async function POST(request: NextRequest) {
  const body = await request.json()

  const article = await db.article.create({
    data: {
      title: body.title,
      content: body.content
    }
  })

  return NextResponse.json({ data: article }, { status: 201 })
}
```

```typescript
// app/api/articles/[id]/route.ts
export async function GET(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  const article = await db.article.findUnique({
    where: { id: params.id }
  })

  if (!article) {
    return NextResponse.json(
      { error: '文章不存在' },
      { status: 404 }
    )
  }

  return NextResponse.json({ data: article })
}
```

## 7. 加载状态与错误处理

```tsx
// app/blog/loading.tsx（同级路由的加载状态）
export default function Loading() {
  return (
    <div className="loading-container">
      <div className="skeleton-card" />
      <div className="skeleton-card" />
      <div className="skeleton-card" />
    </div>
  )
}
```

```tsx
// app/blog/error.tsx
'use client'

export default function Error({
  error,
  reset
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  return (
    <div className="error-page">
      <h2>出错了</h2>
      <p>{error.message}</p>
      <button onClick={reset}>重试</button>
    </div>
  )
}
```

## 8. 中间件

```typescript
// middleware.ts（项目根目录）
import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

export function middleware(request: NextRequest) {
  // 检查登录状态
  const token = request.cookies.get('token')?.value

  if (request.nextUrl.pathname.startsWith('/admin') && !token) {
    return NextResponse.redirect(new URL('/login', request.url))
  }

  return NextResponse.next()
}

export const config = {
  matcher: ['/admin/:path*', '/api/admin/:path*']
}
```

Next.js 14 将 React 的服务端能力发挥到了极致，是 2024 年构建全栈 Web 应用的优秀选择。
