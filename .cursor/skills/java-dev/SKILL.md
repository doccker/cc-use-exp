---
name: java-dev
description: >-
  Java 开发规范。当用户操作 .java、pom.xml、build.gradle 文件，或涉及 Spring Boot、JPA、MyBatis 开发时触发。
  包含命名约定、异常处理、DTO/VO 规范、批量查询、N+1 防范、并发安全、输入校验、Spring Boot 最佳实践等。
---

# Java 开发规范

> 参考来源: Google Java Style Guide、阿里巴巴 Java 开发手册

---

## 工具链

```bash
# Maven
mvn clean compile                    # 编译
mvn test                             # 运行测试

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

## DTO/VO 类规范

| 规则 | 说明 |
|------|------|
| ❌ 禁止手写 getter/setter | DTO、VO、Request、Response 类一律使用 Lombok |
| ✅ 使用 `@Data` | 普通 DTO |
| ✅ 使用 `@Value` | 不可变 DTO |
| ✅ 使用 `@Builder` | 字段较多时配合使用 |
| ⚠️ Entity 类慎用 `@Data` | JPA Entity 的 equals/hashCode 会影响 Hibernate 代理 |

---

## 批量查询规范

| 规则 | 说明 |
|------|------|
| ❌ 禁止 IN 子句超过 500 个参数 | SQL 解析开销大，执行计划不稳定 |
| ✅ 超过时分批查询 | 每批 500，合并结果 |

```java
public static <T, R> List<R> batchQuery(List<T> params, int batchSize,
                                         Function<List<T>, List<R>> queryFn) {
    List<R> result = new ArrayList<>();
    for (int i = 0; i < params.size(); i += batchSize) {
        List<T> batch = params.subList(i, Math.min(i + batchSize, params.size()));
        result.addAll(queryFn.apply(batch));
    }
    return result;
}
```

---

## N+1 查询防范

| 规则 | 说明 |
|------|------|
| ❌ 禁止循环内调用 Repository/Mapper | stream/forEach/for 内每次迭代触发一次查询 |
| ✅ 循环外批量查询，结果转 Map | 查询次数从 N 降为 1 |

```java
// ✅ 循环外批量查询 + Map 查找
List<String> deviceIds = records.stream()
    .map(Record::getDeviceId).distinct().collect(Collectors.toList());
Map<String, Long> countMap = deviceRepo.countByDeviceIdIn(deviceIds).stream()
    .collect(Collectors.toMap(CountDTO::getDeviceId, CountDTO::getCount));
records.forEach(r -> r.setDeviceCount(countMap.getOrDefault(r.getDeviceId(), 0L)));
```

---

## 并发安全规范

| 规则 | 说明 |
|------|------|
| ❌ 禁止 read-modify-write | 先读余额再写回，并发下丢失更新 |
| ✅ 使用原子更新 SQL | `UPDATE SET balance = balance + :delta WHERE id = :id` |
| ✅ 或使用乐观锁 | `@Version` 字段 + 重试机制 |
| ✅ 唯一索引兜底 | 防重复插入的最后防线 |

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

## 输入校验规范

| 规则 | 说明 |
|------|------|
| ❌ 禁止 `@RequestBody` 不加 `@Valid` | 所有请求体必须校验 |
| ✅ DTO 字段加约束注解 | `@NotBlank`、`@Size`、`@Pattern` 等 |
| ✅ 数值字段加范围约束 | `@Min`、`@Max`、`@Positive` 等 |
| ✅ 分页参数加上限 | `size` 必须 `@Max(100)` 防止大量查询 |

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
```

### Auth Filter 降级原则

| 规则 | 说明 |
|------|------|
| ✅ optional-auth 路径遇到无效 token 时降级为匿名访问 | 不应返回 401/403 |
| ❌ 禁止部分凭证用户体验差于匿名用户 | 如：临时 token 在公开接口返回 403 |

---

## Native SQL 规范

**高频踩坑保留字**：`year_month`, `order`, `status`, `key`, `value`, `name`, `type`, `date`, `time`, `rank`

| 规则 | 说明 |
|------|------|
| ✅ 使用短别名或缩写 | `ym`, `ord_status`, `cnt` |
| ❌ 禁止直接用保留字做别名 | `as year_month`、`as order`、`as rank` |

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
    }
}
```

---

## 详细参考

| 文件 | 内容 |
|------|------|
| `references/java-style.md` | 命名约定、异常处理、Spring Boot、测试规范 |
| `references/collections.md` | 不可变集合（Guava）、字符串分割 |
| `references/concurrency.md` | 线程池配置、CompletableFuture 超时 |
| `references/concurrency-db-patterns.md` | Get-Or-Create 并发、N+1 防范、原子更新 |
| `references/code-patterns.md` | 卫语句、枚举优化、策略工厂模式 |
| `references/date-time.md` | 日期加减、账期计算、禁止月末对齐 |
