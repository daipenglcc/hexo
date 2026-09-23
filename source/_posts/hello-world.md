---
title: 折腾博客：Hexo 常用命令备忘
date: 2015-08-28 18:29:33
tags:
  - hexo
  - 光阴小栈
categories: Hexo
---
虽然现在大家都在公众号或者沸点发短文，但我还是习惯把东西丢在自己的 Hexo 博客里。有时候一两个月没发文章，连命令都能忘得一干二净。这里简单整理几个每次发版都要敲的命令，全当给自己留个备忘。

<!-- more -->

## 1. 跑个本地服务看看效果

```bash
hexo s
# 或者是完整拼写：hexo server
```

敲完在浏览器里访问 `http://localhost:4000/` 就行了。
大部分时候你在编辑器里改 Markdown 保存，浏览器会自动刷新，这点还挺顺手的。但如果你改了主题或者外层的 `_config.yml`，就得把终端停了重新跑一次 `hexo s` 才行。

## 2. 搞篇新文章

```bash
# 中间有空格的话得加个引号
hexo new "这周折腾了啥"

# 如果是想搞个独立的关于我页面，就用这个：
hexo new page about
```

新建文章后，它会自动在 `source/_posts/` 给你生成一个 md 文件。如果你加了 `page about`，它就会在 `source/about/index.md` 生成，这种页面不会出现在你的文章列表流里。

## 3. 把 Markdown 变网页

```bash
hexo g
# 完整命令：hexo generate
```

这一步就是把咱们写的纯文本编译成 HTML，输出的东西都在 `public/` 文件夹里。

## 4. 出了莫名其妙的 bug 就清理缓存

```bash
hexo clean
```

这个真的是万能药。有时候明明改了文章但网页没反应，或者标签、分类突然乱掉了，基本上先跑一下 `hexo clean` 把生成的缓存删了，再重新编译，能解决 90% 的玄学问题。

## 5. 推到线上

```bash
hexo d
# 完整命令：hexo deploy
```

只要你把配置里的 Git 地址填好，敲这个命令它就会自动把 `public` 文件夹扔到 Github Pages 之类的地方。

## 6. 一把梭

平时写完文章，我基本就直接盲敲这一句，清理、编译、发布一步到位：

```bash
hexo clean && hexo g && hexo d
```

行了，就这几个，够对付日常写点水文了。
