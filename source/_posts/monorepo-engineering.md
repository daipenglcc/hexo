---
title: 大前端时代的 Monorepo 工程化实践
date: 2023-09-08 15:40:22
tags:
  - Monorepo
  - pnpm
  - 前端工程化
categories: 前端工程化
---

随着业务增长，前端项目往往会拆分出多个子应用、组件库、工具库和配置包。传统的多仓库（Polyrepo）管理方式带来了版本同步困难、代码复用成本高等问题。Monorepo（单一仓库管理多个项目）成为越来越多团队的选择。本文以 pnpm workspace 为核心，记录 Monorepo 工程化的实践方案。

<!-- more -->

## 为什么选择 Monorepo

| 维度 | Polyrepo（多仓库） | Monorepo（单仓库） |
| :--- | :--- | :--- |
| 代码复用 | 需要发布 npm 包后引用 | 直接 workspace 引用 |
| 版本管理 | 各仓库独立版本 | 统一管控，保持同步 |
| 原子提交 | 跨仓库改动需多次 PR | 一次 PR 覆盖所有改动 |
| 工具链 | 每个仓库独立配置 | 统一 ESLint / TS / 构建配置 |
| CI/CD | 每个仓库独立流水线 | 统一流水线，按变更触发 |
| 上手成本 | 低 | 需要一定的工程化基础 |

## 1. 项目结构

```
my-monorepo/
├── package.json           # 根配置
├── pnpm-workspace.yaml    # 工作空间声明
├── turbo.json             # Turborepo 构建配置
├── .eslintrc.js           # 统一 ESLint 配置
├── tsconfig.base.json     # 统一 TypeScript 基础配置
├── packages/
│   ├── ui/                # 公共组件库
│   │   ├── package.json
│   │   ├── src/
│   │   └── tsconfig.json
│   ├── utils/             # 公共工具库
│   │   ├── package.json
│   │   └── src/
│   └── config/            # 共享配置（ESLint、TS 等）
│       └── package.json
├── apps/
│   ├── web/               # 主站应用
│   │   ├── package.json
│   │   └── src/
│   ├── admin/             # 后台管理
│   │   ├── package.json
│   │   └── src/
│   └── docs/              # 文档站点
│       ├── package.json
│       └── src/
└── scripts/               # 自动化脚本
```

## 2. pnpm Workspace 配置

```yaml
# pnpm-workspace.yaml
packages:
  - 'packages/*'
  - 'apps/*'
```

```json
// 根目录 package.json
{
  "name": "my-monorepo",
  "private": true,
  "scripts": {
    "dev": "turbo run dev",
    "build": "turbo run build",
    "lint": "turbo run lint",
    "clean": "turbo run clean && rm -rf node_modules"
  },
  "devDependencies": {
    "turbo": "^1.10.0",
    "typescript": "^5.0.0"
  }
}
```

## 3. 创建共享工具包

```json
// packages/utils/package.json
{
  "name": "@my/utils",
  "version": "1.0.0",
  "main": "./src/index.ts",
  "types": "./src/index.ts",
  "scripts": {
    "build": "tsup src/index.ts --format cjs,esm --dts",
    "lint": "eslint src/"
  }
}
```

```typescript
// packages/utils/src/index.ts
export function formatDate(date: Date | string, format = 'YYYY-MM-DD'): string {
  const d = new Date(date)
  const year = d.getFullYear()
  const month = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')

  return format
    .replace('YYYY', String(year))
    .replace('MM', month)
    .replace('DD', day)
}

export function debounce<T extends (...args: any[]) => any>(
  fn: T,
  delay: number
): (...args: Parameters<T>) => void {
  let timer: ReturnType<typeof setTimeout>
  return function (this: any, ...args: Parameters<T>) {
    clearTimeout(timer)
    timer = setTimeout(() => fn.apply(this, args), delay)
  }
}

export function deepClone<T>(obj: T): T {
  return structuredClone(obj)
}
```

## 4. 创建共享 UI 组件库

```json
// packages/ui/package.json
{
  "name": "@my/ui",
  "version": "1.0.0",
  "main": "./src/index.ts",
  "types": "./src/index.ts",
  "dependencies": {
    "vue": "^3.3.0"
  },
  "scripts": {
    "build": "vite build",
    "lint": "eslint src/"
  }
}
```

```vue
<!-- packages/ui/src/components/Button/Button.vue -->
<script setup lang="ts">
interface Props {
  type?: 'primary' | 'secondary' | 'danger'
  size?: 'small' | 'medium' | 'large'
  loading?: boolean
  disabled?: boolean
}

withDefaults(defineProps<Props>(), {
  type: 'primary',
  size: 'medium',
  loading: false,
  disabled: false
})

defineEmits<{
  click: [event: MouseEvent]
}>()
</script>

<template>
  <button
    :class="['btn', `btn--${type}`, `btn--${size}`]"
    :disabled="disabled || loading"
    @click="$emit('click', $event)"
  >
    <span v-if="loading" class="btn__spinner" />
    <slot />
  </button>
</template>
```

## 5. 在应用中引用内部包

```json
// apps/web/package.json
{
  "name": "@my/web",
  "private": true,
  "dependencies": {
    "@my/ui": "workspace:*",
    "@my/utils": "workspace:*",
    "vue": "^3.3.0"
  }
}
```

```bash
# pnpm 安装 workspace 内部依赖
pnpm add @my/utils --filter @my/web
```

```vue
<!-- apps/web/src/App.vue -->
<script setup>
import { Button } from '@my/ui'
import { formatDate } from '@my/utils'

const today = formatDate(new Date())
</script>

<template>
  <div>
    <p>今天是 {{ today }}</p>
    <Button type="primary" @click="handleClick">点击</Button>
  </div>
</template>
```

## 6. Turborepo 构建编排

Turborepo 提供了增量构建和并行执行能力：

```json
// turbo.json
{
  "$schema": "https://turbo.build/schema.json",
  "pipeline": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": ["dist/**"]
    },
    "dev": {
      "cache": false,
      "persistent": true
    },
    "lint": {
      "outputs": []
    },
    "clean": {
      "cache": false
    }
  }
}
```

```bash
# 常用命令
pnpm turbo run build                    # 构建所有包（增量 + 并行）
pnpm turbo run build --filter=@my/web   # 只构建指定包
pnpm turbo run dev --filter=@my/web     # 启动指定应用的开发服务
pnpm turbo run lint                     # 全量 lint
```

## 7. 统一配置管理

### TypeScript 配置继承

```json
// tsconfig.base.json（根目录）
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true
  }
}
```

```json
// packages/utils/tsconfig.json
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": {
    "outDir": "./dist"
  },
  "include": ["src"]
}
```

## 8. pnpm 常用命令

```bash
# 安装所有包的依赖
pnpm install

# 给根目录添加开发依赖
pnpm add -Dw turbo

# 给指定包添加依赖
pnpm add axios --filter @my/web

# 给所有包执行脚本
pnpm -r run build

# 查看包之间的依赖关系
pnpm ls -r --depth 0
```

Monorepo 的初始搭建成本虽然比单项目要高，但随着项目规模和团队人数的增长，它在代码复用、版本管理和开发体验上的优势会越来越明显。
