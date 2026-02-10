---
paths: "**/*.{go,java,py,ts,js}"
---
# Redis 安全规范

> 防止 Redis 常见性能和稳定性问题，适用于所有语言。

---

## 禁止操作

| 禁止 | 替代 | 原因 |
|------|------|------|
| `KEYS *` / `KEYS pattern` | `SCAN` 游标迭代 | KEYS 是 O(N) 阻塞操作，生产环境会导致 Redis 卡死 |
| `FLUSHDB` / `FLUSHALL` | 按 key 前缀 SCAN + DEL | 全量删除风险极高 |
| 无 TTL 的 SET | 所有 key 必须设置 TTL | 避免内存泄漏 |

## 必须遵守

### 1. 用 SCAN 替代 KEYS

```go
// Go (go-redis) ❌
keys, _ := rdb.Keys(ctx, "user:*").Result()

// Go (go-redis) ✅
var cursor uint64
for {
    keys, cursor, _ = rdb.Scan(ctx, cursor, "user:*", 100).Result()
    // 处理 keys
    if cursor == 0 { break }
}
```

```java
// Java (Jedis) ❌
Set<String> keys = jedis.keys("user:*");

// Java (Jedis) ✅
ScanParams params = new ScanParams().match("user:*").count(100);
String cursor = "0";
do {
    ScanResult<String> result = jedis.scan(cursor, params);
    // 处理 result.getResult()
    cursor = result.getCursor();
} while (!cursor.equals("0"));
```

```python
# Python (redis-py) ❌
keys = r.keys("user:*")

# Python (redis-py) ✅
for key in r.scan_iter(match="user:*", count=100):
    # 处理 key
```

### 2. 大 key 控制

- 单个 key 的 value 不超过 **10KB**
- 集合类型（List/Set/Hash/ZSet）元素不超过 **5000** 个
- 超过时拆分为多个 key

### 3. Pipeline 批量操作

多次 Redis 调用应使用 Pipeline 减少网络往返：

```go
// ❌ 循环单次调用
for _, id := range ids {
    rdb.Get(ctx, "user:"+id)
}

// ✅ Pipeline 批量
pipe := rdb.Pipeline()
for _, id := range ids {
    pipe.Get(ctx, "user:"+id)
}
pipe.Exec(ctx)
```

### 4. 所有 key 设置 TTL

```go
// ❌
rdb.Set(ctx, "token:123", value, 0)

// ✅
rdb.Set(ctx, "token:123", value, 24*time.Hour)
```
