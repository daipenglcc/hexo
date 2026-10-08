---
title: 不想再查了：Flex 布局日常速查笔记
date: 2018-09-10 14:30:22
tags:
  - CSS
  - Flex
  - 布局
categories: CSS3
---

以前写 CSS 布局，不是 float 就是 inline-block，各种清除浮动，元素居中更是要搜一堆 hack。后来 Flexbox 基本上所有浏览器都支持了（IE 就不说了），我就彻底切过来了。不过属性太多，有些不常用的老是搞混，记一下免得每次都去 MDN 翻。

<!-- more -->

## 1. 先搞清楚两个角色

Flex 布局里就两个概念：**容器**（父元素）和**项目**（子元素）。给父元素加 `display: flex`，它所有直接子元素就自动成 flex 项目了。

```css
.container {
  display: flex;
  /* 就这一行，里面的子元素就排成一行了 */
}
```

## 2. 容器上的属性（我常用的）

### flex-direction：主轴方向

```css
.container {
  flex-direction: row;            /* 默认，从左到右 */
  flex-direction: row-reverse;    /* 从右到左 */
  flex-direction: column;         /* 从上到下，做纵向布局的时候用 */
  flex-direction: column-reverse; /* 从下到上，几乎没用过 */
}
```

### justify-content：主轴对齐

这个用得最多，尤其是居中和两端对齐。

```css
.container {
  justify-content: flex-start;    /* 默认，全挤在开头 */
  justify-content: center;        /* 居中，最常用 */
  justify-content: flex-end;      /* 挤到末尾 */
  justify-content: space-between; /* 两端对齐，中间平分间距。导航栏经常用 */
  justify-content: space-around;  /* 每个元素两边间距相等 */
  justify-content: space-evenly;  /* 所有间距完全相等，最好看 */
}
```

### align-items：交叉轴对齐

```css
.container {
  align-items: stretch;     /* 默认，子元素撑满容器高度 */
  align-items: center;      /* 垂直居中！终于不用再写那个 top50%+transform 了 */
  align-items: flex-start;  /* 顶部对齐 */
  align-items: flex-end;    /* 底部对齐 */
  align-items: baseline;    /* 文字基线对齐，文字大小不一样的时候有用 */
}
```

### flex-wrap：换行

```css
.container {
  flex-wrap: nowrap; /* 默认不换行，挤在一行里 */
  flex-wrap: wrap;   /* 放不下就换行，做响应式网格的时候常用 */
}
```

## 3. 水平垂直居中：两行搞定

以前写居中要一堆代码，现在就两行：

```css
.container {
  display: flex;
  justify-content: center; /* 水平居中 */
  align-items: center;     /* 垂直居中 */
}
```

这可能是 Flex 最让人感动的地方了。

## 4. 项目上的属性

### flex: 1 到底是啥

项目上最常写的就是 `flex: 1`，它是三个属性的缩写：

```css
.item {
  /* flex: 1 其实等于 */
  flex-grow: 1;    /* 有剩余空间就撑开 */
  flex-shrink: 1;  /* 空间不够就缩小 */
  flex-basis: 0%;  /* 初始大小为0，完全按比例分 */
}
```

最典型的场景：

```css
/* 经典的 "左侧固定宽度 + 右侧自适应" 布局 */
.sidebar { width: 240px; }
.main { flex: 1; }  /* 剩余空间全归我 */
```

### align-self：单独控制某个项目的对齐

```css
/* 其他项目都居中，就这一个靠底部 */
.special-item {
  align-self: flex-end;
}
```

### order：调顺序

不想改 HTML 结构，又想让某个元素显示在前面？

```css
.item-last {
  order: -1; /* 数字越小越靠前，默认都是0 */
}
```

## 5. 几个实际场景

### 导航栏

```css
.navbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0 20px;
  height: 60px;
}

.navbar .logo { /* 左边的logo */ }
.navbar .nav-links {
  display: flex;
  gap: 20px;  /* 链接之间的间距，gap 比 margin 好使 */
}
```

### 卡片列表自动换行

```css
.card-grid {
  display: flex;
  flex-wrap: wrap;
  gap: 16px;
}

.card {
  /* 一行放三个，减去 gap 的距离 */
  flex: 0 0 calc(33.333% - 16px);
}
```

### 底部粘在页面底部（Sticky Footer）

页面内容少的时候，footer 也能粘在底部：

```css
body {
  display: flex;
  flex-direction: column;
  min-height: 100vh;
}

main {
  flex: 1; /* main 区域撑满剩余空间 */
}

footer {
  /* 不用设什么，它自然就在最底下了 */
}
```

## 6. 跟 Grid 的分工

简单说，Flex 适合一维布局（一行或一列），Grid 适合二维布局（同时控制行和列）。不过说实话，日常写页面 Flex 能搞定 80% 以上的布局需求了，Grid 我一般在做比较规整的表格式布局时才拿出来用。

掌握这些基本就够日常干活了，偶尔遇到记不住的看看这篇就行。
