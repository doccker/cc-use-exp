---
name: frontend-dev
description: 前端开发规范，包含 Vue 3 编码规范、UI 风格约束、TypeScript 规范等
version: v3.0
paths:
  - "**/*.vue"
  - "**/*.tsx"
  - "**/*.jsx"
  - "**/*.ts"
  - "**/*.js"
  - "**/*.css"
  - "**/*.scss"
  - "**/*.less"
  - "**/package.json"
  - "**/vite.config.*"
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

完整规范见 `references/frontend-style.md`，包含：
- 完整 UI 风格约束
- Vue 3 编码规范详解
- Pinia 状态管理
- API 请求封装
- 性能优化详解

---

> 📋 本回复遵循：`frontend-dev` - [具体章节]
