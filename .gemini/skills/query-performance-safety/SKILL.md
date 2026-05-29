---
name: query-performance-safety
description: 当代码涉及循环内查询、批量 ID 查询、IN 子句、BFS/递归遍历、嵌套 service 调用时触发。防止 N+1 查询、IN 子句过长、递归内存炸裂等性能陷阱。
---
<instructions>

# 查询性能安全规范

当代码涉及数据库或远程服务的批量查询时，防止 N+1、IN 子句过长、递归无界等高频性能陷阱。

> 与 `multi-tenant-safety` 配合：本 skill 关注「查询效率」，租户隔离遵循后者。

---

## 陷阱 #1: 循环内调用单条查询 → N+1

**场景**: `for / stream / forEach` 内部直接调用 `repo.findById(...)` 或同等单条远程调用

### 问题根因

每次循环触发一次 SQL/HTTP，N 个元素就是 N 次往返。100 元素 = 100 次 SQL，1000 元素就是 1000 次。本地开发数据少看不出来，生产环境直接拖垮接口。

### 嗅探信号

只要在 service / handler 方法里看到以下任一模式，立即怀疑 N+1：

```java
// ❌ 模式 1：显式 for
for (Order o : orders) {
    User u = userRepository.findById(o.getUserId()).orElse(null);
}

// ❌ 模式 2：stream 链
orders.stream()
      .map(o -> userRepository.findById(o.getUserId()))
      .collect(...);

// ❌ 模式 3：辅助方法被循环调用
for (Item i : items) {
    enrichItem(i);  // 里面又 findById 一次
}

// ❌ 模式 4：嵌套调用
List<X> list = repoA.findByY(y);
for (X x : list) {
    x.setZ(repoB.findById(x.getZId()).orElse(null));
}
```

### 正确做法

「**先批量拿 → 落到 Map → 循环里查 Map**」三步走：

```java
// ✅ 1. 收集所有外键 ID
List<Long> userIds = orders.stream()
        .map(Order::getUserId)
        .filter(Objects::nonNull)
        .distinct()
        .toList();

// ✅ 2. 一次 IN 查询，落到 Map
Map<Long, User> userMap = userRepository
        .findByTenantIdAndIdIn(tenantId, userIds)
        .stream()
        .collect(Collectors.toMap(User::getId, u -> u));

// ✅ 3. 循环内只查 Map，零额外 SQL
for (Order o : orders) {
    User u = userMap.get(o.getUserId());
}
```

### Repository 必须提供的批量方法

| 单条方法 | 必须配套 | 用途 |
|---------|---------|------|
| `findById` | `findAllById` / `findByIdIn` | 已知主键集合 |
| `findByTenantIdAndId` | `findByTenantIdAndIdIn` | 多租户场景批量 |
| `findByFooId` | `findByFooIdIn` | 已知外键集合 |

新增带 IN 的方法时**必须**和单条方法成对出现，避免上层不得不写 N+1。

### 隐式 N+1：循环内调 DTO 转换函数

最坑的一种 N+1 ——`convertToDTO()` / `toResponseDto()` / `enrichEntity()` 这类辅助方法看起来"一个函数搞定一切"，但内部可能藏着 4-5 次 `findById`，循环里调一次就是 N×K 次 SQL。

```java
// ❌ 看起来无害，实际触发 24000 次 SQL（6000 商品 × 4 次内部查询）
public Map<String, List<ProductDTO>> findDuplicates() {
    List<Product> products = productRepository.findByTenantId(tenantId);
    Map<String, List<ProductDTO>> groups = new HashMap<>();
    for (Product p : products) {
        String key = normalize(p.getProductName() + p.getSpecification());
        groups.computeIfAbsent(key, k -> new ArrayList<>())
              .add(convertToDTO(p));  // ❌ 内部每次都查 category/supplier/image/price
    }
    return groups;
}

private ProductDTO convertToDTO(Product p) {
    return ProductDTO.builder()
        .categoryName(categoryRepository.findById(p.getCategoryId())...)     // +1
        .supplier(productSupplierRepository.findByProductId(p.getId())...)   // +1
        .imageUrl(productImageRepository.findByProductId(p.getId())...)      // +1
        .priceTiers(priceTierRepository.findByProductId(p.getId())...)       // +1
        .build();
}
```

#### 修复策略

**策略 A：两阶段处理**（推荐，适合"先筛选再展示"）

```java
// ✅ 阶段 1：用 entity 做筛选/分组，零额外查询
Map<String, List<Product>> grouped = new HashMap<>();
for (Product p : products) {
    grouped.computeIfAbsent(key, k -> new ArrayList<>()).add(p);  // entity，不转 DTO
}

// 只对真正要展示的（如重复组 ≥ 2）做后续处理
grouped.entrySet().removeIf(e -> e.getValue().size() < 2);

// 阶段 2：批量预加载关联数据
Set<Long> categoryIds = grouped.values().stream()
    .flatMap(List::stream)
    .map(Product::getCategoryId)
    .filter(Objects::nonNull)
    .collect(Collectors.toSet());
Map<Long, String> categoryNameMap = categoryRepository.findAllById(categoryIds).stream()
    .collect(Collectors.toMap(ProductCategory::getId, ProductCategory::getCategoryName));

// 阶段 3：用 Map 转 DTO，零额外查询
Map<String, List<ProductDTO>> result = new HashMap<>();
grouped.forEach((k, list) -> {
    result.put(k, list.stream()
        .map(p -> toLightweightDTO(p, categoryNameMap))
        .toList());
});
```

**策略 B：场景化轻量 DTO 转换器**（推荐，结合策略 A）

不同场景用不同 DTO 转换函数。完整版给详情接口，轻量版给列表/查重接口：

```java
// ✅ 列表/查重：只填实际需要的字段
private ProductDTO toLightweightDTO(Product p, Map<Long, String> categoryNameMap) {
    return ProductDTO.builder()
        .id(p.getId())
        .skuCode(p.getSkuCode())
        .productName(p.getProductName())
        .specification(p.getSpecification())
        .categoryId(p.getCategoryId())
        .categoryName(p.getCategoryId() == null ? null : categoryNameMap.get(p.getCategoryId()))
        .status(p.getStatus())
        .build();
    // 不填 supplier/image/priceTiers，列表场景用不到
}

// 详情：用完整 convertToDTO
public ProductDTO getDetail(Long id) {
    return convertToDTO(productRepository.findById(id).orElseThrow());
}
```

**策略 C：批量版 convertToDTO**（适合必须返回完整 DTO 的列表接口）

```java
public List<ProductDTO> convertToDTOs(List<Product> products) {
    // 一次性预加载全部关联
    Set<Long> categoryIds = products.stream().map(Product::getCategoryId).filter(Objects::nonNull).collect(Collectors.toSet());
    Set<Long> productIds = products.stream().map(Product::getId).collect(Collectors.toSet());

    Map<Long, ProductCategory> categoryMap = categoryRepository.findAllById(categoryIds).stream()
        .collect(Collectors.toMap(ProductCategory::getId, c -> c));
    Map<Long, List<ProductImage>> imageMap = productImageRepository.findByProductIdIn(productIds).stream()
        .collect(Collectors.groupingBy(ProductImage::getProductId));
    // ... 其他关联

    // 转换时只查 Map
    return products.stream()
        .map(p -> toDTOWithPreloaded(p, categoryMap, imageMap, ...))
        .toList();
}
```

#### 嗅探信号

代码评审时只要看到以下模式立即怀疑：

- 任意循环（for/stream/forEach）里调用 `convertToDTO(...)` / `toResponseDto(...)` / `to...DTO(...)` / `enrich...(...)`
- 看似"一行搞定"的辅助方法，其实跨了多个 Repository
- 接口响应时间随数据量线性增长，但单条数据看不到明显慢点
- 数据库 SQL 数 = 列表数 × 某个常数

### 检查清单（陷阱 #1 全部场景）

- [ ] service 方法里搜 `findById(` / `getOne(` / `getReferenceById(` / `findOne(`，是否在循环或 stream 链中
- [ ] 每个 list-aware 方法的 SQL 次数与列表大小是否解耦（理想是 O(1) 或 O(log N) 而非 O(N)）
- [ ] enrichment 辅助方法是否被循环调用（隐式 N+1）
- [ ] 跨 service 调用（A.getDetail() → B.findX()）是否在循环里
- [ ] 查重 / 列表 / 统计接口：是否在循环里调用 DTO 转换
- [ ] DTO 转换函数内部 `findXxx` 调用次数 × 列表大小是否能接受
- [ ] 是否区分了"列表轻量 DTO" vs "详情完整 DTO"
- [ ] 批量场景是否提供了 `convertToDTOs(List<T>)` 版本

---

## 陷阱 #2: IN 子句不分批

**场景**: 拿到一个大 list 直接传给 `WHERE id IN (...)`，没有上限保护

### 问题根因

- MySQL `max_allowed_packet`（默认 16M）超限会 fail
- Oracle `IN` 单次最多 1000 个参数
- PostgreSQL 虽无硬限制但单条 SQL 解析与计划生成成本随参数线性增长
- 单条超长 SQL 也会绕过查询计划缓存

### 错误示例

```java
// ❌ 5000 个 ID 直接塞进 IN
List<User> users = userRepository.findByTenantIdAndIdIn(tenantId, allIds);
```

### 正确做法

固定 `IN_BATCH_SIZE = 500`，分批查询后合并：

```java
private static final int IN_BATCH_SIZE = 500;

private List<User> findUsersByIds(Long tenantId, List<Long> ids) {
    List<User> result = new ArrayList<>(ids.size());
    for (int i = 0; i < ids.size(); i += IN_BATCH_SIZE) {
        List<Long> batch = ids.subList(i, Math.min(i + IN_BATCH_SIZE, ids.size()));
        result.addAll(userRepository.findByTenantIdAndIdIn(tenantId, batch));
    }
    return result;
}
```

**聚合 SUM/COUNT/AVG 的分批**：

```java
private long sumByBatches(Long tenantId, List<Long> ids) {
    long total = 0L;
    for (int i = 0; i < ids.size(); i += IN_BATCH_SIZE) {
        List<Long> batch = ids.subList(i, Math.min(i + IN_BATCH_SIZE, ids.size()));
        Long val = repository.sumByIds(tenantId, batch);
        if (val != null) total += val;
    }
    return total;
}
```

> JPA 用户也可借助 `Lists.partition` (Guava) 或 `CollectionUtils.partition` (Apache Commons)。

### 检查清单

- [ ] 所有传入 IN 的 list 是否经过分批（grep `IN (` / `findByIdIn` / `findAllById`）
- [ ] 项目级 `IN_BATCH_SIZE` 常量是否统一在 500 或更小
- [ ] 聚合查询（SUM/COUNT）也已分批
- [ ] 入口参数（如批量删除接口）是否限制了最大 list 长度

---

## 陷阱 #3: BFS/递归遍历无总节点上限

**场景**: 邀请树、组织架构、文件夹、评论树等递归结构，按 depth 限制但不限 totalNodes

### 问题根因

`depth ≤ 3` 看似安全，但每层节点数可能爆炸：层 1=1000 → 层 2=100×1000=10万 → 层 3 可能百万级。全部加载到内存就是 OOM。

### 错误示例

```java
// ❌ 只限 depth，不限总数
public List<User> collectDescendants(Long tenantId, WxUser self) {
    Map<Long, WxUser> visited = new LinkedHashMap<>();
    visited.put(self.getId(), self);
    List<Long> currentLevelIds = List.of(self.getId());
    for (int depth = 1; depth <= MAX_INVITE_DEPTH && !currentLevelIds.isEmpty(); depth++) {
        List<WxUser> nextLevel = repo.findByInviterIdIn(tenantId, currentLevelIds);
        // 没有总数限制，nextLevel 可能 10w+
        ...
    }
}
```

### 正确做法

加 `MAX_TOTAL_NODES` 硬上限 + `log.warn` 截断 + 接口语义文档化：

```java
private static final int MAX_INVITE_DEPTH = 3;
private static final int MAX_TOTAL_NODES = 5000;

public List<User> collectDescendants(Long tenantId, WxUser self) {
    Map<Long, WxUser> visited = new LinkedHashMap<>();
    visited.put(self.getId(), self);

    List<Long> currentLevelIds = List.of(self.getId());
    for (int depth = 1; depth <= MAX_INVITE_DEPTH && !currentLevelIds.isEmpty(); depth++) {
        if (visited.size() >= MAX_TOTAL_NODES) {
            log.warn("BFS 节点达上限 {}，截断: root={}, depth={}",
                     MAX_TOTAL_NODES, self.getId(), depth);
            break;
        }
        List<User> nextLevel = repo.findByInviterIdIn(tenantId, currentLevelIds);
        List<Long> nextIds = new ArrayList<>(nextLevel.size());
        for (User u : nextLevel) {
            if (visited.size() >= MAX_TOTAL_NODES) break;
            if (visited.putIfAbsent(u.getId(), u) == null) {
                nextIds.add(u.getId());
            }
        }
        currentLevelIds = nextIds;
    }
    return new ArrayList<>(visited.values());
}
```

**何时改用流式 / 分页 / 异步**:

- 节点数预期 > MAX_TOTAL_NODES 的 80% → 考虑改为分页/流式遍历，避免一次性载入
- 真的需要全量统计 → 用 SUM/COUNT 聚合 SQL，不要拉全量到内存再 .size()/.stream().mapToLong()

### 检查清单

- [ ] 递归/BFS 是否同时有 `MAX_DEPTH` 和 `MAX_TOTAL_NODES`
- [ ] 截断时是否 `log.warn` 留痕（生产排查依据）
- [ ] 接口注释/文档是否说明「最大返回节点数」语义
- [ ] 统计场景是否优先用聚合 SQL 而非全量加载

---

## 陷阱 #4: 嵌套 service 调用造成隐式重复查询

**场景**: 同一个接口内调用 `getDetail()` + `countMembers()` + `getMembers()`，每个内部都跑一次完整 BFS / 大表查询

### 问题根因

每个 public service 方法封装了一套查询，单独看都合理；组合调用时同样的 BFS 跑 3 次。前端把它当作"查 1 个接口"，后端实际是 3 倍 SQL。

### 错误示例

```java
public TeamDetailVO getMyTeamDetail(Long tenantId, Long userId) {
    int memberCount = teamMemberService.countMembers(tenantId, userId);  // BFS #1
    Long totalPoints = teamMemberService.sumPoints(tenantId, userId);    // BFS #2（内部又调 collectDescendants）
    List<Member> members = teamMemberService.listMembers(tenantId, userId); // BFS #3
    return ...;
}
```

### 正确做法

**提取共享底层方法返回 list**，上层只跑一次：

```java
public TeamDetailVO getMyTeamDetail(Long tenantId, Long userId) {
    // 单次 BFS 拿到全量队员
    List<User> members = teamMemberService.collectDescendants(tenantId, user);

    int memberCount = members.size();
    Long totalPoints = pointsRepository.sumBySourceUserIds(tenantId,
            members.stream().map(User::getId).toList());
    return TeamDetailVO.builder()
            .memberCount(memberCount)
            .totalPoints(totalPoints)
            .members(toVO(members))
            .build();
}

// countMembers / listMembers 标 @Deprecated 或直接删除，避免外部继续踩坑
```

### 检查清单

- [ ] 同一 controller 方法内是否多次调用同一底层重查询（grep 调用次数）
- [ ] 是否存在「`countXxx` + `listXxx`」并存且都跑完整查询
- [ ] 拆分子 service 时，被复用的底层查询是否上提为公共方法
- [ ] 标 `@Deprecated` 的旧方法是否在合理迭代内删除

---

## 陷阱 #5: 大表 WHERE / IN 缺失索引

**场景**: 新增 `findByXxx` 方法，但 xxx 列没有索引；或新增 `sourceUserId IN (...)` 聚合，但该列只被 SELECT 用过

### 问题根因

SUM/IN 1000 行也许还能撑，5000 行直接全表扫描，CPU 飙到 100%。索引在小表上看不出差异，生产数据规模下决定接口生死。

### 检查方法

每次新增 Repository 查询方法，对照实体类的 `@Index` 注解 + Flyway 迁移脚本：

```java
// ✅ 实体上声明索引
@Entity
@Table(name = "points_pending", indexes = {
    @Index(name = "idx_pending_source_user", columnList = "tenant_id, source_user_id"),
    @Index(name = "idx_pending_confirmed_at", columnList = "tenant_id, confirmed_at"),
})
public class PointsPending { ... }
```

```sql
-- ✅ Flyway 显式建索引（实体注解不会自动建索引到已存在的表）
CREATE INDEX idx_pending_source_user ON points_pending (tenant_id, source_user_id);
```

### 检查清单

- [ ] 新增 `findByXxx` 时，xxx 列是否有索引（联合索引含 tenant_id）
- [ ] WHERE 条件命中索引（用 `EXPLAIN` 验证，不是猜）
- [ ] 范围查询字段放在联合索引最后（如 `idx (tenant_id, status, created_at)`）
- [ ] 软删除字段（`deleted_at`）需要时也要加入索引

---

## 陷阱 #6: 缓存 / 二级缓存反模式

**场景**: 用了 `@Cacheable` 但参数包含 `Pageable` 或大对象，导致 cache key 几乎不命中；或缓存了租户敏感数据但 key 没带 tenantId

### 错误示例

```java
// ❌ key 包含 Pageable，每次翻页都是新 key
@Cacheable("products")
public Page<Product> list(Pageable pageable, String keyword) { ... }

// ❌ 跨租户缓存污染
@Cacheable("user")
public User findById(Long id) { ... }
```

### 正确做法

```java
// ✅ key 显式列出稳定字段 + 缓存粒度匹配业务
@Cacheable(value = "products", key = "#tenantId + ':' + #keyword + ':' + #page")
public List<Product> list(Long tenantId, String keyword, int page) { ... }

// ✅ 租户隔离的缓存 key
@Cacheable(value = "user", key = "#tenantId + ':' + #id")
public User findById(Long tenantId, Long id) { ... }
```

### 检查清单

- [ ] `@Cacheable` 的 key 是否稳定（不含 Pageable、Date.now 等不稳定参数）
- [ ] 多租户场景 key 是否包含 tenantId
- [ ] 写操作是否配套 `@CacheEvict`
- [ ] 缓存 TTL 是否与业务一致性要求匹配（强一致就别上缓存）

---

## 性能预算速查表

| 查询模式 | 可接受 SQL 数 | 警戒线 |
|---------|--------------|--------|
| 单实体查询接口 | 1–3 | > 5 |
| 列表查询（N 个外键 join） | 1 + 外键种类数 | 与 N 相关即不可接受 |
| BFS/递归（≤ MAX_TOTAL_NODES） | depth × 1 + IN 批次数 | 与节点数线性相关 |
| 聚合统计 | 1（SUM）/ 分批数 | 全量加载到内存计算 |

---

## 多语言示例

完整的 Java / Go / Python / Node.js 实现见 `references/multi-lang-examples.md`。

---

## 规则溯源

```
> 📋 本回复遵循：`query-performance-safety` - [章节名]
```

</instructions>