# 前端开发与 UI 风格规范

作者：wwj
版本：v1.0
日期：2025-12-17
状态：草稿

> **部署位置**: `~/.claude/rules/frontend-style.md`
> **作用范围**: 前端/界面相关代码
> **参考来源**: Vue 官方风格指南、Element Plus 最佳实践

---
paths:
  - "**/*.vue"
  - "**/*.tsx"
  - "**/*.jsx"
  - "**/*.ts"
  - "**/*.js"
  - "**/*.css"
  - "**/*.scss"
  - "**/*.less"
  - "**/*.html"
  - "**/package.json"
  - "**/vite.config.*"
---

## 0. 适用原则

<!-- [注释] 仅在涉及前端/界面开发时遵循本规则 -->

- **仅在涉及前端/界面开发时遵循**本规则
- **默认使用框架/组件库的脚手架风格**: 不做"AI 设计稿"，不做大改主题色
- **技术栈优先级**: Vue > React；默认使用 TypeScript

---

## 1. UI 视觉风格

<!-- [注释] 这是最重要的约束，防止 AI 生成"炫酷科技风" -->

### 1.1 严格禁止（常见 AI 风格）

- ❌ 蓝紫色霓虹渐变背景、发光描边、玻璃拟态（glassmorphism）
- ❌ 大面积渐变、过多装饰性几何图形、无意义的动效堆叠
- ❌ 随机生成的"科技感"插画/图标，或多套图标混用
- ❌ UI 文案中使用 emoji（除非产品明确要求）
- ❌ 赛博风、暗黑科技风、AI 风格 UI

### 1.2 后台/管理系统（默认风格）

<!-- [注释] 大多数情况下都是后台系统 -->

**目标**: "像一个成熟企业后台"，而不是宣传页

| 要素 | 要求 |
|------|------|
| 主题 | 使用组件库默认主题 + 默认布局 |
| 配色 | 黑白灰为主 + 1 个主色点缀，避免渐变 |
| 信息密度 | 适中，表格、筛选、分页、表单用标准组件 |
| 动效 | 克制，仅保留必要的交互反馈（hover/focus/loading） |

**可选风格**（保持一致，不要混搭）：
- Element Plus 默认风格（推荐）
- Ant Design Vue 风格
- Naive UI 风格

### 1.3 前台宣传/官网（如需要）

**目标**: "简约、大气、留白足、排版高级"

- ✅ 大留白 + 清晰栅格 + 强排版层级
- ✅ 颜色克制: 白/浅灰背景 + 深色文字 + 少量强调色
- ✅ 轻量动效: 小范围的渐显/滚动过渡即可

### 1.4 不确定时先问

如果需求不明确，必须先问清楚：
1. 这是 **后台管理** 还是 **前台宣传**？
2. 期望风格是 **默认脚手架/企业后台/Apple 官网** 哪一种？
3. 是否已有品牌色/组件库/参考站点/设计稿？

---

## 2. 技术栈默认选择

<!-- [注释] 可根据实际项目调整 -->

### 2.1 Vue 技术栈（首选）

| 层级 | 选择 |
|------|------|
| 框架 | Vue 3 + TypeScript |
| 构建 | Vite |
| 路由 | Vue Router 4 |
| 状态管理 | Pinia |
| UI 组件库 | Element Plus |
| HTTP | Axios |

### 2.2 React 技术栈（备选）

| 层级 | 选择 |
|------|------|
| 框架 | React 18 + TypeScript |
| 构建 | Vite |
| 路由 | React Router 6 |
| 状态管理 | Zustand |
| UI 组件库 | Ant Design |
| 数据请求 | TanStack Query |

---

## 3. Vue 编码规范

<!-- [注释] Vue 3 Composition API 风格 -->

### 3.1 组件基础

**必须使用 Composition API + `<script setup>`**：

```vue
<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import type { User } from '@/types'

// Props 定义
const props = defineProps<{
  userId: number
  title?: string
}>()

// Emits 定义
const emit = defineEmits<{
  (e: 'update', value: string): void
  (e: 'delete', id: number): void
}>()

// 响应式状态
const loading = ref(false)
const user = ref<User | null>(null)

// 计算属性
const displayName = computed(() => user.value?.name ?? '未知用户')

// 生命周期
onMounted(async () => {
  await fetchUser()
})

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
    <el-button @click="emit('delete', props.userId)">删除</el-button>
  </div>
</template>

<style scoped>
.user-card {
  padding: 16px;
}
</style>
```

### 3.2 命名约定

| 类型 | 约定 | 示例 |
|------|------|------|
| 组件文件 | PascalCase.vue | `UserCard.vue` |
| 组件目录 | 可复用放 `components/`，页面放 `views/` | |
| Composables | useXxx.ts | `useAuth.ts` |
| Store | useXxxStore.ts | `useUserStore.ts` |
| 类型文件 | xxx.d.ts 或 types/ 目录 | `user.d.ts` |

### 3.3 组件组织

```vue
<script setup lang="ts">
// 1. 导入（按顺序：vue → 第三方 → 项目内部）
import { ref, computed } from 'vue'
import { ElMessage } from 'element-plus'
import { useUserStore } from '@/stores/user'

// 2. Props & Emits
const props = defineProps<{...}>()
const emit = defineEmits<{...}>()

// 3. Store & Composables
const userStore = useUserStore()

// 4. 响应式状态
const loading = ref(false)

// 5. 计算属性
const isAdmin = computed(() => userStore.role === 'admin')

// 6. 生命周期钩子
onMounted(() => {...})

// 7. 方法
function handleSubmit() {...}
</script>
```

### 3.4 Props 规范

```typescript
// ✅ 好：使用 TypeScript 类型定义
const props = defineProps<{
  id: number
  title: string
  disabled?: boolean
}>()

// ✅ 好：需要默认值时使用 withDefaults
const props = withDefaults(defineProps<{
  title: string
  size?: 'small' | 'medium' | 'large'
}>(), {
  size: 'medium'
})

// ❌ 差：使用运行时声明（除非需要复杂验证）
const props = defineProps({
  id: {
    type: Number,
    required: true
  }
})
```

### 3.5 样式规范

```vue
<!-- ✅ 好：使用 scoped 防止样式污染 -->
<style scoped>
.container {
  padding: 16px;
}
</style>

<!-- ✅ 好：需要穿透组件库样式时 -->
<style scoped>
.container :deep(.el-input__inner) {
  border-radius: 8px;
}
</style>

<!-- ❌ 差：全局样式（除非确实需要） -->
<style>
.container {
  padding: 16px;
}
</style>
```

### 3.6 样式组织规范

**核心原则**：全局/共享样式统一放 `src/assets/styles/`，组件级 scoped 样式保留在 SFC 内。

#### 目录结构

```
src/assets/styles/
├── variables.scss      # 设计变量（颜色、字号、间距、断点）
├── mixins.scss         # 可复用 mixin（响应式、文本截断等）
├── reset.scss          # 浏览器重置 / normalize
├── common.scss         # 全局公共样式（布局工具类、通用过渡）
└── index.scss          # 统一入口，按顺序导入上述文件
```

#### 导入方式

```typescript
// main.ts - 统一导入全局样式
import '@/assets/styles/index.scss'
```

```scss
// assets/styles/index.scss
@import './reset.scss';
@import './variables.scss';
@import './mixins.scss';
@import './common.scss';
```

```vue
<!-- 组件中使用变量/mixin 时，通过 vite 自动注入，无需手动 import -->
<!-- vite.config.ts 配置 css.preprocessorOptions.scss.additionalData -->
<style scoped lang="scss">
.card {
  color: $text-primary;
  @include text-ellipsis;
}
</style>
```

#### 规则

| 规则 | 说明 |
|------|------|
| 全局样式放 `assets/styles/` | 变量、mixin、reset、公共类 |
| scoped 样式留在组件内 | 组件私有样式使用 `<style scoped>` |
| 禁止在组件中写非 scoped 全局样式 | 需要全局样式时加到 `common.scss` |
| 内联 `<style>` 块不超过 30 行 | 超过时提取公共部分到 `assets/styles/` |

---

## 4. 状态管理（Pinia）

<!-- [注释] Vue 3 推荐使用 Pinia -->

### 4.1 Store 定义

```typescript
// stores/user.ts
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { User } from '@/types'

export const useUserStore = defineStore('user', () => {
  // State
  const user = ref<User | null>(null)
  const token = ref<string>('')

  // Getters
  const isLoggedIn = computed(() => !!token.value)
  const userName = computed(() => user.value?.name ?? '')

  // Actions
  async function login(username: string, password: string) {
    const res = await api.login(username, password)
    token.value = res.token
    user.value = res.user
  }

  function logout() {
    token.value = ''
    user.value = null
  }

  return {
    user,
    token,
    isLoggedIn,
    userName,
    login,
    logout
  }
})
```

### 4.2 在组件中使用

```vue
<script setup lang="ts">
import { useUserStore } from '@/stores/user'
import { storeToRefs } from 'pinia'

const userStore = useUserStore()

// ✅ 好：使用 storeToRefs 保持响应性
const { user, isLoggedIn } = storeToRefs(userStore)

// ✅ 好：actions 直接解构
const { login, logout } = userStore
</script>
```

---

## 5. API 请求规范

<!-- [注释] 统一的 API 调用方式 -->

### 5.1 API 模块组织

```typescript
// api/index.ts - 统一导出
export * from './user'
export * from './site'

// api/user.ts - 用户相关 API
import request from '@/utils/request'
import type { User, LoginParams, LoginResult } from '@/types'

export function login(params: LoginParams): Promise<LoginResult> {
  return request.post('/api/v1/login', params)
}

export function getUserInfo(): Promise<User> {
  return request.get('/api/v1/user/info')
}

export function updateUser(id: number, data: Partial<User>): Promise<User> {
  return request.put(`/api/v1/users/${id}`, data)
}
```

### 5.2 请求封装

```typescript
// utils/request.ts
import axios from 'axios'
import { ElMessage } from 'element-plus'
import { useUserStore } from '@/stores/user'

const request = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL,
  timeout: 10000
})

// 请求拦截
request.interceptors.request.use(config => {
  const userStore = useUserStore()
  if (userStore.token) {
    config.headers.Authorization = `Bearer ${userStore.token}`
  }
  return config
})

// 响应拦截
request.interceptors.response.use(
  response => {
    const { code, message, data } = response.data
    if (code === 0) {
      return data
    }
    ElMessage.error(message || '请求失败')
    return Promise.reject(new Error(message))
  },
  error => {
    ElMessage.error(error.message || '网络错误')
    return Promise.reject(error)
  }
)

export default request
```

---

## 6. 交互状态规范

<!-- [注释] 完整的交互状态是用户体验的基础 -->

### 6.1 必须处理的状态

| 状态 | 说明 | 示例 |
|------|------|------|
| loading | 加载中 | 骨架屏、加载动画 |
| empty | 空数据 | "暂无数据" 提示 |
| error | 错误 | 错误信息 + 重试按钮 |
| disabled | 禁用 | 按钮置灰 |
| submitting | 提交中 | 按钮 loading + 防重复点击 |

### 6.2 示例实现

```vue
<template>
  <div class="list-container">
    <!-- 加载状态 -->
    <el-skeleton v-if="loading" :rows="5" animated />

    <!-- 错误状态 -->
    <el-result v-else-if="error" icon="error" :title="error">
      <template #extra>
        <el-button @click="fetchData">重试</el-button>
      </template>
    </el-result>

    <!-- 空状态 -->
    <el-empty v-else-if="list.length === 0" description="暂无数据" />

    <!-- 正常内容 -->
    <template v-else>
      <div v-for="item in list" :key="item.id">
        {{ item.name }}
      </div>
    </template>
  </div>
</template>

<script setup lang="ts">
const loading = ref(false)
const error = ref('')
const list = ref<Item[]>([])

async function fetchData() {
  loading.value = true
  error.value = ''
  try {
    list.value = await api.getList()
  } catch (e) {
    error.value = e.message || '加载失败'
  } finally {
    loading.value = false
  }
}
</script>
```

---

## 7. TypeScript 规范

<!-- [注释] 前端也要严格使用 TypeScript -->

### 7.1 基本要求

- 默认使用 TypeScript，禁止大范围 `any`
- 必须为 API 响应定义类型
- 组件 Props 和 Emits 必须有类型定义

### 7.2 类型定义位置

```
src/
├── types/
│   ├── index.ts        # 统一导出
│   ├── user.ts         # 用户相关类型
│   ├── site.ts         # 站点相关类型
│   └── api.ts          # API 通用类型
```

### 7.3 类型定义示例

```typescript
// types/user.ts
export interface User {
  id: number
  username: string
  email: string
  role: 'admin' | 'user'
  createdAt: string
}

export interface LoginParams {
  username: string
  password: string
}

export interface LoginResult {
  token: string
  user: User
}

// types/api.ts
export interface ApiResponse<T = unknown> {
  code: number
  message: string
  data: T
}

export interface PageParams {
  page: number
  pageSize: number
}

export interface PageResult<T> {
  list: T[]
  total: number
}
```

---

## 8. 目录结构

<!-- [注释] 推荐的前端项目结构 -->

```
web/
├── src/
│   ├── api/                 # API 请求模块
│   │   ├── index.ts
│   │   ├── user.ts
│   │   └── site.ts
│   ├── assets/              # 静态资源
│   │   ├── images/
│   │   └── styles/
│   ├── components/          # 通用组件
│   │   ├── common/         # 基础通用组件
│   │   └── business/       # 业务通用组件
│   ├── composables/         # 组合式函数
│   │   ├── useAuth.ts
│   │   └── useTable.ts
│   ├── layouts/             # 布局组件
│   │   └── DefaultLayout.vue
│   ├── router/              # 路由配置
│   │   └── index.ts
│   ├── stores/              # Pinia stores
│   │   ├── index.ts
│   │   └── user.ts
│   ├── types/               # TypeScript 类型
│   │   └── index.ts
│   ├── utils/               # 工具函数
│   │   ├── request.ts
│   │   └── format.ts
│   ├── views/               # 页面组件
│   │   ├── home/
│   │   └── user/
│   ├── App.vue
│   └── main.ts
├── index.html
├── package.json
├── tsconfig.json
└── vite.config.ts
```

---

## 9. 代码检查工具

<!-- [注释] 可根据项目实际配置调整 -->

### 9.1 推荐配置

```bash
# 安装依赖
npm install -D eslint prettier eslint-plugin-vue @typescript-eslint/parser
```

### 9.2 常用命令

```bash
npm run lint          # 代码检查
npm run lint:fix      # 自动修复
npm run format        # 格式化
```

---

## 10. 性能优化

<!-- [注释] 先写正确的代码，再优化性能 -->

### 核心原则

| 原则 | 说明 |
|------|------|
| **先正确后优化** | 先确保功能正确，再考虑性能 |
| **先测量后优化** | 用 DevTools 定位瓶颈 |
| **用户感知优先** | 优化用户能感知到的性能问题 |

### 组件渲染优化

```vue
<script setup lang="ts">
import { computed, shallowRef } from 'vue'

// ✅ 使用 computed 缓存计算结果
const filteredList = computed(() =>
  list.value.filter(item => item.active)
)

// ✅ 大列表使用 shallowRef
const largeList = shallowRef<Item[]>([])

// ✅ 使用 v-once 标记静态内容
// <div v-once>{{ staticContent }}</div>

// ✅ 使用 v-memo 缓存列表项（Vue 3.2+）
// <div v-for="item in list" :key="item.id" v-memo="[item.id, item.selected]">
</script>
```

### 列表渲染优化

```vue
<template>
  <!-- ✅ 大列表使用虚拟滚动 -->
  <el-table-v2
    :columns="columns"
    :data="data"
    :height="400"
    :row-height="50"
  />

  <!-- ✅ 或使用第三方虚拟列表 -->
  <VirtualList
    :data-key="'id'"
    :data-sources="list"
    :data-component="ItemComponent"
    :estimate-size="50"
  />

  <!-- ❌ 避免：大列表直接渲染 -->
  <div v-for="item in hugeList" :key="item.id">
    {{ item.name }}
  </div>
</template>
```

### 懒加载

```typescript
// ✅ 路由懒加载
const routes = [
  {
    path: '/dashboard',
    component: () => import('@/views/Dashboard.vue')
  }
]

// ✅ 组件懒加载
const HeavyComponent = defineAsyncComponent(() =>
  import('@/components/HeavyComponent.vue')
)

// ✅ 图片懒加载
<el-image :src="url" lazy />

// ✅ 条件懒加载（仅在需要时加载）
<template>
  <HeavyComponent v-if="showHeavy" />
</template>
```

### 状态管理优化

```typescript
// ✅ 按需订阅状态（避免不必要的重渲染）
const userStore = useUserStore()
const userName = computed(() => userStore.name)  // 仅订阅 name

// ❌ 差：订阅整个 store
const { name, age, email, ...rest } = storeToRefs(userStore)

// ✅ 大数据使用 shallowRef
const tableData = shallowRef<TableRow[]>([])
function updateData(newData: TableRow[]) {
  tableData.value = newData  // 替换整个数组
}
```

### 网络请求优化

```typescript
// ✅ 请求防抖（搜索场景）
import { useDebounceFn } from '@vueuse/core'

const debouncedSearch = useDebounceFn((keyword: string) => {
  api.search(keyword)
}, 300)

// ✅ 请求缓存
const cache = new Map<string, { data: any; timestamp: number }>()
const CACHE_TTL = 5 * 60 * 1000  // 5 分钟

async function fetchWithCache(url: string) {
  const cached = cache.get(url)
  if (cached && Date.now() - cached.timestamp < CACHE_TTL) {
    return cached.data
  }
  const data = await fetch(url).then(r => r.json())
  cache.set(url, { data, timestamp: Date.now() })
  return data
}

// ✅ 取消重复请求
const controller = new AbortController()
fetch(url, { signal: controller.signal })
// 取消：controller.abort()
```

### 打包优化

```typescript
// vite.config.ts
export default defineConfig({
  build: {
    // ✅ 分包策略
    rollupOptions: {
      output: {
        manualChunks: {
          'vendor': ['vue', 'vue-router', 'pinia'],
          'element-plus': ['element-plus'],
        }
      }
    },
    // ✅ 压缩配置
    minify: 'terser',
    terserOptions: {
      compress: {
        drop_console: true,  // 生产环境移除 console
      }
    }
  }
})
```

### 避免常见陷阱

| 陷阱 | 解决方案 |
|------|---------|
| 大列表直接渲染 | 使用虚拟滚动 |
| 频繁触发计算属性 | 检查依赖是否过多 |
| 未使用 key 或 key 不稳定 | 使用唯一稳定的 key |
| 在模板中调用方法 | 改用 computed |
| 监听整个对象 | 使用 `{ deep: false }` 或监听具体属性 |
| 未取消的请求/定时器 | 在 onUnmounted 中清理 |

### 性能分析工具

```bash
# Chrome DevTools
# - Performance 面板：录制运行时性能
# - Lighthouse：整体性能评分
# - Vue DevTools：组件渲染性能

# 打包分析
npm install -D rollup-plugin-visualizer
# 然后在 vite.config.ts 中配置
```

---

## 规则溯源要求

当回复明确受到本规则约束时，在回复末尾声明：

```
> 📋 本回复遵循规则：`frontend-style.md` - [具体章节]
```

示例：
```
> 📋 本回复遵循规则：`frontend-style.md` - UI 视觉风格
> 📋 本回复遵循规则：`frontend-style.md` - Vue 编码规范
```

---

## 参考资料

- [Vue 3 官方文档](https://vuejs.org/)
- [Vue 风格指南](https://vuejs.org/style-guide/)
- [Element Plus](https://element-plus.org/)
- [Pinia 官方文档](https://pinia.vuejs.org/)
- [TypeScript 官方文档](https://www.typescriptlang.org/)
