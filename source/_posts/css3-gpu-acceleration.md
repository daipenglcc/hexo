---
title: CSS3 transform 的硬件加速：为什么 translateZ(0) 能让动画丝滑
date: 2014-06-08 16:45:22
tags:
  - CSS3
  - 性能优化
  - 动画
  - GPU
categories: CSS
---

做了个滑动菜单，用 `left` 属性做位移动画，在 PC 上还行，但在手机上打开，滑动明显掉帧。改成 `transform: translateX()` 之后，同样的动画立刻丝滑了。

为什么？这背后涉及到浏览器渲染流水线和 GPU 合成层的原理，值得深挖一下。

<!-- more -->

## 浏览器渲染流水线

浏览器把 HTML 渲染成像素，要经过这几个阶段：

```
JavaScript → Style → Layout → Paint → Composite
```

- **Layout（布局/回流）**：计算元素的几何位置和大小，开销最大
- **Paint（绘制/重绘）**：把元素绘制成像素，也有开销
- **Composite（合成）**：把不同图层叠在一起输出，开销最小，GPU 做的

修改 `left`、`top`、`width`、`height`、`margin` 这类属性，会触发 Layout → Paint → Composite 完整链路，每一帧都要重新计算布局，CPU 压力大，在手机上很容易掉帧。

修改 `transform` 和 `opacity`，浏览器能跳过 Layout 和 Paint，**直接在 Composite 阶段处理**，整个运算交给 GPU，这就是为什么 `transform` 动画比 `left` 动画流畅得多。

## 什么是合成层（Composite Layer）

GPU 合成的前提是元素要被提升为独立的合成层。浏览器在以下情况会把元素提升：

- 元素有 `transform` 属性（非 none）
- 元素有 `opacity` < 1
- 有 `will-change` 属性
- 使用了 CSS 滤镜 `filter`
- 元素是 `<video>`、`<canvas>`、`<iframe>`

当元素是独立的合成层，它的内容会被单独光栅化存到 GPU 显存里。做动画时，GPU 直接对这张"贴图"做矩阵变换，不需要 CPU 重新布局和绘制，所以快。

## translateZ(0) 的 hack

早年间强制让元素提升合成层，有个常见的 hack：

```css
.smooth-animation {
  -webkit-transform: translateZ(0);
  transform: translateZ(0);
}
```

`translateZ(0)` 在 3D 变换的意义下是"沿 Z 轴移动 0px"，视觉上没有任何变化，但这个声明足以告诉浏览器"这个元素参与了 3D 变换，给我一个独立的合成层"。

这是个有点取巧的写法。现代浏览器里更推荐用 `will-change`：

```css
.smooth-animation {
  will-change: transform;
}
```

语义更清晰：告诉浏览器"这个元素的 transform 会变化，请提前准备好合成层"。

## 实际对比

**慢的写法（触发 Layout）：**

```css
.slide-menu {
  left: -300px;
  transition: left 0.3s ease;
}
.slide-menu.open {
  left: 0;
}
```

每一帧浏览器要重新计算这个元素的位置，以及所有受影响的兄弟/父级元素的布局。

**快的写法（只走 Composite）：**

```css
.slide-menu {
  transform: translateX(-300px);
  transition: transform 0.3s ease;
  will-change: transform; /* 提前提升合成层 */
}
.slide-menu.open {
  transform: translateX(0);
}
```

动画期间只有 GPU 在做矩阵乘法，CPU 基本不参与，60fps 轻轻松松。

## 合成层的副作用：内存

合成层需要占 GPU 显存（每个合成层要存一份位图），如果你把页面上所有元素都 `will-change: transform`，显存会撑爆，性能反而更差。

**结论：`will-change` 只加给真正要做动画的元素，动画结束后最好移除：**

```javascript
element.addEventListener('animationend', function() {
  element.style.willChange = 'auto'
})
```

## 检查合成层

Chrome DevTools → Rendering（在 More tools 里）→ 勾选 "Layer borders"，页面上所有合成层会用橙色边框高亮出来。也可以在 Layers 面板里，3D 展开看各个图层的内存占用。

这两个工具排查动画性能问题很好用。

---

总结：触发 GPU 加速的核心是让元素成为独立合成层，动画属性优先选 `transform` 和 `opacity`，少用会触发 Layout 的属性。原理理解了，后面遇到动画掉帧基本能快速定位。
