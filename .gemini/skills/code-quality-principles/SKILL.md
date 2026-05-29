---
name: code-quality-principles
description: 当编写新模块、设计接口、重构代码或代码审查时触发。提供经典模块化六原则检查清单（大小适中/调用深度/扇入扇出/边界清晰/作用域内聚/可预测性），适用于 PR/Review/新模块设计场景。
---
<instructions>

# 模块化设计六原则

> 经典软件工程设计原则在 AI 协作场景下的现代化清单。
> 用作新模块设计、重构、代码审查时的对照表，不替代具体执行 skill。

## 触发场景

- 编写新模块、新服务、新接口
- 用户说"设计"、"拆分模块"、"评审"、"重构"
- `/review`、`/new-feature`、`/optimize`、`/design` 命令在设计阶段
- 评估技术债时对照原则定位坏味道

---

## 六原则速查表

| # | 原则 | 一句话 | 衡量指标 | 详细案例 |
|---|------|--------|---------|---------|
| 1 | 模块大小适中 | 单文件控制在职责边界内 | 行数/职责数 | 引用 [size-check](../size-check/) |
| 2 | 减少调用深度 | 调用链尽量 ≤ 3 层 | 栈深度 | [modularity.md#调用深度](references/modularity.md) |
| 3 | 多扇入，少扇出 | 被复用 > 主动依赖 | 依赖数/被依赖数 | [modularity.md#扇入扇出](references/modularity.md) |
| 4 | 接口边界清晰 | 入参/出参/异常统一 | 统一响应包装 | [modularity.md#边界清晰](references/modularity.md) |
| 5 | 作用域内聚 | 改 A 不波及 B | 跨模块副作用 | 引用 [refactor-safety](../refactor-safety/) |
| 6 | 功能可预测 | 同输入→同输出 | 幂等/无副作用/可测 | [predictability.md](references/predictability.md) |

---

## 1. 模块大小适中

> 主要执行交给 `size-check` skill；本 skill 仅作总纲提示。

**核心**：单文件超限是**设计信号**，不是格式问题。提示职责过载，应拆分。

**默认阈值**：Java ≤ 300 / Go ≤ 400 / Vue ≤ 200 / TS ≤ 300 / Python ≤ 300（项目可覆盖）。

---

## 2. 减少调用深度

❌ **反例**：`Controller → ServiceA → ServiceB → ServiceC → DAO → Mapper`（6 层）。定位 bug 需要逐层进栈，新人难以理解。

✅ **正例**：`Controller → Service → Repository`（3 层），其余通过事件/队列/纯函数解耦。

**衡量**：调用栈深度 > 5 即视为坏味道。详见 [modularity.md#调用深度](references/modularity.md)。

---

## 3. 多扇入，少扇出

❌ **反例**：`OrderService.createOrder()` 依赖 UserService、CouponService、PaymentService、StockService、NotifyService、AuditService、CacheService、MetricsService（扇出 8）。改一处可能炸 8 处。

✅ **正例**：`StringUtils.toCamelCase()` 被项目 30 处复用（扇入 30）。复用价值高，无下游污染。

**衡量**：单方法直接依赖数 ≤ 5；被依赖数越多越好。详见 [modularity.md#扇入扇出](references/modularity.md)。

---

## 4. 接口边界清晰 + 统一错误返回

> 现代化改写"单入口单出口"原则。早期 return / guard clause 优于深嵌套。

❌ **反例**：成功返回 `{data}`、失败抛异常、还有一种返 `null`，调用方需要 3 种处理路径。

✅ **正例**：统一 `{code, data, message}` 包装，异常在边界层（middleware / interceptor）集中处理。一个出入口契约对所有调用方一致。

详见 [modularity.md#边界清晰](references/modularity.md)。

---

## 5. 作用域内聚

> 主要执行交给 `refactor-safety` 与 `multi-tenant-safety` skill。

**核心**：
- 模块内的修改不应越界影响其他模块
- 私有实现不暴露成公共 API
- 跨模块通信走**明确的 API、事件或消息**，不通过共享可变状态

---

## 6. 功能可预测

❌ **反例**：
- 同一笔 HTTP 重试扣两次款（无幂等键）
- 定时任务跨夜失败（依赖系统时区）
- 单测时灵时不灵（依赖外部状态）

✅ **正例**：
- 幂等键去重（写操作必有）
- 时间统一 UTC，按需在边界转换
- 纯函数优先，副作用集中在边界（IO/DB/网络）

详见 [predictability.md](references/predictability.md)。

---

## 检查清单（PR / Review 对照）

新增或修改模块前，逐条过一遍：

- [ ] **大小**：单文件未超行数限制？参考 `size-check`
- [ ] **深度**：调用链 ≤ 3 层？没有 A→B→C→D→E 的长链？
- [ ] **扇出**：直接依赖数 ≤ 5？是否引入了过多 service？
- [ ] **边界**：接口入参/出参/异常有统一约定？
- [ ] **作用域**：修改是否越界影响了其他模块？
- [ ] **幂等**：重试/重复调用是否安全？
- [ ] **隐式依赖**：是否依赖时区、当前时间、随机数等隐式环境？

---

## 与其他 skill 的边界

| 原则 | 主要执行 skill | 本 skill 角色 |
|------|---------------|--------------|
| 1 大小适中 | `size-check` | 触发提示 |
| 2 调用深度 | 无独立 skill | **本 skill 主导** |
| 3 扇入扇出 | 无独立 skill | **本 skill 主导** |
| 4 边界清晰 | `api-design-safety` | 决策对照 |
| 5 作用域内聚 | `refactor-safety` / `multi-tenant-safety` | 触发提示 |
| 6 可预测 | `time-zone-safety` / `redis-safety` / `query-performance-safety` | **本 skill 主导，专项 skill 处理具体陷阱** |

本 skill 是**总纲与决策对照表**，具体执行细节在上述各 skill 内。

---

## 规则溯源

```
> 📋 本回复遵循：`code-quality-principles` - [原则编号]
```

</instructions>