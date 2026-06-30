# Spring Boot 进阶规范

> 注入方式、Auth 降级、循环依赖防范、self-invocation 陷阱、DTO 静默忽略、分页参数规范

---

## 基础注入

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

## Auth Filter 降级原则

| 规则 | 说明 |
|------|------|
| ✅ optional-auth 路径遇到无效/过期/不完整 token 时降级为匿名访问 | 不应返回 401/403 |
| ❌ 禁止部分凭证用户体验差于匿名用户 | 如：临时 token 在公开接口返回 403 |

---

## 循环依赖防范（Spring Boot 3.x）

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

> 详见 `cc-refactor-safety` skill - 陷阱 #5

---

## Spring self-invocation 陷阱（`@Transactional` / `@Async` / `@Cacheable` 失效）

**根因**：Spring 注解通过 AOP 代理生效，`this.someMethod()` 是直接方法调用，**不经过代理**，所以注解形同虚设。最常见的踩坑场景：

```java
@Service
public class ProductService {
    public BulkDeleteResult bulkDelete(List<Long> ids) {
        for (Long id : ids) {
            try {
                deleteProduct(id, "批量清理");  // ❌ this 调用，不走代理
                // → @Transactional 不生效
                // → 内部的 @Modifying JPA 查询抛 "Executing an update/delete query"
                // → 全部 29 条都 failed，看起来像权限问题，实际是事务问题
            } catch (Exception e) { /* ... */ }
        }
        return result;
    }

    @Transactional
    public void deleteProduct(Long id, String reason) {
        productSupplierRepository.deleteByProductId(id);  // @Modifying 必须在事务中
        // ...
    }
}
```

### 修复方案

**方案 1：self-injection（推荐）**

```java
@Service
public class ProductService {
    @Autowired
    @Lazy  // 解决 self-injection 的循环依赖
    private ProductService self;

    public BulkDeleteResult bulkDelete(List<Long> ids) {
        for (Long id : ids) {
            self.deleteProduct(id, "批量清理");  // ✅ 走代理
        }
    }

    @Transactional
    public void deleteProduct(Long id, String reason) { /* ... */ }
}
```

**方案 2：拆分到不同 Bean**

```java
@Service @RequiredArgsConstructor
public class ProductBulkService {
    private final ProductService productService;  // 跨 Bean 调用走代理

    public BulkDeleteResult bulkDelete(List<Long> ids) {
        for (Long id : ids) productService.deleteProduct(id, "批量清理");
    }
}
```

**方案 3：`AopContext.currentProxy()`**（最少推荐，需要 `@EnableAspectJAutoProxy(exposeProxy = true)`）

```java
((ProductService) AopContext.currentProxy()).deleteProduct(id, "批量清理");
```

### 嗅探信号

代码评审时只要看到以下模式，立即怀疑：

- `service` 类的方法内直接调用同类另一个带 `@Transactional` / `@Async` / `@Cacheable` 的方法
- 报错 `Executing an update/delete query`（`@Modifying` 没事务）
- `@Async` 方法跑在调用方线程而非线程池
- `@Cacheable` 没命中缓存反复打数据库

### `@Modifying` JPA 方法的事务硬约束

```java
@Modifying(clearAutomatically = true)
@Query("UPDATE Product p SET p.categoryId = :newId WHERE p.categoryId = :oldId")
int reparent(...);
```

- 调用方**必须**在 `@Transactional` 中（REQUIRED 复用现有事务也行）
- 不在事务中调用 → `InvalidDataAccessApiUsageException: Executing an update/delete query`
- 通过 self-invocation 调用带 `@Transactional` 的包装方法 → 同样失败（注解失效）

### 检查清单

- [ ] 同类内方法调用是否依赖 `@Transactional` 注解生效
- [ ] 批量循环里调用单条 `@Transactional` 方法时，是否通过 self proxy 调用
- [ ] `@Async` 方法是否在另一个类中（或通过 self proxy）
- [ ] 看到 `Executing an update/delete query` 错误，先排查 self-invocation
- [ ] `bulkXxx` 类批量方法本身是否需要 `@Transactional`（取决于"全部成功" vs "逐条独立事务"语义）

---

## DTO 静默忽略陷阱

更新接口返回 200 只代表请求已被处理,不代表请求体里的每个字段都进入 DTO、经过 Service 赋值并最终落库。项目如果关闭未知字段失败,请求体中 DTO 未声明的字段会在反序列化阶段被忽略;即使 DTO 已声明字段,Service 未赋值也同样不会更新。

```java
// ❌ 请求体包含 brandId: 1,但 DTO 没有 brandId 字段
// 结果:接口可能返回 200,但 brandId 没有进入更新逻辑
@Data
public class UpdateProductRequest {
    private String name;
    private BigDecimal price;
}

// ✅ 显式定义主更新接口能接收的字段
@Data
public class UpdateProductRequest {
    private String name;
    private BigDecimal price;
    private Long brandId;
    private BigDecimal marketPrice;
    private List<Long> tagIds;
}
```

### 排查方法

1. 对比原始请求体、原始响应体和数据库结果。前端页面状态不等于后端真实响应。
2. 检查 DTO 是否声明字段,再检查 Service 是否实际赋值。
3. 检查项目 Jackson 配置是否允许未知字段被忽略,例如 `FAIL_ON_UNKNOWN_PROPERTIES` 相关配置。

### 后端已有独立端点 ≠ 主更新接口已包含

```
PUT /products/{id}/brand   ← 只更新 brand
PUT /products/{id}         ← 主更新接口,也需要显式处理 brandId 才会更新
```

独立端点存在,不代表主更新接口已经处理同一字段。新增可编辑字段时,同步检查 DTO、Mapper/Service、响应 DTO 和测试。

### 检查清单

- [ ] 请求体字段是否全部在 DTO 中声明
- [ ] DTO 字段是否在 Service 更新逻辑中赋值
- [ ] 主更新接口是否覆盖了前端页面所有可编辑字段
- [ ] API 返回 200 但 DB 没更新时,是否已对比原始 request/response 和数据库

---

## 分页参数规范（Spring Data JPA）

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
