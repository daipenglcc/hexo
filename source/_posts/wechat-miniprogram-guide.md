---
title: 微信小程序开发避坑录：从零搞个能跑的项目
date: 2019-10-25 11:20:35
tags:
  - 小程序
  - 微信
categories: 小程序
---

前端干久了，难免会被老板抓壮丁去搞微信小程序。一开始以为这玩意儿就是套了壳的 Vue，真上手去官网下了个开发者工具才发现，它的标签语法、生命周期甚至连 CSS 名字（WXSS）全是一套独立的体系，搞得人晕头转向。

跌跌撞撞总算摸透了它最基础的套路，整理了一份傻瓜式的入门笔记，下次再有新项目要开荒，直接拿这篇来抄作业就行了。

<!-- more -->

## 1. 长什么样？文件结构摸底

一个小程序页面，不想 Vue 那样全写在 `.vue` 一个文件里，它非要拆成四个文件，强迫症看着是挺整齐的：

```
├── app.js          # 全局的老大，小程序一启动就跑这里
├── app.json        # 配置文件，全屋的装修风格都在这定（比如底部导航栏）
├── app.wxss        # 全局公共样式
├── pages/
│   ├── index/      # 首页
│   │   ├── index.js      # 写 JS 逻辑的
│   │   ├── index.json    # 这页单独的配置（比如改个标题）
│   │   ├── index.wxml    # 就是 HTML
│   │   └── index.wxss    # 就是 CSS
```

## 2. 第一关：把底部导航栏（TabBar）搞出来

通常做个 App 第一步就是配底下那几个按钮，去全局的 `app.json` 里面加个 `tabBar` 节点就行了，图片自己去下点小 icon 扔进去：

```json
{
  "pages": [
    "pages/index/index",
    "pages/mine/mine"
  ],
  "tabBar": {
    "color": "#999999",
    "selectedColor": "#1296db",
    "list": [
      {
        "pagePath": "pages/index/index",
        "text": "大厅",
        "iconPath": "images/home.png",
        "selectedIconPath": "images/home-active.png"
      },
      {
        "pagePath": "pages/mine/mine",
        "text": "我的",
        "iconPath": "images/user.png",
        "selectedIconPath": "images/user-active.png"
      }
    ]
  }
}
```

## 3. 第二关：页面怎么写？（WXML vs HTML）

忘了你的 `<div>` 和 `<span>` 吧，微信不吃这一套，他们自己造了词：
- `<div>` 变成了 `<view>`
- `<span>` 变成了 `<text>`
- `<img>` 变成了 `<image>`

写数据绑定的时候倒是很亲切，也是双花括号，但有些细节极其容易踩坑：

```html
<!-- 插变量一样是两片大括号 -->
<view>{{ title }}</view>

<!-- 循环渲染（注意 wx:key 不用加大括号了） -->
<view wx:for="{{ list }}" wx:key="id" wx:for-item="item">
  {{ index }} - {{ item.name }}
</view>

<!-- 点击事件，不用 @click，得用 bindtap -->
<button bindtap="handleClick">点我一下</button>
<!-- 如果你想阻止事件冒泡往上传递，用 catchtap -->
<button catchtap="handleStop">点我，但我不会通知父元素</button>
```

## 4. 第三关：数据怎么变？（让人头疼的 setData）

这是从 Vue 转过来最难受的地方。Vue 里 `this.name = '铁柱'` 页面就更新了，在小程序里，你这样改页面理都不理你，必须老老实实用原生的 `setData`：

```javascript
Page({
  // 数据全放这里
  data: {
    message: '你好',
    count: 0
  },

  handleClick() {
    // ❌ 错误示范：这样写数据变了，但页面不会变
    // this.data.count = 1 

    // ✅ 正确姿势：只能用 setData 通知它
    this.setData({
      count: this.data.count + 1,
      message: '我被点击了'
    })
  }
})
```

## 5. 第四关：网络请求怎么发？

小程序里没有内置 `axios`，发请求用它自带的 `wx.request`，写法很古老，一般我会自己用 Promise 粗略封装一层扔在 `utils/request.js` 里：

```javascript
const BASE_URL = 'https://api.mywebsite.com'

export function request(url, method = 'GET', data = {}) {
  return new Promise((resolve, reject) => {
    // 顺手搞个加载中动画
    wx.showLoading({ title: '拼命加载中...' })

    wx.request({
      url: BASE_URL + url,
      method: method,
      data: data,
      header: {
        // 比如在这里塞个登录 Token 啥的
        'Authorization': 'Bearer ' + wx.getStorageSync('token')
      },
      success: (res) => {
        if (res.statusCode === 200) {
          resolve(res.data)
        } else {
          wx.showToast({ title: '出错了兄弟', icon: 'none' })
          reject(res)
        }
      },
      complete: () => {
        wx.hideLoading() // 完事了把动画关掉
      }
    })
  })
}
```
然后在页面里就可以舒服地用了：
```javascript
import { request } from '../../utils/request'

Page({
  async onLoad() {
    // 现在支持 async/await 了，写起来爽得多
    const res = await request('/articles', 'GET')
    this.setData({ list: res.data })
  }
})
```

## 6. 一些高频 API 速查

经常用到，但我脑子经常短路忘掉拼写的几个 API：

```javascript
// 页面怎么跳？
wx.navigateTo({ url: '/pages/detail/detail?id=123' })  // 普通跳转，左上角能点返回
wx.redirectTo({ url: '/pages/login/login' })             // 重定向，回不去了
wx.switchTab({ url: '/pages/index/index' })               // 跳到底部导航栏的页面，必须用这个！

// 弹个窗
wx.showToast({ title: '搞定了', icon: 'success' })

// 存点本地数据（比如历史记录）
wx.setStorageSync('searchHistory', ['Vue', 'React'])
const history = wx.getStorageSync('searchHistory')
```

总结下来，小程序的门槛其实不高，只要你习惯了它那套 `setData` 和不按套路出牌的 HTML 标签，基本上写两天就能熟练干活了。不说了，去对付老板的新需求了。
