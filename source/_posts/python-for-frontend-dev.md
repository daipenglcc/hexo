---
title: AI 时代不会 Python 不行了？前端的速成笔记
date: 2024-03-18 14:20:35
tags:
  - Python
  - AI
  - 前端
categories: Python
---

去年 AI 火了以后，很多工具和教程都是 Python 的。想跑个本地模型要 Python，想调 OpenAI 的接口官方示例也是 Python，想建立一个数据分析还是 Python。作为一个写了好几年 JavaScript 的前端，终于还是没忍住学了一下。

这里不打算写一篇完整的 Python 教程，就记一下我作为 JS 开发者学 Python 过程中那些"跟 JS 不一样"的地方，以及一些快速上手的笔记。

<!-- more -->

## 1. 环境搭建

```bash
# macOS 自带 Python，但版本可能很旧
# 推荐用 brew 装
brew install python@3.11

# 验证
python3 --version
pip3 --version
```

**虚拟环境**这个概念在 JS 里没有（node_modules 天然就是项目级的），但 Python 需要手动搞：

```bash
# 创建虚拟环境（类似于给项目建个独立的 node_modules）
python3 -m venv myenv

# 激活
source myenv/bin/activate   # macOS/Linux
# myenv\Scripts\activate    # Windows

# 退出
deactivate
```

激活之后装的包只在当前虚拟环境里，不会污染全局。

## 2. 语法层面：跟 JS 的主要区别

### 缩进代替大括号

这个是最不习惯的。Python 用缩进来表示代码块，没有花括号。

```python
# Python
if score >= 90:
    print("优秀")
elif score >= 60:
    print("及格")
else:
    print("不及格")

# 对比 JS
# if (score >= 90) {
#     console.log("优秀")
# }
```

刚开始经常忘了加冒号，或者缩进弄乱了报 `IndentationError`。

### 变量和类型

```python
# 不用 let/const/var，直接赋值
name = "张三"
age = 25
is_active = True   # 注意是大写的 True/False，不是 true/false

# 类型标注（可选的，不写也行）
name: str = "张三"
age: int = 25
scores: list[int] = [90, 85, 78]
```

### 字符串

```python
# f-string，类似 JS 的模板字符串
name = "光阴小栈"
print(f"欢迎来到 {name}")

# 多行字符串用三引号
html = """
<div>
  <h1>Hello</h1>
</div>
"""
```

### 列表和字典

```python
# 列表 ≈ JS 的数组
fruits = ["apple", "banana", "cherry"]
fruits.append("orange")  # push
fruits.pop()              # pop
len(fruits)               # length

# 字典 ≈ JS 的对象
user = {
    "name": "张三",
    "age": 25,
    "skills": ["Python", "JavaScript"]
}
print(user["name"])      # 取值用方括号，不能用点号
user["email"] = "xxx"    # 添加/修改
```

### 列表推导式

Python 的一大特色，JS 里没有直接对应的语法：

```python
# 相当于 JS 的 [1,2,3,4,5].map(x => x * x)
squares = [x * x for x in range(1, 6)]
# [1, 4, 9, 16, 25]

# 带过滤，相当于 filter + map
even_squares = [x * x for x in range(10) if x % 2 == 0]
# [0, 4, 16, 36, 64]
```

### 函数

```python
def greet(name, greeting="你好"):
    """这是文档字符串，用来写函数说明"""
    return f"{greeting}, {name}!"

# 调用
print(greet("张三"))          # 你好, 张三!
print(greet("张三", "嗨"))    # 嗨, 张三!

# lambda 表达式（相当于 JS 的箭头函数）
add = lambda a, b: a + b
```

## 3. 包管理：pip ≈ npm

```bash
# 安装包
pip install requests        # npm install axios 的感觉

# 安装指定版本
pip install requests==2.28.0

# 导出依赖（相当于 package.json）
pip freeze > requirements.txt

# 从文件安装所有依赖
pip install -r requirements.txt
```

`requirements.txt` 就是 Python 的 `package.json`，不过简陋得多，就是一行行包名。

## 4. 前端最可能用到的场景

### 调 OpenAI 接口

```bash
pip install openai
```

```python
from openai import OpenAI

client = OpenAI(api_key="你的key")

response = client.chat.completions.create(
    model="gpt-3.5-turbo",
    messages=[
        {"role": "user", "content": "用一句话解释什么是闭包"}
    ]
)

print(response.choices[0].message.content)
```

### 写个简单的 HTTP 接口

```bash
pip install flask
```

```python
from flask import Flask, jsonify, request

app = Flask(__name__)

todos = []

@app.route('/api/todos', methods=['GET'])
def get_todos():
    return jsonify(todos)

@app.route('/api/todos', methods=['POST'])
def add_todo():
    data = request.get_json()
    todos.append(data)
    return jsonify({"message": "ok"}), 201

if __name__ == '__main__':
    app.run(debug=True, port=5000)
```

写起来确实比 Express 还简洁。

### 数据处理

```bash
pip install pandas
```

```python
import pandas as pd

# 读 CSV
df = pd.read_csv("data.csv")

# 看前几行
print(df.head())

# 筛选
active_users = df[df["status"] == "active"]

# 分组统计
stats = df.groupby("department")["salary"].mean()
print(stats)
```

## 5. 一些"差点被绊倒"的地方

- **没有 `===`**：Python 判等就用 `==`，没有严格等于的概念
- **None 不是 null**：Python 里空值叫 `None`，判断用 `is None` 而不是 `== None`
- **没有 `{}`**：空字典是 `{}`，但空集合是 `set()`，不是 `{}`
- **for 循环没有传统的 `for(i=0; i<n; i++)`**：用 `for i in range(n)` 代替
- **整数除法**：`7 / 2` 结果是 `3.5`，想要整数用 `7 // 2` 得到 `3`

## 6. 总结

作为一个前端开始学 Python，最大的感受是：**语法比 JS 简洁，但生态和工具链风格完全不同**。JS 的 npm 生态虽然混乱但足够丰富，Python 的包管理更原始一些（虚拟环境那套东西不如 node_modules 直观）。

不过在 AI 和数据处理这两个领域，Python 的库确实比 JS 成熟太多了。花几天时间学个基本语法，至少以后看到 Python 代码不会发怵，遇到 AI 相关的东西也能自己动手试了。
