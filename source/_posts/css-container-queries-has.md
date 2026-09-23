---
title: CSS 新特性实战：Container Queries 与 :has() 选择器
date: 2022-10-12 11:25:40
tags:
  - CSS
  - 前端
categories: CSS3
---

2022 年 CSS 迎来了几个重量级新特性的落地支持。其中 Container Queries（容器查询）和 `:has()` 选择器是最值得关注的两个，它们分别解决了响应式设计和选择器能力上的长期痛点。本文通过实际案例演示这些新特性的用法。

<!-- more -->

## 一、Container Queries（容器查询）

### 问题背景

传统的 Media Queries 基于**视口（viewport）**宽度来做响应式布局，但组件并不总是占满整个视口。一个卡片组件在侧边栏中只有 300px 宽，和在主内容区 800px 宽时，应该有不同的布局方式——这正是 Container Queries 要解决的问题。

### 基本用法

```css
/* 1. 声明容器 */
.card-wrapper {
  container-type: inline-size;  /* 基于内联方向（宽度）的容器查询 */
  container-name: card;         /* 可选：命名容器 */
}

/* 简写 */
.card-wrapper {
  container: card / inline-size;
}

/* 2. 基于容器宽度编写响应式样式 */
.card {
  display: grid;
  gap: 1rem;
  padding: 1rem;
}

/* 容器宽度 >= 400px 时，改为水平布局 */
@container card (min-width: 400px) {
  .card {
    grid-template-columns: 200px 1fr;
  }
}

/* 容器宽度 >= 700px 时，进一步调整 */
@container card (min-width: 700px) {
  .card {
    grid-template-columns: 250px 1fr auto;
  }

  .card__title {
    font-size: 1.5rem;
  }
}
```

```html
<div class="card-wrapper">
  <article class="card">
    <img class="card__cover" src="cover.jpg" alt="" />
    <div class="card__body">
      <h3 class="card__title">文章标题</h3>
      <p class="card__summary">文章摘要内容...</p>
    </div>
    <div class="card__meta">
      <span>2022-10-12</span>
      <span>128 阅读</span>
    </div>
  </article>
</div>
```

### 容器查询单位

Container Queries 还引入了一组新的单位：

```css
.card__title {
  /* cqw: 容器宽度的 1% */
  font-size: clamp(1rem, 3cqw, 2rem);
}

.card__cover {
  /* cqi: 容器内联尺寸的 1% */
  width: 30cqi;
}
```

| 单位 | 含义 |
| :--- | :--- |
| `cqw` | 容器宽度的 1% |
| `cqh` | 容器高度的 1% |
| `cqi` | 容器内联方向尺寸的 1% |
| `cqb` | 容器块方向尺寸的 1% |
| `cqmin` | `cqi` 和 `cqb` 中较小的值 |
| `cqmax` | `cqi` 和 `cqb` 中较大的值 |

### 实际场景：Dashboard 卡片

```css
.dashboard-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 1.5rem;
}

.stat-card-container {
  container: stat / inline-size;
}

.stat-card {
  padding: 1.5rem;
  border-radius: 12px;
  background: white;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
}

/* 窄容器：垂直布局 */
.stat-card .stat-value {
  font-size: 2rem;
  font-weight: 700;
}

/* 宽容器：水平展示更多信息 */
@container stat (min-width: 350px) {
  .stat-card {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }

  .stat-card .stat-chart {
    display: block;  /* 空间足够时显示迷你图表 */
    width: 120px;
  }
}
```

## 二、:has() 选择器（父元素选择器）

### 问题背景

CSS 长期以来只能从父元素向子元素选择，无法根据子元素的状态反选父元素。`:has()` 被称为"CSS 中缺失的最后一块拼图"，它可以根据后代、兄弟元素的存在或状态来选择元素。

### 基本用法

```css
/* 选中包含 img 子元素的 .card */
.card:has(img) {
  grid-template-columns: 200px 1fr;
}

/* 选中不包含 img 的 .card */
.card:not(:has(img)) {
  grid-template-columns: 1fr;
}

/* 选中包含 .badge 的导航项 */
.nav-item:has(.badge) {
  font-weight: bold;
}
```

### 实战案例

#### 1. 表单验证视觉反馈

```css
/* 当输入框处于无效状态时，整个表单组高亮 */
.form-group:has(input:invalid) {
  border-left: 3px solid #e74c3c;
  background-color: #fef2f2;
}

/* 当输入框获得焦点时，高亮整个组 */
.form-group:has(input:focus) {
  border-left: 3px solid #3498db;
  background-color: #eff6ff;
}

/* 当复选框被选中时，改变父容器样式 */
.option-card:has(input[type="checkbox"]:checked) {
  border-color: #3498db;
  background-color: #eff6ff;
  box-shadow: 0 0 0 2px rgba(52, 152, 219, 0.3);
}
```

#### 2. 根据内容自适应布局

```css
/* 文章列表：有封面图时使用双栏布局 */
.article-item:has(.cover-image) {
  display: grid;
  grid-template-columns: 200px 1fr;
  gap: 1rem;
}

/* 没有封面图时，正常单栏 */
.article-item:not(:has(.cover-image)) {
  display: block;
}

/* 侧边栏有内容时，主区域缩窄 */
.page-layout:has(.sidebar:not(:empty)) {
  grid-template-columns: 1fr 300px;
}
```

#### 3. 交互增强

```css
/* 当下拉菜单展开时，给触发按钮添加样式 */
.dropdown:has(.menu[open]) .dropdown-trigger {
  background-color: #f0f0f0;
  border-bottom-left-radius: 0;
  border-bottom-right-radius: 0;
}

/* 当表格行有被选中的复选框时 */
tr:has(input[type="checkbox"]:checked) {
  background-color: #e8f4fd;
}

/* figure 包含 figcaption 时添加底部间距 */
figure:has(figcaption) {
  margin-bottom: 2rem;
}
figure:not(:has(figcaption)) {
  margin-bottom: 1rem;
}
```

## 三、其他值得关注的 CSS 新特性

### Cascade Layers（@layer）

控制样式的优先级层次，解决大型项目中的样式冲突：

```css
/* 定义层的优先级顺序（后面的优先级更高） */
@layer reset, base, components, utilities;

@layer reset {
  * { margin: 0; padding: 0; box-sizing: border-box; }
}

@layer base {
  body { font-family: 'Inter', sans-serif; }
  a { color: #3498db; }
}

@layer components {
  .btn { padding: 0.5rem 1rem; border-radius: 6px; }
}

@layer utilities {
  .mt-4 { margin-top: 1rem; }
  .hidden { display: none; }
}
```

### accent-color

一行代码美化原生表单控件的主题色：

```css
:root {
  accent-color: #3498db;
}

/* 所有 checkbox、radio、range、progress 都会自动使用这个颜色 */
```

### color-mix()

在 CSS 中直接混合颜色：

```css
.btn-primary {
  background: #3498db;
}
.btn-primary:hover {
  /* 主色混入 20% 白色 → 变亮 */
  background: color-mix(in srgb, #3498db, white 20%);
}
.btn-primary:active {
  /* 主色混入 20% 黑色 → 变暗 */
  background: color-mix(in srgb, #3498db, black 20%);
}
```

这些新特性正在被主流浏览器逐步支持，建议在新项目中积极尝试使用。
