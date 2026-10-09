---
title: 把 Grunt 换成 Gulp，构建时间从 40 秒降到 8 秒
date: 2014-11-22 10:18:50
tags:
  - Gulp
  - Grunt
  - 前端工程化
  - Node.js
categories: 前端工程化
---

最近把项目的构建工具从 Grunt 换成了 Gulp，顺手记一下过程和原理层面的差异，不是教怎么用 API，而是搞清楚为什么 Gulp 快。

项目背景：中型后台系统，30+ 个 Less 文件，20+ 个 JS 模块，构建时 Grunt 要跑 40 多秒，换完 Gulp 大概 8 秒出头。

<!-- more -->

## 为什么 Grunt 慢：临时文件 I/O

Grunt 的任务模型是这样的：每个 task 从磁盘读文件 → 处理 → 写回磁盘。下一个 task 再从磁盘读刚才输出的文件 → 处理 → 写磁盘。

一个 Less 编译流程大概长这样：

```
[磁盘] → grunt-contrib-less → [临时文件写磁盘]
[磁盘] → grunt-autoprefixer  → [临时文件写磁盘]
[磁盘] → grunt-cssmin        → [最终文件写磁盘]
```

三次磁盘读写，每次都是完整的文件系统操作。Less 文件多了，这个开销加起来相当可观，而且是串行的，一批处理完才开始下一批。

## Gulp 为什么快：Node.js Stream

Gulp 的核心是 Node.js 的 Stream（流）。文件从磁盘读出来之后，以二进制流的形式在内存里流转，经过每个 transform 插件，最后才写一次磁盘。

```
[磁盘读一次]
  → gulp-less (Stream transform)
  → gulp-autoprefixer (Stream transform)
  → gulp-minify-css (Stream transform)
  → [磁盘写一次]
```

中间任何步骤都不落磁盘，纯内存操作。Node Stream 的 pipe 机制还实现了背压（backpressure）控制，上游生产速度和下游消费速度自动平衡，不会把内存撑爆。

## Gulp 4 的任务组织

Gulp 4 相比 Gulp 3 一个重要变化：不再用 `gulp.task('name', deps, fn)` 这种隐式依赖方式，改为显式的 `series()` 和 `parallel()`：

```javascript
const { src, dest, watch, series, parallel, lastRun } = require('gulp')
const less       = require('gulp-less')
const autoprefix = require('gulp-autoprefixer')
const cleanCSS   = require('gulp-clean-css')
const uglify     = require('gulp-uglify')
const babel      = require('gulp-babel')
const sourcemaps = require('gulp-sourcemaps')
const changed    = require('gulp-changed')

// Less 编译链
function compileLess() {
  return src('./src/less/**/*.less')
    .pipe(sourcemaps.init())
    .pipe(less())
    .pipe(autoprefix({ browsers: ['last 2 versions', 'ie >= 9'] }))
    .pipe(cleanCSS({ level: 2 }))  // level 2 是结构优化，比 level 1 更激进
    .pipe(sourcemaps.write('./maps'))
    .pipe(dest('./dist/css'))
}

// JS 处理
function buildJS() {
  return src('./src/js/**/*.js')
    .pipe(sourcemaps.init())
    .pipe(babel({ presets: ['@babel/preset-env'] }))
    .pipe(uglify({
      compress: {
        drop_console: true,   // 生产环境去掉 console
        dead_code: true
      }
    }))
    .pipe(sourcemaps.write('./maps'))
    .pipe(dest('./dist/js'))
}

// 增量构建：只处理改变过的文件
function buildJSIncremental() {
  return src('./src/js/**/*.js', { since: lastRun(buildJSIncremental) })
    .pipe(babel({ presets: ['@babel/preset-env'] }))
    .pipe(dest('./dist/js'))
}

// 并行跑，互不依赖的任务同时开始
const build = parallel(compileLess, buildJS)

// 开发 watch
function watchFiles() {
  watch('./src/less/**/*.less', compileLess)
  watch('./src/js/**/*.js', buildJSIncremental)
}

exports.build = build
exports.watch = watchFiles
exports.default = series(build, watchFiles)
```

`parallel()` 让 Less 编译和 JS 构建同时跑，互不等待，这是从 40 秒掉到 8 秒的另一个原因。

## gulp-changed / lastRun：增量编译

全量构建首次没法避免，但 `watch` 模式下每次改一个文件就把所有文件重新过一遍，完全没必要。

`gulp-changed` 对比源文件和输出文件的 mtime，只处理新的：

```javascript
function compileLessIncremental() {
  return src('./src/less/**/*.less')
    .pipe(changed('./dist/css', { extension: '.css' }))
    .pipe(less())
    .pipe(dest('./dist/css'))
}
```

`lastRun(task)` 是 Gulp 4 内置的，返回该 task 上次运行的时间戳，`src()` 的 `since` 选项只 glob 在那个时间之后修改的文件：

```javascript
src('./src/js/**/*.js', { since: lastRun(buildJSIncremental) })
```

这两种方式都能让 watch 下的单次构建从几秒降到几百毫秒。

## Stream 错误处理的坑

Gulp 有个恶心的问题：Stream 里如果插件抛错（比如 Less 语法错误），会导致整个 Stream "中断"，watch 进程挂掉，后续改文件都不会触发重新构建。

解法是用 `gulp-plumber` 接管错误：

```javascript
const plumber = require('gulp-plumber')
const notify  = require('gulp-notify')

function compileLess() {
  return src('./src/less/**/*.less')
    .pipe(plumber({
      errorHandler: notify.onError({
        title: 'Less 编译出错',
        message: '<%= error.message %>'
      })
    }))
    .pipe(less())
    .pipe(dest('./dist/css'))
}
```

`plumber` 截获 Stream 的 error 事件，打印出来但不让它把整个进程搞死。这个在开发模式下几乎是必加的。

## 为什么后来 Gulp 被 Webpack 取代

Gulp 的问题不是慢（比 Grunt 快多了），而是**它的流处理模型不适合 JS 模块系统**。

`require`/`import` 形成的模块依赖树是图状的，Gulp 的 `src → pipe → dest` 是线性流，处理单个文件或一批独立文件没问题，但处理"模块间依赖"就力不从心了——你没办法用 Gulp 做真正意义上的 tree-shaking 或代码分割。

Webpack 从一开始就把 JS 当有向图来处理，从入口出发递归解析依赖，这才是 SPA 时代需要的工具。

Gulp 被取代不是因为它不好，而是应用场景变了。到今天它在处理多页面传统项目、构建 npm 库的时候，还是很顺手的。
