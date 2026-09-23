---
title: 微信小程序开发入门笔记
date: 2019-10-25 11:20:35
tags:
  - 小程序
  - 微信
categories: 小程序
---

微信小程序自 2017 年发布以来持续火热，2019 年已经成为移动端开发不可忽视的一环。相比传统 H5 应用，小程序在微信生态内拥有更好的性能表现和用户触达能力。本文从项目搭建到核心知识点，整理了小程序开发的入门要点。

<!-- more -->

## 1. 项目结构

一个标准的小程序项目包含以下核心文件：

```
├── app.js          # 小程序入口逻辑（应用生命周期）
├── app.json        # 全局配置（页面路径、窗口样式、TabBar 等）
├── app.wxss        # 全局样式
├── pages/
│   ├── index/
│   │   ├── index.js      # 页面逻辑
│   │   ├── index.json    # 页面配置
│   │   ├── index.wxml    # 页面模板（类似 HTML）
│   │   └── index.wxss    # 页面样式（类似 CSS）
│   └── detail/
│       ├── detail.js
│       ├── detail.json
│       ├── detail.wxml
│       └── detail.wxss
├── components/     # 自定义组件
├── utils/          # 工具函数
└── project.config.json  # 项目配置
```

## 2. 全局配置 app.json

```json
{
  "pages": [
    "pages/index/index",
    "pages/list/list",
    "pages/detail/detail",
    "pages/mine/mine"
  ],
  "window": {
    "navigationBarTitleText": "光阴小栈",
    "navigationBarBackgroundColor": "#2d8cf0",
    "navigationBarTextStyle": "white",
    "backgroundColor": "#f5f5f5",
    "enablePullDownRefresh": false
  },
  "tabBar": {
    "color": "#999",
    "selectedColor": "#2d8cf0",
    "list": [
      {
        "pagePath": "pages/index/index",
        "text": "首页",
        "iconPath": "images/home.png",
        "selectedIconPath": "images/home-active.png"
      },
      {
        "pagePath": "pages/mine/mine",
        "text": "我的",
        "iconPath": "images/mine.png",
        "selectedIconPath": "images/mine-active.png"
      }
    ]
  }
}
```

## 3. 页面生命周期

```javascript
// pages/index/index.js
Page({
  data: {
    articles: [],
    loading: false,
    page: 1
  },

  // 页面加载（只执行一次）
  onLoad(options) {
    console.log('页面参数:', options)
    this.loadArticles()
  },

  // 页面显示（每次切换回来都会触发）
  onShow() {
    console.log('页面显示')
  },

  // 页面初次渲染完成
  onReady() {
    console.log('页面渲染完成')
  },

  // 页面隐藏
  onHide() {
    console.log('页面隐藏')
  },

  // 页面卸载
  onUnload() {
    console.log('页面卸载')
  },

  // 下拉刷新
  onPullDownRefresh() {
    this.setData({ page: 1 })
    this.loadArticles().then(() => {
      wx.stopPullDownRefresh()
    })
  },

  // 触底加载更多
  onReachBottom() {
    this.setData({ page: this.data.page + 1 })
    this.loadMoreArticles()
  },

  // 自定义方法
  loadArticles() {
    this.setData({ loading: true })
    return new Promise((resolve) => {
      wx.request({
        url: 'https://api.example.com/articles',
        data: { page: this.data.page },
        success: (res) => {
          this.setData({
            articles: res.data.list,
            loading: false
          })
          resolve()
        }
      })
    })
  }
})
```

## 4. 数据绑定与模板语法

小程序模板语法（WXML）和 Vue 模板有相似之处，但也有不少差异：

```html
<!-- 数据绑定用双花括号 -->
<view class="article-card">
  <text>{{ title }}</text>
  <text>阅读量: {{ readCount }}</text>
</view>

<!-- 条件渲染 -->
<view wx:if="{{ status === 'loading' }}">加载中...</view>
<view wx:elif="{{ status === 'empty' }}">暂无数据</view>
<view wx:else>
  <!-- 列表渲染 -->
  <view wx:for="{{ articles }}" wx:key="id" wx:for-item="article">
    <text>{{ index + 1 }}. {{ article.title }}</text>
    <text class="date">{{ article.date }}</text>
  </view>
</view>

<!-- 事件绑定用 bind / catch -->
<button bindtap="handleSubmit">提交</button>
<button catchtap="handleCancel">取消（阻止冒泡）</button>

<!-- 双向绑定（简易） -->
<input model:value="{{ inputValue }}" placeholder="请输入" />
```

## 5. 网络请求封装

```javascript
// utils/request.js
const BASE_URL = 'https://api.example.com'

function request({ url, method = 'GET', data = {} }) {
  return new Promise((resolve, reject) => {
    wx.showLoading({ title: '加载中' })

    wx.request({
      url: `${BASE_URL}${url}`,
      method,
      data,
      header: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${wx.getStorageSync('token')}`
      },
      success(res) {
        if (res.statusCode === 200) {
          resolve(res.data)
        } else if (res.statusCode === 401) {
          // token 过期，跳转登录
          wx.redirectTo({ url: '/pages/login/login' })
          reject(new Error('未授权'))
        } else {
          wx.showToast({ title: '请求失败', icon: 'none' })
          reject(new Error(res.data.message || '请求失败'))
        }
      },
      fail(err) {
        wx.showToast({ title: '网络异常', icon: 'none' })
        reject(err)
      },
      complete() {
        wx.hideLoading()
      }
    })
  })
}

// 导出快捷方法
module.exports = {
  get: (url, data) => request({ url, method: 'GET', data }),
  post: (url, data) => request({ url, method: 'POST', data }),
  put: (url, data) => request({ url, method: 'PUT', data }),
  del: (url, data) => request({ url, method: 'DELETE', data })
}
```

## 6. 自定义组件

小程序支持组件化开发：

```javascript
// components/article-card/article-card.js
Component({
  properties: {
    title: { type: String, value: '' },
    date: { type: String, value: '' },
    cover: { type: String, value: '' },
    readCount: { type: Number, value: 0 }
  },
  data: {
    liked: false
  },
  methods: {
    onTapCard() {
      this.triggerEvent('tap', { title: this.properties.title })
    },
    onToggleLike() {
      this.setData({ liked: !this.data.liked })
      this.triggerEvent('like', { liked: this.data.liked })
    }
  }
})
```

```html
<!-- components/article-card/article-card.wxml -->
<view class="card" bindtap="onTapCard">
  <image class="cover" src="{{ cover }}" mode="aspectFill" />
  <view class="info">
    <text class="title">{{ title }}</text>
    <view class="meta">
      <text class="date">{{ date }}</text>
      <text class="read">{{ readCount }} 阅读</text>
    </view>
  </view>
  <view class="like {{ liked ? 'active' : '' }}" catchtap="onToggleLike">
    ♥
  </view>
</view>
```

使用组件前需要在页面的 JSON 中注册：

```json
{
  "usingComponents": {
    "article-card": "/components/article-card/article-card"
  }
}
```

## 7. 本地存储

```javascript
// 同步存储（适合轻量数据）
wx.setStorageSync('userInfo', { name: 'Tom', id: 1 })
const user = wx.getStorageSync('userInfo')
wx.removeStorageSync('userInfo')

// 异步存储（适合较大数据，不阻塞 UI）
wx.setStorage({
  key: 'historyList',
  data: historyArray,
  success() {
    console.log('保存成功')
  }
})
```

## 8. 常用 API 速查

```javascript
// 页面跳转
wx.navigateTo({ url: '/pages/detail/detail?id=123' })  // 保留当前页
wx.redirectTo({ url: '/pages/login/login' })             // 关闭当前页
wx.switchTab({ url: '/pages/index/index' })               // 切换 Tab
wx.navigateBack({ delta: 1 })                             // 返回上一页

// 用户交互
wx.showToast({ title: '操作成功', icon: 'success' })
wx.showModal({
  title: '提示',
  content: '确定要删除吗？',
  success(res) {
    if (res.confirm) console.log('用户点击确定')
  }
})
wx.showActionSheet({
  itemList: ['拍照', '从相册选择'],
  success(res) {
    console.log('选择了:', res.tapIndex)
  }
})

// 获取系统信息
const sysInfo = wx.getSystemInfoSync()
console.log('屏幕宽度:', sysInfo.windowWidth)
console.log('系统:', sysInfo.platform)
```

小程序的开发体验和 Web 前端有不少共通之处，掌握了上述基础知识后，结合微信开发者文档就可以开始实际项目开发了。
