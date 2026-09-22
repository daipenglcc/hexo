---
title: 重新认识伪类和伪元素
date: 2017-04-28 16:35:10
tags:
  - 伪类
  - 伪元素
categories: CSS3
---

在 CSS 开发中，“伪类（Pseudo-classes）”与“伪元素（Pseudo-elements）”是经常被混淆的两个核心概念。本文从规范定义、核心区别、常见用法及现代 CSS 选择器进行系统梳理。

<!-- more -->

## 1. 核心定义与本质区别

W3C 对伪类与伪元素的官方定义核心在于**是否脱离或扩展了文档树（DOM Tree）**：

| 对比维度 | 伪类（Pseudo-classes） | 伪元素（Pseudo-elements） |
| :--- | :--- | :--- |
| **本质作用** | 用于匹配元素处于**某种特定状态**或符合特定结构特征 | 用于创建并修饰**DOM 树中不存在的抽象元素** |
| **CSS3 语法规范** | **单冒号 `:`**（如 `:hover`, `:first-child`） | **双冒号 `::`**（如 `::before`, `::after`） |
| **类比理解** | 效果等同于动态给 DOM 节点**添加一个 class 类名** | 效果等同于在 DOM 内部**插入了一个真实的虚拟标签** |

---

## 2. 常用伪类（Pseudo-classes）

伪类用来对已有 DOM 元素的动态行为、状态或结构位置进行筛选：

### ① 用户交互与状态伪类
- `:hover`：鼠标悬停状态
- `:active`：鼠标按下激活状态
- `:focus` / `:focus-visible`：获得焦点状态
- `:checked`：表单控件（单选/复选框）被选中状态
- `:disabled` / `:enabled`：禁用 / 启用状态

### ② 结构与树形伪类
- `:first-child` / `:last-child`：作为父级下的首个 / 最后一个子元素
- `:nth-child(n)`：第 n 个子元素（支持 `2n`、`odd`、`even` 等表达式）
- `:only-child`：作为父级下的唯一子元素
- `:empty`：没有任何子节点（包含文本节点）的空元素

### ③ 现代 CSS 高阶伪类（CSS Selectors Level 4）
- `:not(selector)`：反选伪类，匹配不符合条件的元素
- `:is(selector)` / `:where(selector)`：批量选择器分组与优先级简化
- `:has(selector)`：**父选择器**，当包含指定后代时匹配该父元素

---

## 3. 常用伪元素（Pseudo-elements）

伪元素会生成虚拟的内容容器，必须使用 **双冒号 `::`**（兼容旧浏览器时单冒号也可被解析）：

### ① 内容生成（最常用）
- `::before`：在宿主元素内容**最前方**插入生成内容
- `::after`：在宿主元素内容**最后方**插入生成内容

> **注意**：`::before` 与 `::after` 必须显式设置 `content` 属性（即便为空字符串 `content: ""`），否则伪元素不会被渲染。

### ② 文本修饰与高亮
- `::first-letter`：修饰块级元素文本的**首个字母/汉字**（常用于首字下沉排版）
- `::first-line`：修饰块级元素文本的**第一行**（随视口宽度自适应）
- `::selection`：修饰用户鼠标划词选中的高亮文本背景与颜色
- `::placeholder`：修饰 input / textarea 占位符文本样式

---

## 4. 实战典型用法

### ① 利用 `attr()` 获取属性值渲染气泡

```css
.tooltip::after {
  content: attr(data-tip);
  position: absolute;
  background: #333;
  color: #fff;
  padding: 4px 8px;
  border-radius: 4px;
}
```

```html
<button class="tooltip" data-tip="这是提示文字">悬停查看提示</button>
```

### ② 结合伪类与伪元素实现动态悬浮效果

```css
.btn::before {
  content: "";
  display: inline-block;
  width: 8px;
  height: 8px;
  background: gray;
  margin-right: 6px;
  border-radius: 50%;
  transition: background 0.3s;
}

/* 当按钮处于 hover 状态时改变 ::before 伪元素的样式 */
.btn:hover::before {
  background: #10b981;
}
```

---

## 5. 总结

- **区分标准**：看是否“创建了新节点”。修饰状态用伪类（`:`），创建虚拟内容用伪元素（`::`）。
- **编码习惯**：在现代开发中，统一为伪类使用单冒号 `:`，伪元素使用双冒号 `::`，代码语义更清晰。
