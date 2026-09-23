---
title: CSS 里的李鬼与李逵：伪类和伪元素到底啥区别
date: 2017-04-28 16:35:10
tags:
  - 伪类
  - 伪元素
categories: CSS3
---

写了这么多年 CSS，经常看到有人把 `:hover` 和 `::before` 混在一块叫“伪类”。虽然浏览器很宽容，不管你写一个冒号还是俩冒号它都能认出来并且渲染，但强迫症发作的时候，还是想把它们理清楚。

这里顺便记一下这俩玩意儿在实际开发中能搞出的常用操作。

<!-- more -->

## 1. 到底怎么区分？

其实官方的定义特别简单粗暴，就看一点：**有没有凭空造出一个新的东西来**。

- **伪类（单冒号 `:`）**：人家 DOM 节点本来就在那，你只是在它**某种状态**下（比如鼠标滑过）给它加了点样式。效果就像是你动态用 JS 往它身上套了个 class。
- **伪元素（双冒号 `::`）**：这玩意儿在 HTML 源码里根本不存在，是你用 CSS 硬生生在页面上“无中生有”捏造出来的一个虚拟 DOM 节点。

## 2. 常用的伪类（Pseudo-classes）

主要就是用来抓取元素状态或者找位置的：

```css
/* 用户在瞎点瞎滑的时候 */
.btn:hover { ... }      /* 鼠标悬停 */
.btn:active { ... }     /* 鼠标按住不放 */
input:focus { ... }     /* 选中的输入框 */

/* 找儿子的技巧 */
ul li:first-child { ... }   /* 第一个 li */
ul li:last-child { ... }    /* 最后一个 li */
ul li:nth-child(2n) { ... } /* 斑马线效果，选偶数行 */

/* 新出的几个狠角色 */
.box:not(.active) { ... }   /* 把带 active 的排除掉 */
.card:has(img) { ... }      /* 逆天的父选择器：只要卡片里有图，就给卡片变色 */
```

## 3. 常用的伪元素（Pseudo-elements）

必须要用双冒号 `::`（虽然老浏览器写单冒号也行，但现在建议全改双冒号规范一下）：

```css
/* 这俩兄弟是出场率最高的，用来画图标、画气泡、清除浮动全靠它们 */
.box::before { content: ""; }  /* 插在最前面 */
.box::after { content: ""; }   /* 插在最后面 */
/* ⚠️ 必须写 content，哪怕是空的，不然伪元素出不来！ */

/* 文字排版偶尔用一下 */
p::first-letter { ... }  /* 首字下沉（像杂志那样第一个字贼大） */
p::first-line { ... }    /* 只给第一行换个颜色 */

/* 稍微好玩点的 */
::selection { background: #3498db; color: #fff; } /* 用户鼠标划选文字时的高亮颜色 */
input::placeholder { color: #ccc; }               /* 修改输入框提示文字的颜色 */
```

## 4. 日常开发里的实战骚操作

### ① 不写 HTML，用属性把文字提出来当提示框

有时候不想写一堆嵌套的 DOM，可以直接用伪元素读 `data-*` 属性。

```html
<!-- HTML 就干干净净一行 -->
<button class="tooltip" data-tip="你点我试试？">提交</button>
```

```css
/* 用 ::after 把它后面的气泡造出来 */
.tooltip::after {
  content: attr(data-tip); /* 重点在这，直接读出 HTML 里的文字 */
  position: absolute;
  background: #333;
  color: #fff;
  padding: 4px 8px;
  border-radius: 4px;
  display: none;
}

/* 结合伪类，滑过去才显示 */
.tooltip:hover::after {
  display: block;
}
```

### ② 给按钮加个悬浮小圆点

想做个通知中心那种“有新消息”的红点，直接用伪元素画个圆，连图片都省了：

```css
.msg-btn::after {
  content: "";
  display: inline-block;
  width: 8px;
  height: 8px;
  background: red;
  border-radius: 50%;
  margin-left: 5px;
}
```

简单来说，以后跟别人交流别再管 `::before` 叫伪类了，不然很容易暴露咱们 CSS 不扎实。记住单冒号是状态（伪类），双冒号是造物（伪元素），就行了。
