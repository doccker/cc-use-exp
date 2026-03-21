---
name: frontend-dev
description: >-
  前端开发规范。当用户操作 .vue、.tsx、.jsx、.ts、.js、.css、.scss、.less、package.json、vite.config 文件，
  或涉及 Vue 3、React、TypeScript、Element Plus、Ant Design 开发时触发。
  包含 UI 风格约束、Vue 编码规范、Pinia 状态管理、TypeScript 规范、性能优化、样式管理等。
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

const props = defineProps<{ userId: number }>()
const emit = defineEmits<{ (e: 'update', value: string): void }>()

const loading = ref(false)
const user = ref<User | null>(null)
const displayName = computed(() => user.value?.name ?? '未知用户')

onMounted(async () => { await fetchUser() })

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

## 性能优化

| 场景 | 方案 |
|------|------|
| 大列表 | 虚拟滚动 |
| 路由 | 懒加载 `() => import()` |
| 计算 | 使用 `computed` 缓存 |
| 大数据 | 使用 `shallowRef` |

---

## 样式管理规范

| 规则 | 说明 |
|------|------|
| ❌ 禁止在 `.vue` 中写大段样式 | `<style>` 块不超过 20 行 |
| ✅ 共享样式抽到 `src/assets/styles/` | 按模块拆分文件 |
| ✅ 组件内只保留极简样式 | Vue: scoped 微调；React: className 引用 |

---

## 请求体完整性规范

| 规则 | 说明 |
|------|------|
| ❌ 禁止 UI 可选字段未传入 API | 用户选择/输入的字段必须全部传入请求体 |
| ✅ 提交函数与表单字段一一对应 | 用 TypeScript interface 约束请求体 |

---

## API 错误处理规范

| 规则 | 说明 |
|------|------|
| ❌ 禁止静默忽略非成功响应 | `res.code !== 200` 时必须提示用户 |
| ✅ 统一错误提示 | 非成功响应统一 `message.error` 提示 |
| ✅ 网络异常也要处理 | `try/catch` 捕获请求异常 |

---

## 类型复用规范

| 规则 | 说明 |
|------|------|
| ❌ 禁止多个文件重复定义相同接口 | `PageResponse`、`BaseResult` 等 |
| ✅ 通用类型统一放 `@/types/common.ts` | 全局导出，各处引用 |

---

## 详细参考

| 文件 | 内容 |
|------|------|
| `references/frontend-style.md` | UI 风格、Vue 3 规范、Pinia、API 封装、性能优化 |
| `references/miniapp-pitfalls.md` | uni-app 陷阱：页面栈只读、Storage 清理时机 |
| `references/date-time.md` | dayjs/date-fns 日期加减、账期计算 |
