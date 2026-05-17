# 查询性能安全 - 多语言示例

## N+1 修复

### Java (Spring Data JPA)

```java
// ❌ N+1
for (Order o : orders) {
    User u = userRepository.findById(o.getUserId()).orElse(null);
}

// ✅ 批量 IN + Map
List<Long> userIds = orders.stream().map(Order::getUserId).distinct().toList();
Map<Long, User> userMap = userRepository.findAllById(userIds).stream()
        .collect(Collectors.toMap(User::getId, u -> u));
for (Order o : orders) {
    User u = userMap.get(o.getUserId());
}
```

### Go (GORM)

```go
// ❌ N+1
for _, o := range orders {
    var u User
    db.First(&u, o.UserID)
}

// ✅ Preload 或显式批量
var userIDs []uint64
for _, o := range orders {
    userIDs = append(userIDs, o.UserID)
}
var users []User
db.Where("tenant_id = ? AND id IN ?", tenantID, userIDs).Find(&users)
userMap := make(map[uint64]User, len(users))
for _, u := range users {
    userMap[u.ID] = u
}

// 或更地道：使用 Preload
db.Preload("User").Where("status = ?", "paid").Find(&orders)
```

### Python (SQLAlchemy)

```python
# ❌ N+1
for o in orders:
    user = session.query(User).get(o.user_id)

# ✅ 使用 joinedload 或显式 IN
from sqlalchemy.orm import joinedload
orders = session.query(Order).options(joinedload(Order.user)).all()

# 或显式
user_ids = {o.user_id for o in orders}
users = session.query(User).filter(User.id.in_(user_ids)).all()
user_map = {u.id: u for u in users}
```

### Node.js (Prisma)

```typescript
// ❌ N+1
for (const o of orders) {
  const user = await prisma.user.findUnique({ where: { id: o.userId } });
}

// ✅ include 或批量
const orders = await prisma.order.findMany({
  include: { user: true },
});

// 或显式批量
const userIds = [...new Set(orders.map(o => o.userId))];
const users = await prisma.user.findMany({ where: { id: { in: userIds } } });
const userMap = new Map(users.map(u => [u.id, u]));
```

---

## IN 子句分批

### Java

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

### Go (with lo)

```go
import "github.com/samber/lo"

const InBatchSize = 500

func findUsersByIDs(db *gorm.DB, tenantID uint64, ids []uint64) ([]User, error) {
    var all []User
    batches := lo.Chunk(ids, InBatchSize)
    for _, batch := range batches {
        var users []User
        if err := db.Where("tenant_id = ? AND id IN ?", tenantID, batch).Find(&users).Error; err != nil {
            return nil, err
        }
        all = append(all, users...)
    }
    return all, nil
}
```

### Python

```python
IN_BATCH_SIZE = 500

def find_users_by_ids(session, tenant_id: int, ids: list[int]) -> list[User]:
    result = []
    for i in range(0, len(ids), IN_BATCH_SIZE):
        batch = ids[i:i + IN_BATCH_SIZE]
        result.extend(
            session.query(User)
            .filter(User.tenant_id == tenant_id, User.id.in_(batch))
            .all()
        )
    return result
```

---

## BFS 带总节点上限

### Java

```java
private static final int MAX_DEPTH = 3;
private static final int MAX_TOTAL_NODES = 5000;

public List<User> collectDescendants(Long tenantId, Long rootId) {
    Map<Long, User> visited = new LinkedHashMap<>();
    List<Long> currentIds = List.of(rootId);
    for (int depth = 1; depth <= MAX_DEPTH && !currentIds.isEmpty(); depth++) {
        if (visited.size() >= MAX_TOTAL_NODES) {
            log.warn("BFS 截断 at depth={}, root={}", depth, rootId);
            break;
        }
        List<User> next = repo.findByInviterIdIn(tenantId, currentIds);
        List<Long> nextIds = new ArrayList<>();
        for (User u : next) {
            if (visited.size() >= MAX_TOTAL_NODES) break;
            if (visited.putIfAbsent(u.getId(), u) == null) {
                nextIds.add(u.getId());
            }
        }
        currentIds = nextIds;
    }
    return new ArrayList<>(visited.values());
}
```

### Go

```go
const (
    MaxDepth      = 3
    MaxTotalNodes = 5000
)

func collectDescendants(db *gorm.DB, tenantID, rootID uint64) []User {
    visited := map[uint64]User{}
    currentIDs := []uint64{rootID}
    for depth := 1; depth <= MaxDepth && len(currentIDs) > 0; depth++ {
        if len(visited) >= MaxTotalNodes {
            log.Warnf("BFS 截断 at depth=%d, root=%d", depth, rootID)
            break
        }
        var next []User
        db.Where("tenant_id = ? AND inviter_id IN ?", tenantID, currentIDs).Find(&next)
        var nextIDs []uint64
        for _, u := range next {
            if len(visited) >= MaxTotalNodes {
                break
            }
            if _, ok := visited[u.ID]; !ok {
                visited[u.ID] = u
                nextIDs = append(nextIDs, u.ID)
            }
        }
        currentIDs = nextIDs
    }
    result := make([]User, 0, len(visited))
    for _, u := range visited {
        result = append(result, u)
    }
    return result
}
```

---

## 聚合 SUM 分批

### Java

```java
private long sumPointsByBatches(Long tenantId, List<Long> ids, LocalDateTime since) {
    long total = 0L;
    for (int i = 0; i < ids.size(); i += IN_BATCH_SIZE) {
        List<Long> batch = ids.subList(i, Math.min(i + IN_BATCH_SIZE, ids.size()));
        Long val = since == null
                ? repo.sumByIds(tenantId, batch)
                : repo.sumByIdsAfter(tenantId, batch, since);
        if (val != null) total += val;
    }
    return total;
}
```

```java
@Query("SELECT COALESCE(SUM(p.points), 0) FROM PointsPending p"
     + " WHERE p.tenantId = :tenantId"
     + " AND p.sourceUserId IN :ids"
     + " AND p.status <> 2")
Long sumByIds(@Param("tenantId") Long tenantId, @Param("ids") List<Long> ids);
```
