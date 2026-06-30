---
name: cc-frontend-dev
description: 前端开发规范，包含 Vue 3 编码规范、UI 风格约束、TypeScript 规范等
---

# 前端开发规范

> 参考来源: Vue 官方风格指南、Element Plus 最佳实践

---

## UI 风格约束

### 严格禁止（常见 AI 风格）

- ❌ 蓝紫色霓虹渐变、发光描边、玻璃拟态
- ❌ 大面积渐变、过多装饰性几何图形
- ❌ 赛博风、暗黑科技风、AI 风格 UI
- ❌ UI 文案中使用 emoji

### 后台系统（默认风格）

| 要素 | 要求 |
|------|------|
| 主题 | 使用组件库默认主题 |
| 配色 | 黑白灰为主 + 1 个主色点缀 |
| 动效 | 克制，仅保留必要交互反馈 |

---

## 技术栈

| 层级 | Vue（首选） | React（备选） |
|------|------------|--------------|
| 框架 | Vue 3 + TypeScript | React 18 + TypeScript |
| 构建 | Vite | Vite |
| 路由 | Vue Router 4 | React Router 6 |
| 状态 | Pinia | Zustand |
| UI 库 | Element Plus | Ant Design |

---

## Vue 编码规范

### 组件基础

```vue
<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import type { User } from '@/types'

// Props & Emits
const props = defineProps<{ userId: number }>()
const emit = defineEmits<{ (e: 'update', value: string): void }>()

// 响应式状态
const loading = ref(false)
const user = ref<User | null>(null)

// 计算属性
const displayName = computed(() => user.value?.name ?? '未知用户')

// 生命周期
onMounted(async () => { await fetchUser() })

// 方法
async function fetchUser() {
  loading.value = true
  try {
    user.value = await api.getUser(props.userId)
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="user-card">
    <h3>{{ displayName }}</h3>
  </div>
</template>

<style scoped>
.user-card { padding: 16px; }
</style>
```

### 命名约定

| 类型 | 约定 | 示例 |
|------|------|------|
| 组件文件 | PascalCase.vue | `UserCard.vue` |
| Composables | useXxx.ts | `useAuth.ts` |
| Store | useXxxStore.ts | `useUserStore.ts` |

---

## 状态管理（Pinia）

```typescript
// stores/user.ts
export const useUserStore = defineStore('user', () => {
  const user = ref<User | null>(null)
  const token = ref<string>('')

  const isLoggedIn = computed(() => !!token.value)

  async function login(username: string, password: string) {
    const res = await api.login(username, password)
    token.value = res.token
    user.value = res.user
  }

  return { user, token, isLoggedIn, login }
})
```

---

## 交互状态处理

**必须处理的状态**: loading、empty、error、disabled、submitting

```vue
<template>
  <el-skeleton v-if="loading" :rows="5" animated />
  <el-result v-else-if="error" icon="error" :title="error">
    <template #extra>
      <el-button @click="fetchData">重试</el-button>
    </template>
  </el-result>
  <el-empty v-else-if="list.length === 0" description="暂无数据" />
  <template v-else>
    <!-- 正常内容 -->
  </template>
</template>
```

---

## TypeScript 规范

```typescript
// types/user.ts
export interface User {
  id: number
  username: string
  role: 'admin' | 'user'
}

export interface ApiResponse<T = unknown> {
  code: number
  message: string
  data: T
}
```

---

## API 调用类型安全

| 规则 | 说明 |
|------|------|
| ✅ API 工具函数支持泛型 | `get<T>(url): Promise<T>` 而非返回 `unknown` |
| ✅ 调用处指定泛型或断言 | `get<UserInfo>(url)` 或 `data as typeof ref.value` |
| ❌ 禁止 `as any` 绕过 | 掩盖类型问题，后续维护踩坑 |

```typescript
// ❌ get() 返回 unknown，赋值报 TS2322
const data = await get('/contact/config')
contact.value = data

// ❌ as any 绕过
contact.value = data as any

// ✅ 泛型约束（推荐）
const data = await get<ContactConfig>('/contact/config')
contact.value = data

// ✅ 类型断言（最小改动）
contact.value = data as typeof contact.value
```

---

## 性能优化

| 场景 | 方案 |
|------|------|
| 大列表 | 虚拟滚动 |
| 路由 | 懒加载 `() => import()` |
| 计算 | 使用 `computed` 缓存 |
| 大数据 | 使用 `shallowRef` |

```typescript
// 路由懒加载
const routes = [
  { path: '/dashboard', component: () => import('@/views/Dashboard.vue') }
]

// 请求防抖
import { useDebounceFn } from '@vueuse/core'
const debouncedSearch = useDebounceFn((keyword) => api.search(keyword), 300)
```

---

## 目录结构

```
src/
├── assets/
│   └── styles/          # 全局/共享样式
├── api/                 # API 请求
├── components/          # 通用组件
├── composables/         # 组合式函数
├── router/              # 路由配置
├── stores/              # Pinia stores
├── types/               # TypeScript 类型
├── utils/               # 工具函数
├── views/               # 页面组件
├── App.vue
└── main.ts
```

---

## 样式管理规范

| 规则 | 说明 |
|------|------|
| ❌ 禁止在 `.vue` 中写大段样式 | `<style>` 块不超过 20 行 |
| ❌ 禁止在 `.tsx` 中写大段内联样式 | 样式对象/CSS-in-JS 不超过 20 行 |
| ✅ 共享样式抽到 `src/assets/styles/` | 按模块拆分文件 |
| ✅ 组件内只保留极简样式 | Vue: scoped 微调；React: className 引用 |

```
src/assets/styles/
├── variables.scss       # 变量（颜色、间距、字号）
├── common.scss          # 通用样式
└── [module].scss        # 按模块拆分
```

---

## 请求体完整性规范

| 规则 | 说明 |
|------|------|
| ❌ 禁止 UI 可选字段未传入 API | 用户选择/输入的字段必须全部传入请求体 |
| ✅ 提交函数与表单字段一一对应 | 用 TypeScript interface 约束请求体 |

```typescript
// ❌ UI 有支付方式选择器，但请求体没传 payMethod
const payMethod = ref<'wechat' | 'points' | 'mixed'>('wechat')

async function createOrder() {
  await api.createOrder({
    items: orderItems.value,
    addressId: selectedAddress.value.id,
    // payMethod 忘记传了！支付方式选择 UI 形同虚设
  })
}

// ✅ 请求体与 UI 表单字段对应
interface CreateOrderRequest {
  items: OrderItem[]
  addressId: number
  payMethod: 'wechat' | 'points' | 'mixed'  // 类型约束确保不遗漏
}

async function createOrder() {
  const request: CreateOrderRequest = {
    items: orderItems.value,
    addressId: selectedAddress.value.id,
    payMethod: payMethod.value,  // TypeScript 会提示缺少字段
  }
  await api.createOrder(request)
}
```

---

## API 错误处理规范

| 规则 | 说明 |
|------|------|
| ❌ 禁止静默忽略非成功响应 | `res.code !== 200` 时必须提示用户 |
| ✅ 统一错误提示 | 非成功响应统一 `message.error` 提示 |
| ✅ 网络异常也要处理 | `try/catch` 捕获请求异常 |

```typescript
// ❌ 只处理成功，非 200 静默忽略
const res = await api.getList(params)
if (res.code === 200) {
  list.value = res.data
}

// ✅ 成功 + 失败都处理
try {
  const res = await api.getList(params)
  if (res.code === 200) {
    list.value = res.data
  } else {
    message.error(res.message || '加载失败')
  }
} catch (e) {
  message.error('网络异常，请稍后重试')
}
```

---

## React/antd 高频陷阱

本节适用 React + Ant Design 项目（Vue + Element Plus 用户跳过）。Vue 同类问题见 references/frontend-style.md。

### 陷阱 #1: controlled vs uncontrolled 误用 → 用户操作失效

`<Table pagination={{ pageSize: 20 }}>` 把 pageSize 写死成 20 → 组件认为是 controlled 属性，用户切换 "10 / 50 / 100" 立刻被覆盖回 20。底部下拉看似可点，实际无效。

| 属性 | controlled 形式 | uncontrolled 形式（推荐） |
|------|----------------|------------------------|
| antd Table 分页大小 | `pagination={{ pageSize, onChange }}` | `pagination={{ defaultPageSize: 20 }}` |
| antd Tree 展开 | `expandedKeys + onExpand` | `defaultExpandedKeys` 或 `defaultExpandAll` |
| antd Input 内容 | `value + onChange` | `defaultValue` |
| antd Form 字段 | Form.Item + form 实例 | `initialValue` |
| antd Tabs 当前页 | `activeKey + onChange` | `defaultActiveKey` |

```tsx
// ❌ controlled 但没 onChange → 用户切换无效
<Table pagination={{ pageSize: 20, showSizeChanger: true }} />

// ✅ uncontrolled，组件自己管
<Table pagination={{
  defaultPageSize: 20,
  showSizeChanger: true,
  pageSizeOptions: [10, 20, 50, 100],
}} />

// ✅ 或完整 controlled
const [pageSize, setPageSize] = useState(20);
<Table pagination={{
  pageSize,
  onShowSizeChange: (_, size) => setPageSize(size),
  showSizeChanger: true,
}} />
```

**判定规则**：要么 "传值 + 监听" 全套，要么用 `defaultXxx`。**不要只传值不监听**。

### 陷阱 #2: Tree `defaultExpandAll` + setState → 编辑后被重置回全展开

`<Tree defaultExpandAll>` 是 uncontrolled 默认值，每次 `setCategories(...)` 重新渲染 Tree 都会被重置 → 用户辛苦收起的节点全弹开。

```tsx
// ❌ 编辑分类名后整棵树被重置成全展开
<Tree treeData={treeData} defaultExpandAll />

// ✅ controlled expandedKeys + 只在初次 mount 时填充
const [expandedKeys, setExpandedKeys] = useState<React.Key[]>([]);
const initialExpandDoneRef = useRef(false);

const loadCategories = async () => {
  const data = (await getCategoryTree()).data || [];
  setCategories(data);
  if (!initialExpandDoneRef.current && data.length > 0) {
    setExpandedKeys(collectAllCategoryKeys(data));
    initialExpandDoneRef.current = true;  // 关键：之后再 loadCategories 不重置
  }
};

<Tree
  treeData={treeData}
  expandedKeys={expandedKeys}
  onExpand={setExpandedKeys}
/>
```

### 陷阱 #3: useEffect 双轮询冲突 → 定时器爆炸

一个 useEffect 用 `setTimeout` 递归 polling，另一个依赖 status 的 useEffect 又起 `setInterval`。两者并存 → 每个周期触发 2 次接口；status 变化让第二个 effect 重建 interval → 残留定时器越积越多。

```tsx
// ❌ 双 polling 共存
useEffect(() => {
  let timerId: NodeJS.Timeout | null = null;
  const pollOnce = async () => {
    const s = (await getStatus()).data;
    setRefreshState(s);
    if (s.status === 'RUNNING') {
      timerId = setTimeout(pollOnce, 3000);  // 第一套
    }
  };
  pollOnce();
  return () => { if (timerId) clearTimeout(timerId); };
}, []);

useEffect(() => {
  if (refreshState?.status !== 'RUNNING') return;
  const timerId = setInterval(async () => {  // 第二套
    setRefreshState((await getStatus()).data);
  }, 3000);
  return () => clearInterval(timerId);
}, [refreshState?.status]);
```

```tsx
// ✅ 只能一套：初次 fetch 在 mount effect，polling 由 status effect 接管
useEffect(() => {
  let cancelled = false;
  getStatus().then(resp => { if (!cancelled) setRefreshState(resp.data); });
  return () => { cancelled = true; };
}, []);

useEffect(() => {
  if (refreshState?.status !== 'RUNNING') return;
  const timerId = setInterval(async () => {
    const s = (await getStatus()).data;
    setRefreshState(s);
    if (s.status !== 'RUNNING') clearInterval(timerId);
  }, 3000);
  return () => clearInterval(timerId);
}, [refreshState?.status]);
```

> 详见 `cc-async-task-pattern` skill - 陷阱 #5

### 陷阱 #4: 跨组件状态同步用 prop drilling 或全局 store 太重 → revision counter 模式

场景：分类管理 tab 改了分类名，商品列表 tab 的下拉框需要刷新。Redux/Zustand 引入成本高，prop 一层层传又麻烦。

```tsx
// ✅ revision counter：父级维护一个数字，子组件 useEffect 监听
const ProductPage = () => {
  const [categoryRevision, setCategoryRevision] = useState(0);
  const bumpCategoryRevision = () => setCategoryRevision(n => n + 1);

  return <Tabs items={[
    { key: 'products', children: <ProductManagement categoryRevision={categoryRevision} /> },
    { key: 'categories', children: <CategoryManagement onCategoriesChanged={bumpCategoryRevision} /> },
  ]} />;
};

// ProductManagement 内部
useEffect(() => {
  if (categoryRevision !== undefined && categoryRevision > 0) {
    loadCategories();  // 任意 > 0 的变化都触发重新拉取
  }
}, [categoryRevision]);
```

为什么不用 useContext？跨远距离组件、变化频率低、且不想让所有 Consumer 都重渲染时，revision counter 比 Context 更轻。

### 陷阱 #5: 异步操作可能超时 → 应改异步任务模式

前端遇到接口 30s 超时、用户重复点击、loading 转圈卡死，根因常在后端是同步接口。**不要在前端加 timeout 重试**，让后端改成 trigger + polling 模式（见 `cc-async-task-pattern` skill）。前端配合：

| UX 项 | 实现 |
|-------|------|
| 触发按钮 RUNNING 状态 | `loading + disabled`，文案变 `"回填中 N%"` |
| 顶部进度提示 | `<Alert type="info">` + `<Progress percent={N} />` |
| 任意用户进来都见状态 | mount 时调一次 `getStatus()` |
| 完成时自动刷主列表 | `useEffect` 监听 status 变化，SUCCESS 时 `loadData()` |
| 错误透传 | `state.errorMessage` 直接 `message.error()` |

---

## 类型复用规范

| 规则 | 说明 |
|------|------|
| ❌ 禁止多个文件重复定义相同接口 | `PageResponse`、`BaseResult` 等 |
| ✅ 通用类型统一放 `@/types/common.ts` | 全局导出，各处引用 |

```typescript
// ❌ 每个 api 文件都定义一遍
// api/user.ts
interface PageResponse<T> { list: T[]; total: number }
// api/order.ts
interface PageResponse<T> { list: T[]; total: number } // 重复

// ✅ 统一定义，各处引用
// types/common.ts
export interface PageResponse<T> {
  list: T[]
  total: number
}

// api/user.ts
import type { PageResponse } from '@/types/common'
```

---

## 详细参考

| 文件 | 内容 |
|------|------|
| `references/frontend-style.md` | UI 风格、Vue 3 规范、Pinia、API 封装、性能优化 |
| `references/miniapp-pitfalls.md` | uni-app 陷阱：页面栈只读、Storage 清理时机、生命周期双触发、前端校验镜像 |
| `references/date-time.md` | dayjs/date-fns 日期加减、账期计算、禁止月末对齐 |

---

> 📋 本回复遵循：`cc-frontend-dev` - [具体章节]
