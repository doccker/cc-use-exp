# Go 日期计算最佳实践

## 核心原则

"N 个月" = `AddDate(0, N, 0)`，保持日不变。仅当需求明确要求"月末"时才手动调整。

---

## 日期加减

```go
// ✅ 正确：保持日不变
base := time.Date(2025, 9, 27, 0, 0, 0, 0, time.Local)
due := base.AddDate(0, 3, 0)
// 结果: 2025-12-27

// ❌ 错误：手动算月末
due := time.Date(2025, 12+1, 0, 0, 0, 0, 0, time.Local)
// 结果: 2025-12-31
```

## 前 N 月 / 后 N 月

```go
// 前 1 个月
lastMonth := time.Now().AddDate(0, -1, 0)

// 后 3 个月
threeMonthsLater := time.Now().AddDate(0, 3, 0)
```

## 账期/逾期日期计算

```go
// 账期 N 个月
func CalculateDueDateByMonths(invoiceDate time.Time, termMonths int) time.Time {
    return invoiceDate.AddDate(0, termMonths, 0)
}

// 账期 N 天
func CalculateDueDateByDays(invoiceDate time.Time, termDays int) time.Time {
    return invoiceDate.AddDate(0, 0, termDays)
}
```

## Go 的月末溢出行为

Go 的 `AddDate` 会自动规范化溢出日期：
- `time.Date(2025, 1, 31, ...).AddDate(0, 1, 0)` → `2025-03-03`（非 2 月 28 日）

如果需要"钳位"到月末，需手动处理：

```go
func AddMonthsClamped(t time.Time, months int) time.Time {
    result := t.AddDate(0, months, 0)
    // 如果日期溢出到下个月，回退到上月最后一天
    if result.Day() < t.Day() {
        return result.AddDate(0, 0, -result.Day())
    }
    return result
}
```

## 禁止的做法

- ❌ 手动计算月份天数（`switch month { case 2: ... }`）
- ❌ 用字符串拼接构造日期
