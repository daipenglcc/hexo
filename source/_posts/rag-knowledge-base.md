---
title: 折腾 RAG：给大模型接个本地知识库
date: 2024-09-15 11:20:45
tags:
  - AI
  - RAG
  - LLM
  - 大模型
categories: AI
---

大模型平时拿来聊聊天确实好用，但一问到公司内部情况或者没公开的数据，它就开始胡编乱造了。RAG（检索增强生成）算是个比较稳妥的解决办法。最近简单摸索了一下这套东西，整理点基础的概念，算是个入门备忘。

<!-- more -->

## RAG 到底在干嘛

说白了，RAG 就是在让大模型回答之前，先帮它翻一下“资料库”。

```text
以前直接问大模型：
用户提问 → 大模型瞎编一个回答

现在用了 RAG：
用户提问 → 先从本地文档库里搜出几段相关的资料 → 把“资料+问题”一起喂给大模型 → 大模型看着资料给出准确回答
```

不用 RAG 的话，想让大模型懂你的数据就得去“微调”，那个成本太高了。RAG 就省事很多，把资料存进向量数据库就行。

## 大致的流程是怎样的

想要跑通 RAG，基本分两步走。

### 第一步：把资料存起来（建索引）

你得先把 PDF、Word 或者 Markdown 文档切碎，然后转成向量，存到库里。

```text
原始文档 → 切成小块文本 → 算成向量（Embedding） → 存入向量数据库
```

如果是用 Python，一般用 LangChain 写，伪代码大概长这样：

```python
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain.embeddings import OpenAIEmbeddings
from langchain.vectorstores import Chroma

# 1. 读文件
documents = load_documents("./docs/")

# 2. 把长文章切成小段，比如 500 个字一段
splitter = RecursiveCharacterTextSplitter(
    chunk_size=500,
    chunk_overlap=50
)
chunks = splitter.split_documents(documents)

# 3. 调接口转成向量，塞进 Chroma 这种本地库里
embeddings = OpenAIEmbeddings()
vectorstore = Chroma.from_documents(documents=chunks, embedding=embeddings)
```

### 第二步：搜资料并生成回答

有人提问的时候，拿着问题去库里找最相近的那几段话，然后连着问题一起发给大模型。

```python
from langchain.chat_models import ChatOpenAI
from langchain.chains import RetrievalQA

# 创建个检索器，找最像的 3 段话
retriever = vectorstore.as_retriever(search_kwargs={"k": 3})

# 把检索器和大模型绑在一起
qa_chain = RetrievalQA.from_chain_type(
    llm=ChatOpenAI(model="gpt-4", temperature=0),
    chain_type="stuff",
    retriever=retriever
)

# 直接问就行了
result = qa_chain({"query": "公司的年假怎么算的？"})
print(result["result"])
```

## 用 Node.js 怎么搞

我自己写前端多一点，其实拿 Node.js 也是能跑这套流程的。装几个 LangChain.js 的包就能干活。

```bash
npm i langchain @langchain/openai @langchain/community chromadb
```

写法跟 Python 差不多：

```javascript
import { ChatOpenAI, OpenAIEmbeddings } from '@langchain/openai'
import { Chroma } from '@langchain/community/vectorstores/chroma'
import { RecursiveCharacterTextSplitter } from 'langchain/text_splitter'
import { RetrievalQAChain } from 'langchain/chains'
import { TextLoader } from 'langchain/document_loaders/fs/text'
import { DirectoryLoader } from 'langchain/document_loaders/fs/directory'

// 读取目录下的 md 和 txt
const loader = new DirectoryLoader('./knowledge', {
  '.md': (path) => new TextLoader(path),
  '.txt': (path) => new TextLoader(path)
})
const docs = await loader.load()

// 切段
const splitter = new RecursiveCharacterTextSplitter({
  chunkSize: 500,
  chunkOverlap: 50
})
const chunks = await splitter.splitDocuments(docs)

// 存进库里
const embeddings = new OpenAIEmbeddings()
const vectorStore = await Chroma.fromDocuments(chunks, embeddings, {
  collectionName: 'my-knowledge'
})

// 提问
const llm = new ChatOpenAI({ modelName: 'gpt-4', temperature: 0 })
const chain = RetrievalQAChain.fromLLM(llm, vectorStore.asRetriever(3))

const response = await chain.call({
  query: '项目的部署流程是什么？'
})
console.log(response.text)
```

## 踩到的几个坑

实际玩了一下，发现 RAG 门槛虽然低，但要想回答得准，还是得费点功夫：

1. **切段大小很玄学**：一篇文章如果一刀切到底，搜出来的信息太乱；如果切得太细，一句话截断了，上下文连不起来。一般 500-1000 字符一块，留一点重叠比较稳。
2. **纯向量搜索不够看**：光靠向量算相似度有时候会有点偏，现在比较流行加上传统的关键词搜索（比如 BM25）混合起来用，能准不少。
3. **格式太乱影响解析**：如果文档里面全是奇奇怪怪的表格和图片，切出来喂给大模型的效果就很惨，所以文档的清洗整理其实是最费劲的。

总之，这套方案感觉挺实用，打算后面慢慢打磨一下，接个微信机器人给自己查资料用。
