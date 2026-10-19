---
title: 用 AI Agent 做逆向工程：rea 工具链初探
date: 2026-04-16 11:30:00
tags:
  - 逆向工程
  - AI Agent
  - MCP
  - 静态分析
  - Ghidra
categories: AI
---

上周在 GitHub 上刷到了一个仓库 [morluto/rea](https://github.com/morluto/rea)，定位是「用 Agent 逆向分析任何东西，从 App 行为一路打到原生二进制」。标题看着挺唬人，但 stars 数已经快速爬到很多，还有 Ghidra、MCP、Claude Code 等关键词——感觉不像纯噱头，花了一下午研究了一下，顺便整理成这篇。

<!-- more -->

## 它在解决什么问题

逆向工程这件事，传统流程大概是这样的：

1. 用 Ghidra / IDA Pro 反汇编或反编译二进制
2. 手动阅读伪代码，靠经验猜函数语义
3. 写 Frida 脚本动态 hook，观察运行时行为
4. 在各个工具之间来回切换，手动整理笔记

这个流程耗时的核心不是工具不够强，而是**人脑需要在几十个上下文之间来回切换，而且每一步的输出都是非结构化的文本**。rea 想解决的就是这个：把这整条链路用 AI Agent 串起来，让 LLM 驱动整个分析过程，人只需要提目标和问题。

## 架构大概长这样

rea 用了 [Cordis](https://github.com/cordis-lib/cordis) 做插件架构，把每个分析能力封装成独立的 `dsh-plugin`。核心流程是：

```
用户输入 → Agent（Claude / Codex） → MCP 工具调用 → 各类分析插件 → 结果聚合 → 输出
```

它暴露了一批 MCP（Model Context Protocol）工具，Agent 可以按需调用：

```typescript
// 大概是这种感觉（根据 topics 和文档推测）
const tools = [
  {
    name: "decompile_function",
    description: "用 Ghidra 反编译指定地址的函数，返回伪代码",
    inputSchema: {
      binary_path: "string",
      address: "string"  // 十六进制地址，如 0x401000
    }
  },
  {
    name: "find_xrefs",
    description: "查找对某个函数或地址的所有引用",
    inputSchema: {
      binary_path: "string",
      target: "string"
    }
  },
  {
    name: "run_frida_script",
    description: "附加到进程并运行 Frida 脚本，返回运行时输出",
    inputSchema: {
      pid_or_name: "string",
      script: "string"
    }
  },
  {
    name: "analyze_network_traffic",
    description: "抓包并分析应用网络请求的特征",
    inputSchema: {
      target: "string",
      duration_seconds: "number"
    }
  }
]
```

MCP 协议本身前段时间写过一篇（[MCP 协议深度解析](./mcp-protocol-in-depth.md)），这里就不展开了。简单说就是 LLM 和外部工具通信的标准接口，现在 Claude 原生支持，Claude Code 里用起来很顺手。

## 实际跑起来是什么感觉

根据 README 和 issue 里的演示，一个典型的使用场景大概是这样：

**目标**：分析一个不知道来源的 macOS 程序，搞清楚它到底在往哪发数据。

你输入的 prompt 可能就是一句话：

```
分析 /Applications/SuspiciousApp.app，找出它所有的网络请求目标，
重点看有没有把本地文件发出去的行为。
```

然后 Agent 自己决定：

1. 先静态分析 binary，找 `URLSession` / `libcurl` 相关调用
2. 用 Ghidra 插件反编译可疑函数，理解数据构造逻辑
3. 动态 hook 网络相关 API，记录实际发包内容
4. 汇总整理，给出结论和可疑代码片段的位置

这种把「分析链路」变成「对话」的思路，跟 Cursor 把「写代码」变成「对话」是同一个路数。

## 一些值得注意的地方

**Ghidra 集成**

rea 调 Ghidra 不是直接起 GUI，而是用 Ghidra 的 headless 模式跑分析脚本，把结果序列化后返回给 Agent。这样的好处是可以无人值守批量分析，坏处是 Ghidra headless 本身就有一堆坑，第一次配环境比较花时间。

需要有 Java 环境，Ghidra 路径要配对：

```bash
# rea 大概需要这样配
export GHIDRA_HOME=/path/to/ghidra_11.x
export JAVA_HOME=/path/to/jdk-21
```

**关于准确性**

LLM 分析二进制的准确性肯定不能跟经验丰富的安全研究员比。它的价值更多在于：

- 快速给出「这段代码可能在做什么」的初步判断
- 自动化处理重复性工作（找字符串、追引用链）
- 把分析过程变成可以追溯的对话记录

高价值漏洞挖掘还是得靠人，但 rea 能把前期探索时间压缩不少。

**TypeScript 写的 CLI**

整个工具链是 TypeScript 写的，对前端来说门槛低一些，改起来也方便。插件体系用了 Cordis 的依赖注入，想自己扩展分析能力（比如接一个自己的反编译器）理论上改动量不大。

## 还能做什么

除了二进制分析，rea 的 topics 里有 `touhou`，issue 里也有人拿它做游戏逆向（拆封包格式、分析游戏资源加密）。本质上只要能写插件接进去的分析工具，理论上都可以。

还有人在 issue 里讨论接 Hopper（macOS 下的反汇编器），以及支持 Android APK 分析（smali + jadx），目前看起来在规划里但还没合入。

---

总体感觉，rea 思路是对的——逆向工程里真正慢的不是工具，是「理解」这个步骤，而这恰好是 LLM 目前比较擅长的。工程成熟度上还有些粗糙，但作为一个框架级的工具来用，值得关注。感兴趣的话可以搜一下，项目还挺活跃的。
