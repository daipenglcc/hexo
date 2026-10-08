---
title: shadcn/ui + Next.js 搭了个后台管理系统
date: 2024-08-06 09:45:30
tags:
  - React
  - Next.js
  - shadcn/ui
  - 全栈
categories: React
---

最近要给一个小项目搭后台管理系统，对比了一圈方案——Ant Design Pro 太重了，用 ElementUI 又想换个口味。刷推看到好多人在安利 shadcn/ui，说它不是传统的组件库，而是直接把源码复制到你项目里，想怎么改就怎么改。正好最近在写 Next.js，就试着搭了一个。

<!-- more -->

## 1. shadcn/ui 到底是什么

先说它跟 Ant Design、ElementUI 这类组件库最大的区别：**它不是一个 npm 包**。

你不会在 `package.json` 里看到 `"shadcn-ui": "x.x.x"` 这种依赖。它的工作方式是通过 CLI 把你选的组件源代码直接拷贝到你项目的 `components/ui/` 目录下。

好处是：
- 完全可以自定义，改源码不会被升级覆盖
- 按需添加，不加的组件不存在于项目里
- 底层基于 Radix UI（无障碍做得很好）+ Tailwind CSS

坏处是：
- 跟传统组件库比，没有"升级版本自动修bug"这回事
- 需要你自己维护这些组件代码

## 2. 搭建过程

### 初始化 Next.js 项目

```bash
npx create-next-app@latest admin-dashboard --typescript --tailwind --eslint --app --src-dir
```

### 初始化 shadcn/ui

```bash
npx shadcn-ui@latest init
```

它会问你几个问题，比如用什么样式、颜色主题、CSS 变量等等。我一般选默认就行。

初始化完成后会生成：
- `components.json` — 配置文件
- `lib/utils.ts` — 一个 `cn()` 工具函数（合并 Tailwind 类名用的）

### 添加需要的组件

```bash
# 按需加，不是一次全装
npx shadcn-ui@latest add button
npx shadcn-ui@latest add table
npx shadcn-ui@latest add dialog
npx shadcn-ui@latest add form
npx shadcn-ui@latest add input
npx shadcn-ui@latest add select
npx shadcn-ui@latest add card
npx shadcn-ui@latest add dropdown-menu
npx shadcn-ui@latest add sidebar
```

每执行一个，它就往 `components/ui/` 下面放一个组件文件。打开看就是普通的 React 组件代码，想改随便改。

## 3. 搭后台布局

### 侧边栏 + 顶栏 + 内容区

```tsx
// app/layout.tsx
import { SidebarProvider, Sidebar, SidebarContent, SidebarMenu, SidebarMenuItem } from "@/components/ui/sidebar"

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  return (
    <SidebarProvider>
      <div className="flex h-screen w-full">
        <Sidebar>
          <SidebarContent>
            <SidebarMenu>
              <SidebarMenuItem>
                <a href="/dashboard">仪表盘</a>
              </SidebarMenuItem>
              <SidebarMenuItem>
                <a href="/users">用户管理</a>
              </SidebarMenuItem>
              <SidebarMenuItem>
                <a href="/orders">订单管理</a>
              </SidebarMenuItem>
            </SidebarMenu>
          </SidebarContent>
        </Sidebar>

        <main className="flex-1 overflow-auto p-6">
          {children}
        </main>
      </div>
    </SidebarProvider>
  )
}
```

### 数据表格页

```tsx
// app/users/page.tsx
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { Button } from "@/components/ui/button"

// 实际项目从接口拿，这里先写死
const users = [
  { id: 1, name: "张三", email: "zhangsan@example.com", role: "管理员" },
  { id: 2, name: "李四", email: "lisi@example.com", role: "编辑" },
  { id: 3, name: "王五", email: "wangwu@example.com", role: "普通用户" },
]

export default function UsersPage() {
  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold">用户管理</h1>
        <Button>新增用户</Button>
      </div>

      <div className="rounded-md border">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>ID</TableHead>
              <TableHead>姓名</TableHead>
              <TableHead>邮箱</TableHead>
              <TableHead>角色</TableHead>
              <TableHead>操作</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {users.map((user) => (
              <TableRow key={user.id}>
                <TableCell>{user.id}</TableCell>
                <TableCell>{user.name}</TableCell>
                <TableCell>{user.email}</TableCell>
                <TableCell>{user.role}</TableCell>
                <TableCell>
                  <Button variant="ghost" size="sm">编辑</Button>
                  <Button variant="ghost" size="sm" className="text-red-500">删除</Button>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </div>
    </div>
  )
}
```

### 弹窗表单

```tsx
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { Button } from "@/components/ui/button"
import { Label } from "@/components/ui/label"

function AddUserDialog() {
  return (
    <Dialog>
      <DialogTrigger asChild>
        <Button>新增用户</Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>新增用户</DialogTitle>
        </DialogHeader>
        <div className="space-y-4 mt-4">
          <div>
            <Label htmlFor="name">姓名</Label>
            <Input id="name" placeholder="请输入姓名" />
          </div>
          <div>
            <Label htmlFor="email">邮箱</Label>
            <Input id="email" type="email" placeholder="请输入邮箱" />
          </div>
          <Button className="w-full">提交</Button>
        </div>
      </DialogContent>
    </Dialog>
  )
}
```

## 4. 深色模式

shadcn/ui 天然支持深色模式，加个 theme provider 就行：

```bash
npm install next-themes
```

```tsx
// components/theme-provider.tsx
"use client"
import { ThemeProvider as NextThemesProvider } from "next-themes"

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  return (
    <NextThemesProvider attribute="class" defaultTheme="system">
      {children}
    </NextThemesProvider>
  )
}
```

切换按钮：

```tsx
"use client"
import { useTheme } from "next-themes"
import { Button } from "@/components/ui/button"

export function ThemeToggle() {
  const { theme, setTheme } = useTheme()
  return (
    <Button variant="ghost" onClick={() => setTheme(theme === "dark" ? "light" : "dark")}>
      {theme === "dark" ? "🌞" : "🌙"}
    </Button>
  )
}
```

深色模式下的样式效果直接就出来了，因为 Tailwind 的 `dark:` 前缀在 shadcn/ui 组件里都写好了。

## 5. 使用感受

**优点：**
- 代码在自己手里，改什么都行
- 样式统一好看，深色模式几乎零成本
- 跟 Next.js + Tailwind 配合堪称完美
- 组件质量高，Radix UI 底层的无障碍支持很好

**缺点：**
- 功能不如 Ant Design 丰富（比如没有高级表格组件：排序、筛选、分页要自己搞或者用 TanStack Table）
- 没有统一升级机制，组件有 bug 得自己去 GitHub 看改了没
- 深度绑定 Tailwind CSS，如果项目不用 Tailwind 就没法用

总的来说，如果你的技术栈是 Next.js + Tailwind + TypeScript，shadcn/ui 基本是目前最舒服的选择。做中小型的后台系统完全够用了。
