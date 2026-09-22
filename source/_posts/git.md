---
title: Git 常用命令学习及整理
date: 2017-04-23 10:23:21
tags:
  - Git
categories: Git
---

最近用 Git 比较多，所以整理了一份常用的 Git 命令速查手册。**Git 是目前世界上最先进的分布式版本控制系统。**

<!--more-->

## 安装

各个系统的安装包可在官方网站下载：
- 官方下载地址：[Git Downloads](https://git-scm.com/downloads)

## 基础配置

首次使用前需配置提交者信息及常用别名：

```bash
git config --global user.name "your_name"               # 设置全局用户名
git config --global user.email "your_email@example.com" # 设置全局邮箱
git config --global color.ui true                       # 开启终端彩色输出
git config --global alias.co checkout                   # 配置 checkout 别名
git config --global alias.ci commit                     # 配置 commit 别名
git config --global alias.st status                     # 配置 status 别名
git config --global alias.br branch                     # 配置 branch 别名
git config --global core.quotepath false                # 解决中文文件名乱码问题
git config -l                                           # 列出当前所有配置
# 用户全局配置文件位于 ~/.gitconfig
```

## SSH 秘钥配置

生成并绑定 SSH Key 用于免密推送代码（例如 GitHub / GitLab）：

```bash
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
# 按 3 次回车（保持默认路径，不设私钥密码）
# 生成的秘钥文件位于 ~/.ssh/ 目录：
# - id_rsa: 私钥，必须严格保密
# - id_rsa.pub: 公钥，复制其内容添加到 GitHub/GitLab 的 SSH Keys 设置中
```

### GitHub 连通性测试

```bash
ssh -T git@github.com
# 若看到 "Hi <username>! You've successfully authenticated..." 则说明配置成功
```

## 常用工作流命令

- 初始化本地仓库：`git init`
- 查看工作区状态：`git status`
- 添加文件到暂存区：`git add <file>` 或 `git add .`（添加所有改动）
- 提交暂存区到本地仓库：`git commit -m "提交说明信息"`
- 查看具体文件修改内容：`git diff <file>`

```bash
git help <command>             # 查看指定命令的帮助文档
git show <commit_id>           # 查看某次提交的详细改动（省略 id 则查看最新提交）

# 撤销与恢复
git restore <file>             # 【推荐】丢弃工作区的修改（Git 2.23+）
git checkout -- <file>         # 丢弃工作区的修改（旧版用法）
git restore --staged <file>    # 【推荐】将暂存区的文件移出到工作区
git reset HEAD <file>          # 将暂存区的文件移出到工作区（旧版用法）
git reset --hard HEAD~1        # 彻底回退到上一个版本（丢弃本地所有未提交改动）

# 版本回滚
git revert <commit_id>         # 撤销指定提交（会生成一条新的反向提交记录）
git revert HEAD                # 撤销最近一次提交
```

## 查看差异（Diff）

```bash
git diff                       # 比较工作区与暂存区的差异
git diff <file>                # 比较工作区指定文件与暂存区的差异
git diff --cached              # 比较暂存区与最新提交（HEAD）的差异（等同于 --staged）
git diff <commit1> <commit2>   # 比较两次提交之间的差异
git diff <branch1>..<branch2>  # 比较两个分支之间的差异
git diff --stat                # 仅显示改动文件的统计摘要
```

## 查看提交历史（Log）

```bash
git log                        # 查看提交历史记录
git log --oneline              # 单行简洁显示提交历史
git log --graph --oneline      # 图形化展示分支合并历史
git log <file>                 # 查看指定文件的提交记录
git log -p <file>              # 查看指定文件的每次提交具体 diff
git log -n 5                   # 仅查看最近 5 次提交
git log --stat                 # 显示每次提交的简要文件修改统计
```

## 分支管理（Branch）

```bash
# 查看分支
git branch                     # 查看本地所有分支（当前分支前有 *）
git branch -r                  # 查看所有远程分支
git branch -a                  # 查看所有本地与远程分支
git branch -v                  # 查看各个分支最后一次提交信息

# 创建与切换分支
git branch <new_branch>        # 基于当前分支创建新分支
git switch <branch>            # 【推荐】切换到指定分支（Git 2.23+）
git checkout <branch>          # 切换到指定分支（旧版用法）
git switch -c <new_branch>     # 【推荐】创建并切换到新分支
git checkout -b <new_branch>   # 创建并切换到新分支（旧版用法）

# 删除分支
git branch -d <branch>         # 安全删除分支（已合并的分支）
git branch -D <branch>         # 强制删除分支（即使未合并）
```

## 分支合并与 Rebase

```bash
git merge <branch>             # 将指定分支合并到当前分支
git merge --no-ff <branch>     # 禁用 Fast-Forward 合并，强制生成一条 Merge 提交记录
git rebase master              # 将当前分支变基到 master 分支
```

> **冲突处理说明**：
> - **`merge` 冲突**：手动解决冲突文件后，执行 `git add .` 然后 `git commit` 完成合并。
> - **`rebase` 冲突**：解决冲突后，执行 `git add .`，接着运行 `git rebase --continue` 继续变基；或者使用 `git rebase --abort` 终止并恢复变基前的状态。

## 储藏管理（Stash）

临时保存未提交的工作进度，方便紧急切换分支处理其他任务：

```bash
git stash                      # 储藏当前未提交的修改
git stash save "message"       # 带说明信息的储藏
git stash list                 # 查看所有储藏记录列表
git stash pop                  # 恢复最近一次储藏的内容，并从储藏列表中删除（最常用）
git stash apply                # 恢复储藏内容，但保留储藏列表中的记录
git stash drop                 # 删除最近一次的储藏记录
git stash clear                # 清空所有储藏记录
```

## 远程仓库与协同管理

```bash
# 远程仓库信息
git remote -v                  # 查看绑定的远程仓库地址与别名
git remote show origin         # 查看远程仓库 origin 的详细状态信息
git remote add origin <url>    # 关联远程仓库
git remote set-url origin <url># 修改远程仓库地址
git remote rm origin           # 解绑远程仓库

# 拉取与推送
git fetch origin               # 从远程获取最新版本到本地，但不自动合并
git pull origin <branch>       # 拉取远程分支并自动与当前分支合并（fetch + merge）
git push origin <branch>       # 推送本地分支到远程仓库
git push -u origin master      # 首次推送并建立上游跟踪关系
git push origin --delete <branch> # 【推荐】删除远程分支
```

## 分支关联追踪（Upstream）

设置本地分支与远程分支的追踪关系：

```bash
# 设置当前分支追踪远程分支
git branch -u origin/<branch>
# 或显式指定本地分支与远程分支
git branch --set-upstream-to=origin/<remote_branch> <local_branch>
```
