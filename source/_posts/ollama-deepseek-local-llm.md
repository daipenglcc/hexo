---
title: 用 Ollama + DeepSeek 搞个本地免费大模型助手
date: 2025-02-18 14:20:00
tags:
  - AI
  - DeepSeek
  - Ollama
  - 本地大模型
  - 前端开发
categories: AI
---

前阵子 DeepSeek 开源把圈子炸翻了，连不懂技术的朋友都在问怎么搞。我自己的破电脑虽然没有顶级显卡，但也想凑个热闹。折腾了一圈发现，用 Ollama 在本地跑个小参数量的版本体验最好，基本没啥心智负担，断网了也能用，还不用担心自己的代码被传到网上当训练料。

这里简单记录一下怎么用 Ollama 把模型跑起来，顺带搞个前端小 Demo 调一下。

<!-- more -->

## 1. 无脑装 Ollama

Ollama 就像是大模型界的 Docker，把它装好，跑模型只要一行命令。

- **Mac 用家**：最简单，直接 brew 一下：
  ```bash
  brew install ollama
  ```
- **Windows 用家**：去官网下个 `.exe` 点下一步完事。

装好后，控制台敲一下，看看是不是还活着：
```bash
ollama --version
```

## 2. 把 DeepSeek 拉下来跑起

大模型吃内存和显存，咱们得根据电脑的体质选：
- **普通轻薄本 (8G/16G内存)**：跑个 7B 或者 1.5B 的小版本，聪明度够日常对付了。
- **高配游戏本/M芯片Mac (32G+)**：可以尝试 14B 甚至 32B。

比如我要跑个 7B 版本的 DeepSeek-R1：
```bash
# 这一句敲下去，它会自动下载模型并启动（大概几十个G，网慢得等会儿）
ollama run deepseek-r1:7b
```

下完之后，终端就变成聊天窗口了，你可以直接问它问题，速度飞快。

平时常用的几个管理命令：
```bash
ollama list                  # 看看本地下了哪些大块头
ollama stop deepseek-r1:7b   # 电脑风扇狂转受不了了，赶紧停掉释放内存
ollama rm deepseek-r1:1.5b   # 空间不够了，删掉没用的
```

## 3. 前端怎么去连它？

Ollama 启动后，会在本地悄悄开一个 `11434` 端口，接口格式甚至跟 OpenAI 是兼容的。这就意味着我们能自己写代码去连它。

比如用 JavaScript 的 `fetch` 搞个流式输出（就是那种像打字机一样一个字一个字蹦出来的效果）：

```typescript
// 写个方法调本地接口
async function askLocalAI(question) {
  const response = await fetch('http://localhost:11434/api/generate', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model: 'deepseek-r1:7b',
      prompt: question,
      stream: true, // 开启流式输出
    }),
  });

  const reader = response.body.getReader();
  const decoder = new TextDecoder('utf-8');

  // 一点点读流过来的数据
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    
    // 解析出来拼起来就能展示在页面上了
    const chunk = decoder.decode(value);
    console.log(chunk); 
  }
}

askLocalAI("用 JS 写个深拷贝");
```

> **踩坑预警**：如果你用前端直接发请求报跨域错误（CORS），得去改一下 Ollama 的环境变量，允许所有源访问（`OLLAMA_ORIGINS="*"`），重启服务就好了。

## 4. 搞点进阶的：定制自己的“人设”

如果觉得官方的模型废话太多，我们可以像写 Dockerfile 一样写个 `Modelfile`，把它调教成一个高冷的代码机器。

建个文本文件叫 `Modelfile`：
```text
# 基于哪个模型底座
FROM deepseek-r1:7b

# 把温度调低，别让它发散瞎编（写代码一般 0.2）
PARAMETER temperature 0.2

# 强制给定人设
SYSTEM """
你是一个资深程序员，精通 Vue3 和 Node.js。
我的问题你直接给代码，不要废话解释，不要寒暄。
"""
```

然后在终端里把它打成一个新的包：
```bash
ollama create my-coder-ai -f ./Modelfile
```
以后你只要跑 `ollama run my-coder-ai`，它就会变成一个毫无感情的吐码机器了。

总结一下，用本地大模型最大的爽点就是“不用心疼接口钱”，写个脚本疯狂向它发请求测试也不心疼。对于平时想尝试大模型开发又不想买 API Key 的人来说，Ollama + 开源模型绝对是最好玩的玩具了。
