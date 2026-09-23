---
title: Model Context Protocol (MCP) 实战：构建你自己的 AI 外部工具与服务
date: 2026-03-12 11:15:30
tags:
  - AI
  - MCP
  - 架构设计
  - TypeScript
  - 效率工具
categories: AI
---

在 AI 应用爆发的初期，每个开发者想要为大模型接入外部数据或操作（如读取本地 Git 仓库、操作 MySQL 数据库、触发构建流程），都必须在各自的框架里重复实现一遍插件或 Function Calling 胶水代码。直到 2025 年末至 2026 年，**Model Context Protocol（MCP，模型上下文协议）** 迅速成为了业界事实上的统一标准。如果说各类 LLM 是现代计算的主机，那么 MCP 就相当于 AI 世界的 "USB-C" 接口规范。

本文将深入拆解 MCP 的核心架构，并带领大家用 TypeScript 从零手写一个自定义的 MCP Server，实现本地数据查询与自动化操作。

<!-- more -->

## 1. 什么是 Model Context Protocol (MCP)

Model Context Protocol 是由 Anthropic 开源、现已被 Cursor、Claude Desktop、Zed、VS Code 等主流 AI 编程与日常工具广泛支持的开放标准协议。

### 1.1 痛点与破局

在 MCP 出现前：
- Cursor 有自己的扩展系统
- Claude Desktop 有一套私有的工具调用配置
- 自建的 AI Agent 框架（如 LangChain、LlamaIndex）各有各的 Tool 抽象

这导致开发者为某一个工具编写的数据库连接插件，无法直接复用给其他 AI 客户端。而 MCP 的诞生解决了这一碎片化痛点：**只要你实现了一个标准的 MCP Server，任何支持 MCP 的客户端均可即插即用。**

```text
┌────────────────────────────────────────┐
│  AI 客户端 (MCP Host / Client)         │
│  (Claude Desktop / Cursor / Antigravity)│
└──────────────────┬─────────────────────┘
                   │ MCP 协议 (STDIO / SSE)
┌──────────────────▼─────────────────────┐
│  MCP Server (提供服务与能力)           │
│  ├─ Resources (文件、日志、数据库表)   │
│  ├─ Tools     (增删改查、执行脚本、调用API)│
│  └─ Prompts   (预置专业工作流提示词)   │
└────────────────────────────────────────┘
```

---

## 2. MCP 的三大核心构件

MCP 协议规范中将服务端提供的能力抽象为三个基本维度：

| 构件 | 角色定位 | 典型场景 |
| :--- | :--- | :--- |
| **Resources** | 数据的只读访问抽象 | 让 AI 直接把本地文件、数据库 Schema、系统日志作为上下文阅读 |
| **Tools** | 可调用的函数与行为 | 允许 AI 执行外部动作：运行 SQL、调用 REST API、发送邮件 |
| **Prompts** | 预定义的交互模板 | 帮助用户预设常用的特定提示词流程（如 Code Review、Debug 模版） |

通信机制上，MCP 支持两种主要传输层：
1. **STDIO（标准输入输出）**：客户端通过子进程直接唤起 Server，通过进程标准输入/输出进行 JSON-RPC 通信，速度快、免鉴权，非常适合本地工具。
2. **SSE / HTTP**：通过 HTTP Server-Sent Events 进行长连接通信，适合部署在远端服务器或集群中的团队级共享服务。

---

## 3. 实战：用 TypeScript 编写 SQLite 数据查询 MCP Server

接下来，我们使用官方 SDK `@modelcontextprotocol/sdk` 和 `zod`，构建一个可以让 AI 客户端安全查询本地 SQLite 数据库的 MCP Server。

### 3.1 初始化项目与依赖

```bash
mkdir mcp-sqlite-server
cd mcp-sqlite-server
npm init -y
npm install @modelcontextprotocol/sdk zod better-sqlite3
npm install -D typescript @types/node @types/better-sqlite3 tsx
npx tsc --init
```

在 `tsconfig.json` 中确保开启现代模块解析：
```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "esModuleInterop": true,
    "strict": true,
    "skipLibCheck": true
  }
}
```

### 3.2 编写 MCP Server 核心逻辑

新建 `src/index.ts`：

```typescript
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  ListResourcesRequestSchema,
  ReadResourceRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import Database from "better-sqlite3";
import { z } from "zod";

// 初始化本地数据库（此处使用内存或本地 db 文件）
const db = new Database("app.db");

// 初始化测试表
db.exec(`
  CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    role TEXT NOT NULL,
    email TEXT UNIQUE
  );
  INSERT OR IGNORE INTO users (id, name, role, email) VALUES
    (1, 'Alice', 'admin', 'alice@company.com'),
    (2, 'Bob', 'developer', 'bob@company.com'),
    (3, 'Charlie', 'tester', 'charlie@company.com');
`);

// 实例化 MCP Server
const server = new Server(
  {
    name: "local-sqlite-inspector",
    version: "1.0.0",
  },
  {
    capabilities: {
      resources: {},
      tools: {},
    },
  }
);

// 1. 注册 Resources：将数据库表结构作为只读资源暴露
server.setRequestHandler(ListResourcesRequestSchema, async () => {
  return {
    resources: [
      {
        uri: "sqlite://schema",
        name: "Database Schema",
        mimeType: "text/plain",
        description: "当前 SQLite 数据库中的所有表结构定义",
      },
    ],
  };
});

server.setRequestHandler(ReadResourceRequestSchema, async (request) => {
  if (request.params.uri === "sqlite://schema") {
    const tables = db.prepare("SELECT sql FROM sqlite_master WHERE type='table'").all();
    const schemaText = tables.map((t: any) => t.sql).join("\n\n");
    return {
      contents: [
        {
          uri: request.params.uri,
          mimeType: "text/plain",
          text: schemaText,
        },
      ],
    };
  }
  throw new Error("Resource not found");
});

// 2. 注册 Tools：提供只读 SQL 查询工具
const QuerySchema = z.object({
  sql: z.string().describe("要执行的 SQL 查询语句（必须是 SELECT 语句）"),
});

server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      {
        name: "execute_sql_query",
        description: "在本地 SQLite 数据库中执行 SELECT 只读查询",
        inputSchema: {
          type: "object",
          properties: {
            sql: {
              type: "string",
              description: "只读 SELECT 语句，禁止包含 DROP/DELETE/INSERT/UPDATE",
            },
          },
          required: ["sql"],
        },
      },
    ],
  };
});

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  if (request.params.name === "execute_sql_query") {
    const { sql } = QuerySchema.parse(request.params.arguments);

    // 安全检查：强制只读，防止破坏性指令
    const trimmed = sql.trim().toLowerCase();
    if (!trimmed.startsWith("select") && !trimmed.startsWith("explain")) {
      return {
        isError: true,
        content: [{ type: "text", text: "权限拦截：此工具只允许执行 SELECT 或 EXPLAIN 查询！" }],
      };
    }

    try {
      const rows = db.prepare(sql).all();
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify(rows, null, 2),
          },
        ],
      };
    } catch (err: any) {
      return {
        isError: true,
        content: [{ type: "text", text: `SQL 执行失败: ${err.message}` }],
      };
    }
  }

  throw new Error(`Tool not found: ${request.params.name}`);
});

### 3.3 启动并连接传输层 (STDIO)
async function run() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("Local SQLite MCP Server running on stdio");
}

run().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
```

> **注意**：由于 STDIO 传输依赖标准输出（`stdout`）传输 JSON-RPC 数据，所有的调试日志、诊断信息一律使用 `console.error` 输出到标准错误（`stderr`），否则会导致协议解析崩溃！

---

## 4. 接入客户端进行联调

在你的客户端配置文件（如 Claude Desktop 的 `claude_desktop_config.json` 或 Cursor 的 MCP 设置页面）中添加：

```json
{
  "mcpServers": {
    "sqlite-inspector": {
      "command": "npx",
      "args": [
        "-y",
        "tsx",
        "/Users/username/mcp-sqlite-server/src/index.ts"
      ]
    }
  }
}
```

配置保存后重启客户端，即可直接在对话中对 AI 提问：
> *"请先读取 sqlite://schema 了解有哪些表，然后告诉我系统里有哪些角色的用户？"*

AI 会自动发现 `sqlite://schema` 资源，并调用 `execute_sql_query` 执行 `SELECT role, count(*) FROM users GROUP BY role`，最后以人类友好的方式把分析结果展示出来。

---

## 5. MCP 开发中的安全与架构建议

1. **最小权限原则（Least Privilege）**：
   暴露给 AI 的 Tool 必须做严格的参数校验和权限收敛。涉及到写操作（如更新订单、删除数据、发送线上请求）的 Tool，建议设置 `requireConfirmation` 或在客户端配置中加入人机交互确认（Human-in-the-loop）。
2. **结构化上下文传输**：
   充分利用 MCP Resources 机制将结构体、配置规范化输出，避免把海量无关日志直接堆进单次调用中。
3. **可观测性与审计日志**：
   在 MCP Server 内部记录所有收到的 Tool 调用入参和返回结果，形成清晰的操作审计流，便于追溯。

---

## 总结

MCP 的普及标志着 AI 编程与大模型应用开发进入了标准化与模块化的新纪元。它打破了不同模型、不同开发工具之间的生态壁垒。无论未来大模型的技术底座如何演进，掌握 MCP 协议标准都将成为全栈工程师扩展系统能力、让 AI 真正深入具体业务场景的必备技能。
