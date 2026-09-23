---
title: 前端折腾 Monorepo (pnpm + Turbo) 的一些实践
date: 2023-09-08 15:40:22
tags:
  - Monorepo
  - pnpm
  - 前端工程化
categories: 前端工程化
---

现在做个稍微大点的前端项目，动不动就得拆出几个管理后台、C端项目，还有一堆大家都要用的组件库和工具函数。以前把它们分开建在好几个仓库里，每次改个公共函数，都得发个 npm 包，然后再去各个项目里跑一遍 update，特别心累。

后来实在受不了了，把它们全塞进了一个仓库里（Monorepo），用 `pnpm` 加上 `Turborepo` 统一管，踩了些坑但弄完确实顺畅不少。这里简单记录一下基础配置，以后开新项目直接回来抄。

<!-- more -->

## 为什么要搞 Monorepo？

以前多仓库（Polyrepo）的时候，最烦的就是版本同步。公共库改了一行代码，所有依赖它的项目都要发版。放在一起（Monorepo）后最大的感觉是：
1. **代码复用无脑**：公共包连发 npm 都不用发了，直接本地项目互相引。
2. **提交方便**：修一个跨项目的 bug，一次 Commit 直接搞定。
3. **配置统一**：TypeScript、ESLint 都在最外层配一套，下面所有项目自动继承，清爽。

## 1. 大概长什么样

把一堆项目放进一个文件夹，目录一般这么分：

```text
my-monorepo/
├── package.json           # 最外层统领全局的配置
├── pnpm-workspace.yaml    # 告诉 pnpm 哪些文件夹是子项目
├── turbo.json             # 打包加速配置
├── tsconfig.base.json     # 全局的 TS 配置
├── packages/              # 专门放大家都要用的东西
│   ├── ui/                # 自己撸的公共组件库
│   └── utils/             # 时间处理之类的小工具
└── apps/                  # 具体的业务项目
    ├── web/               # 比如 C 端的网站
    └── admin/             # 比如管理后台
```

## 2. 把 pnpm 搞起来

先在根目录建个 `pnpm-workspace.yaml`，这就相当于画了个圈：

```yaml
# 告诉它这里面的都是兄弟项目，大家有福同享
packages:
  - 'packages/*'
  - 'apps/*'
```

最外层的 `package.json` 别忘了加句 `"private": true`，免得一不小心把整个空壳项目发布到了 npm。

## 3. 写个公共库试试

比如写个工具库，在 `packages/utils/package.json` 给它起个名：

```json
{
  "name": "@my/utils",
  "version": "1.0.0",
  "main": "./src/index.ts"
}
```

里面随便写个公用方法，比如 `export const formatTime = ...`。

## 4. 业务项目怎么去用它？

到了重头戏。比如我在 `apps/web/package.json` 这个项目里想用上面那个工具库，直接这么配：

```json
{
  "name": "@my/web",
  "dependencies": {
    "@my/utils": "workspace:*"
  }
}
```

注意那个 `workspace:*`，这就是 pnpm 厉害的地方，它不会去 npm 上找，而是直接在这个大仓库里把那个工具库通过软链接牵过来。

要是嫌手敲麻烦，也能直接跑命令加依赖：
```bash
# 意思就是把 @my/utils 装到 @my/web 里面去
pnpm add @my/utils --filter @my/web
```

然后代码里直接 `import { formatTime } from '@my/utils'` 就能跑了，体验丝滑。

## 5. 加个 Turborepo 提速

项目一多，要在外层跑一键打包，如果是一个个挨着构建，时间能把人等死。Turborepo 就是干这个的，它会自己看哪个包依赖哪个包，然后并行开干，没改动的包就直接走缓存。

在最外层弄个 `turbo.json`：

```json
{
  "$schema": "https://turbo.build/schema.json",
  "pipeline": {
    "build": {
      "dependsOn": ["^build"], // 这个符号 ^ 意思是先打包它依赖的库，再打包自己
      "outputs": ["dist/**"]
    },
    "dev": {
      "cache": false, // 开发模式不缓存
      "persistent": true
    }
  }
}
```

平时干活就敲这两个命令：
```bash
pnpm turbo run build                    # 一键打包所有能打包的项目
pnpm turbo run dev --filter=@my/web     # 只把 web 这个项目跑起来开发
```

## 6. TS 配置的继承

如果在每个项目下都写一个几百行的 `tsconfig.json` 会疯掉的。一般的搞法是在最外面写一个基础版本：

```json
// 根目录的 tsconfig.base.json
{
  "compilerOptions": {
    "strict": true,
    "esModuleInterop": true
  }
}
```

然后到各个子项目里面去“继承”它，加点自己特有的东西就行了：

```json
// apps/web/tsconfig.json
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": {
    "outDir": "./dist"
  }
}
```

## 随便总结两句

折腾这一套，第一次搭架子的时候确实有点繁琐，各种配置容易报错。但搭完之后再去开新项目、抽离公共代码，速度会快得多。对于平时喜欢瞎写各种配套周边小项目的人来说，这种“全部装在一个大桶里”的模式感觉刚刚好。
