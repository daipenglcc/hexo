---
title: LLM 应用落地的工程难题：上下文窗口、幻觉和成本控制
date: 2024-06-08 14:20:00
tags:
  - LLM
  - AI工程
  - RAG
  - prompt engineering
categories: AI
---

做 AI 应用接近一年了，最开始以为就是把 API 调一调，很快发现坑多得超出想象。模型本身的能力已经很强了，真正难的是工程部分：怎么让它在生产环境里稳定、准确、成本可控地运行。整理一些实际遇到的问题和解法。

<!-- more -->

## 上下文窗口的管理

现在主流模型的 context window：GPT-4o 是 128K tokens，Claude 3.5 Sonnet 是 200K，Gemini 1.5 Pro 甚至到了 1M。看起来很大，但生产场景里用起来并不是"有多少塞多少"这么简单。

**token 成本问题**

以 GPT-4o 为例（截至写这篇文章），input $5/1M tokens，output $15/1M tokens。一个对话如果每轮都带着全部历史，50 轮对话下来 input token 消耗是个等差数列求和，成本会爆。

**长上下文的"迷失"问题**

论文 "Lost in the Middle" 表明，当上下文很长时，模型对中间位置的内容注意力明显下降，首尾的内容处理得更好。所以简单地把所有文档塞满 context 并不能保证质量。

**实际的上下文管理策略：**

```
会话历史压缩：
- 保留最近 N 轮完整对话
- 更早的历史用摘要替换（让模型总结前面说了什么）
- system prompt 里放关键约束和角色定义

RAG 检索内容：
- 不预先全部加载，每次 query 时检索相关片段
- 控制检索结果总量（通常 3-5 个最相关的 chunk 比 10 个更好）
- 按相关性排序，最相关的放首尾，次相关的放中间

动态 system prompt：
- 根据用户意图动态注入相关工具文档
- 不相关的功能说明不塞进去
```

## 幻觉（Hallucination）的工程解法

模型会一本正经地说错话，这不会彻底消失，只能通过工程手段减少。

**结构化输出 + 验证**

让模型返回 JSON 而不是自然语言，然后在应用层验证：

```javascript
// 用 Zod 定义期望的输出结构
const OrderSchema = z.object({
  orderId: z.string().regex(/^ORD-\d{8}$/),
  items: z.array(z.object({
    productId: z.string(),
    quantity: z.number().positive().int(),
    price: z.number().positive()
  })),
  totalAmount: z.number()
})

async function extractOrder(text: string) {
  const response = await openai.chat.completions.create({
    model: 'gpt-4o',
    messages: [
      { role: 'system', content: '从用户输入中提取订单信息，返回严格的 JSON 格式' },
      { role: 'user', content: text }
    ],
    response_format: { type: 'json_object' }  // 强制 JSON 输出
  })

  const raw = JSON.parse(response.choices[0].message.content)
  
  // Zod 验证，不符合预期就抛错，由上层处理
  return OrderSchema.parse(raw)
}
```

GPT-4o 支持 `response_format: { type: 'json_schema', json_schema: { ... } }` 直接传 schema，更进一步约束输出格式。

**事实性内容靠 RAG + citation**

对于需要准确性的场景（客服问答、知识库检索），不让模型"自由发挥"，而是：
1. 从知识库检索相关内容
2. 让模型只基于检索到的内容回答
3. 要求模型给出引用来源

```
system: 你只能基于提供的参考文档回答问题，不能使用文档以外的知识。
回答时必须标注引用来源 [文档ID]。如果文档里没有答案，直接说"根据现有文档无法回答"。

参考文档：
[DOC-1] ...
[DOC-2] ...
```

**Self-consistency 抽样**

对关键问题让模型回答多次（temperature > 0），取多次答案中的"众数"。一次回答可能幻觉，但多次回答如果大多数一致，可信度更高。成本翻几倍，适合精度要求极高的场景。

## 成本控制

LLM API 的成本不容忽视，特别是高流量场景。

**缓存语义相似的请求**

完全相同的 prompt 可以用 Redis 精确匹配缓存。更进一步，对语义相似的查询也可以缓存：

```javascript
async function cachedLLMCall(prompt: string) {
  // 1. 把 prompt 向量化
  const embedding = await getEmbedding(prompt)
  
  // 2. 在向量数据库里查相似的历史请求
  const similar = await vectorDB.search(embedding, { topK: 1, threshold: 0.95 })
  
  if (similar.length > 0) {
    console.log('命中语义缓存')
    return similar[0].cachedResponse
  }
  
  // 3. cache miss，调 LLM
  const response = await callLLM(prompt)
  
  // 4. 存缓存
  await vectorDB.insert({ embedding, prompt, cachedResponse: response })
  
  return response
}
```

**模型路由（Model Routing）**

不同复杂度的任务用不同模型：

```javascript
function selectModel(taskType: string, complexity: 'low' | 'medium' | 'high') {
  // 简单分类、提取，用便宜的小模型
  if (complexity === 'low') return 'gpt-4o-mini'
  
  // 中等复杂度
  if (complexity === 'medium') return 'gpt-4o'
  
  // 复杂推理、代码生成
  return 'claude-3-5-sonnet'
}
```

`gpt-4o-mini` 比 `gpt-4o` 便宜约 15 倍，能处理的任务比想象中多。先用小模型，不行再 fallback 到大模型，能省不少钱。

**流式响应减少超时和体感延迟**

LLM 生成长响应时间长，用 streaming 让用户看到逐步生成：

```javascript
const stream = await openai.chat.completions.create({
  model: 'gpt-4o',
  messages: [...],
  stream: true
})

for await (const chunk of stream) {
  const delta = chunk.choices[0]?.delta?.content
  if (delta) {
    process.stdout.write(delta)  // 实时输出，前端 SSE 推送
  }
}
```

流式输出让用户感觉"快"很多，即使总时长相同。

## 观测性（Observability）

生产环境里，LLM 调用黑盒化非常危险——你不知道它什么时候开始退化、哪类问题准确率低、哪个 prompt 版本效果更好。

最基本的要记录：

```typescript
interface LLMCallLog {
  requestId: string
  timestamp: Date
  model: string
  promptVersion: string      // prompt 要版本化管理
  inputTokens: number
  outputTokens: number
  latencyMs: number
  cost: number               // 每次调用的费用
  userFeedback?: 'good' | 'bad'  // 如果有用户反馈
}
```

有了这些数据，才能做 A/B 测试 prompt、分析成本趋势、及时发现模型性能退化。

---

LLM 应用的工程复杂度超出了很多人的预期。模型调通只是开始，上下文管理、幻觉控制、成本优化、监控这些才是真正决定产品质量的地方。
