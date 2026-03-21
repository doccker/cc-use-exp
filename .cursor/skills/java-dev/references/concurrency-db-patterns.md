# 并发与数据库模式

> 解决 Race Condition、N+1 查询、原子更新等常见问题的标准模式。

---

## 1. 解决 Get-Or-Create 并发竞争

**场景**：高并发下检查记录是否存在，不存在则创建。
**反模式**：`check-then-act`（先 `findBy` 后 `save`），并发时会产生重复数据或异常。

### ✅ 推荐方案：唯一索引兜底 + 异常捕获

利用数据库唯一索引作为最后防线，代码层面捕获冲突异常。

```java
public Account getOrCreateAccount(Long userId) {
    // 1. 尝试直接查询
    return accountRepo.findByUserId(userId)
        .orElseGet(() -> {
            try {
                // 2. 并发关键点：可能多个线程同时进入此处
                Account newAccount = new Account(userId);
                return accountRepo.save(newAccount);
            } catch (DataIntegrityViolationException e) {
                // 3. 捕获唯一索引冲突，说明已被其他线程创建
                // 4. 重新查询（此时一定存在）
                return accountRepo.findByUserId(userId)
                    .orElseThrow(() -> new IllegalStateException("Account creation conflict handling failed", e));
            }
        });
}
```

---

## 2. N+1 查询防范

**场景**：在循环中调用 Repository 查询方法（如 `findById`, `countBy`）。
**反模式**：`items.forEach(item -> repo.findById(item.getId()))`。

### ✅ 推荐方案：循环外批量查询 + 内存匹配

将 N 次数据库交互合并为 1 次。

```java
public List<OrderDTO> calculatePoints(List<Order> orders) {
    // 1. 提取所有需要的 ID
    List<Long> userIds = orders.stream().map(Order::getUserId).distinct().collect(Collectors.toList());

    // 2. 批量查询（一次 DB 交互）
    Map<Long, Integer> userLevels = userRepo.findAllById(userIds).stream()
        .collect(Collectors.toMap(User::getId, User::getLevel));

    // 3. 内存匹配计算
    return orders.stream().map(order -> {
        Integer level = userLevels.getOrDefault(order.getUserId(), 1);
        return new OrderDTO(order, calculate(order, level));
    }).collect(Collectors.toList());
}
```

---

## 3. 原子更新（余额/库存扣减）

**场景**：扣减余额、库存等数值。
**反模式**：`read-modify-write`（先 `get`，内存计算，再 `set`），并发会导致丢失更新。

### ✅ 推荐方案：CAS 思想 SQL 更新

让数据库保证原子性，通过影响行数判断成功。

**Repository:**

```java
@Modifying
@Query("UPDATE Account a SET a.balance = a.balance - :amount WHERE a.id = :id AND a.balance >= :amount")
int deductBalance(@Param("id") Long id, @Param("amount") BigDecimal amount);
```

**Service:**

```java
@Transactional
public void pay(Long accountId, BigDecimal amount) {
    int updatedRows = accountRepo.deductBalance(accountId, amount);
    if (updatedRows == 0) {
        throw new BusinessException("余额不足或账户不存在");
    }
}
```

---

## 4. SQL 聚合优化（多重 Count）

**场景**：需要统计多个不同条件的总数（如：总订单数、逾期订单数）。
**反模式**：执行多条 SQL (`countByStatus`, `countByOverdue`)。

### ✅ 推荐方案：CASE WHEN 聚合

一条 SQL 计算所有指标。

**Repository:**

```java
@Query("SELECT new com.example.dto.StatsDTO(" +
       "  COUNT(o), " +
       "  SUM(CASE WHEN o.status = 'PAID' THEN 1 ELSE 0 END), " +
       "  SUM(CASE WHEN o.dueDate < CURRENT_DATE AND o.status != 'PAID' THEN 1 ELSE 0 END) " +
       ") FROM Order o WHERE o.tenantId = :tenantId")
StatsDTO getStats(@Param("tenantId") Long tenantId);
```

---

## 5. Redis + DB 多数据源一致性

**场景**：库存、余额等热数据用 Redis 做原子扣减，DB 做持久化记录。
**核心问题**：Redis 操作不参与 `@Transactional` 回滚，两者之间存在一致性风险。

### 5.1 单一数据源原则（禁止 TOCTOU 跨数据源）

校验和扣减必须在同一数据源完成，禁止用 DB 校验 + Redis 扣减。

```java
// ❌ TOCTOU 竞态：DB 校验与 Redis 扣减数据源不一致
@Transactional
public void createOrder(OrderRequest request) {
    Product product = productRepo.findById(request.getProductId());
    if (product.getStock() < request.getQuantity()) {  // DB 校验
        throw new BusinessException("库存不足");
    }
    // 高并发下 DB stock 可能大于 Redis stock，校验通过但扣减失败
    redisTemplate.opsForValue().decrement("stock:" + request.getProductId(), request.getQuantity());  // Redis 扣减
}

// ✅ 完全依赖 Redis 原子扣减结果，不做 DB 前置校验
@Transactional
public void createOrder(OrderRequest request) {
    Long remaining = redisTemplate.opsForValue()
        .decrement("stock:" + request.getProductId(), request.getQuantity());
    if (remaining == null || remaining < 0) {  // null: key 不存在; < 0: 库存不足
        // 扣减失败，回补 Redis
        redisTemplate.opsForValue()
            .increment("stock:" + request.getProductId(), request.getQuantity());
        throw new BusinessException("库存不足");
    }
    // Redis 扣减成功，继续 DB 操作...
    orderRepo.save(buildOrder(request));
}
```

### 5.2 操作顺序：先 DB 后 Redis，或 Redis 先扣 + 失败补偿

Redis 操作不受 `@Transactional` 管理，DB 回滚时 Redis 不会自动恢复。

| 方案 | 操作顺序 | 适用场景 |
|------|---------|---------|
| **A. 先 DB 后 Redis** | DB 写入 -> Redis 更新 | DB 为主、Redis 为缓存 |
| **B. Redis 先扣 + 补偿** | Redis 扣减 -> DB 写入 -> 失败时回补 Redis | Redis 为主、高并发扣减 |

```java
// ❌ Redis 先扣，DB 后写，无补偿 —— DB 回滚后 Redis 库存永久丢失
@Transactional
public void lockStock(Long productId, int quantity) {
    redisTemplate.opsForValue().decrement("stock:" + productId, quantity);  // Redis 先扣
    stockLockRepo.save(new StockLock(productId, quantity));  // DB 后写
    // 如果 save 抛异常，DB 回滚，但 Redis 已扣减，库存"漏"掉
}

// ✅ 方案 B：Redis 先扣 + try-catch 补偿
@Transactional
public void lockStock(Long productId, int quantity) {
    // 1. Redis 原子扣减
    Long remaining = redisTemplate.opsForValue()
        .decrement("stock:" + productId, quantity);
    if (remaining == null || remaining < 0) {
        redisTemplate.opsForValue().increment("stock:" + productId, quantity);
        throw new BusinessException("库存不足");
    }
    try {
        // 2. DB 持久化
        stockLockRepo.save(new StockLock(productId, quantity));
        orderRepo.save(buildOrder(productId, quantity));
    } catch (Exception e) {
        // 3. DB 失败，回补 Redis
        redisTemplate.opsForValue().increment("stock:" + productId, quantity);
        throw e;
    }
}
```

### 5.3 决策速查

```
Redis + DB 一起用？
├─ Redis 仅做缓存（读多写少）→ 方案 A：先写 DB，再更新 Redis
├─ Redis 做原子扣减（高并发）→ 方案 B：Redis 先扣，失败补偿
└─ 校验逻辑 → 只信任原子操作结果，不做跨数据源前置校验
```
