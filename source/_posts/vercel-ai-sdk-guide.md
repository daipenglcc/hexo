---
title: 用 Vercel AI SDK 给网站接上大模型对话
date: 2025-04-22 11:30:18
tags:
  - AI
  - Vercel AI SDK
  - Next.js
  - LLM
categories: AI
---

之前折腾 RAG、跑本地模型啥的都是自己玩，最近想在正经项目里加一个 AI 对话功能。自己从零写流式响应、处理 SSE 什么的还是挺麻烦的，后来发现 Vercel 出了个 AI SDK，把跟大模型交互的脏活累活都封装好了，前后端都有对应的工具函数。试了一下，确实省了不少事。

<!-- more -->

## 1. Vercel AI SDK 是什么

简单说就是一个 TypeScript 库，帮你处理：
- 跟各种大模型 API（OpenAI、Anthropic、Google 等）的对接
- 流式响应（一个字一个字蹦出来的效果）
- 前端的对话状态管理（消息列表、loading 状态等）

它分两个部分：
- `ai` — 后端用的，处理模型调用和流式传输
- `ai/react` — 前端用的，提供 `useChat` 等 Hook

## 2. 搭个最简单的对话页面

用 Next.js 项目（App Router）来搞。

```bash
npm install ai @ai-sdk/openai
```

### 后端：API Route

```typescript
// app/api/chat/route.ts
import { openai } from '@ai-sdk/openai'
import { streamText } from 'ai'

export async function POST(req: Request) {
  const { messages } = await req.json()

  const result = streamText({
    model: openai('gpt-4o-mini'),
    system: '你是一个友好的前端开发助手，回答要简洁实用。',
    messages,
  })

  return result.toDataStreamResponse()
}
```

就这几行，后端就搞定了。`streamText` 会自动处理流式响应，不用自己写 SSE 的逻辑。

### 前端：对话组件

```tsx
// app/chat/page.tsx
'use client'

import { useChat } from 'ai/react'

export default function ChatPage() {
  const { messages, input, handleInputChange, handleSubmit, isLoading } = useChat()

  return (
    <div className="max-w-2xl mx-auto p-6">
      <h1 className="text-2xl font-bold mb-6">AI 助手</h1>
      
      {/* 消息列表 */}
      <div className="space-y-4 mb-6">
        {messages.map((msg) => (
          <div
            key={msg.id}
            className={`p-4 rounded-lg ${
              msg.role === 'user'
                ? 'bg-blue-100 ml-12'
                : 'bg-gray-100 mr-12'
            }`}
          >
            <p className="text-sm text-gray-500 mb-1">
              {msg.role === 'user' ? '我' : 'AI'}
            </p>
            <p className="whitespace-pre-wrap">{msg.content}</p>
          </div>
        ))}
        
        {isLoading && (
          <div className="bg-gray-100 p-4 rounded-lg mr-12">
            <p className="text-gray-400">思考中...</p>
          </div>
        )}
      </div>

      {/* 输入框 */}
      <form onSubmit={handleSubmit} className="flex gap-2">
        <input
          value={input}
          onChange={handleInputChange}
          placeholder="问点什么..."
          className="flex-1 border rounded-lg px-4 py-2"
        />
        <button
          type="submit"
          disabled={isLoading}
          className="bg-blue-500 text-white px-6 py-2 rounded-lg disabled:opacity-50"
        >
          发送
        </button>
      </form>
    </div>
  )
}
```

`useChat` 这个 Hook 帮你管了消息列表、输入状态、loading 状态、流式接收等所有琐碎的事情。

## 3. 流式响应的体验

用 AI SDK 最爽的一点就是流式响应基本不用管。后端用 `streamText` 返回流，前端用 `useChat` 自动接收，回答一个字一个字地蹦出来，跟 ChatGPT 网页版的体验一样。

如果自己实现的话，要处理 SSE 连接、解析 chunk、拼接内容、处理中断和错误……光想想就头大。

## 4. 换模型

AI SDK 的一个好处是换模型特别简单，基本上改一行代码：

```typescript
// 用 OpenAI
import { openai } from '@ai-sdk/openai'
const model = openai('gpt-4o-mini')

// 用 Anthropic Claude
import { anthropic } from '@ai-sdk/anthropic'
const model = anthropic('claude-3-5-sonnet-20241022')

// 用 Google Gemini
import { google } from '@ai-sdk/google'
const model = google('gemini-1.5-flash')
```

接口是统一的，不用因为换了模型就重写后端逻辑。

## 5. 加点实用功能

### 限制对话长度

免得 token 消耗太快：

```typescript
// 只保留最近 10 条消息作为上下文
const result = streamText({
  model: openai('gpt-4o-mini'),
  messages: messages.slice(-10),
})
```

### 停止生成

```tsx
const { stop, isLoading } = useChat()

// 用户点击停止
{isLoading && (
  <button onClick={stop} className="text-red-500">
    停止生成
  </button>
)}
```

### 带上下文的问答（简易版 RAG）

```typescript
// 在 system prompt 里塞进去相关内容
const result = streamText({
  model: openai('gpt-4o-mini'),
  system: `你是一个产品客服。以下是产品文档内容，请基于文档回答用户问题：
  
${relevantDocs}

如果文档中没有相关信息，请诚实地说"这个问题我暂时无法回答"。`,
  messages,
})
```

当然真正的 RAG 需要向量检索，但对于文档量不大的场景，直接塞 prompt 里也够用了。

## 6. 注意事项

- **API Key 安全**：Key 只在后端的 API Route 里用，别暴露到前端。用环境变量 `OPENAI_API_KEY` 存
- **费用控制**：加个速率限制，防止有人疯狂刷你的接口。简单做可以用 `next-rate-limit`
- **错误处理**：模型 API 可能超时或报错，前端要展示友好的错误信息
- **内容安全**：如果是面向用户的产品，要考虑内容过滤

总的来说 Vercel AI SDK 把"前端接 AI"这件事的门槛降低了很多。以前觉得搞流式对话很复杂，现在前后端加起来不到 50 行代码就能跑起来一个能用的对话界面。
