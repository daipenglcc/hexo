---
title: Git 常用命令备忘录
date: 2017-04-23 10:23:21
tags:
  - Git
categories: Git
---

工作也挺长时间了，Git 天天敲，但遇到点偏门的撤销或者合并，偶尔还是得去网上搜半天。干脆把我自己平时高频用到的几个命令整理出来，当个个人的速查备忘录，省得老去翻文档。

<!--more-->

## 1. 刚装好要干嘛

新电脑拿到手第一件事，配名字、邮箱和别名：

```bash
git config --global user.name "your_name"               # 你的名字
git config --global user.email "your_email@example.com" # 你的邮箱
git config --global color.ui true                       # 开启彩色输出
git config --global core.quotepath false                # 解决中文文件名显示成数字的问题
```

顺手给常用命令弄点缩写，少敲两个字母：
```bash
git config --global alias.co checkout
git config --global alias.ci commit
git config --global alias.st status
git config --global alias.br branch
```

如果要去拉代码，还得弄个 SSH 秘钥：
```bash
ssh-keygen -t rsa -b 4096 -C "你的邮箱"
# 一直回车就行，最后去 ~/.ssh/ 里面把 id_rsa.pub 的内容复制到 GitHub 上
```

## 2. 最普通的日常操作

这些几乎每天都要敲几十遍：

```bash
git status                     # 看看改了啥
git add .                      # 全部扔进暂存区
git commit -m "改了某个bug"    # 提交
git push                       # 推上天
```

## 3. 看历史和看改动

想看看之前自己或者别人写了什么鬼代码：

```bash
git log --oneline              # 单行简短看历史，比较清爽
git log -p <file>              # 看看某个文件具体的历史改动
git diff                       # 看看刚刚敲了啥代码还没 add
git show                       # 看看最近一次 commit 到底改了啥
```

## 4. 后悔药（撤销与回滚）

常在河边走哪有不湿鞋，写错代码想反悔的时候查这些：

```bash
# 代码还在本地，没 commit：
git restore <file>             # 把文件恢复到修改前的样子（新版 Git 用法）
git checkout -- <file>         # 老版本用法，效果一样

# 已经 git add 了，想退回没 add 的状态：
git restore --staged <file>

# 已经 commit 了，但还在本地想彻底不要了：
git reset --hard HEAD~1        # 彻底回退到上一个版本，慎用！改动全没

# 已经推到线上了，想体面地撤销：
git revert HEAD                # 生成一个新的 commit，内容是把上一次的改动反向操作一下
```

## 5. 玩转分支

接新需求、切分支修 bug 时用：

```bash
git branch                     # 看看现在有哪些分支
git switch <branch>            # 切换过去（比 checkout 语义更清楚）
git switch -c <new_branch>     # 创个新分支顺带切过去

# 删分支
git branch -d <branch>         # 删掉已经合过的分支
git branch -D <branch>         # 强制删掉，不管合没合
```

## 6. 合并代码

一般在测试通过后要合代码了：

```bash
git merge <branch>             # 把别人的分支合到我这里
git rebase master              # 变基，把我的提交拼接到 master 最上面（记录看起来是一条直线）
```

> **小坑提醒**：
> 如果遇到冲突，老老实实打开文件把冲突符号 `< <<<<<` 之类的清掉，然后再 `git add .`。如果是 rebase 遇到冲突，add 完后记得跑 `git rebase --continue`，千万别再去 commit。

## 7. 临时藏代码（Stash）

正写着需求呢，突然让去修个紧急 bug，这个时候 `stash` 最救命：

```bash
git stash                      # 赶紧把现在的改动藏起来
git stash list                 # 看看藏了哪些东西
git stash pop                  # 紧急 bug 修完回来，把之前藏的代码拿出来继续写
git stash clear                # 不要了，全清掉
```

基本就这些了。真遇到这些解决不了的疑难杂症，大概率是代码合废了，到时候再 Google 吧。
