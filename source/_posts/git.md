---
title: Git 线上事故实录：如何优雅处理错乱的分支合并与代码回滚
date: 2017-04-23 10:23:21
tags:
  - Git
  - 架构设计
  - 工程化
categories: Git
---

这两天团队里出了个线上问题：有个新来的同学在处理一个紧急 Bug 时，不仅把测试分支的代码合到了主干，还在操作不当时用 `git push -f` 覆盖了远程分支。等我们发现的时候，线上已经带着几个没测完的功能跑了半个小时了。

最后靠着 `git reflog` 和一些底层的操作成功恢复了代码。趁着周末有空，我把日常开发中真正会救命的几个 Git 骚操作复盘一下。别再把 Git 当个机械的 `add/commit/push` 机器了。

<!--more-->

## 1. 灾难现场：远程分支被 `push -f` 覆盖了怎么办？

这是最棘手的场景。很多人以为 `push -f` 之后代码就彻底没了。其实 Git 的设计哲学是：**只要是被 commit 过的内容，几乎不可能真正丢失。**

如果只是你本地的分支被搞乱了，救命稻草是 `git reflog`。
`git log` 只能看当前分支的提交历史，而 `git reflog` 记录的是你在这个仓库里所有的 HEAD 变更轨迹，包括你删掉的 commit、切分支、甚至是那些被你 reset 掉的提交。

```bash
# 查看所有操作记录
git reflog

# 找到被覆盖前的那个 commit hash，比如是 abc1234
# 直接强行把当前分支指针拨回那个时刻
git reset --hard abc1234

# 然后再小心翼翼地强推上去（如果团队允许的话）
git push -f origin main
```

**但是如果别人 `push -f` 覆盖了远程，而你本地没有最新的代码怎么办？**
这时候要去 GitLab/GitHub 上看。哪怕分支被覆盖了，之前的 Commit 对象在服务端并不会立刻被垃圾回收（GC）。只要你能通过 CI/CD 的日志、或者别人的本地缓存找到那个 Commit Hash，直接在本地 `git fetch origin <commit-hash>`，就能把它拉下来重新建分支。

## 2. 优雅的代码回滚：`revert` vs `reset`

很多人回滚代码喜欢用 `git reset --hard`，但这在多人协作的分支上是个灾难。`reset` 是把历史直接“抹掉”，如果别人基于被你抹掉的历史继续开发，下次 push 就会产生严重的冲突。

正确的线上回滚姿势是使用 `revert`。

```bash
# 撤销最近一次提交，并生成一个新的“反向提交”
git revert HEAD

# 如果要撤销中间的某一个提交（比如两个星期前引入的 bug）
git revert <commit-hash>
```

如果是合并（Merge）提交导致的线上问题，单纯的 `revert` 还会报错，因为 Git 不知道你要撤销合并的哪一条线。这时候需要加 `-m` 参数：

```bash
# 通常 -m 1 代表主干分支那条线，撤销掉合并进来的特性分支代码
git revert -m 1 <merge-commit-hash>
```

> **注意事项**：一旦你 `revert` 了一个 Merge Commit，这部分代码在 Git 眼里就是“被明确拒绝”的。如果后续这个特性分支修好了 bug 再次合并，Git 会直接忽略那些之前被 revert 过的文件修改！解决方案是要么再次 revert 那个 revert，要么改用 rebase 重新生成新的 commit。

## 3. 把代码揉得更好看：`git rebase -i`

在自己的特性分支上开发时，往往会产生一堆类似 "fix typo", "update", "wip" 这种垃圾 commit。如果直接合进主干，Code Review 的时候同事会难以通过代码审查。

这时候 `git rebase -i` (interactive) 就派上用场了。它可以让你在合并前，灵活地重塑你的提交历史。

```bash
# 交互式处理最近的 5 个 commit
git rebase -i HEAD~5
```

弹出的编辑器里会有几个常用指令：
- `pick`：保留这个 commit
- `squash` (或 `s`)：把这个 commit 揉进上一个 commit 里
- `edit` (或 `e`)：在这个 commit 停下来，让你修改文件
- `drop` (或 `d`)：直接丢弃这个 commit

通过把中间的琐碎的提交 `squash` 掉，最后提交的 PR 就能保持极其清高效的逻辑线。

## 4. 挑拣特定的代码：`git cherry-pick`

有个极其常见的场景：你在 `feat-A` 分支上开发，顺手修了一个基础组件的 Bug。现在主干急需这个 Bug 修复，但你 `feat-A` 的其他代码还没开发完，不能一起合进去。

不要手动去主干手动把代码再改一遍，直接用 `cherry-pick`：

```bash
# 先切到主干
git checkout main

# 把那个修 bug 的特定 commit 摘取过来
git cherry-pick <commit-hash>
```

如果遇到冲突，解决完冲突后执行 `git cherry-pick --continue` 即可。

## 总结

Git 的学习曲线确实有点陡峭，它的心智模型跟 SVN 完全不同。理解 Git 的核心在于理解它的数据结构：**它不是记录文件差异，而是记录文件系统在特定时刻的完整快照（Snapshot）。**

理解了这一点，你就会明白为什么切分支那么快，为什么 `reflog` 这么强大，以及为什么我们在进行任何危险操作前，都应该先切个临时分支做个快照。多造几次“事故”，多翻几次车，Git 就能用溜了。
