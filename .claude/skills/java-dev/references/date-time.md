# Java 日期计算最佳实践

## 核心原则

"N 个月" = `plusMonths(N)`，保持日不变。仅当需求明确要求"月末"时才用 `YearMonth.atEndOfMonth()`。

---

## 日期加减

```java
// ✅ 正确：保持日不变
LocalDate base = LocalDate.of(2025, 9, 27);
LocalDate due = base.plusMonths(3);
// 结果: 2025-12-27

// ❌ 错误：月末对齐（除非需求明确要求）
YearMonth ym = YearMonth.from(base).plusMonths(3);
LocalDate wrong = ym.atEndOfMonth();
// 结果: 2025-12-31
```

## 前 N 月 / 后 N 月

```java
// 前 1 个月
LocalDate lastMonth = LocalDate.now().minusMonths(1);

// 后 3 个月
LocalDate threeMonthsLater = LocalDate.now().plusMonths(3);
```

## 账期/逾期日期计算

```java
// 账期 N 个月：开票日 + N 月
public LocalDate calculateDueDateByMonths(LocalDate invoiceDate, int termMonths) {
    return invoiceDate.plusMonths(termMonths);
}

// 账期 N 天：开票日 + N 天
public LocalDate calculateDueDateByDays(LocalDate invoiceDate, int termDays) {
    return invoiceDate.plusDays(termDays);
}
```

## 禁止的做法

- ❌ `YearMonth.atEndOfMonth()` 用于普通"N 个月"计算
- ❌ 手动计算月份天数（`switch(month) { case 2: ... }`）
- ❌ 用 `Calendar` 替代 `java.time` API
