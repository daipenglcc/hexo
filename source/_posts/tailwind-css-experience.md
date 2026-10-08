---
title: Tailwind CSS 写了半年，说说真实感受
date: 2021-06-22 09:50:22
tags:
  - CSS
  - Tailwind CSS
  - 前端
categories: CSS3
---

之前一直是手写 CSS 或者用 Sass 的，看到 Tailwind 流行起来后一直没尝试。总觉得在 HTML 里堆一堆 `class="flex items-center justify-between px-4 py-2 bg-gray-100"` 这种代码，跟当年的行内样式有啥区别？后来新项目 leader 说用 Tailwind，我才硬着头皮上了。用了半年下来，嗯……真香。

<!-- more -->

## 1. 装起来

以 Vite + Vue 3 项目为例：

```bash
npm install -D tailwindcss postcss autoprefixer
npx tailwindcss init -p
```

会生成 `tailwind.config.js` 和 `postcss.config.js` 两个文件。

配一下扫描路径：

```javascript
// tailwind.config.js
module.exports = {
  content: [
    './index.html',
    './src/**/*.{vue,js,ts,jsx,tsx}',
  ],
  theme: {
    extend: {},
  },
  plugins: [],
}
```

在主 CSS 文件里引入：

```css
/* src/styles/main.css */
@tailwind base;
@tailwind components;
@tailwind utilities;
```

就这样，能用了。

## 2. 日常高频用到的

### 布局

```html
<!-- Flex 居中 -->
<div class="flex items-center justify-center h-screen">
  <p>我居中了</p>
</div>

<!-- 常见的左右布局 -->
<div class="flex">
  <aside class="w-60">侧边栏</aside>
  <main class="flex-1">主内容</main>
</div>

<!-- Grid 网格 -->
<div class="grid grid-cols-3 gap-4">
  <div>1</div>
  <div>2</div>
  <div>3</div>
</div>
```

### 间距和尺寸

Tailwind 的数字对应 `0.25rem` 的倍数：`p-4` = `padding: 1rem`，`mt-2` = `margin-top: 0.5rem`。

```html
<div class="p-4 m-2">padding 1rem, margin 0.5rem</div>
<div class="px-6 py-3">水平 padding 大，垂直 padding 小</div>
<div class="w-full max-w-lg mx-auto">最大宽度 + 水平居中</div>
```

### 响应式

这个确实比写 media query 方便多了：

```html
<!-- 手机一列，平板两列，桌面三列 -->
<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
  <div>卡片1</div>
  <div>卡片2</div>
  <div>卡片3</div>
</div>

<!-- 手机上隐藏侧边栏 -->
<aside class="hidden md:block w-60">侧边栏</aside>
```

断点默认是：`sm:640px`、`md:768px`、`lg:1024px`、`xl:1280px`。

### 颜色和样式

```html
<button class="bg-blue-500 hover:bg-blue-600 text-white font-bold py-2 px-4 rounded">
  按钮
</button>

<div class="bg-white shadow-md rounded-lg p-6">
  一个卡片
</div>

<p class="text-gray-500 text-sm">灰色小字</p>
```

## 3. 之前的疑虑和现在的看法

### "这不就是行内样式吗？"

一开始确实这么觉得。但实际用下来，Tailwind 跟行内样式有本质区别：
- 有设计系统约束（颜色、间距、字号都是预设好的），不会写出 `padding: 13px` 这种奇葩数值
- 支持响应式、hover、focus 等伪类状态
- 有 `@apply` 可以提取公共样式

### "HTML 不会很难看吗？"

确实会长一些。但搭配 Vue 组件化之后其实还好，一个组件也就那么大。而且省去了命名 CSS 类的心智负担——以前给一个容器 div 起名叫 `.wrapper`、`.container`、`.box`、`.content`，能想半天。

### "团队协作会不会乱？"

我觉得反而比传统 CSS 更统一。因为大家都用同一套 token，不会出现"你写 `#333` 我写 `#3a3a3a`"这种问题。

## 4. 几个提升效率的技巧

### @apply 提取公共样式

重复的类组合可以用 `@apply` 收拢到一个 class 里：

```css
/* 在 CSS 文件里 */
.btn-primary {
  @apply bg-blue-500 hover:bg-blue-600 text-white font-bold py-2 px-4 rounded;
}
```

但官方建议少用这个，因为用多了就失去了 Tailwind 的意义。

### VS Code 插件

装个 `Tailwind CSS IntelliSense` 插件，写类名的时候有自动补全和预览，不然全靠记忆太痛苦了。

### 自定义 theme

```javascript
// tailwind.config.js
module.exports = {
  theme: {
    extend: {
      colors: {
        brand: {
          light: '#e0f2fe',
          DEFAULT: '#0284c7',
          dark: '#075985',
        }
      },
      spacing: {
        '18': '4.5rem',
      }
    }
  }
}
```

然后就能用 `bg-brand`、`text-brand-dark`、`p-18` 了。

## 5. 不太适合的场景

- **复杂动画**：Tailwind 有些简单的 transition 和 animation 工具类，但复杂动画还是得自己写 CSS
- **深度定制已有组件库样式**：比如你要大量覆盖 ElementUI 的样式，Tailwind 帮不上太多忙
- **老项目迁移**：已有大量 CSS 的项目，混着用会很别扭

## 6. 总结

写了半年 Tailwind 的真实感受：

- **开发速度**确实快了，尤其是搭页面布局的时候，边看设计稿边写，不用跳来跳去找 CSS 文件
- **一致性**好了，整个项目的间距、颜色、圆角都有约束
- **维护**也简单了，删组件就是删模板，不用担心"这个 CSS 类还有别的地方在用吗"

最大的代价是上手需要记一堆类名，前两周会比较痛苦。过了那个阶段后，效率确实起飞了。
