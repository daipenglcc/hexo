---
title: 体验了一下 Generative UI：前端开发的一点新变化
date: 2026-07-16 16:40:00
tags:
  - 前端架构
  - Generative UI
  - React
  - AI
categories: 前端工程化
---

平时写前端，大家习惯的都是“状态驱动视图”那一套：产品出原型，后端给接口，前端调接口拼组件。但最近体验了一下所谓的 Generative UI（生成式 UI），感觉交互方式确实有了一些变化。

以前的 AI 对话框，你问它机票，它给你吐一堆纯文本。现在通过 Generative UI，AI 可以直接返回一个可点击、可交互的前端组件。这里简单记录一下我测试这套方案的感受。

<!-- more -->

## 实际效果是怎样的？

普通的对话式 AI，你问它问题，它只能在 Markdown 框里给你列一堆字。比如查询航班，给你一条条列出来，看着其实挺费劲的，也没法直接操作。

Generative UI 的逻辑是，让模型在后台调用接口，然后直接给你扔一个 React 组件出来。

```text
【以前的体验】
User: "帮我查明天去上海的高铁"
AI:  "G101 次，08:00 出发，二等座 553 元..." (纯文本)

【Generative UI 体验】
User: "帮我查明天去上海的高铁"
AI:   (直接渲染出一个像携程一样的卡片，能看到余票，还能直接点按钮预订)
```

## 用 Next.js 简单跑了个 Demo

目前比较成熟的方案是用 Next.js 配合 Vercel AI SDK。我照着文档试着写了一个。

### 服务端部分

核心思路是在服务端把模型的工具调用和 React 组件绑定起来：

```javascript
// app/actions.tsx
'use server';

import { createAI, streamUI } from 'ai/rsc';
import { openai } from '@ai-sdk/openai';
import { z } from 'zod';
import { FlightCard } from '@/components/flight-card';
import { FlightSkeleton } from '@/components/flight-skeleton';

export async function submitUserMessage(userInput) {
  'use server';

  const ui = await streamUI({
    model: openai('gpt-4o'),
    prompt: userInput,
    system: '你是一名专业的差旅助手。当用户查询航班时，调用 searchFlights 工具展示交互卡片。',
    text: ({ content }) => <div>{content}</div>,
    tools: {
      searchFlights: {
        description: '查询航班信息并展示交互卡片',
        parameters: z.object({
          from: z.string().describe('出发城市'),
          to: z.string().describe('目的城市'),
          date: z.string().describe('出发日期，格式 YYYY-MM-DD'),
        }),
        // 请求还没回来的时候，先展示个骨架屏
        loading: () => <FlightSkeleton />,
        // 拿到数据后，直接渲染组件
        generate: async ({ from, to, date }) => {
          const flightData = await fetchFlightsFromDB(from, to, date);
          return (
            <FlightCard
              from={from}
              to={to}
              date={date}
              flights={flightData}
            />
          );
        },
      },
    },
  });

  return {
    id: Date.now(),
    display: ui.value,
  };
}
```

### 客户端部分

前端拿到的直接就是渲染好的 `FlightCard`，这个组件自己本身可以带着点击事件、内部状态：

```javascript
// components/flight-card.tsx
'use client';

import React, { useState } from 'react';

export function FlightCard({ from, to, date, flights }) {
  const [selectedFlight, setSelectedFlight] = useState(null);

  return (
    <div className="rounded-xl border border-slate-200 bg-white p-4 shadow-sm my-3">
      <div className="flex items-center justify-between pb-3 border-b border-slate-100">
        <span className="font-semibold text-slate-800">{from} ✈️ {to}</span>
        <span className="text-xs text-slate-500">{date}</span>
      </div>

      <div className="mt-3 space-y-2">
        {flights.map((f) => (
          <div
            key={f.id}
            className={`flex items-center justify-between p-3 rounded-lg cursor-pointer transition ${
              selectedFlight === f.id ? 'bg-blue-50 border border-blue-400' : 'bg-slate-50 hover:bg-slate-100'
            }`}
            onClick={() => setSelectedFlight(f.id)}
          >
            <div>
              <span className="font-medium text-slate-900">{f.flightNo}</span>
            </div>
            <div className="flex items-center gap-3">
              <span className="font-bold text-amber-600">¥{f.price}</span>
              <button
                className="px-3 py-1 bg-blue-600 text-white text-xs rounded"
                onClick={(e) => {
                  e.stopPropagation();
                  alert(`已预订 ${f.flightNo}！`);
                }}
              >
                预订
              </button>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
```

## 踩坑体会：一些不太好处理的地方

虽然看着挺顺的，但真要往项目里塞，还是会遇到几个比较头疼的问题：

1. **状态有点乱**：一边是 AI 的对话历史流，一边是组件本身的内部状态（比如你有没有点那个预订按钮），还有全局的业务状态（购物车、登录态）。一不小心就容易把组件状态传丢，或者让 AI 记串了上下文。
2. **页面容易抖**：大模型反应稍微慢一点，页面上就会出现好几秒的空白或骨架屏。等组件突然渲染出来，页面就会猛地跳动一下，体验不是很好。
3. **模型抽风（幻觉）**：有时候模型会传过来一些奇奇怪怪的参数。所以一定要用像 Zod 这种库把好关，不然参数一错，页面直接白屏，那就尴尬了。

## 简单总结

Generative UI 提供了一种新的交互形式，确实比纯文本看起来舒服很多。对于前端来说，以后除了切图、写逻辑，可能还得稍微了解下怎么把这些组件和 AI 的接口对接好。感兴趣的可以自己拉个 Demo 跑跑看，感觉还行，但离完全普及估计还得看各大框架的进一步支持。
