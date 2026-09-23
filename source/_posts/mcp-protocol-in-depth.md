---
title: 试了一下 MCP 协议：给 AI 写个本地工具
date: 2026-03-12 11:15:30
tags:
  - AI
  - MCP
  - 架构设计
  - TypeScript
categories: AI
---

最近大家都在折腾 AI 应用，以前想给大模型接点外部数据（比如读个本地数据库、查个文件），得在各种框架里自己写一堆胶水代码。直到后来 MCP（Model Context Protocol）慢慢成了标准，感觉这套东西有点像给 AI 装了个“USB 接口”。

这周末抽空研究了一下，顺手用 TypeScript 写了个简单的 MCP Server，能让大模型直接去查本地的 SQLite 数据库。这里简单记录一下整个过程。

<!-- more -->

## MCP 大概是个啥

Model Context Protocol 是 Anthropic 搞出来的一套开源标准，现在像 Cursor、Claude Desktop 这些工具基本都支持了。

以前的痛点是，你在 Cursor 里写了个查数据库的插件，换到 Claude 桌面版里就没法用了，得重新搞一套。有了 MCP，你只要按标准写个 Server，这些客户端就能即插即用。

```text
┌────────────────────────────────────────┐
│  AI 客户端 (MCP Host / Client)         │
│  (Claude Desktop / Cursor / 等等)      │
└──────────────────┬─────────────────────┘
                   │ MCP 协议 (STDIO / SSE)
┌──────────────────▼─────────────────────┐
│  MCP Server (提供服务与能力)           │
│  ├─ Resources (文件、日志、数据库表)   │
│  ├─ Tools     (增删改查、执行脚本、调用API)│
│  └─ Prompts   (预置专业工作流提示词)   │
└────────────────────────────────────────┘
```

## MCP 的三个核心部分

按协议规范，服务端提供的能力大概分成三块：

| 模块 | 是干嘛的 | 一般用来做啥 |
| :--- | :--- | :--- |
| **Resources** | 给数据提供只读访问 | 让 AI 直接把本地文件、表结构当成上下文阅读 |
| **Tools** | 定义一些可以执行的函数 | 允许 AI 执行外部动作，比如跑 SQL、调 API |
| **Prompts** | 预设一些交互模板 | 存一些常用的提示词（比如 Code Review 模版） |

通信方式目前比较常见的是通过 STDIO（标准输入输出）直接调起子进程，这种在本地跑非常快，也省去了鉴权的麻烦。

## 动手写个 SQLite 的 MCP Server

下面是我用官方的 `@modelcontextprotocol/sdk` 和 `zod` 撸的一个简单 Server，目的是让 AI 能够安全地查询本地 SQLite 数据库。

### 1. 搞定依赖

```bash
mkdir mcp-sqlite-server
cd mcp-sqlite-server
npm init -y
npm install @modelcontextprotocol/sdk zod better-sqlite3
npm install -D typescript @types/node @types/better-sqlite3 tsx
npx tsc --init
```

`tsconfig.json` 里记得配好模块解析：
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

### 2. 核心代码

建一个 `src/index.ts`，主要是把 Resources 和 Tools 注册进去：

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

// 初始化本地数据库测试
const db = new Database("app.db");
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

const server = new Server(
  { name: "local-sqlite-inspector", version: "1.0.0" },
  { capabilities: { resources: {}, tools: {} } }
);

// 注册 Resources：把数据库表结构暴露出去
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
      contents: [{ uri: request.params.uri, mimeType: "text/plain", text: schemaText }],
    };
  }
  throw new Error("Resource not found");
});

// 注册 Tools：提供一个只读的 SQL 查询工具
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
            sql: { type: "string", description: "只读 SELECT 语句" },
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

    // 简单拦截一下，防止乱改数据
    const trimmed = sql.trim().toLowerCase();
    if (!trimmed.startsWith("select") && !trimmed.startsWith("explain")) {
      return {
        isError: true,
        content: [{ type: "text", text: "拦截：只能执行 SELECT" }],
      };
    }

    try {
      const rows = db.prepare(sql).all();
      return { content: [{ type: "text", text: JSON.stringify(rows, null, 2) }] };
    } catch (err: any) {
      return { isError: true, content: [{ type: "text", text: `报错了: ${err.message}` }] };
    }
  }
  throw new Error(`Tool not found: ${request.params.name}`);
});

// 启动
async function run() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("Local SQLite MCP Server 跑起来了");
}

run().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
```

有个坑需要注意：用 STDIO 通信的时候，**日志必须用 `console.error` 打到标准错误流**。如果用 `console.log`，会干扰正常的 JSON-RPC 通信，直接报错崩溃。

## 连上客户端试一试

写完之后，我在 Claude Desktop 的配置文件 `claude_desktop_config.json` 里加了这段：

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

重启客户端，直接在输入框里提问：
> *"请先读取 sqlite://schema 了解有哪些表，然后告诉我系统里有哪些角色的用户？"*

它真的顺着去读了结构，自己组装了 `SELECT role, count(*) FROM users GROUP BY role` 去跑工具，感觉还挺顺的。

## 一点体会

写完这个 Demo，最大的感触是安全问题。把工具开放给 AI 的时候，权限控制一定要做得死死的。如果是线上的敏感数据，最好能在调用前加个二次确认。

总体来说 MCP 降低了接外部工具的门槛，感兴趣的朋友可以抽空写个小工具接进去玩玩。
