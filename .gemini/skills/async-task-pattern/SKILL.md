---
name: async-task-pattern
description: 当 API/任务可能执行超过 10 秒（批量数据处理、远程 API 批量调用、全表扫描、跨租户聚合）时触发。防止同步接口被网关 30s 超时切断、用户重复点击触发并发、状态缓存内存泄漏等问题。提供异步任务状态机标准模板。
---
<instructions>

# 异步任务模式规范

当一个操作可能跑超过 **10 秒**，必须改成 `triggerAsync()` + `getStatus()` 的异步状态机模式。
不要让用户盯着一个会超时的 loading 转圈，更不要让他点第二下。

> 与 `query-performance-safety` 配合：先用后者把同步性能压到能跑完的范围；只有"再优化也压不到 10s 以内"时，才走本规范。

---

## 触发条件

只要满足任一条件，就属于本 skill 的覆盖范围：

- 单次操作处理数据量 ≥ 1000 条（批量导入、全表扫描、跨租户聚合）
- 链路里有远程 API 批量调用，且 batch size × 单次延迟 > 5s
- 历史上同步实现已经出过 504/502/30s timeout
- 用户描述里出现"卡住"、"转圈很久"、"点完没反应"

---

## 陷阱 #1: 同步阻塞被网关切断

**场景**: 6000 条商品查重，同步接口 30s 超时；前端无回执，用户重复点击。

### 错误示例

```java
// ❌ HTTP 请求线程内串行跑 N 次远程调用 + JPA 写库
@PostMapping("/duplicates/check")
public ApiResponse<Map<String, List<ProductDTO>>> checkDuplicates() {
    return ApiResponse.success(productService.findDuplicateProducts());
    // 6000 条 × 4 次隐藏查询 = 24000 次 SQL，必然 > 30s
}
```

后果：
- Nginx/网关默认 30-60s 截断 → 用户看到 502/504
- 用户重试 → 后端线程池被占满 → 雪崩
- 前端 loading 状态没法跨刷新保持

### 正确模板（Spring 版）

```java
@Service
public class DuplicateChecker {
    private static final long FINISHED_STATE_TTL_MINUTES = 60;
    private final Executor executor;
    private final ProductService productService;

    // 关键：状态缓存按租户隔离，永远不要让它无界增长
    private final Map<Long, CheckState> tenantStates = new ConcurrentHashMap<>();

    public CheckState triggerAsync() {
        evictExpiredStates();
        Long tenantId = TenantContext.getTenantId();
        // 同租户已 RUNNING：返回当前状态，不重复启动
        CheckState existing = tenantStates.get(tenantId);
        if (existing != null && existing.getStatus() == Status.RUNNING) {
            return existing.snapshot();
        }
        CheckState state = new CheckState();
        state.setStatus(Status.RUNNING);
        state.setStartedAt(LocalDateTime.now());
        tenantStates.put(tenantId, state);
        executor.execute(() -> {
            try {
                TenantContext.setTenantId(tenantId);  // 子线程必须恢复上下文
                run(tenantId, state);
            } finally {
                TenantContext.clear();
            }
        });
        return state.snapshot();
    }

    public CheckState getStatus() {
        evictExpiredStates();
        Long tenantId = TenantContext.getTenantId();
        CheckState state = tenantStates.get(tenantId);
        if (state == null) {
            CheckState idle = new CheckState();
            idle.setStatus(Status.IDLE);
            return idle;
        }
        return state.snapshot();
    }

    private void evictExpiredStates() {
        LocalDateTime threshold = LocalDateTime.now().minusMinutes(FINISHED_STATE_TTL_MINUTES);
        tenantStates.entrySet().removeIf(entry -> {
            CheckState s = entry.getValue();
            return s.getStatus() != Status.RUNNING
                    && s.getFinishedAt() != null
                    && s.getFinishedAt().isBefore(threshold);
        });
    }

    public enum Status { IDLE, RUNNING, SUCCESS, FAILED }
}
```

```java
// Controller 立即返回
@PostMapping("/duplicates/check")
public ApiResponse<CheckState> trigger() {
    return ApiResponse.success("已触发", duplicateChecker.triggerAsync());
}

@GetMapping("/duplicates/check/status")
public ApiResponse<CheckState> status() {
    return ApiResponse.success(duplicateChecker.getStatus());
}
```

---

## 陷阱 #2: 状态缓存无界增长 → 内存泄漏

**根因**：`ConcurrentHashMap<Long, State>` 作为长生命周期缓存，每个进入过的租户都留下一条记录，FINISHED 后也不清理。

```java
// ❌ 错误：永远不清理
private final Map<Long, RefreshState> tenantStates = new ConcurrentHashMap<>();
// 多租户 SaaS 跑 3 个月后：1000 个租户 × 平均 2KB state = 内存只增不减
// 若 state 里还带着完整结果集（duplicateGroups Map<String,List>）→ 单租户就可能 MB 级
```

### 必须实现的清理策略

任选其一（推荐第 1 个，最简单）：

| 策略 | 实现 | 适用 |
|------|------|------|
| **入口清理 + TTL**（推荐） | 每次 `triggerAsync`/`getStatus` 时遍历清理 `finishedAt < now - 1h` 的非 RUNNING 状态 | 状态数量 < 1000，访问频率高 |
| 定时任务清理 | `@Scheduled(fixedRate = 600000)` 每 10 分钟扫描 | 状态数量大，访问频率低 |
| LRU 限容 | `Caffeine.newBuilder().maximumSize(500).expireAfterWrite(1, HOURS)` | 状态超大（含完整结果） |

### 检查清单

- [ ] 任何 `Map<X, State>` 作为成员变量时，是否有 TTL/LRU 策略
- [ ] RUNNING 状态是否被错误清理（不能！）
- [ ] 清理触发点是否在 hot path 上（每次 status 调用都清理 OK；每次 trigger 都清理 OK）
- [ ] 状态对象里是否塞了大块结果集（如全部商品 DTO 列表）→ 考虑只存摘要，结果落 Redis 或 DB

---

## 陷阱 #3: 子线程丢失 TenantContext

异步执行后 `ThreadLocal` 默认不传递。如果业务依赖 `TenantContext`，子线程拿不到 → 跨租户数据串、空指针。

```java
// ❌ 子线程拿不到 tenantId
executor.execute(() -> run(state));

// ✅ 在子线程入口手动恢复
executor.execute(() -> {
    try {
        TenantContext.setTenantId(tenantId);
        run(tenantId, state);
    } finally {
        TenantContext.clear();
    }
});
```

> 同样适用：`SecurityContextHolder`、`MDC`(日志上下文)、自定义请求级 ThreadLocal。

---

## 陷阱 #4: 重复触发导致并发跑

用户点了"刷新"按钮没反应，再点一下 → 后端起了两个并发任务，互相覆盖状态。

```java
public State triggerAsync() {
    State existing = states.get(key);
    if (existing != null && existing.getStatus() == Status.RUNNING) {
        return existing.snapshot();  // 关键：直接返回，不要重新启动
    }
    // ... 启动新任务
}
```

前端配合：按钮在 RUNNING 状态下 `disabled`，文案变 `"回填中 N%"`，让任何用户进来都看见同一任务在跑。

---

## 陷阱 #5: 前端双 useEffect 轮询冲突

mount 时用 `setTimeout` 递归 polling，状态变 RUNNING 时又起 `setInterval` —— 两套并存 → 每 3s 触发 2 次接口；状态变化让第二个 effect 重新创建 interval → 可能爆出 N×N 个定时器。

**只能有一套 polling 机制**：mount 时只做一次初始 fetch，polling 完全由依赖 `status` 的 effect 接管。

> 完整错误/正确代码示例见 `frontend-dev` skill - 陷阱 #3「useEffect 双轮询冲突」

---

## 前端 UX 规范

| 项 | 规范 |
|----|------|
| 触发按钮 | 立即变 `loading={true} disabled`，文案 `"回填中 N%"` |
| 进度可见 | 顶部加 `<Alert>` + `<Progress>`,显示 `processed / total` |
| 任意用户进来都能看见 | 进入页面先 `getStatus()`，RUNNING 时自动启动 polling |
| 切换页面再回来 | polling 依赖 status，重新 mount 自动接续 |
| RUNNING → 完成 | `message.success/error` + 自动 `loadData()` 刷新主列表 |
| FAILED 显示原因 | `state.errorMessage` 透传到 message |
| 关闭浏览器再开 | 后端任务不受影响（在 Executor 里跑），下次进来仍能查 |

---

## 检查清单（Code Review）

新增异步任务时挨条核：

- [ ] 是否真的需要异步（同步可压到 < 5s 就别上）
- [ ] 触发接口立即返回，不带任何业务计算
- [ ] 状态缓存有 TTL/LRU
- [ ] RUNNING 状态拒绝重复触发
- [ ] 子线程恢复了 TenantContext / SecurityContext / MDC
- [ ] FAILED 状态的 `errorMessage` 透传给前端
- [ ] 前端只有一套 polling 机制
- [ ] 前端按钮在 RUNNING 时 disabled
- [ ] 关键路径写了 `log.info` 便于排查（开始 / 进度 / 结束）

---

## 反模式（不要这么做）

| 反模式 | 为什么不行 |
|--------|-----------|
| 启动新线程而非 `Executor` | 不受池化管理，OOM 风险 |
| 把结果塞进 HTTP Session | 多实例部署直接失效 |
| 把状态写文件 | 多实例部署、容器重启都丢 |
| 用 `@Async` 但不管返回值 | 异常被吞，用户不知道失败 |
| 前端轮询用 `setInterval` 但不 cleanup | 路由切换后还在跑，反复触发 setState 报警 |
| 同步接口加 `@Async` 注解（self-invocation） | 不走代理，注解不生效 → 见 `java-dev` skill 「Spring self-invocation 陷阱」 |

---

## 升级路径

任务规模继续增长时的演进方向：

| 当前规模 | 推荐方案 |
|---------|---------|
| 单租户单进程，< 1 小时 | 本 skill 描述的 `ConcurrentHashMap` 状态机 |
| 多实例部署，需共享状态 | 状态存 Redis（TTL 1h）+ 分布式锁 |
| 长任务（> 1 小时）或需要重试 | 上专门的任务队列（Spring Batch / XXL-Job / RocketMQ） |
| 工作流编排 | Temporal / Activiti |

不要过早上重型方案。`ConcurrentHashMap + Executor` 能覆盖 80% 的"同步太慢"场景。

---

## 规则溯源

```
> 📋 本回复遵循：`async-task-pattern` - [章节]
```

</instructions>