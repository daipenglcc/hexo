---
title: Node.js 实战：从零搭建 RESTful API
date: 2022-06-18 14:30:55
tags:
  - Node
  - Express
  - RESTful
categories: Node
---

在前后端分离的架构下，后端提供 RESTful API，前端通过 HTTP 请求获取数据已经成为主流模式。对于前端开发者来说，用 Node.js + Express 搭建 API 服务是进入全栈开发最自然的路径。本文以一个博客文章管理接口为例，记录从零搭建 RESTful API 的完整过程。

<!-- more -->

## 1. 项目初始化

```bash
mkdir blog-api && cd blog-api
npm init -y
npm i express mongoose dotenv cors helmet morgan
npm i -D nodemon
```

```json
// package.json scripts
{
  "scripts": {
    "dev": "nodemon src/app.js",
    "start": "node src/app.js"
  }
}
```

项目结构：

```
blog-api/
├── src/
│   ├── app.js              # 应用入口
│   ├── config/
│   │   └── db.js           # 数据库连接
│   ├── models/
│   │   └── Article.js      # 数据模型
│   ├── routes/
│   │   └── articles.js     # 路由
│   ├── controllers/
│   │   └── articleController.js  # 控制器
│   └── middleware/
│       └── errorHandler.js  # 错误处理中间件
├── .env
└── package.json
```

## 2. 应用入口

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

// 连接数据库
connectDB()

// 中间件
app.use(helmet())           // 安全头
app.use(cors())             // 跨域
app.use(morgan('dev'))      // 请求日志
app.use(express.json())     // 解析 JSON body
app.use(express.urlencoded({ extended: true }))

// 路由
app.use('/api/articles', articleRoutes)

// 健康检查
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() })
})

// 404 处理
app.use((req, res) => {
  res.status(404).json({ error: '接口不存在' })
})

// 全局错误处理
app.use(errorHandler)

app.listen(PORT, () => {
  console.log(`🚀 服务器运行在 http://localhost:${PORT}`)
})
```

## 3. 数据库连接

```javascript
// src/config/db.js
const mongoose = require('mongoose')

const connectDB = async () => {
  try {
    const conn = await mongoose.connect(process.env.MONGO_URI, {
      useNewUrlParser: true,
      useUnifiedTopology: true
    })
    console.log(`📦 MongoDB 已连接: ${conn.connection.host}`)
  } catch (error) {
    console.error(`数据库连接失败: ${error.message}`)
    process.exit(1)
  }
}

module.exports = connectDB
```

```bash
# .env
PORT=3000
MONGO_URI=mongodb://localhost:27017/blog
```

## 4. 数据模型

```javascript
// src/models/Article.js
const mongoose = require('mongoose')

const articleSchema = new mongoose.Schema({
  title: {
    type: String,
    required: [true, '标题不能为空'],
    trim: true,
    maxlength: [100, '标题不能超过 100 个字符']
  },
  content: {
    type: String,
    required: [true, '内容不能为空']
  },
  summary: {
    type: String,
    maxlength: [200, '摘要不能超过 200 个字符']
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
  author: {
    type: String,
    default: '匿名'
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
  timestamps: true,   // 自动添加 createdAt / updatedAt
  toJSON: { virtuals: true },
  toObject: { virtuals: true }
})

// 虚拟字段
articleSchema.virtual('readTime').get(function () {
  const wordsPerMinute = 300
  const wordCount = this.content ? this.content.length : 0
  return Math.ceil(wordCount / wordsPerMinute)
})

// 索引
articleSchema.index({ title: 'text', content: 'text' })
articleSchema.index({ category: 1, createdAt: -1 })

module.exports = mongoose.model('Article', articleSchema)
```

## 5. 控制器

```javascript
// src/controllers/articleController.js
const Article = require('../models/Article')

// 获取文章列表（支持分页、筛选、搜索）
exports.getArticles = async (req, res, next) => {
  try {
    const {
      page = 1,
      limit = 10,
      category,
      tag,
      keyword,
      sort = '-createdAt'
    } = req.query

    // 构建查询条件
    const query = { published: true }

    if (category) query.category = category
    if (tag) query.tags = { $in: [tag] }
    if (keyword) {
      query.$or = [
        { title: { $regex: keyword, $options: 'i' } },
        { content: { $regex: keyword, $options: 'i' } }
      ]
    }

    const skip = (parseInt(page) - 1) * parseInt(limit)
    const total = await Article.countDocuments(query)

    const articles = await Article
      .find(query)
      .select('-content')     // 列表不返回正文
      .sort(sort)
      .skip(skip)
      .limit(parseInt(limit))

    res.json({
      data: articles,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / parseInt(limit))
      }
    })
  } catch (error) {
    next(error)
  }
}

// 获取单篇文章
exports.getArticle = async (req, res, next) => {
  try {
    const article = await Article.findById(req.params.id)

    if (!article) {
      return res.status(404).json({ error: '文章不存在' })
    }

    // 阅读量 +1
    article.viewCount += 1
    await article.save()

    res.json({ data: article })
  } catch (error) {
    next(error)
  }
}

// 创建文章
exports.createArticle = async (req, res, next) => {
  try {
    const article = await Article.create(req.body)
    res.status(201).json({ data: article })
  } catch (error) {
    if (error.name === 'ValidationError') {
      const messages = Object.values(error.errors).map(e => e.message)
      return res.status(400).json({ error: '数据校验失败', details: messages })
    }
    next(error)
  }
}

// 更新文章
exports.updateArticle = async (req, res, next) => {
  try {
    const article = await Article.findByIdAndUpdate(
      req.params.id,
      req.body,
      { new: true, runValidators: true }
    )

    if (!article) {
      return res.status(404).json({ error: '文章不存在' })
    }

    res.json({ data: article })
  } catch (error) {
    next(error)
  }
}

// 删除文章
exports.deleteArticle = async (req, res, next) => {
  try {
    const article = await Article.findByIdAndDelete(req.params.id)

    if (!article) {
      return res.status(404).json({ error: '文章不存在' })
    }

    res.json({ message: '删除成功' })
  } catch (error) {
    next(error)
  }
}
```

## 6. 路由

```javascript
// src/routes/articles.js
const express = require('express')
const router = express.Router()
const {
  getArticles,
  getArticle,
  createArticle,
  updateArticle,
  deleteArticle
} = require('../controllers/articleController')

router.route('/')
  .get(getArticles)       // GET    /api/articles
  .post(createArticle)    // POST   /api/articles

router.route('/:id')
  .get(getArticle)        // GET    /api/articles/:id
  .put(updateArticle)     // PUT    /api/articles/:id
  .delete(deleteArticle)  // DELETE /api/articles/:id

module.exports = router
```

## 7. 错误处理中间件

```javascript
// src/middleware/errorHandler.js
const errorHandler = (err, req, res, next) => {
  console.error('❌', err.stack)

  // Mongoose ObjectId 格式错误
  if (err.name === 'CastError') {
    return res.status(400).json({ error: '无效的 ID 格式' })
  }

  // Mongoose 唯一性约束
  if (err.code === 11000) {
    return res.status(400).json({ error: '数据重复' })
  }

  res.status(err.statusCode || 500).json({
    error: err.message || '服务器内部错误'
  })
}

module.exports = errorHandler
```

## 8. 接口测试

```bash
# 创建文章
curl -X POST http://localhost:3000/api/articles \
  -H "Content-Type: application/json" \
  -d '{
    "title": "第一篇文章",
    "content": "这是文章内容...",
    "category": "技术",
    "tags": ["Node.js", "Express"],
    "published": true
  }'

# 获取列表（分页 + 筛选）
curl "http://localhost:3000/api/articles?page=1&limit=5&category=技术"

# 搜索
curl "http://localhost:3000/api/articles?keyword=Node"

# 更新
curl -X PUT http://localhost:3000/api/articles/ID \
  -H "Content-Type: application/json" \
  -d '{"title": "更新后的标题"}'

# 删除
curl -X DELETE http://localhost:3000/api/articles/ID
```

这是一个结构清晰、可扩展的 RESTful API 起点。在此基础上可以继续添加用户认证（JWT）、文件上传、请求限流等功能。
