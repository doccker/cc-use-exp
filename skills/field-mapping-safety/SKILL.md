---
name: field-mapping-safety
description: 当重构涉及字段映射（dataIndex、枚举映射、类型转换）时触发。防止字段名推测错误，确保字段映射的正确性。
---

# 字段映射安全规范

## 触发场景

- 重构表格列定义（dataIndex、columns）
- 重构枚举类型映射（typeMap、statusMap）
- 重构数据转换逻辑（render 函数、formatter）
- 类型定义中有多个相似字段（changedAt vs createdAt）

---

## 核心原则

**不要根据类型定义推测字段名，必须查看原始代码的实际使用**

---

## 检查清单

### 1. 字段名验证

- [ ] 查看原始代码的 dataIndex
- [ ] 查看后端 API 返回的实际字段名
- [ ] 优先使用必填字段，避免可选字段
- [ ] 注意字段名的细微差异（changedAt vs createdAt、changeType vs operationType）

### 2. 枚举映射验证

- [ ] 对照原始代码，逐个检查枚举值
- [ ] 确保映射完整（不遗漏任何枚举值）
- [ ] 检查枚举值的拼写（UPLOAD vs Upload）
- [ ] 检查枚举值的颜色、文本是否一致

### 3. 运行时测试

- [ ] TypeScript 类型检查通过（必要但不充分）
- [ ] 在实际环境中测试功能
- [ ] 检查是否显示 "Invalid Date"、"undefined"、空白
- [ ] 检查枚举值是否都有对应的映射

---

## 常见陷阱

### 陷阱 1: 类型定义有歧义

**场景**：类型定义中有多个相似字段

```typescript
interface InvoiceHistory {
  changedAt?: string  // 可选字段
  createdAt: string   // 必填字段
  changeType?: string // 错误字段
  operationType: string // 正确字段
}
```

**错误做法**：
```typescript
// ❌ 根据类型定义推测，选择了可选字段
dataIndex: 'changedAt'  // 可能为 undefined → Invalid Date
dataIndex: 'changeType' // 字段不存在 → 显示为空
```

**正确做法**：
```typescript
// ✅ 查看原始代码的实际使用
git show HEAD~1:src/components/InvoiceHistoryTab.tsx

// 原始代码使用 createdAt（必填）和 operationType（正确）
dataIndex: 'createdAt'
dataIndex: 'operationType'
```

### 陷阱 2: 枚举映射不完整

**场景**：重构时遗漏部分枚举值

**错误做法**：
```typescript
// ❌ 只保留了 3 个类型
typeMap: {
  CREATE: { text: '创建', color: 'green' },
  UPDATE: { text: '更新', color: 'blue' },
  DELETE: { text: '删除', color: 'red' },
}
```

**正确做法**：
```typescript
// ✅ 查看原始代码，确保完整
git show HEAD~1:src/components/InvoiceHistoryTab.tsx

// 原始代码有 10 个类型
typeMap: {
  UPLOAD: { text: '上传发票', color: 'blue' },
  OCR_START: { text: '开始OCR', color: 'cyan' },
  OCR_SUCCESS: { text: 'OCR成功', color: 'green' },
  OCR_FAILED: { text: 'OCR失败', color: 'red' },
  OCR_RETRY: { text: '重试OCR', color: 'orange' },
  MANUAL_EDIT: { text: '手动编辑', color: 'orange' },
  LINK_ORDER: { text: '关联订单', color: 'purple' },
  UNLINK_ORDER: { text: '取消关联', color: 'magenta' },
  FIELD_CONFIRM: { text: '确认字段', color: 'green' },
  DELETE: { text: '删除发票', color: 'red' },
}
```

### 陷阱 3: TypeScript 无法检测

**场景**：字段名错误但 TypeScript 不报错

```typescript
// ❌ TypeScript 不会报错（changedAt 在类型定义中存在）
dataIndex: 'changedAt'  // 类型检查通过
render: (val: string) => new Date(val).toLocaleString()
// 运行时：val 为 undefined → Invalid Date
```

**正确做法**：
```typescript
// ✅ 运行时测试 + 防御性编程
dataIndex: 'createdAt'
render: (val: string) => {
  if (!val) return '-'
  try {
    return new Date(val).toLocaleString('zh-CN')
  } catch {
    return val
  }
}
```

### 陷阱 4: rowKey 使用可选字段

**场景**：rowKey 使用了可能为 undefined 的字段

**错误做法**：
```typescript
// ❌ changedAt 可能为 undefined
rowKey={(record, index) => `${record.changedAt}-${index}`}
// 结果：undefined-0, undefined-1 → key 重复
```

**正确做法**：
```typescript
// ✅ 使用必填字段 id
rowKey={(record) => record.id}
```

---

## 验证流程

### 1. 静态检查

```bash
# TypeScript 类型检查
npm run type-check

# ESLint 检查
npm run lint
```

### 2. 运行时测试

- [ ] 在开发环境中测试功能
- [ ] 检查是否显示 "Invalid Date"
- [ ] 检查是否显示 "undefined" 或空白
- [ ] 检查枚举值是否都有对应的映射
- [ ] 检查 rowKey 是否唯一

### 3. 对比验证

```bash
# 查看原始代码
git show HEAD~1:src/components/InvoiceHistoryTab.tsx

# 制作对比清单
| 字段 | 原始代码 | 重构后 | 状态 |
|------|---------|--------|------|
| 时间字段 | createdAt | changedAt | ❌ 错误 |
| 操作类型 | operationType | changeType | ❌ 错误 |
| 枚举映射 | 10 个 | 3 个 | ❌ 不完整 |
| rowKey | record.id | record.changedAt | ❌ 错误 |
```

---

## 防御性编程

### 1. 可选字段处理

```typescript
// ✅ 检查字段是否存在
render: (val: string) => {
  if (!val) return '-'
  return val
}
```

### 2. 日期格式化

```typescript
// ✅ 捕获异常
render: (val: string) => {
  if (!val) return '-'
  try {
    return new Date(val).toLocaleString('zh-CN', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
      hour12: false,
    })
  } catch {
    return val
  }
}
```

### 3. 枚举映射

```typescript
// ✅ 提供默认值
render: (type: string) => {
  const config = typeMap[type] || { text: type, color: 'default' }
  return <Tag color={config.color}>{config.text}</Tag>
}
```

---

## 规则溯源

```
> 📋 本回复遵循：`field-mapping-safety` - [章节]
```
