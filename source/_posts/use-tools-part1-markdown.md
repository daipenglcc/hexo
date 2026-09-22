---
title: 工具使用篇之Markdown
date: 2016-11-27 10:35:12
tags:
  - Markdown语法规范
  - tools
categories: Markdown
---

Markdown 是一种轻量级标记语言，由 John Gruber 于 2004 年创建。它允许人们使用易读易写的纯文本格式编写文档，并可轻松转换为格式良好的 HTML。如今，GitHub、各大技术社区、静态博客（如 Hexo）以及笔记软件广泛采用 Markdown 作为标准的排版格式。

<!--more-->

## 1. 为什么选择 Markdown

- **专注内容本身**：无需被 Word 等复杂排版工具分散精力；
- **极佳的通用性与可移植性**：纯文本存储，永远不会因软件版本淘汰而打不开；
- **全平台支持与丰富生态**：广泛用于技术博客、API 文档、项目 README、笔记与书籍编写。

---

## 2. 常用 Markdown 编辑器推荐

- **[VS Code](https://code.visualstudio.com/)**：自带双栏实时预览（快捷键 `Cmd/Ctrl + K V`），配合插件如 *Markdown All in One* 体验极佳。
- **[Typora](https://typoraio.cn/)**：优雅的所见即所得单栏 Markdown 编辑器。
- **[Obsidian](https://obsidian.md/)**：基于本地 Markdown 文件的双向链接知识库笔记工具。

---

## 3. Markdown 基础语法

### ① 标题（Headings）

使用 `#` 标识标题，支持 1 ~ 6 级标题：

```markdown
# 一级标题
## 二级标题
### 三级标题
#### 四级标题
##### 五级标题
###### 六级标题
```

### ② 文本样式（粗体、斜体、删除线）

```markdown
**这是粗体文本**
*这是斜体文本*
***这是粗斜体文本***
~~这是带删除线的文本~~
```

### ③ 无序与有序列表

```markdown
<!-- 无序列表（使用 - 或 *） -->
- 项目 A
- 项目 B
  - 子项目 B-1
  - 子项目 B-2

<!-- 有序列表（数字加圆点） -->
1. 第一步
2. 第二步
3. 第三步
```

### ④ 引用（Blockquotes）

```markdown
> 这是一个标准引用块。
> > 引用也可以多层嵌套。
```

### ⑤ 超链接与图片

```markdown
<!-- 文本链接 -->
[访问光阴小栈](https://www.vueweb.cn/)

<!-- 插入图片（比链接多一个 ! 前缀） -->
![图片描述文字](https://www.vueweb.cn/images/avatar.png)
```

### ⑥ 行内代码与代码块

行内代码使用单个反引号包裹，代码块使用三个反引号并声明语言高亮：

````markdown
这里是行内代码 `const a = 1;`

```javascript
function greet(name) {
  console.log(`Hello, ${name}!`);
}
greet('World');
```
````

### ⑦ 表格（Tables）

```markdown
| 快捷键 | 功能说明 | 适用平台 |
| :--- | :---: | ---: |
| Ctrl + B | 粗体 | 通用 |
| Ctrl + I | 斜体 | 通用 |
| Ctrl + K | 插入链接 | 通用 |
```

> **对齐方式**：`:---` 为左对齐，`:---:` 为居中对齐，`---:` 为右对齐。

### ⑧ 分割线与任务列表

```markdown
<!-- 分割线（三个以上的 - 或 *） -->
---

<!-- 任务清单 (Task Lists) -->
- [x] 已完成的任务事项
- [ ] 待完成的任务事项
```
