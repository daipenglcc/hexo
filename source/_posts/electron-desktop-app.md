---
title: 前端搞 Electron 桌面应用：从入门到能跑
date: 2021-11-20 14:30:55
tags:
  - Electron
  - Node
  - 桌面应用
categories: Node
---

前阵子组里要搞一个内部工具，需要读本地文件、调系统剪贴板，用网页搞不定。正好一直想试试 Electron，借这个机会花费时间一下。写篇记录，主要是理清主进程和渲染进程的关系，这个概念一开始真的会绕。

<!-- more -->

## 1. Electron 是个啥

简单说：**Electron = Chromium（浏览器）+ Node.js**。你用前端写页面，然后用 Node.js 去干一些系统层面的事情（读写文件、调系统通知等等），最后打包成 .exe 或 .dmg 给人装。

VS Code、Slack、飞书桌面版都是用它做的，所以性能和体验方面问题不大（虽然内存占用确实偏高）。

## 2. 快速上手

```bash
mkdir my-electron-app && cd my-electron-app
npm init -y
npm install --save-dev electron
```

创建入口文件：

```javascript
// main.js（主进程）
const { app, BrowserWindow } = require('electron')
const path = require('path')

function createWindow() {
  const win = new BrowserWindow({
    width: 1000,
    height: 700,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      // 注意：不要开 nodeIntegration，安全隐患大
      nodeIntegration: false,
      contextIsolation: true,
    }
  })

  // 加载页面
  win.loadFile('index.html')
  
  // 开发的时候打开 DevTools
  // win.webContents.openDevTools()
}

app.whenReady().then(() => {
  createWindow()

  // macOS 下点 dock 图标要重新创建窗口
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow()
    }
  })
})

// Windows/Linux 下关闭所有窗口就退出
app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit()
  }
})
```

```javascript
// preload.js（预加载脚本，连接主进程和渲染进程的桥）
const { contextBridge, ipcRenderer } = require('electron')

contextBridge.exposeInMainWorld('electronAPI', {
  // 只暴露你需要的功能给渲染进程
  readFile: (filePath) => ipcRenderer.invoke('read-file', filePath),
  saveFile: (filePath, content) => ipcRenderer.invoke('save-file', filePath, content),
})
```

```html
<!-- index.html -->
<!DOCTYPE html>
<html>
<head><title>我的工具</title></head>
<body>
  <h1>Hello Electron</h1>
  <button id="readBtn">读取文件</button>
  <pre id="output"></pre>

  <script>
    document.getElementById('readBtn').addEventListener('click', async () => {
      // 这个 window.electronAPI 就是 preload.js 里暴露出来的
      const content = await window.electronAPI.readFile('/some/path/file.txt')
      document.getElementById('output').textContent = content
    })
  </script>
</body>
</html>
```

package.json 里加上启动命令：

```json
{
  "main": "main.js",
  "scripts": {
    "start": "electron ."
  }
}
```

`npm start` 就能看到窗口了。

## 3. 搞懂主进程和渲染进程

这是 Electron 最核心的概念，也是我一开始最懵的地方。

**主进程（Main Process）：**
- 就是 `main.js` 这个文件
- 用 Node.js 跑的，能读写文件、调系统 API
- 负责创建和管理窗口
- 整个应用只有一个主进程

**渲染进程（Renderer Process）：**
- 每个窗口就是一个渲染进程
- 跑的是网页，能用所有前端技术
- 默认情况下不能直接用 Node.js 的东西（出于安全考虑）

**Preload 脚本：**
- 在渲染进程加载页面之前执行
- 可以同时访问 Node.js API 和 DOM
- 通过 `contextBridge` 安全地把功能暴露给页面

它们之间通过 **IPC（进程间通信）** 来互相喊话：

```javascript
// 主进程里监听消息
const { ipcMain } = require('electron')
const fs = require('fs')

ipcMain.handle('read-file', async (event, filePath) => {
  try {
    const content = fs.readFileSync(filePath, 'utf-8')
    return content
  } catch (err) {
    return '读取失败: ' + err.message
  }
})

ipcMain.handle('save-file', async (event, filePath, content) => {
  fs.writeFileSync(filePath, content, 'utf-8')
  return '保存成功'
})
```

## 4. 结合 Vue 开发

实际项目里总不能手写 HTML 吧，一般会接一个前端框架。我用的 Vue + Vite：

```bash
# 用现成的模板省事
npm create @nicepkg/electron-vite-app
```

这样开发体验就跟写普通 Vue 项目差不多了，热更新也有，很顺滑。

不过这里有个常见问题：Vite 开发模式下主进程加载的是 `http://localhost:xxxx`，打包后加载的是本地文件。所以 main.js 里需要判断一下：

```javascript
if (process.env.NODE_ENV === 'development') {
  win.loadURL('http://localhost:5173')
} else {
  win.loadFile(path.join(__dirname, '../dist/index.html'))
}
```

## 5. 打包发布

打包用 `electron-builder`，支持 Windows、macOS、Linux 三个平台：

```bash
npm install --save-dev electron-builder
```

```json
// package.json
{
  "build": {
    "appId": "com.example.mytool",
    "productName": "我的工具",
    "mac": {
      "target": "dmg"
    },
    "win": {
      "target": "nsis"
    }
  },
  "scripts": {
    "build:electron": "electron-builder"
  }
}
```

不过打包体积是个问题，一个空壳 Electron 应用打出来就 70-80MB 起步。因为它得把整个 Chromium 和 Node.js 都打进去。

如果你特别在意体积，可以去看看 Tauri，用 Rust 写后端，打出来才几 MB。但 Tauri 的学习成本比 Electron 高不少。

## 6. 小结

Electron 对前端来说确实是搞桌面应用最省事的方案，Web 技术直接复用，不用学 C++ 或者 Swift。缺点就是内存占用高、打包体积大，做个内部工具或者小型客户端没问题，但如果是面向 C 端的大型应用，可能要慎重考虑。

我那个内部工具最后做下来还挺顺利的，拿 Vue 写界面，IPC 调 Node 读写文件和操作剪贴板。同事们用着反馈也还行。
