---
title: 终于能用了：CSS 的容器查询和 :has() 选择器
date: 2022-10-12 11:25:40
tags:
  - CSS
  - 前端
categories: CSS3
---

以前写响应式布局，最烦的就是只能看着屏幕宽度（Viewport）来调样式。一个卡片组件放到侧边栏和主区域，还得写两套类名去控制。前阵子看文档发现 Container Queries 和 `:has()` 终于大规模支持了，试着改了下老项目的代码，感觉还挺香的。

<!-- more -->

## 一、Container Queries（容器查询）

### 以前的痛点

以前用 `@media (max-width: 768px)`，判断的是整个浏览器的宽度。但很多时候，我们只想知道“这个组件所在的容器有多宽”。比如一个商品卡片，不管屏幕多大，只要给它的坑位小于 300px，它就应该竖着排。

### 现在怎么写

先给父容器声明一下“我要监听你的尺寸”：

```css
/* 1. 声明容器 */
.card-wrapper {
  /* 监听内联方向（也就是宽度） */
  container-type: inline-size;
  /* 顺便取个名字，方便后面调用 */
  container-name: card;
}

/* 也可以简写成这样 */
.card-wrapper {
  container: card / inline-size;
}
```

然后再写卡片本身的响应式：

```css
.card {
  display: grid;
  gap: 1rem;
}

/* 当名叫 card 的容器宽度大于 400px 时，变成左右布局 */
@container card (min-width: 400px) {
  .card {
    grid-template-columns: 200px 1fr;
  }
}

/* 容器大于 700px 时，再变一下 */
@container card (min-width: 700px) {
  .card {
    grid-template-columns: 250px 1fr auto;
  }
}
```

对应的 HTML 结构大概是这样：

```html
<div class="card-wrapper">
  <article class="card">
    <img src="cover.jpg" alt="" />
    <div class="card__body">
      <h3>文章标题</h3>
    </div>
  </article>
</div>
```

除了这个，还多了几个单位，比如 `cqw`（容器宽度的 1%），用它来做字体自适应挺顺手的：

```css
.card__title {
  /* 字体大小跟着容器宽度走 */
  font-size: clamp(1rem, 3cqw, 2rem);
}
```

## 二、:has() 选择器（父元素选择器）

### 终于能从儿子选爸爸了

以前 CSS 只能顺着写 `.parent .child`，如果想实现“当里面有图片时，父容器背景变灰”，纯 CSS 是做不到的，只能写 JS 去加类名。`:has()` 算是补齐了这个短板。

### 几个顺手的场景

**1. 表单报错高亮**

如果输入框不合法，直接把外层容器标红，以前得用 JS 监听，现在一行 CSS 搞定：

```css
/* 当里面有处于 invalid 状态的 input 时 */
.form-group:has(input:invalid) {
  border-left: 3px solid #e74c3c;
  background-color: #fef2f2;
}

/* 选中了复选框，就把卡片边框变蓝 */
.option-card:has(input[type="checkbox"]:checked) {
  border-color: #3498db;
}
```

**2. 列表样式自适应**

如果文章没配封面图，就不留空位，直接整行显示：

```css
/* 有封面的卡片，左右排版 */
.article-item:has(.cover-image) {
  display: grid;
  grid-template-columns: 200px 1fr;
}

/* 没封面的卡片，正常上下排 */
.article-item:not(:has(.cover-image)) {
  display: block;
}
```

**3. 下拉菜单交互**

```css
/* 菜单打开时，给按钮换个样式 */
.dropdown:has(.menu[open]) .dropdown-trigger {
  background-color: #f0f0f0;
}
```

## 顺带提几个其他的

### @layer (级联层)

以前写组件库最烦样式被别人的 `!important` 覆盖。现在可以用 `@layer` 给样式排个优先级：

```css
/* 定义顺序，越靠后优先级越高 */
@layer reset, base, components, utilities;

@layer reset {
  * { margin: 0; padding: 0; }
}

@layer utilities {
  .mt-4 { margin-top: 1rem; }
}
```

### accent-color

改原生 radio 和 checkbox 的颜色，以前得隐藏掉自己画，现在一行解决：

```css
:root {
  accent-color: #3498db;
}
```

总的来说，CSS 现在是越来越能打了，很多以前要写几百行 JS 处理的交互，现在几行样式就对付过去了。兼容性的话，主流浏览器基本都绿了，新项目完全可以放心用。
