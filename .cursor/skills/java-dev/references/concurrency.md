# 并发编程进阶

> 线程池配置与 CompletableFuture 最佳实践

---

## 线程池配置

### 禁止项

| 禁止 | 原因 |
|------|------|
| `Executors.newFixedThreadPool()` | 使用无界队列，可能导致 OOM |
| `Executors.newCachedThreadPool()` | maxPoolSize = MAX_VALUE，可能创建过多线程 |
| `maximumPoolSize = Integer.MAX_VALUE` | 导致 `OOM: unable to create new native thread` |

### 反面教材

```java
// ❌ 教材1：文件打印线程池
new ThreadPoolExecutor(
    Runtime.getRuntime().availableProcessors() * 10,  // 核心线程过多
    Integer.MAX_VALUE,  // 致命！无限创建线程
    60L, TimeUnit.SECONDS,
    new LinkedBlockingQueue<>(100000),
    new ThreadPoolExecutor.CallerRunsPolicy()  // 几乎不会触发
);

// ❌ 教材2：数据校验线程池
new ThreadPoolExecutor(
    Runtime.getRuntime().availableProcessors() * 20,  // 160个常驻线程！
    200,  // 与核心数差距太小，失去弹性
    60L, TimeUnit.SECONDS,
    new LinkedBlockingQueue<>(1500),
    new ThreadPoolExecutor.CallerRunsPolicy()
);
```

### 参数设置原则

| 任务类型 | 特点 | corePoolSize | maximumPoolSize |
|---------|------|--------------|-----------------|
| CPU 密集型 | 计算、编码、算法 | CPU 核心数 | CPU 核心数 + 1 |
| I/O 密集型 | 数据库、网络、文件 | CPU 核心数 × 2 | CPU 核心数 × 4（或经压测确定） |

### 最佳实践配置

```java
private static final int CPU_COUNT = Runtime.getRuntime().availableProcessors();

// I/O 密集型任务（如文件处理）
private final ThreadPoolExecutor ioExecutor = new ThreadPoolExecutor(
    CPU_COUNT * 2,      // 核心线程
    CPU_COUNT * 4,      // 最大线程（有界！）
    60L, TimeUnit.SECONDS,
    new LinkedBlockingQueue<>(10000),  // 有界队列
    new NamedThreadFactory("io-task"),
    new ThreadPoolExecutor.AbortPolicy()  // 明确拒绝
);

// CPU 密集型任务（如计算）
private final ThreadPoolExecutor cpuExecutor = new ThreadPoolExecutor(
    CPU_COUNT,
    CPU_COUNT + 1,
    60L, TimeUnit.SECONDS,
    new LinkedBlockingQueue<>(1000),
    new NamedThreadFactory("cpu-task"),
    new ThreadPoolExecutor.CallerRunsPolicy()  // 反压
);
```

### 拒绝策略选择

| 策略 | 行为 | 适用场景 |
|------|------|---------|
| `AbortPolicy` | 抛异常 | 需要感知过载、支持重试 |
| `CallerRunsPolicy` | 调用方执行 | 不丢弃任务、可接受阻塞 |
| `DiscardPolicy` | 静默丢弃 | ⚠️ 慎用，任务不重要时 |
| `DiscardOldestPolicy` | 丢弃最老任务 | ⚠️ 慎用，有数据丢失风险 |

---

## CompletableFuture 超时处理

### 三种方式对比

| 方式 | 行为 | Future 状态变化 | 后续 get |
|------|------|----------------|---------|
| `get(timeout, unit)` | 本次获取超时 | 不变 | 可继续 get |
| `orTimeout(timeout, unit)` | Future 异常完成 | 变为异常状态 | 抛 CompletionException |
| `completeOnTimeout(value, timeout, unit)` | Future 用默认值完成 | 变为正常完成 | 返回默认值 |

### 代码示例

```java
CompletableFuture<String> future = CompletableFuture.supplyAsync(() -> {
    // 模拟耗时操作
    Thread.sleep(2000);
    return "完成";
});

// 方式1：温和超时，可重试
try {
    String result = future.get(1, TimeUnit.SECONDS);
} catch (TimeoutException e) {
    // 这次超时，但 future 状态未变，可继续 get
}

// 方式2：强制超时终止
CompletableFuture<String> strict = future
    .orTimeout(1, TimeUnit.SECONDS);
// 超时后，后续所有 get 都抛 CompletionException

// 方式3：优雅降级
CompletableFuture<String> graceful = future
    .completeOnTimeout("默认值", 1, TimeUnit.SECONDS);
// 超时后返回"默认值"，原任务可能继续执行
```

### 选择原则

```
需要重试？
├─ 是 → get(timeout, unit)
└─ 否 → 需要降级默认值？
         ├─ 是 → completeOnTimeout()
         └─ 否 → orTimeout()（严格超时）
```

### 批量任务超时

```java
List<CompletableFuture<String>> futures = ids.stream()
    .map(id -> CompletableFuture
        .supplyAsync(() -> fetchData(id), executor)
        .completeOnTimeout("N/A", 500, TimeUnit.MILLISECONDS))
    .toList();

// 等待全部完成
CompletableFuture.allOf(futures.toArray(new CompletableFuture[0])).join();

// 收集结果
List<String> results = futures.stream()
    .map(CompletableFuture::join)
    .toList();
```

---

## 规则溯源

```
> 📋 本回复遵循：`java-dev/concurrency.md` - [具体章节]
```
