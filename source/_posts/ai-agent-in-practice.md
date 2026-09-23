---
title: 动手写个 AI Agent：从概念到简单实现
date: 2025-06-12 14:50:30
tags:
  - AI
  - Agent
  - LLM
categories: AI
---

最近老听人聊 AI Agent，说它不止能陪你聊天，还能自己跑去查天气、调接口干活。周末闲着没事，照着文档自己撸了一个，感觉确实有点意思。这里随便记录下折腾的过程。

<!-- more -->

## 1. Agent 到底和以前的机器人有什么不同

以前用 ChatGPT 这种 ChatBot：
我问一个问题 -> 它瞎编或者靠脑子里的知识回我 -> 聊天结束。

现在的 Agent 逻辑变了：
我下达一个目标 -> 它自己想第一步干嘛 -> 调用我给它的工具（比如查数据库） -> 看看结果 -> 决定第二步干嘛 -> 最后告诉我搞定了。

其实就是给大模型装了手和脚。模型当大脑（Brain），外部的 API 当工具（Tools），然后再给它点记忆（Memory）。

## 2. 它是怎么思考的

我看大多数框架用的都是一种叫 ReAct（Reasoning + Acting）的模式，说白了就是一边想一边干：

```text
遇到问题：
  1. 思考（Thought）：分析现在是啥情况
  2. 行动（Action）：选个工具去调
  3. 观察（Observation）：看看工具返回了啥
  4. 循环：没做完就继续想，做完了就输出结果
```

打个比方，我说：“帮我查下北京今天天气，如果过 30 度了给我发封邮件。”
它就会自己在那边碎碎念：先调查天气工具... 哦 33 度，超过了... 那我再调发邮件工具... 好了搞定了，回复用户。

## 3. 拿 LangChain 跑一个试试

想最快跑起来，用 Python 配合 LangChain 是最简单的：

```python
from langchain.agents import AgentExecutor, create_openai_tools_agent
from langchain.chat_models import ChatOpenAI
from langchain.tools import tool
from langchain.prompts import ChatPromptTemplate, MessagesPlaceholder
import requests
import json

# 自己写几个工具给它用
@tool
def search_articles(keyword: str) -> str:
    """根据关键词搜索博客文章"""
    response = requests.get(f"https://api.example.com/articles?q={keyword}")
    articles = response.json()["data"]
    return json.dumps([{"title": a["title"]} for a in articles[:5]], ensure_ascii=False)

@tool
def get_weather(city: str) -> str:
    """获取城市实时天气"""
    return f"{city}: 33°C, 晴"  # 偷懒 mock 一下

@tool
def calculate(expression: str) -> str:
    """算算术"""
    try:
        return str(eval(expression))
    except Exception as e:
        return f"算错了: {e}"

# 初始化模型
llm = ChatOpenAI(model="gpt-4", temperature=0)

prompt = ChatPromptTemplate.from_messages([
    ("system", "你是一个得力助手。先思考再用工具。"),
    MessagesPlaceholder(variable_name="chat_history", optional=True),
    ("human", "{input}"),
    MessagesPlaceholder(variable_name="agent_scratchpad"),
])

tools = [search_articles, get_weather, calculate]
agent = create_openai_tools_agent(llm, tools, prompt)

# 跑起来
agent_executor = AgentExecutor(
    agent=agent,
    tools=tools,
    verbose=True,  # 开启后能看到它在那碎碎念的过程
)

result = agent_executor.invoke({
    "input": "搜索关于 Vue3 的文章，帮我算算每天读2篇需要多久"
})
print(result["output"])
```

## 4. 前端怎么搞？用 Node.js 也行

作为一个写前端的，我也试着用 Node.js 直接调 OpenAI 的接口写了一遍。没用那些花里胡哨的框架，纯手写循环：

```typescript
import OpenAI from 'openai'

const openai = new OpenAI()

// 1. 定义好工具的说明
const tools: OpenAI.ChatCompletionTool[] = [
  {
    type: 'function',
    function: {
      name: 'search_database',
      description: '在数据库中搜索文章',
      parameters: {
        type: 'object',
        properties: {
          keyword: { type: 'string' }
        },
        required: ['keyword']
      }
    }
  }
]

// 2. 真正干活的函数
const toolHandlers: Record<string, (args: any) => Promise<string>> = {
  async search_database({ keyword }) {
    // 假装去请求了
    return JSON.stringify([{ title: `关于 ${keyword} 的文章` }])
  }
}

// 3. 让它死循环跑，直到它说干完了
async function runAgent(userMessage: string) {
  const messages: OpenAI.ChatCompletionMessageParam[] = [
    { role: 'system', content: '你是助手' },
    { role: 'user', content: userMessage }
  ]

  for (let i = 0; i < 5; i++) { // 加个限制，别让它无限跑破产了
    const response = await openai.chat.completions.create({
      model: 'gpt-4',
      messages,
      tools,
      tool_choice: 'auto'
    })

    const assistantMessage = response.choices[0].message
    messages.push(assistantMessage)

    // 它没调工具，说明聊完了
    if (!assistantMessage.tool_calls?.length) {
      return assistantMessage.content
    }

    // 它要调工具，我们就帮它跑，然后把结果塞回去
    for (const toolCall of assistantMessage.tool_calls) {
      const handler = toolHandlers[toolCall.function.name]
      const args = JSON.parse(toolCall.function.arguments)
      
      console.log(`正在调工具: ${toolCall.function.name}...`)
      const result = await handler(args)

      messages.push({
        role: 'tool',
        tool_call_id: toolCall.id,
        content: result
      })
    }
  }
  return '跑太久了，强制停了'
}

const answer = await runAgent('搜一下最新的文章')
console.log(answer)
```

## 总结

其实搞了一圈下来，感觉 Agent 最大的坑不在模型智商，而是在“工具的设计”和“异常处理”上。如果接口老是报错，或者参数定义得含糊不清，它就会陷入死循环一直重试，账单看着都心疼。

后面如果要做复杂的业务，还得加一层二次确认，不能完全放权让它自己跑，不然线上库被它删了就搞笑了。感兴趣的可以自己搞个小 Demo 玩玩。
