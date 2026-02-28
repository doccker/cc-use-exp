# JS/TS 日期计算最佳实践

## 核心原则

"N 个月" = `dayjs().add(N, 'month')` 或 `addMonths(date, N)`，保持日不变。仅当需求明确要求"月末"时才用 `endOf('month')`。

---

## dayjs（推荐）

```typescript
import dayjs from 'dayjs'

// ✅ 正确：保持日不变
const base = dayjs('2025-09-27')
const due = base.add(3, 'month')
// 结果: 2025-12-27

// ❌ 错误：月末对齐（除非需求明确要求）
const wrong = base.add(3, 'month').endOf('month')
// 结果: 2025-12-31
```

## date-fns（备选）

```typescript
import { addMonths, subMonths } from 'date-fns'

// 加 3 个月
const due = addMonths(new Date('2025-09-27'), 3)
// 结果: 2025-12-27

// 减 1 个月
const prev = subMonths(new Date('2026-03-15'), 1)
// 结果: 2026-02-15
```

## 账期/逾期日期计算

```typescript
function calculateDueDate(invoiceDate: string, termMonths: number): string {
  return dayjs(invoiceDate).add(termMonths, 'month').format('YYYY-MM-DD')
}

function calculateDueDateByDays(invoiceDate: string, termDays: number): string {
  return dayjs(invoiceDate).add(termDays, 'day').format('YYYY-MM-DD')
}
```

## 禁止的做法

- ❌ `endOf('month')` 用于普通"N 个月"计算
- ❌ 手动操作 `Date` 对象的 `setMonth()`（边界处理不可靠）
- ❌ 手动计算月份天数
