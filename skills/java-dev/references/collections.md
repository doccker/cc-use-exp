# 集合与字符串处理

> Java 8 环境下的集合和字符串最佳实践

---

## 不可变集合（Guava）

### 为什么需要不可变集合？

`static final` 只保证引用不变，集合内容仍可被修改：

```java
// ❌ 危险：final 无法阻止内容被修改
private static final Map<String, String> CONFIG = new HashMap<>();
static {
    CONFIG.put("key", "value");
}
// 任何地方都能执行 CONFIG.put("hack", "data") 或 CONFIG.clear()
```

### Guava 依赖

```xml
<dependency>
    <groupId>com.google.guava</groupId>
    <artifactId>guava</artifactId>
    <version>32.1.2-jre</version>
</dependency>
```

### ImmutableMap vs ImmutableSortedMap

| 需求 | 选择 | 说明 |
|------|------|------|
| 键值查找，顺序不重要 | `ImmutableMap` | 更通用，性能稍好 |
| 需要键有序遍历 | `ImmutableSortedMap` | 按自然顺序或 Comparator 排列 |

```java
// 无序场景：状态码映射
private static final ImmutableMap<String, String> PERIOD_NAME_MAP = ImmutableMap.of(
    "M", "月度",
    "Q", "季度",
    "H", "半年度",
    "Y", "年度"
);

// 有序场景：月份映射（需要按 1,2,3... 顺序遍历）
private static final ImmutableSortedMap<Integer, String> MONTH_MAP =
    new ImmutableSortedMap.Builder<Integer, String>(Comparator.naturalOrder())
        .put(1, "一月")
        .put(2, "二月")
        // ...
        .build();
```

### 创建方式

| 方式 | 适用场景 | 示例 |
|------|---------|------|
| `of()` | 少量固定元素（≤5个） | `ImmutableMap.of("k1", "v1", "k2", "v2")` |
| `builder()` | 动态构建或超过5个 | `ImmutableMap.builder().put(...).build()` |
| `copyOf()` | 从已有集合创建 | `ImmutableSet.copyOf(existingSet)` |
| `toImmutableXxx()` | Stream 收集 | `.collect(ImmutableSet.toImmutableSet())` |

### ImmutableSet / ImmutableList

```java
// Set：自动去重，保持插入顺序
ImmutableSet<String> tags = ImmutableSet.of("java", "spring", "java");
// 结果：[java, spring]

// List：保持顺序，允许重复
ImmutableList<String> items = ImmutableList.of("a", "b", "a");
// 结果：[a, b, a]

// 替代 Arrays.asList()
ImmutableList<Integer> codes = ImmutableList.of(
    BudgetUsageTypeEnum.FROZEN.getValue(),
    BudgetUsageTypeEnum.UNFROZEN.getValue()
);
```

### 与 JDK 的区别

| 特性 | Guava Immutable* | Collections.unmodifiableXxx |
|------|-----------------|----------------------------|
| 真正不可变 | ✅ 防御性拷贝，完全独立 | ❌ 只是视图，原集合变它也变 |
| null 元素 | ❌ 不允许（快速失败） | ✅ 允许 |
| 线程安全 | ✅ 天然安全 | ⚠️ 取决于原集合 |

---

## 字符串分割

### StringUtils.split vs String.split

| 特性 | `StringUtils.split(str, sep)` | `String.split(regex)` |
|------|------------------------------|----------------------|
| 分隔符类型 | 普通字符串 | 正则表达式 |
| null 处理 | ✅ 返回 null | ❌ 抛 NPE |
| 连续分隔符 | 合并为一个 | 产生空串 |
| 结果含空串 | ❌ 不包含 | ✅ 包含中间空串 |
| 性能 | ⚡ 更快 | 🐌 涉及正则编译 |

### 常见陷阱

```java
String ip = "192.168.1.1";

// ❌ 陷阱：. 在正则中匹配任意字符
ip.split(".");           // 结果：[] 空数组！

// ✅ 正确：转义或用 StringUtils
ip.split("\\.");         // 结果：[192, 168, 1, 1]
StringUtils.split(ip, "."); // 结果：[192, 168, 1, 1]
```

```java
String path = "/home//user/";

// String.split：保留中间空串
path.split("/");         // ["", "home", "", "user"]
path.split("/", -1);     // ["", "home", "", "user", ""]

// StringUtils.split：干净结果
StringUtils.split(path, "/"); // ["home", "user"]
```

### 选择原则

```
需要正则匹配？
├─ 是 → String.split(regex)
│       └─ 性能敏感？→ Pattern.compile() 预编译
└─ 否 → 输入可能为 null？
         ├─ 是 → StringUtils.split()
         └─ 否 → 需要控制分割次数？
                  ├─ 是 → String.split(str, limit)
                  └─ 否 → StringUtils.split()（更安全）
```

---

## 规则溯源

```
> 📋 本回复遵循：`java-dev/collections.md` - [具体章节]
```
