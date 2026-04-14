# uni-app / 小程序常见陷阱

> 针对 uni-app 开发中容易忽略的平台差异和反模式。

---

## 1. 禁止对框架返回的数组调用变更方法

`getCurrentPages()` 返回的是框架内部页面栈引用，调用 `pop()`/`splice()`/`shift()` 会直接修改页面栈。

```typescript
// ❌ pop() 会删除页面栈最后一个元素
const pages = getCurrentPages()
const currentPage = pages.pop()  // 变更了页面栈！

// ✅ 用索引读取，不修改原数组
const pages = getCurrentPages()
const currentPage = pages[pages.length - 1]
```

**通用原则**：框架返回的数组/对象视为只读，不调用变更方法。

---

## 2. Storage 清理必须在解析成功之后

`removeStorageSync` 放在 `finally` 或 `try` 块顶部会导致：解析失败时数据已被删除，用户无法重试。

```typescript
// ❌ 解析失败时数据已丢失，用户无法重试
const raw = uni.getStorageSync('order_confirm_items')
uni.removeStorageSync('order_confirm_items')  // 先删再解析
const items = JSON.parse(raw)  // 如果这里抛异常，数据已丢

// ❌ finally 中删除同样有问题
try {
  const raw = uni.getStorageSync('order_confirm_items')
  const items = JSON.parse(raw)
} finally {
  uni.removeStorageSync('order_confirm_items')  // 解析失败也删
}

// ✅ 仅在成功解析后删除
const raw = uni.getStorageSync('order_confirm_items')
let items: OrderItem[]
try {
  items = JSON.parse(raw)
} catch (e) {
  uni.showToast({ title: '数据异常，请返回重试', icon: 'none' })
  return
}
// 解析成功，安全删除
uni.removeStorageSync('order_confirm_items')
```

---

## 3. onMounted + onShow 双触发问题

uni-app 页面首次加载时，`onMounted` 和 `onShow` **都会触发**。数据加载放两处会导致双重请求。

```typescript
// ❌ 首次加载会触发两次 fetchProducts
onMounted(() => {
  fetchProducts(true)  // 第 1 次
})

onShow(() => {
  fetchProducts(true)  // 第 2 次（首次也触发）
})

// ✅ 数据加载只放 onShow（覆盖首次 + 返回刷新）
// onMounted 仅做一次性初始化（如事件监听、DOM 操作）
onMounted(() => {
  // 一次性初始化，如注册事件监听
})

onShow(() => {
  fetchProducts(true)  // 首次 + 每次返回都刷新
})
```

| 钩子 | 用途 | 触发时机 |
|------|------|---------|
| `onMounted` | 一次性初始化（事件监听、DOM） | 页面创建时 1 次 |
| `onShow` | 数据加载、状态刷新 | 页面创建 + 每次从后台/子页面返回 |
| `onLoad` | 接收页面参数 | 页面创建时 1 次（早于 onMounted） |

---

## 4. 前端校验应镜像后端约束

后端有校验（如 `@Min(1)`、`stock` 上限），前端必须做相同校验提前拦截，避免用户等待网络往返才看到错误。

```typescript
// ❌ 仅检查 stock <= 0，未验证用户选择数量
function handleBuy() {
  if (product.value.stock <= 0) {
    uni.showToast({ title: '商品已售罄', icon: 'none' })
    return
  }
  createOrder({ quantity: quantity.value })  // quantity 可能 > stock
}

// ✅ 镜像后端校验：数量 >= 1 且 <= 库存
function handleBuy() {
  if (product.value.stock <= 0) {
    uni.showToast({ title: '商品已售罄', icon: 'none' })
    return
  }
  if (quantity.value < 1) {
    uni.showToast({ title: '数量不能小于 1', icon: 'none' })
    return
  }
  if (quantity.value > product.value.stock) {
    uni.showToast({ title: `库存不足，剩余 ${product.value.stock} 件`, icon: 'none' })
    return
  }
  createOrder({ quantity: quantity.value })
}
```

**原则**：前端校验是用户体验优化，后端校验是安全保障，两者都不可省略。

---

## 规则溯源

```
> 📋 本回复遵循：`frontend-dev/miniapp-pitfalls.md` - [具体章节]
```
