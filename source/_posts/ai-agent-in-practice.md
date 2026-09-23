---
title: AI Agent 开发实战：从概念到落地
date: 2025-06-12 14:50:30
tags:
  - AI
  - Agent
  - LLM
categories: AI
---

2025 年，AI 应用的焦点从简单的对话和内容生成，转向了更具自主性的 AI Agent（智能体）。Agent 不仅能"说"，更能通过调用工具、执行代码、访问外部系统来完成复杂任务。本文记录 AI Agent 的核心概念和开发实践。

<!-- more -->

## 1. 什么是 AI Agent

Agent 的核心区别于普通 AI 对话：

```text
普通 ChatBot:
  用户提问 → LLM 回答 → 结束

AI Agent:
  用户下达目标 → LLM 分析任务 → 规划步骤 → 调用工具执行 → 观察结果
  → 判断是否完成 → 继续执行或返回最终结果
```

一个 Agent 由三部分组成：
- **大模型（Brain）**：负责理解、推理和决策
- **工具（Tools）**：Agent 可以调用的外部能力（API、数据库、代码执行等）
- **记忆（Memory）**：对话历史和中间结果的存储

## 2. Agent 的工作循环

Agent 遵循经典的 **ReAct（Reasoning + Acting）** 模式：

```text
循环开始 →
  1. Thought（思考）：分析当前状况，决定下一步做什么
  2. Action（行动）：选择并调用一个工具
  3. Observation（观察）：获取工具返回的结果
  4. 重复 1-3，直到任务完成
← 返回最终答案
```

实际例子：

```text
用户: "帮我查一下北京今天的天气，如果温度超过30度，给我发一封邮件提醒"

Agent 思考: 需要先查询天气，再根据温度决定是否发邮件
Agent 行动: 调用 weather_api.get("北京")
Agent 观察: {"温度": 33, "天气": "晴", "湿度": 45}
Agent 思考: 温度 33°C > 30°C，需要发送提醒邮件
Agent 行动: 调用 email.send(to="user@example.com", subject="高温提醒", body="北京今天33°C...")
Agent 观察: {"status": "sent"}
Agent 回答: "北京今天33°C，已经给您发送了高温提醒邮件。"
```

## 3. 用 LangChain 构建 Agent

```python
from langchain.agents import AgentExecutor, create_openai_tools_agent
from langchain.chat_models import ChatOpenAI
from langchain.tools import tool
from langchain.prompts import ChatPromptTemplate, MessagesPlaceholder
import requests
import json

# 定义工具
@tool
def search_articles(keyword: str) -> str:
    """根据关键词搜索博客文章，返回相关文章列表"""
    response = requests.get(
        f"https://api.example.com/articles?q={keyword}"
    )
    articles = response.json()["data"]
    return json.dumps([
        {"title": a["title"], "url": a["url"]}
        for a in articles[:5]
    ], ensure_ascii=False)

@tool
def get_weather(city: str) -> str:
    """获取指定城市的实时天气信息"""
    response = requests.get(
        f"https://api.weather.com/current?city={city}"
    )
    data = response.json()
    return f"{city}: {data['temp']}°C, {data['weather']}, 湿度{data['humidity']}%"

@tool
def calculate(expression: str) -> str:
    """计算数学表达式，如 '2 + 3 * 4'"""
    try:
        result = eval(expression)
        return str(result)
    except Exception as e:
        return f"计算错误: {e}"

# 创建 Agent
llm = ChatOpenAI(model="gpt-4", temperature=0)

prompt = ChatPromptTemplate.from_messages([
    ("system", "你是一个智能助手，可以使用工具帮助用户完成任务。"
               "在使用工具前请先思考需要什么信息，然后选择合适的工具。"),
    MessagesPlaceholder(variable_name="chat_history", optional=True),
    ("human", "{input}"),
    MessagesPlaceholder(variable_name="agent_scratchpad"),
])

tools = [search_articles, get_weather, calculate]
agent = create_openai_tools_agent(llm, tools, prompt)

# Agent 执行器
agent_executor = AgentExecutor(
    agent=agent,
    tools=tools,
    verbose=True,          # 打印思考过程
    max_iterations=5,      # 最大迭代次数
    handle_parsing_errors=True
)

# 运行
result = agent_executor.invoke({
    "input": "搜索关于 Vue3 的文章，并帮我计算如果每天读2篇需要多少天"
})
print(result["output"])
```

## 4. 用 Node.js 构建工具调用 Agent

```typescript
import OpenAI from 'openai'

const openai = new OpenAI()

// 定义工具
const tools: OpenAI.ChatCompletionTool[] = [
  {
    type: 'function',
    function: {
      name: 'search_database',
      description: '在数据库中搜索文章',
      parameters: {
        type: 'object',
        properties: {
          keyword: { type: 'string', description: '搜索关键词' },
          limit: { type: 'number', description: '返回数量', default: 5 }
        },
        required: ['keyword']
      }
    }
  },
  {
    type: 'function',
    function: {
      name: 'send_notification',
      description: '发送通知消息给用户',
      parameters: {
        type: 'object',
        properties: {
          title: { type: 'string', description: '通知标题' },
          content: { type: 'string', description: '通知内容' }
        },
        required: ['title', 'content']
      }
    }
  }
]

// 工具执行函数映射
const toolHandlers: Record<string, (args: any) => Promise<string>> = {
  async search_database({ keyword, limit = 5 }) {
    const res = await fetch(`/api/search?q=${keyword}&limit=${limit}`)
    return JSON.stringify(await res.json())
  },
  async send_notification({ title, content }) {
    await fetch('/api/notify', {
      method: 'POST',
      body: JSON.stringify({ title, content })
    })
    return JSON.stringify({ success: true })
  }
}

// Agent 执行循环
async function runAgent(userMessage: string) {
  const messages: OpenAI.ChatCompletionMessageParam[] = [
    { role: 'system', content: '你是一个智能助手，可以搜索文章和发送通知。' },
    { role: 'user', content: userMessage }
  ]

  let iterations = 0
  const MAX_ITERATIONS = 5

  while (iterations < MAX_ITERATIONS) {
    const response = await openai.chat.completions.create({
      model: 'gpt-4',
      messages,
      tools,
      tool_choice: 'auto'
    })

    const assistantMessage = response.choices[0].message
    messages.push(assistantMessage)

    // 如果没有工具调用，说明 Agent 已完成
    if (!assistantMessage.tool_calls?.length) {
      return assistantMessage.content
    }

    // 执行每个工具调用
    for (const toolCall of assistantMessage.tool_calls) {
      const handler = toolHandlers[toolCall.function.name]
      const args = JSON.parse(toolCall.function.arguments)

      console.log(`🔧 调用工具: ${toolCall.function.name}`, args)

      const result = await handler(args)

      // 将工具结果反馈给 LLM
      messages.push({
        role: 'tool',
        tool_call_id: toolCall.id,
        content: result
      })
    }

    iterations++
  }

  return '达到最大迭代次数，任务未完成'
}

// 使用
const answer = await runAgent('帮我搜索最新的 AI 相关文章，然后发一条总结通知给我')
console.log(answer)
```

## 5. Agent 设计要点

### 5.1 工具设计原则

- **单一职责**：每个工具只做一件事
- **清晰描述**：工具的 description 写清楚用途和参数含义，这是 LLM 选择工具的依据
- **错误处理**：工具要返回明确的错误信息，让 Agent 能够做出调整

### 5.2 安全边界

```python
# 限制 Agent 的能力范围
agent_executor = AgentExecutor(
    agent=agent,
    tools=tools,
    max_iterations=10,          # 防止无限循环
    max_execution_time=60,      # 超时限制
    early_stopping_method="force",  # 超出限制直接停止
)
```

### 5.3 记忆管理

```python
from langchain.memory import ConversationBufferWindowMemory

# 只保留最近 10 轮对话
memory = ConversationBufferWindowMemory(
    memory_key="chat_history",
    return_messages=True,
    k=10
)
```

## 6. Agent 的适用场景

| 场景 | 例子 |
| :--- | :--- |
| 数据分析助手 | 查询数据库 → 计算统计 → 生成报告 |
| 客服机器人 | 理解问题 → 查知识库 → 创建工单 |
| 开发辅助 | 读代码 → 分析问题 → 生成修复方案 |
| 自动化运维 | 监控告警 → 诊断原因 → 执行修复 |

## 总结

Agent 的核心价值在于将 LLM 的推理能力与外部工具的执行能力结合，实现真正的"AI 办事"而不只是"AI 聊天"。
