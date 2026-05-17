---
name: time-zone-safety
description: 当代码出现 LocalDate.now() / LocalDateTime.now() / Instant.now() / new Date() / Date.now() / time.Now() 等"当前时间"调用，或涉及周/月/日起点、跨时区比较、数据库时间字段时触发。防止生产环境时区漂移导致的统计错乱。
---

# 时区安全规范

服务端代码里，"当前时间"几乎从不应该裸调。一个 docker 镜像默认 UTC、一个生产机配置 Asia/Shanghai，同一份代码跑出来的"本周起点"就差 8 小时。

> 配套：`query-performance-safety`（性能） / `multi-tenant-safety`（隔离）

---

## 陷阱 #1: 裸调 `.now()` 依赖 JVM 默认时区

**场景**: `LocalDate.now()` / `LocalDateTime.now()` / `Instant.now()` / `new Date()` 不传时区

### 问题根因

- `LocalDate.now()` 在 UTC 服务器上返回的"今天"比业务时区少 1 天（凌晨场景）
- `LocalDateTime.now()` 拿到的是 JVM 默认时区时间，docker base image 经常默认 UTC
- 同一段代码在开发机（Asia/Shanghai）和生产（UTC）跑出不同结果，无法本地复现
- 数据库时间通常按业务时区入库，比较时一边是业务时区一边是 UTC → 偏差 8h

### 错误示例

```java
// ❌ 错误：依赖 JVM 默认时区
LocalDateTime weekStart = LocalDate.now()
        .with(DayOfWeek.MONDAY)
        .atStartOfDay();

// ❌ 错误：跨日切换的统计依赖默认时区
LocalDate today = LocalDate.now();
List<Order> todayOrders = orderRepository.findByCreatedAtAfter(today.atStartOfDay());

// ❌ 错误：Date 用默认时区
Date now = new Date();
```

### 正确做法

**项目级业务时区常量** + 所有 `.now()` 显式传入：

```java
// ✅ 项目常量类（如 TimeConstants.java）
public final class TimeConstants {
    /** 系统业务时区（中国大陆） */
    public static final ZoneId BIZ_ZONE = ZoneId.of("Asia/Shanghai");
    private TimeConstants() {}
}

// ✅ 业务代码统一传入
LocalDateTime weekStart = LocalDate.now(BIZ_ZONE)
        .with(DayOfWeek.MONDAY)
        .atStartOfDay();

LocalDate today = LocalDate.now(BIZ_ZONE);
LocalDateTime nowBiz = LocalDateTime.now(BIZ_ZONE);
Instant instantNow = Instant.now();  // Instant 本身是 UTC 时间戳，无歧义
```

### 嗅探信号

```bash
# 任何裸 .now() 在业务代码中都该 review
grep -rnE "LocalDate\.now\(\)|LocalDateTime\.now\(\)|LocalTime\.now\(\)" src/main/java/ \
    | grep -v "TimeConstants\|@Configuration"

# Date 系列在新代码中应淘汰
grep -rnE "new Date\(\)|new GregorianCalendar\(\)" src/main/java/

# Go
grep -rnE "time\.Now\(\)" --include="*.go" .

# JS / TS
grep -rnE "new Date\(\)|Date\.now\(\)" --include="*.ts" --include="*.js" src/
```

### 检查清单

- [ ] 项目内是否有统一的 `BIZ_ZONE` 常量
- [ ] Service / Handler 层禁止裸 `.now()`，必须显式时区
- [ ] `Instant.now()` 可以裸用（UTC 时间戳无歧义）
- [ ] 测试用 `Clock.fixed(instant, zone)` 注入，不要硬编码 `now()`

---

## 陷阱 #2: 周/月/日起点计算缺失时区

**场景**: 计算"本周起点 / 本月初 / 今日 00:00"用于统计聚合

### 问题根因

跨日/跨周/跨月切换时间点最敏感。如果起点用 UTC 算，业务时区下"本周一 0 点"对应 UTC 周日 16:00，导致统计错位。

### 错误示例

```java
// ❌ 错误：周起点未指定时区
LocalDateTime weekStart = LocalDate.now()
        .with(DayOfWeek.MONDAY)
        .atStartOfDay();

// ❌ 错误：月起点未指定时区
LocalDateTime monthStart = LocalDate.now().withDayOfMonth(1).atStartOfDay();
```

### 正确做法

```java
// ✅ 周起点（业务周一 00:00）
LocalDateTime weekStart = LocalDate.now(BIZ_ZONE)
        .with(DayOfWeek.MONDAY)
        .atStartOfDay();

// ✅ 月起点
LocalDateTime monthStart = LocalDate.now(BIZ_ZONE).withDayOfMonth(1).atStartOfDay();

// ✅ 今日 00:00（业务时区）
LocalDateTime todayStart = LocalDate.now(BIZ_ZONE).atStartOfDay();

// ✅ 与数据库时间字段比较（假设 DB 存的也是业务时区 LocalDateTime）
List<Order> todayOrders = orderRepository.findByCreatedAtAfter(todayStart);
```

**如果 DB 存的是 UTC `TIMESTAMP` / `Instant`**，必须先把 BIZ 起点转 UTC：

```java
Instant todayStartUtc = LocalDate.now(BIZ_ZONE)
        .atStartOfDay(BIZ_ZONE)
        .toInstant();
```

### 检查清单

- [ ] 所有 `with(DayOfWeek.X).atStartOfDay()` 链路前是否带 `BIZ_ZONE`
- [ ] 周起点定义是否符合业务（周一 vs 周日 vs ISO 周）
- [ ] 数据库时间字段单位与查询参数单位一致（同为 LocalDateTime 或同为 Instant）

---

## 陷阱 #3: 数据库与应用层时区不一致

**场景**: JDBC 默认 `serverTimezone` 与 JVM 不一致；MySQL `TIMESTAMP` 自动转换与 `DATETIME` 不同步

### 问题根因

- MySQL `TIMESTAMP` 会按 session/server 时区做存读转换；`DATETIME` 是裸字符串
- JDBC URL `serverTimezone=UTC` 时，Java 写入 `2026-05-14 10:00 BIZ` 实际存为 UTC，读出来又转一次
- 若 JVM 用 `UTC` 但 DB session 用 `+08:00`，会出现"今天的数据"在 `WHERE created_at >= today` 查不到

### 正确做法

固定时区策略并文档化（团队内统一选一种）：

| 策略 | DB 列类型 | JDBC URL | Java 字段 | 适用场景 |
|------|----------|----------|----------|---------|
| **A. 业务时区全栈** | `DATETIME` | `serverTimezone=Asia/Shanghai` | `LocalDateTime` | 单一时区业务（推荐 90% 中国场景） |
| **B. UTC 存储 + 业务展示** | `TIMESTAMP` | `serverTimezone=UTC` | `Instant` / `OffsetDateTime` | 跨时区 SaaS、需要全球部署 |

**强烈禁止混用**：DB 列用 `DATETIME` 又把 `serverTimezone=UTC`，最难排查。

```yaml
# ✅ 策略 A 的连接串示例
spring:
  datasource:
    url: jdbc:mysql://host:3306/db?serverTimezone=Asia/Shanghai&useLegacyDatetimeCode=false
```

```dockerfile
# ✅ 部署层固定 JVM 时区，避免 base image 飘
ENV TZ=Asia/Shanghai
RUN ln -sf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
```

### 检查清单

- [ ] JDBC URL 是否显式设置 `serverTimezone`
- [ ] Dockerfile 是否固定 `TZ` 环境变量
- [ ] DB 字段类型选择（`DATETIME` vs `TIMESTAMP`）与策略一致
- [ ] 团队 wiki 是否文档化了时区策略

---

## 陷阱 #4: 跨时区比较的隐式陷阱

**场景**: 用户上传"2026-05-14 10:00"字符串，后端转换时丢失时区信息

### 错误示例

```java
// ❌ 错误：字符串直接 parse 成 LocalDateTime，时区信息丢失
LocalDateTime userTime = LocalDateTime.parse(request.getTimeStr());

// ❌ 错误：与 Instant 比较时隐式用 JVM 时区
Instant dbTime = order.getCreatedInstant();
LocalDateTime userTime = LocalDateTime.parse(request.getTimeStr());
if (userTime.isAfter(LocalDateTime.ofInstant(dbTime, ZoneId.systemDefault()))) { ... }
```

### 正确做法

```java
// ✅ 明确字符串是业务时区
LocalDateTime userLocal = LocalDateTime.parse(request.getTimeStr());
Instant userInstant = userLocal.atZone(BIZ_ZONE).toInstant();

// ✅ 比较时都转 Instant
if (userInstant.isAfter(order.getCreatedInstant())) { ... }
```

### 检查清单

- [ ] 用户输入的时间字符串是否定义了时区语义（HTTP API 文档应声明）
- [ ] 跨时区比较一律用 `Instant`，不用 `LocalDateTime` 直接比
- [ ] 日志输出时间是否带时区（`yyyy-MM-dd HH:mm:ss z`）

---

## 多语言示例

### Go

```go
// ❌ 依赖系统时区
now := time.Now()

// ✅ 业务时区
var bizZone = time.FixedZone("Asia/Shanghai", 8*3600)
// 或加载 IANA
bizZone, _ := time.LoadLocation("Asia/Shanghai")

now := time.Now().In(bizZone)
weekStart := now.AddDate(0, 0, -int(now.Weekday()-time.Monday)).
    Truncate(24 * time.Hour)
```

### Python

```python
# ❌ naive datetime
from datetime import datetime
now = datetime.now()

# ✅ aware datetime
from datetime import datetime
from zoneinfo import ZoneInfo
BIZ_ZONE = ZoneInfo("Asia/Shanghai")
now = datetime.now(tz=BIZ_ZONE)
week_start = (now - timedelta(days=now.weekday())).replace(hour=0, minute=0, second=0, microsecond=0)
```

### Node.js / TypeScript

```typescript
// ❌ Date 默认本地时区
const now = new Date();
const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());

// ✅ 用 luxon 或 date-fns-tz 显式时区
import { DateTime } from "luxon";
const BIZ_ZONE = "Asia/Shanghai";
const now = DateTime.now().setZone(BIZ_ZONE);
const weekStart = now.startOf("week");  // luxon 默认 Monday
const todayStart = now.startOf("day");

// 落库前转 UTC ISO
const utcIso = now.toUTC().toISO();
```

---

## 总检查清单

**应用层**:
- [ ] 项目内有统一 `BIZ_ZONE` / `BIZ_LOCATION` 常量
- [ ] 业务代码无裸 `LocalDate.now()` / `LocalDateTime.now()` / `new Date()` / `time.Now()`
- [ ] 周/月/日起点计算显式带时区
- [ ] 测试用 `Clock.fixed()` / Mock，不依赖真实时间

**数据层**:
- [ ] JDBC URL 显式设置 `serverTimezone`
- [ ] DB 字段类型与时区策略一致
- [ ] 跨时区比较一律用 `Instant` / UTC 时间戳

**部署层**:
- [ ] Docker / k8s 设置 `TZ` 环境变量
- [ ] CI 测试容器与生产时区一致

**接口层**:
- [ ] API 文档声明时间参数的时区语义（ISO 8601 + 时区偏移）
- [ ] 响应时间字段带时区（`2026-05-14T10:00:00+08:00`）

---

## 规则溯源

```
> 📋 本回复遵循：`time-zone-safety` - [章节名]
```
