---
title: MongoDB 常用的增删改查语法备忘
date: 2017-03-27 15:07:03
tags:
  - MongoDB
  - NoSQL
categories: MongoDB
---

平时写点简单的 Node.js 后端，或者接个小活，一般我都习惯顺手拿 MongoDB 当数据库。毕竟直接存 JSON 格式太符合前端的直觉了，不用像 MySQL 那样提前建好表结构。

但每次写查询语句，那些带 `$` 符号的操作符过一段时间不写就容易搞混。干脆整理个速查表，下次直接过来抄代码。

<!--more-->

## 1. 库和表（集合）的基础操作

刚连上控制台（`mongosh`），最常敲的几个命令：

```javascript
show dbs                     // 看看有哪些库
use my_database              // 切换进去。如果是新库也没事，存第一条数据时就自动建了
show collections             // 看看当前库里有哪些表（集合）
db.users.drop()              // 直接把 users 表删了（跑路专用）
```

## 2. 存数据（Create）

写数据最简单，丢个对象进去就行：

```javascript
// 塞一条进去
db.users.insertOne({
  name: "张三",
  age: 24,
  tags: ["前端", "摸鱼"],
  createAt: new Date()
});

// 一口气塞多条
db.users.insertMany([
  { name: "李四", age: 28 },
  { name: "王五", age: 32 }
]);
```

## 3. 查数据（Read）

查询的花样最多，也是最容易忘的地方：

```javascript
// 1. 无脑查全部
db.users.find()

// 2. 精确查找
db.users.find({ name: "张三" })

// 3. 那些恶心的大于小于符号
// $gt (大), $gte (大等), $lt (小), $lte (小等), $ne (不等)
db.users.find({ age: { $gt: 20 } })           // 大于20岁
db.users.find({ age: { $gte: 20, $lte: 30 } }) // 20到30岁之间

// 4. 多条件拼接 ($or, $and, $in)
db.users.find({ $or: [{ age: 24 }, { name: "李四" }] })
db.users.find({ age: { $in: [24, 28, 32] } }) // 在数组里就行

// 5. 模糊搜索（直接写正则，不用啥 like）
db.users.find({ name: /张/ })     // 名字带“张”的

// 6. 我只想要某几个字段，别全给我返回（省带宽）
// 1 是要，0 是不要。_id 默认会给，所以一般显式关掉
db.users.find({}, { name: 1, age: 1, _id: 0 }) 

// 7. 排序（1 是从小到大，-1 是从大到小）
db.users.find().sort({ age: -1 })

// 8. 经典的分页写法
db.users.find().skip(10).limit(5) // 跳过前10条，拿5条

// 9. 查总数
db.users.countDocuments({ age: { $gt: 20 } }) 
```

## 4. 改数据（Update）

改数据要小心，忘了加条件或者没加 `$set`，很容易把别的字段给覆盖没了。

```javascript
// 改一条，记得用 $set，不然整条记录就被替换成 {age: 25} 了
db.users.updateOne(
  { name: "张三" },
  { $set: { age: 25 } }
);

// 满足条件的批量全改了
db.users.updateMany(
  { age: { $lt: 20 } },
  { $set: { status: "未成年" } }
);

// 想让数字自己往上加，不用先查出来再存，直接用 $inc
db.users.updateOne(
  { name: "张三" },
  { $inc: { viewCount: 1 } } // 阅读量自动+1
);
```

## 5. 删数据（Delete）

跟改数据差不多：

```javascript
// 删第一条匹配的
db.users.deleteOne({ name: "张三" })

// 匹配的全干掉
db.users.deleteMany({ age: { $lt: 18 } })
```

## 6. 加点索引（Index）

数据量上了几万条之后，要是经常按某个字段查，查起来就会很慢，这时候就得建索引。

```javascript
// 按名字建个普通索引（1 升序，-1 降序无所谓，单字段都可以）
db.users.createIndex({ name: 1 })

// 复合索引：经常组合查询的字段建在一起
db.users.createIndex({ age: 1, createAt: -1 })

// 唯一索引：比如注册邮箱，强制不准重复
db.users.createIndex({ email: 1 }, { unique: true })

// 看看现在的索引有哪些
db.users.getIndexes()
```

其实业务不大、就几千上万条记录的时候，连索引都不用管，随便查速度也够快了。上面这些基本上能覆盖日常开发 80% 的需求，剩下的复杂聚合（aggregate）还是等遇到实在没招了再去翻文档吧。
