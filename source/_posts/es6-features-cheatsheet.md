---
title: 写了三年 ES6+，盘点那些容易被忽视的性能陷阱与优雅写法
date: 2018-11-20 09:45:33
tags:
  - JavaScript
  - ES6
  - 性能优化
categories: 前端
---

ES6 (ECMAScript 2015) 发布到现在差不多三年多了，箭头函数、解构赋值、Promise 大家都已经用得飞起。

但在 Code Review 的时候，我经常发现很多同学只是在用新语法写老逻辑，甚至有时候滥用新语法，写出了性能堪忧、内存泄漏的代码。今天不背语法书，纯粹从实战角度，盘点一下咱们平时写 ES6+ 容易踩进去的那些“坑”，以及到底怎么写才算优雅。

<!-- more -->

## 1. 箭头函数不是万能的：别丢了你的 `this`

箭头函数解决了令人头疼的 `this` 指向问题，因为它不绑定 `this`，而是直接捕获词法作用域。但滥用箭头函数同样会引发灾难。

**典型的反面教材：Vue/React 组件中的方法定义**

在早期的 Vue 中，如果你把生命周期或者 methods 写成箭头函数：
```javascript
export default {
  data() {
    return { count: 0 }
  },
  mounted: () => {
    // 💥 这里的 this 是 undefined (或者 window)！直接报错
    this.count++; 
  }
}
```

**另一个坑：给 DOM 绑定事件**

```javascript
const button = document.getElementById('myButton');
button.addEventListener('click', () => {
  // 💥 这里的 this 不再是 button 元素，拿不到 this.id
  console.log(this.id); 
});
```
**建议**：只有在真正需要保留外层 `this` 上下文时（比如 `setTimeout` 的回调、数组的 `map`/`filter` 回调），才去使用箭头函数。对于对象方法，规范地写普通的函数。

## 2. 闭包与 `let/const`：不要再在循环里造垃圾了

`let` 和 `const` 带来了块级作用域（Block Scope），大家都知道要用来替换 `var`。但在循环里，处理不当会造成严重的内存问题。

看看下面这段代码：
```javascript
for (let i = 0; i < 10000; i++) {
  const processItem = () => {
    console.log(i);
  };
  processItem();
}
```
因为 `let i` 是块级作用域，引擎会在每次循环时，都为这一个迭代创建一个全新的环境（Environment Record）。如果在循环体内部还生成了函数（闭包），会导致每次循环的对象都无法被垃圾回收，极大消耗内存。

**优雅写法**：如果循环内不需要强行保留作用域快照，尽量把函数定义提到循环外部，通过传参解决。

## 3. 解构赋值陷阱：小心深层解构导致的崩溃

解构赋值是个好东西，能大幅减少代码量。但如果服务端返回的数据结构不稳定，深层解构就是定时炸弹。

```javascript
const response = { code: 200, data: null };

// 💥 如果 data 是 null 或者 undefined，这里直接抛出 TypeError 阻断程序
const { data: { user: { name } } } = response; 
```

**优雅方案**：结合 ES2020 的可选链（Optional Chaining `?.`）和默认值，不要过度使用多层解构。

```javascript
// 更安全的写法
const name = response.data?.user?.name || '匿名用户';
```
如果非要在函数参数里做默认解构，记得给外层也赋默认值：
```javascript
function renderUser({ name = 'Unknown', age = 0 } = {}) {
  // ...
}
```

## 4. `Spread Operator` (...扩展运算符) 的性能危机

扩展运算符是一种非常高效的语法，合并数组、克隆对象非常便捷：
```javascript
const newObj = { ...oldObj, newProp: 1 };
```

但请记住，**这只是浅拷贝**。而且在处理巨大数组时，扩展运算符是有严重性能瓶颈的。

比如要把一个大数组推入另一个数组：
```javascript
// 假设 bigArray 有 10 万条数据
const arr = [1, 2, 3];
arr.push(...bigArray); 
```
这个操作会把 `bigArray` 完全解构成参数列表，极容易触发引擎的 `Maximum call stack size exceeded`（调用栈溢出）。

**性能更好的写法**：规范地用原生的方式。
```javascript
// 没有栈溢出风险
bigArray.forEach(item => arr.push(item));
// 或者
Array.prototype.push.apply(arr, bigArray); // 注意，apply 也有参数个数限制风险
```

## 5. `Array.from()` 和 `Set` 的奇妙化学反应

数组去重以前大家喜欢写两层 `for` 循环，现在有了 `Set`，一句话搞定：
```javascript
const uniqueArr = [...new Set([1, 1, 2, 3, 3])];
```
但你知道吗，对于某些特定的类数组对象（比如巨大的 NodeList），使用 `Array.from()` 会比 `[...iterable]` 稍微快那么一点，因为引擎对 `Array.from` 的内置优化做得更好，并且它可以直接接收一个 `map` 函数。

```javascript
// 直接在一个方法里完成去重和映射，性能更好，少生成一次中间数组
const mappedUnique = Array.from(new Set(arr), x => x * 2);
```

## 总结

ES6+ 带来了极强的表现力，让 JS 变得像一门“现代语言”。但在使用任何语法糖之前，多问自己一句：这行代码在 V8 引擎眼里，到底被转换成了什么？

只有深刻理解了闭包、作用域链、引用传递，你才能把新语法写得真正“优雅”，而不是给后人留下一堆跑不动的历史包袱。
