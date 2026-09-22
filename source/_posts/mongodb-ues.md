---
title: MongoDB学习笔记
date: 2017-03-27 15:07:03
tags:
  - MongoDB
  - NoSQL
categories: MongoDB
---

整理了 MongoDB / `mongosh` 开发中最常用的基础命令、CRUD 查询、聚合分页以及索引优化操作速查。

<!--more-->

## 1. 基础服务与数据库操作

```javascript
// 帮助命令
help                         // 查看系统级帮助
db.help()                    // 查看当前数据库方法帮助
db.colName.help()            // 查看集合方法帮助

// 数据库切换与查看
show dbs                     // 列出所有数据库
use my_database              // 切换到指定数据库（不存在时，插入第一条数据时自动创建）
db.getName()                 // 查看当前所在数据库名称
db.stats()                   // 查看当前数据库的存储状态与统计信息
db.dropDatabase()            // 删除当前数据库
```

## 2. 集合（Collection）管理

```javascript
show collections             // 查看当前库下的所有集合（或 show tables）
db.createCollection("users") // 显式创建名为 users 的集合
db.users.drop()              // 删除 users 集合
```

## 3. 文档插入（Create）

```javascript
// 插入单条文档
db.users.insertOne({
  name: "张三",
  age: 24,
  tags: ["javascript", "mongodb"],
  createAt: new Date()
});

// 批量插入多条文档
db.users.insertMany([
  { name: "李四", age: 28 },
  { name: "王五", age: 32 }
]);
```

## 4. 文档查询（Read / Retrieve）

```javascript
// 1. 查询全部
db.users.find()

// 2. 精确匹配查询
db.users.find({ name: "张三" })

// 3. 比较操作符 ($gt, $gte, $lt, $lte, $ne)
db.users.find({ age: { $gt: 20 } })           // age > 20
db.users.find({ age: { $gte: 20, $lte: 30 } }) // 20 <= age <= 30

// 4. 逻辑操作符 ($or, $and, $in)
db.users.find({ $or: [{ age: 24 }, { name: "李四" }] })
db.users.find({ age: { $in: [24, 28, 32] } })

// 5. 正则模糊匹配
db.users.find({ name: /张/ })     // 匹配包含 "张" 的记录
db.users.find({ name: /^张/ })    // 匹配以 "张" 开头的记录

// 6. 字段投影（指定返回/排除的字段，_id 默认包含）
db.users.find({}, { name: 1, age: 1, _id: 0 }) // 仅返回 name 和 age 字段

// 7. 排序（1 为升序，-1 为降序）
db.users.find().sort({ age: 1 })

// 8. 分页（limit 限制条数，skip 跳过条数）
db.users.find().skip(10).limit(5) // 获取第 3 页数据（每页 5 条）

// 9. 查询首条与计数
db.users.findOne({ name: "张三" })
db.users.countDocuments({ age: { $gt: 20 } }) // 统计满足条件的文档数量
```

## 5. 文档更新（Update）

```javascript
// 更新单条满足条件的文档 ($set 保留其他字段)
db.users.updateOne(
  { name: "张三" },
  { $set: { age: 25 } }
);

// 批量更新多条
db.users.updateMany(
  { age: { $lt: 20 } },
  { $set: { status: "minor" } }
);

// 自增/自减操作符 ($inc)
db.users.updateOne(
  { name: "张三" },
  { $inc: { age: 1 } } // age 自动 +1
);
```

## 6. 文档删除（Delete）

```javascript
// 删除满足条件的第一条数据
db.users.deleteOne({ name: "张三" })

// 批量删除所有满足条件的数据
db.users.deleteMany({ age: { $lt: 18 } })
```

## 7. 索引管理（Index）

合理的索引可以极大地提升海量数据下的查询性能：

```javascript
// 1. 创建单字段索引（1 升序，-1 降序）
db.users.createIndex({ name: 1 })

// 2. 创建复合索引
db.users.createIndex({ age: 1, createAt: -1 })

// 3. 创建唯一索引（防止字段重复插入）
db.users.createIndex({ email: 1 }, { unique: true })

// 4. 查看当前集合的所有索引
db.users.getIndexes()

// 5. 查看索引总占用空间
db.users.totalIndexSize()

// 6. 删除指定索引
db.users.dropIndex("name_1")

// 7. 删除集合所有自定义索引
db.users.dropIndexes()
```
