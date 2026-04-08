---
name: java-dev
description: Java 开发规范，包含命名约定、异常处理、Spring Boot 最佳实践等
version: v3.0
paths:
  - "**/*.java"
  - "**/pom.xml"
  - "**/build.gradle"
  - "**/build.gradle.kts"
---

# Java 开发规范

> 参考来源: Google Java Style Guide、阿里巴巴 Java 开发手册

---

## 工具链

```bash
# Maven
mvn clean compile                    # 编译
mvn test                             # 运行测试
mvn verify                           # 运行所有检查

# Gradle
./gradlew build                      # 构建
./gradlew test                       # 运行测试
```

---

## 命名约定

| 类型 | 规则 | 示例 |
|------|------|------|
| 包名 | 全小写，域名反转 | `com.example.project` |
| 类名 | 大驼峰，名词/名词短语 | `UserService`, `HttpClient` |
| 方法名 | 小驼峰，动词开头 | `findById`, `isValid` |
| 常量 | 全大写下划线分隔 | `MAX_RETRY_COUNT` |
| 布尔返回值 | is/has/can 前缀 | `isActive()`, `hasPermission()` |

---

## 类成员顺序

```java
public class Example {
    // 1. 静态常量
    public static final String CONSTANT = "value";

    // 2. 静态变量
    private static Logger logger = LoggerFactory.getLogger(Example.class);

    // 3. 实例变量
    private Long id;

    // 4. 构造函数
    public Example() { }

    // 5. 静态方法
    public static Example create() { return new Example(); }

    // 6. 实例方法（公共 → 私有）
    public void doSomething() { }
    private void helperMethod() { }

    // 7. getter/setter（或使用 Lombok）
}
```

---

## DTO/VO 类规范

| 规则 | 说明 |
|------|------|
| ❌ 禁止手写 getter/setter | DTO、VO、Request、Response 类一律使用 Lombok |
| ✅ 使用 `@Data` | 普通 DTO |
| ✅ 使用 `@Value` | 不可变 DTO |
| ✅ 使用 `@Builder` | 字段较多时配合使用 |
| ⚠️ Entity 类慎用 `@Data` | JPA Entity 的 equals/hashCode 会影响 Hibernate 代理 |

```java
// ❌ 手写 getter/setter
public class UserDTO {
    private Long id;
    private String name;
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    // ... 大量样板代码
}

// ✅ 使用 Lombok
@Data
public class UserDTO {
    private Long id;
    private String name;
}
```

---

## 批量查询规范

| 规则 | 说明 |
|------|------|
| ❌ 禁止 IN 子句超过 500 个参数 | SQL 解析开销大，执行计划不稳定 |
| ✅ 超过时分批查询 | 每批 500，合并结果 |
| ✅ 封装通用工具方法 | 避免每处手写分批逻辑 |

```java
// ❌ 1700 个 ID 一次查询
List<User> users = userRepository.findByIdIn(allIds); // IN 子句过长

// ✅ 分批查询工具方法
public static <T, R> List<R> batchQuery(List<T> params, int batchSize,
                                         Function<List<T>, List<R>> queryFn) {
    List<R> result = new ArrayList<>();
    for (int i = 0; i < params.size(); i += batchSize) {
        List<T> batch = params.subList(i, Math.min(i + batchSize, params.size()));
        result.addAll(queryFn.apply(batch));
    }
    return result;
}

// 使用
List<User> users = batchQuery(allIds, 500, ids -> userRepository.findByIdIn(ids));
```

---

## N+1 查询防范

| 规则 | 说明 |
|------|------|
| ❌ 禁止循环内调用 Repository/Mapper | stream/forEach/for 内每次迭代触发一次查询 |
| ✅ 循环外批量查询，结果转 Map | 查询次数从 N 降为 1（或 distinct 数） |

```java
// ❌ N+1：循环内逐行查询 count
records.forEach(record -> {
    long count = deviceRepo.countByDeviceId(record.getDeviceId()); // 每条触发一次查询
    record.setDeviceCount(count);
});

// ✅ 循环外批量查询 + Map 查找
List<String> deviceIds = records.stream()
    .map(Record::getDeviceId).distinct().collect(Collectors.toList());
Map<String, Long> countMap = deviceRepo.countByDeviceIdIn(deviceIds).stream()
    .collect(Collectors.toMap(CountDTO::getDeviceId, CountDTO::getCount));
records.forEach(r -> r.setDeviceCount(countMap.getOrDefault(r.getDeviceId(), 0L)));
```

常见 N+1 场景及修复模式：

| 场景 | 循环内（❌） | 循环外（✅） |
|------|------------|------------|
| count | `repo.countByXxx(id)` | `repo.countByXxxIn(ids)` → `Map<id, count>` |
| findById | `repo.findById(id)` | `repo.findByIdIn(ids)` → `Map<id, entity>` |
| exists | `repo.existsByXxx(id)` | `repo.findXxxIn(ids)` → `Set<id>` + `set.contains()` |

---

## 并发安全规范

| 规则 | 说明 |
|------|------|
| ❌ 禁止 read-modify-write | 先读余额再写回，并发下丢失更新 |
| ❌ 禁止 check-then-act 无兜底 | 先检查再操作，并发下条件失效 |
| ✅ 使用原子更新 SQL | `UPDATE SET balance = balance + :delta WHERE id = :id` |
| ✅ 或使用乐观锁 | `@Version` 字段 + 重试机制 |
| ✅ 唯一索引兜底 | 防重复插入的最后防线 |

```java
// ❌ read-modify-write 竞态条件
PointsAccount account = accountRepo.findById(id);
account.setBalance(account.getBalance() + points); // 并发时丢失更新
accountRepo.save(account);

// ✅ 方案一：原子更新 SQL
@Modifying
@Query("UPDATE PointsAccount SET balance = balance + :points WHERE id = :id")
int addBalance(@Param("id") Long id, @Param("points") int points);

// ✅ 方案二：乐观锁
@Version
private Long version; // Entity 中添加版本字段
```

```java
// ❌ check-then-act 无兜底（并发下可能重复结算）
if (!rewardRepo.existsByTenantIdAndPeriod(tenantId, period)) {
    rewardRepo.save(new RankingReward(...));
}

// ✅ 唯一索引兜底 + 异常捕获
// DDL: UNIQUE INDEX uk_tenant_period (tenant_id, ranking_type, period, rank_position)
try {
    rewardRepo.save(new RankingReward(...));
} catch (DataIntegrityViolationException e) {
    log.warn("重复结算已被唯一索引拦截: tenantId={}, period={}", tenantId, period);
}
```

---

## 异常处理

```java
// ✅ 好：捕获具体异常，添加上下文
try {
    user = userRepository.findById(id);
} catch (DataAccessException e) {
    throw new ServiceException("Failed to find user: " + id, e);
}

// ✅ 好：资源自动关闭
try (InputStream is = new FileInputStream(file)) {
    // 使用资源
}

// ❌ 差：捕获过宽
catch (Exception e) { e.printStackTrace(); }
```

---

## 空值处理

```java
// ✅ 使用 Optional
public Optional<User> findById(Long id) {
    return userRepository.findById(id);
}

// ✅ 参数校验
public void updateUser(User user) {
    Objects.requireNonNull(user, "user must not be null");
}

// ✅ 安全的空值处理
String name = Optional.ofNullable(user)
    .map(User::getName)
    .orElse("Unknown");
```

---

## 并发编程

```java
// ✅ 使用 ExecutorService
ExecutorService executor = Executors.newFixedThreadPool(10);
Future<Result> future = executor.submit(() -> doWork());

// ✅ 使用 CompletableFuture
CompletableFuture<User> future = CompletableFuture
    .supplyAsync(() -> findUser(id))
    .thenApply(user -> enrichUser(user));

// ❌ 差：直接创建线程
new Thread(() -> doWork()).start();
```

---

## 测试规范 (JUnit 5)

```java
class UserServiceTest {
    @Test
    @DisplayName("根据 ID 查找用户 - 用户存在时返回用户")
    void findById_whenUserExists_returnsUser() {
        // given
        when(userRepository.findById(1L)).thenReturn(Optional.of(expected));

        // when
        Optional<User> result = userService.findById(1L);

        // then
        assertThat(result).isPresent();
        assertThat(result.get().getName()).isEqualTo("test");
    }
}
```

---

## Spring Boot 规范

```java
// ✅ 构造函数注入
@Service
@RequiredArgsConstructor
public class UserService {
    private final UserRepository userRepository;
    private final EmailService emailService;
}

// ✅ REST Controller
@RestController
@RequestMapping("/api/users")
public class UserController {
    @GetMapping("/{id}")
    public ResponseEntity<UserDto> findById(@PathVariable Long id) {
        return userService.findById(id)
            .map(ResponseEntity::ok)
            .orElse(ResponseEntity.notFound().build());
    }
}
```

### Auth Filter 降级原则

| 规则 | 说明 |
|------|------|
| ✅ optional-auth 路径遇到无效/过期/不完整 token 时降级为匿名访问 | 不应返回 401/403 |
| ❌ 禁止部分凭证用户体验差于匿名用户 | 如：临时 token 在公开接口返回 403 |

### 循环依赖防范（Spring Boot 3.x）

Spring Boot 3.x 默认禁止构造器循环依赖。从大 Service 拆分子 Service 时必须检查依赖方向。

| 处理方式 | 优先级 | 适用场景 |
|----------|--------|---------|
| 提取公共方法到独立工具类 | ✅ 首选 | 纯工具方法（如 resolveTenantIds） |
| `@Lazy` 字段注入 | ⚠️ 应急 | 确实需要双向调用 |
| `Function<>` 回调 | ⚠️ 备选 | 灵活但增加复杂度 |

```java
// ❌ 拆分后子服务回调父服务 → 循环依赖
@RequiredArgsConstructor
public class ReportInvoiceService {
    private final ReportService reportService; // 启动失败！
}

// ✅ 提取公共方法到独立类
@Component
public class TenantHelper {
    public List<Long> resolveTenantIds(Long tenantId) { ... }
}
```

> 详见 `refactor-safety` skill - 陷阱 #5

### 分页参数规范（Spring Data JPA）

Spring Data JPA 分页索引从 0 开始。重构分页参数时必须确保前后端索引基准一致。

| 规则 | 说明 |
|------|------|
| 全栈统一 0-based | 前端、Controller、Service、JPA 全部使用 0-based 索引 |
| Controller 默认值必须是 0 | `@RequestParam(defaultValue = "0") int page` |
| Service 直接使用 page | `PageRequest.of(page, size)`，不要 `page - 1` |

```java
// ❌ 错误：前端传 page=0，Controller 默认值 1，Service 内部 -1
@GetMapping("/list")
public Page<Product> list(@RequestParam(defaultValue = "1") int page) {
    return service.list(page);  // Service 内部 PageRequest.of(page - 1, size)
}
// 问题：前端传 page=0 → Service 计算 page - 1 = -1 → 异常

// ✅ 正确：全栈统一 0-based
@GetMapping("/list")
public Page<Product> list(@RequestParam(defaultValue = "0") int page) {
    return service.list(page);  // Service 内部 PageRequest.of(page, size)
}
```

**重构检查清单**：
- [ ] 前端调用传递 `page: 0`（第 1 页）
- [ ] Controller 默认值是 `0`
- [ ] Service 使用 `PageRequest.of(page, size)`（不减 1）
- [ ] 测试 `page=0` 和 `page=1` 都能正常返回数据

---

## 输入校验规范

| 规则 | 说明 |
|------|------|
| ❌ 禁止 `@RequestBody` 不加 `@Valid` | 所有请求体必须校验 |
| ✅ DTO 字段加约束注解 | `@NotBlank`、`@Size`、`@Pattern` 等 |
| ✅ 数值字段加范围约束 | `@Min`、`@Max`、`@Positive` 等 |
| ✅ 分页参数加上限 | `size` 必须 `@Max(100)` 防止大量查询 |
| ✅ 枚举/状态字段白名单校验 | 自定义校验器或 `@Pattern` |

**常见 DTO 字段校验速查**：

| 字段类型 | 必须注解 | 说明 |
|---------|---------|------|
| 数量 quantity | `@NotNull @Min(1)` | 防止 0 或负数（负数可导致反向操作） |
| 金额 amount/price | `@NotNull @Positive` | 或 `@DecimalMin("0.01")` |
| 分页 size | `@Min(1) @Max(100)` | 防止 `size=999999` 拖垮数据库 |
| 分页 page | `@Min(1)` | 页码从 1 开始 |
| 百分比 rate | `@Min(0) @Max(100)` | 视业务定义范围 |

```java
// ❌ 无校验，任意输入直接进入业务逻辑
@PostMapping("/ship")
public Result ship(@RequestBody ShippingRequest request) { ... }

// ✅ 完整校验
@PostMapping("/ship")
public Result ship(@RequestBody @Valid ShippingRequest request) { ... }

public record ShippingRequest(
    @NotNull Long orderId,
    @NotBlank @Size(max = 500) String shippingInfo,
    @Pattern(regexp = "pending|shipped|delivered") String giftStatus
) {}

// ❌ quantity 只有 @NotNull，负数会导致 Redis DECRBY 反向加库存
public record CreateOrderRequest(
    @NotNull Integer quantity  // 可提交 0 或负数
) {}

// ✅ 数量必须 >= 1
public record CreateOrderRequest(
    @NotNull @Min(1) Integer quantity
) {}

// ❌ 分页无上限，用户可传 size=999999
@GetMapping("/orders")
public Result list(@RequestParam int page, @RequestParam int size) { ... }

// ✅ 分页参数加约束
@GetMapping("/orders")
public Result list(@RequestParam @Min(1) int page,
                   @RequestParam @Min(1) @Max(100) int size) { ... }
```

---

## 性能优化

| 陷阱 | 解决方案 |
|------|---------|
| N+1 查询 | 见「N+1 查询防范」章节 |
| 循环拼接字符串 | 使用 `StringBuilder` |
| 频繁装箱拆箱 | 使用原始类型流 |
| 未指定集合初始容量 | `new ArrayList<>(size)` |

---

## 第三方 API HTTP 客户端选型

| 规则 | 说明 |
|------|------|
| ❌ 避免 `RestTemplate` 默认客户端调用国内平台 API | 默认 `HttpURLConnection` 的 POST 请求与微信/支付宝等 CDN 存在兼容性问题（已知触发 412/403） |
| ✅ 优先用 `java.net.http.HttpClient`（JDK 11+） | 现代 HTTP 客户端，无 CDN 兼容性问题 |
| ✅ 或配置 `HttpComponentsClientHttpRequestFactory` | 让 RestTemplate 底层走 Apache HttpClient |

**诊断特征**：HTTP 错误 + body 为空 + response headers 极简（只有 Connection/Content-Length）= CDN 层拦截，不是 API 本身的响应。同一 API 的 GET 正常但 POST 异常时，优先怀疑 HTTP 客户端兼容性。

---

## Native SQL 规范

### 别名避免 MySQL 保留字

`@Query(nativeQuery = true)` 中的列别名如果是 MySQL 保留字，会导致语法错误。

**高频踩坑保留字**：`year_month`, `order`, `status`, `key`, `value`, `name`, `type`, `date`, `time`, `rank`, `range`, `rows`, `column`, `user`, `role`, `group`

| 规则 | 说明 |
|------|------|
| ✅ 使用短别名或缩写 | `ym`, `ord_status`, `cnt` |
| ✅ 或用反引号转义 | `` `year_month` `` |
| ❌ 禁止直接用保留字做别名 | `as year_month`、`as order`、`as rank` |

```java
// ❌ year_month 是 MySQL 保留字（INTERVAL YEAR_MONTH）
@Query(value = """
    SELECT DATE_FORMAT(o.order_date, '%Y-%m') as year_month,
           COUNT(*) as cnt
    FROM orders o
    GROUP BY year_month
    """, nativeQuery = true)

// ✅ 改用非保留字别名
@Query(value = """
    SELECT DATE_FORMAT(o.order_date, '%Y-%m') as ym,
           COUNT(*) as cnt
    FROM orders o
    GROUP BY ym
    """, nativeQuery = true)
```

---

## 日志规范

```java
// ✅ 参数化日志
log.debug("Finding user by id: {}", userId);
log.info("User {} logged in successfully", username);
log.error("Failed to process order {}", orderId, exception);

// ❌ 差：字符串拼接
log.debug("Finding user by id: " + userId);
```

---

## 详细参考

| 文件 | 内容 |
|------|------|
| `references/java-style.md` | 命名约定、异常处理、Spring Boot、测试规范 |
| `references/collections.md` | 不可变集合（Guava）、字符串分割 |
| `references/concurrency.md` | 线程池配置、CompletableFuture 超时 |
| `references/concurrency-db-patterns.md` | Get-Or-Create 并发、N+1 防范、原子更新、Redis+DB 一致性 |
| `references/code-patterns.md` | 卫语句、枚举优化、策略工厂模式 |
| `references/date-time.md` | 日期加减、账期计算、禁止月末对齐 |
| `references/http-client.md` | 第三方 API HTTP 客户端选型、CDN 兼容性问题 |

---

> 📋 本回复遵循：`java-dev` - [具体章节]
