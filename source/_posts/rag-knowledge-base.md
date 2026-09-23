---
title: RAG 技术入门：为你的应用接入大模型知识库
date: 2024-09-15 11:20:45
tags:
  - AI
  - RAG
  - LLM
  - 大模型
categories: AI
---

大模型（LLM）虽然能力强大，但存在知识截止、幻觉以及无法访问私有数据等问题。RAG（Retrieval-Augmented Generation，检索增强生成）是目前解决这些问题最实用的方案——先从知识库中检索相关信息，再将检索结果作为上下文交给大模型生成回答。本文从原理到实现，记录 RAG 的入门实践。

<!-- more -->

## RAG 是什么

简单来说，RAG 在大模型回答问题之前，先"帮它查资料"：

```
传统 LLM:
  用户提问 → 大模型直接回答（可能过时或编造）

RAG 流程:
  用户提问 → 从知识库检索相关文档 → 将文档 + 问题一起交给大模型 → 生成有据可依的回答
```

### 为什么需要 RAG

| 问题 | 纯 LLM | RAG |
| :--- | :--- | :--- |
| 知识时效 | 训练数据有截止日期 | 可以接入最新文档 |
| 幻觉问题 | 可能编造答案 | 基于检索到的真实数据回答 |
| 私有数据 | 无法访问企业内部数据 | 可以索引企业知识库 |
| 成本 | 微调模型成本高 | 只需维护向量数据库 |
| 可解释性 | 黑盒输出 | 可以展示引用来源 |

## 核心流程

RAG 分为两个阶段：

### 阶段一：索引（Indexing）—— 构建知识库

```
原始文档 → 文本分割 → 向量化（Embedding） → 存入向量数据库
```

```python
# 伪代码示例
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain.embeddings import OpenAIEmbeddings
from langchain.vectorstores import Chroma

# 1. 加载文档
documents = load_documents("./docs/")  # PDF、Markdown、网页等

# 2. 文本分割
splitter = RecursiveCharacterTextSplitter(
    chunk_size=500,       # 每块 500 个字符
    chunk_overlap=50,     # 块之间重叠 50 个字符
    separators=["\n\n", "\n", "。", ".", " "]
)
chunks = splitter.split_documents(documents)

# 3. 向量化并存入数据库
embeddings = OpenAIEmbeddings()
vectorstore = Chroma.from_documents(
    documents=chunks,
    embedding=embeddings,
    persist_directory="./chroma_db"
)
```

### 阶段二：检索与生成（Retrieval & Generation）

```
用户提问 → 问题向量化 → 在向量数据库中检索相似文档 → 组装 Prompt → LLM 生成回答
```

```python
from langchain.chat_models import ChatOpenAI
from langchain.chains import RetrievalQA

# 加载已有的向量数据库
vectorstore = Chroma(
    persist_directory="./chroma_db",
    embedding_function=OpenAIEmbeddings()
)

# 创建检索器
retriever = vectorstore.as_retriever(
    search_type="similarity",
    search_kwargs={"k": 3}   # 检索最相关的 3 个文档块
)

# 创建问答链
qa_chain = RetrievalQA.from_chain_type(
    llm=ChatOpenAI(model="gpt-4", temperature=0),
    chain_type="stuff",       # 将所有检索结果拼接到 prompt 中
    retriever=retriever,
    return_source_documents=True  # 返回引用来源
)

# 提问
result = qa_chain({"query": "公司的年假制度是怎样的？"})
print(result["result"])
print("引用来源:", result["source_documents"])
```

## 3. 用 Node.js 实现简易 RAG

对于前端/Node.js 开发者，可以使用 LangChain.js：

```bash
npm i langchain @langchain/openai @langchain/community chromadb
```

```javascript
// rag-demo.js
import { ChatOpenAI, OpenAIEmbeddings } from '@langchain/openai'
import { Chroma } from '@langchain/community/vectorstores/chroma'
import { RecursiveCharacterTextSplitter } from 'langchain/text_splitter'
import { RetrievalQAChain } from 'langchain/chains'
import { TextLoader } from 'langchain/document_loaders/fs/text'
import { DirectoryLoader } from 'langchain/document_loaders/fs/directory'

// 1. 加载文档
const loader = new DirectoryLoader('./knowledge-base', {
  '.md': (path) => new TextLoader(path),
  '.txt': (path) => new TextLoader(path)
})
const docs = await loader.load()

// 2. 文本分割
const splitter = new RecursiveCharacterTextSplitter({
  chunkSize: 500,
  chunkOverlap: 50
})
const chunks = await splitter.splitDocuments(docs)

// 3. 创建向量存储
const embeddings = new OpenAIEmbeddings()
const vectorStore = await Chroma.fromDocuments(chunks, embeddings, {
  collectionName: 'my-knowledge-base'
})

// 4. 创建问答链
const llm = new ChatOpenAI({ modelName: 'gpt-4', temperature: 0 })
const chain = RetrievalQAChain.fromLLM(llm, vectorStore.asRetriever(3))

// 5. 提问
const response = await chain.call({
  query: '项目的部署流程是什么？'
})
console.log(response.text)
```

## 4. 关键概念解析

### 4.1 文本分割（Chunking）

分割策略直接影响检索质量：

```text
文档太大（整篇文章作为一块）：
  → 检索精度低，噪音多，浪费 Token

文档太小（按句子分割）：
  → 上下文断裂，语义不完整

推荐策略：
  → 500-1000 字符一块，块之间有 10-20% 重叠
  → 按段落或语义边界分割
```

### 4.2 向量化（Embedding）

将文本转换为高维数值向量，语义相似的文本在向量空间中距离更近：

```text
"Vue 组件通信" → [0.12, -0.34, 0.56, ...]  ← 512维或1536维向量
"React Props 传值" → [0.11, -0.33, 0.55, ...]  ← 语义相近，向量也相近
"今天天气真好" → [0.89, 0.23, -0.67, ...]  ← 语义不同，向量距离远
```

### 4.3 向量检索

通过计算问题向量与知识库中所有文档向量的相似度（余弦相似度），找到最相关的文档：

```text
用户问题: "如何配置 Nginx 的反向代理？"
   ↓ 向量化
   ↓ 在向量数据库中搜索最相似的文档块
   ↓
检索结果:
  1. [相似度 0.92] "Nginx 反向代理配置详解..."
  2. [相似度 0.87] "proxy_pass 参数说明..."
  3. [相似度 0.83] "Nginx location 匹配规则..."
```

## 5. 优化技巧

1. **混合检索**：结合关键词搜索（BM25）和向量语义搜索，取长补短
2. **重排序（Reranking）**：对初步检索结果用交叉编码器重新排序，提高精度
3. **元数据过滤**：给文档块添加元数据（来源、日期、分类），检索时可以按条件过滤
4. **查询改写**：用 LLM 将模糊的用户问题改写为更精确的检索查询

## 总结

RAG 是当前大模型应用中最实用的技术之一，门槛相对较低，适合开发者快速上手为自己的产品注入 AI 能力。
