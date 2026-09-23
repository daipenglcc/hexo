---
title: 用 Node.js 撸一个简单的 RESTful API
date: 2022-06-18 14:30:55
tags:
  - Node
  - Express
  - RESTful
categories: Node
---

平时写前端，有时候总得自己折腾点后端接口。用 Node.js 搭配 Express 算是比较顺手的方案，轻量又好上手。这几天正好又帮朋友写了个博客的增删改查接口，顺便把整个流程记录一下，以后要用的时候可以直接拿来抄。

<!-- more -->

## 1. 建目录和装依赖

先随便建个文件夹，把该装的包都装上：

```bash
mkdir blog-api && cd blog-api
npm init -y
npm i express mongoose dotenv cors helmet morgan
npm i -D nodemon
```

在 `package.json` 里加个启动脚本，方便本地开发热更新：

```json
{
  "scripts": {
    "dev": "nodemon src/app.js",
    "start": "node src/app.js"
  }
}
```

项目结构大概弄成这样，看着清楚点：

```text
blog-api/
├── src/
│   ├── app.js              # 入口
│   ├── config/
│   │   └── db.js           # 连数据库的
│   ├── models/
│   │   └── Article.js      # 数据表模型
│   ├── routes/
│   │   └── articles.js     # 路由配置
│   ├── controllers/
│   │   └── articleController.js  # 具体的业务逻辑
│   └── middleware/
│       └── errorHandler.js  # 统一处理报错
├── .env
└── package.json
```

## 2. 搞定入口文件

`app.js` 主要是把各种中间件挂载上去，顺便配个路由。

```javascript
// src/app.js
const express = require('express')
const cors = require('cors')
const helmet = require('helmet')
const morgan = require('morgan')
const connectDB = require('./config/db')
const articleRoutes = require('./routes/articles')
const errorHandler = require('./middleware/errorHandler')

require('dotenv').config()

const app = express()
const PORT = process.env.PORT || 3000

// 连一下数据库
connectDB()

// 一堆常规中间件
app.use(helmet())           // 加点安全头
app.use(cors())             // 允许跨域
app.use(morgan('dev'))      // 打印请求日志
app.use(express.json())     // 接收 JSON 数据
app.use(express.urlencoded({ extended: true }))

// 挂载路由
app.use('/api/articles', articleRoutes)

// 写个探针，方便以后部署检测存活
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() })
})

// 处理乱请求的 404
app.use((req, res) => {
  res.status(404).json({ error: '接口不存在' })
})

// 兜底的错误处理
app.use(errorHandler)

app.listen(PORT, () => {
  console.log(`服务器跑起来了：http://localhost:${PORT}`)
})
```

## 3. 连数据库

我习惯用 MongoDB，这里搞个简单的连接文件。

```javascript
// src/config/db.js
const mongoose = require('mongoose')

const connectDB = async () => {
  try {
    const conn = await mongoose.connect(process.env.MONGO_URI, {
      useNewUrlParser: true,
      useUnifiedTopology: true
    })
    console.log(`MongoDB 连上了: ${conn.connection.host}`)
  } catch (error) {
    console.error(`数据库连不上，是不是服务没起: ${error.message}`)
    process.exit(1)
  }
}

module.exports = connectDB
```

别忘了在根目录建个 `.env` 文件放配置：

```text
PORT=3000
MONGO_URI=mongodb://localhost:27017/blog
```

## 4. 定义数据模型

文章的数据结构，Mongoose 写起来还挺像 TypeScript 的：

```javascript
// src/models/Article.js
const mongoose = require('mongoose')

const articleSchema = new mongoose.Schema({
  title: {
    type: String,
    required: [true, '标题总得填一下吧'],
    trim: true,
    maxlength: [100, '标题别太长']
  },
  content: {
    type: String,
    required: [true, '内容不能为空']
  },
  category: {
    type: String,
    enum: ['技术', '生活', '随笔'],
    default: '技术'
  },
  tags: {
    type: [String],
    default: []
  },
  viewCount: {
    type: Number,
    default: 0
  },
  published: {
    type: Boolean,
    default: false
  }
}, {
  timestamps: true   // 这个省事，自动加 createdAt 和 updatedAt
})

module.exports = mongoose.model('Article', articleSchema)
```

## 5. 撸控制器逻辑

把增删改查抽出来写，免得路由文件太乱。

```javascript
// src/controllers/articleController.js
const Article = require('../models/Article')

// 查列表，顺便做下分页
exports.getArticles = async (req, res, next) => {
  try {
    const { page = 1, limit = 10 } = req.query
    const query = { published: true }

    const skip = (parseInt(page) - 1) * parseInt(limit)
    const total = await Article.countDocuments(query)

    const articles = await Article
      .find(query)
      .select('-content')     // 列表页就别查正文了，费带宽
      .sort('-createdAt')
      .skip(skip)
      .limit(parseInt(limit))

    res.json({
      data: articles,
      pagination: {
        page: parseInt(page),
        total,
        pages: Math.ceil(total / parseInt(limit))
      }
    })
  } catch (error) {
    next(error)
  }
}

// 查详情
exports.getArticle = async (req, res, next) => {
  try {
    const article = await Article.findById(req.params.id)
    if (!article) return res.status(404).json({ error: '找不到这篇文章' })
    
    // 顺手增加下阅读量
    article.viewCount += 1
    await article.save()

    res.json({ data: article })
  } catch (error) {
    next(error)
  }
}

// 新增
exports.createArticle = async (req, res, next) => {
  try {
    const article = await Article.create(req.body)
    res.status(201).json({ data: article })
  } catch (error) {
    next(error)
  }
}

// 修改
exports.updateArticle = async (req, res, next) => {
  try {
    const article = await Article.findByIdAndUpdate(
      req.params.id,
      req.body,
      { new: true, runValidators: true }
    )
    if (!article) return res.status(404).json({ error: '找不到这篇文章' })
    res.json({ data: article })
  } catch (error) {
    next(error)
  }
}

// 删除
exports.deleteArticle = async (req, res, next) => {
  try {
    const article = await Article.findByIdAndDelete(req.params.id)
    if (!article) return res.status(404).json({ error: '找不到这篇文章' })
    res.json({ message: '删除了' })
  } catch (error) {
    next(error)
  }
}
```

## 6. 绑路由

有了控制器，路由文件就很干净了：

```javascript
// src/routes/articles.js
const express = require('express')
const router = express.Router()
const {
  getArticles, getArticle, createArticle, updateArticle, deleteArticle
} = require('../controllers/articleController')

router.route('/')
  .get(getArticles)
  .post(createArticle)

router.route('/:id')
  .get(getArticle)
  .put(updateArticle)
  .delete(deleteArticle)

module.exports = router
```

## 7. 兜一下报错

平时最烦的就是异常没捕获导致后端进程挂掉，加个全局中间件处理一下：

```javascript
// src/middleware/errorHandler.js
const errorHandler = (err, req, res, next) => {
  console.error('出错了：', err.stack)

  // 比如查了个不存在的 mongo id 格式
  if (err.name === 'CastError') {
    return res.status(400).json({ error: 'ID 格式不太对' })
  }

  res.status(err.statusCode || 500).json({
    error: err.message || '服务器闹脾气了'
  })
}

module.exports = errorHandler
```

## 简单测一下

用 `npm run dev` 跑起来，然后拿 curl 试两下：

```bash
# 新增
curl -X POST http://localhost:3000/api/articles \
  -H "Content-Type: application/json" \
  -d '{
    "title": "测试文章",
    "content": "测试内容...",
    "published": true
  }'

# 查列表
curl "http://localhost:3000/api/articles?page=1&limit=5"
```

这就算是个能用的基础架子了。自己平时写点内部小项目或者个人应用，这个结构足够了。等后面有需求，再往里面塞 JWT 认证之类的也比较好加。
