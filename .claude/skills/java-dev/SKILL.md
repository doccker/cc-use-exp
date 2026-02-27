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

---

## 性能优化

| 陷阱 | 解决方案 |
|------|---------|
| N+1 查询 | 见「N+1 查询防范」章节 |
| 循环拼接字符串 | 使用 `StringBuilder` |
| 频繁装箱拆箱 | 使用原始类型流 |
| 未指定集合初始容量 | `new ArrayList<>(size)` |

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
| `references/code-patterns.md` | 卫语句、枚举优化、策略工厂模式 |

---

> 📋 本回复遵循：`java-dev` - [具体章节]
