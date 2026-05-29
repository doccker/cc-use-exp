---
name: api-design-safety
description: 当设计或修改 REST API 响应结构、处理 API 返回值，或生成 Excel/CSV/PDF/对账文件等下游产物时触发。防止 API 设计缺陷导致的字段错位、类型歧义，以及生成产物时关键字段缺失但静默成功的问题。
---
<instructions>

# API 设计安全规范

当设计或修改 REST API 响应结构时，防止常见的设计缺陷。

---

## 陷阱 #1: 泛型方法重载歧义

**场景**: 返回类型为 String 时，Java 重载解析可能匹配错误的方法

### 问题根因

Java 方法重载解析时，`String` 类型参数会优先匹配 `success(String message)` 而非 `success(T data)`，导致数据进入错误的字段。

### 错误示例

```java
// ApiResponse 有两个重载:
public static <T> ApiResponse<T> success(T data)
public static <T> ApiResponse<T> success(String message, T data)

// ❌ 错误: String 类型匹配到 success(String message)
String avatarUrl = "http://example.com/avatar.jpg";
return ApiResponse.success(avatarUrl);
// 结果: {"code":200, "message":"http://...", "data":null}
// 前端 data.data 拿到 null，导致功能异常
```

### 正确做法

```java
// ✅ 方案1: 明确指定 message 参数（推荐）
return ApiResponse.success("上传成功", avatarUrl);
// 结果: {"code":200, "message":"上传成功", "data":"http://..."}

// ✅ 方案2: 使用泛型明确类型
return ApiResponse.<String>success(avatarUrl);

// ✅ 方案3: 包装为 DTO（复杂场景推荐）
return ApiResponse.success(new UploadResult(avatarUrl));
```

### 检查清单

- [ ] 返回 String 类型时，是否明确指定 message 参数
- [ ] 是否有单参数和双参数的重载方法
- [ ] 前端是否正确解析 `data` 字段（而非 `message`）
- [ ] 是否有单元测试验证响应结构

---

## 陷阱 #2: 响应字段语义不清

**场景**: `message` 和 `data` 字段职责混淆

### 规范

| 字段 | 用途 | 类型 | 示例 |
|------|------|------|------|
| `code` | 业务状态码 | int | 200, 400, 500 |
| `message` | 用户可读的提示信息 | String | "上传成功", "参数错误" |
| `data` | 业务数据 | T | `{"url": "..."}`, `[...]` |
| `timestamp` | 响应时间戳 | String | ISO 8601 格式 |

### 错误示例

```java
// ❌ 错误: 把业务数据放在 message
return ApiResponse.success("avatars/2026-04/xxx.jpeg");

// ❌ 错误: message 包含技术细节
return ApiResponse.error("NullPointerException at line 42");
```

### 正确做法

```java
// ✅ message 是用户提示，data 是业务数据
return ApiResponse.success("上传成功", avatarUrl);

// ✅ 错误信息对用户友好
return ApiResponse.error("文件格式不支持，请上传 JPG/PNG 格式");
```

---

## 陷阱 #3: 空值处理不一致

**场景**: 无数据时返回 `null`、`{}`、`[]` 不统一

### 规范

| 场景 | 推荐返回 | 说明 |
|------|---------|------|
| 单个对象不存在 | `data: null` | 前端判断 `if (!data)` |
| 列表为空 | `data: []` | 前端可直接遍历 |
| 分页数据为空 | `data: {list: [], total: 0}` | 保持结构一致 |

### 错误示例

```java
// ❌ 错误: 有时返回 null，有时返回空对象
if (user == null) {
    return ApiResponse.success(null);  // 不一致
}
return ApiResponse.success(new UserVO());
```

### 正确做法

```java
// ✅ 统一返回 null 表示不存在
if (user == null) {
    return ApiResponse.success(null);
}
return ApiResponse.success(userVO);

// ✅ 列表统一返回空数组
List<UserVO> users = userService.list();
return ApiResponse.success(users);  // 永远不返回 null
```

---

## 陷阱 #4: HTTP 状态码与业务状态码混淆

**场景**: 业务失败时返回 HTTP 500

### 规范

| 场景 | HTTP 状态码 | 业务 code | 说明 |
|------|------------|----------|------|
| 成功 | 200 | 200 | 正常响应 |
| 参数错误 | 200 | 400 | 业务层校验失败 |
| 未授权 | 401 | - | 认证失败 |
| 无权限 | 403 | - | 授权失败 |
| 资源不存在 | 200 | 404 | 业务资源不存在 |
| 服务器错误 | 500 | - | 代码异常 |

### 错误示例

```java
// ❌ 错误: 业务失败返回 HTTP 500
if (user == null) {
    throw new RuntimeException("用户不存在");  // HTTP 500
}
```

### 正确做法

```java
// ✅ 业务失败返回 HTTP 200 + 业务 code
if (user == null) {
    return ApiResponse.error(404, "用户不存在");  // HTTP 200
}

// ✅ 只有代码异常才返回 HTTP 500
@ExceptionHandler(Exception.class)
public ResponseEntity<ApiResponse<?>> handleException(Exception e) {
    log.error("服务器错误", e);
    return ResponseEntity.status(500)
        .body(ApiResponse.error("服务器错误，请稍后重试"));
}
```

---

## 陷阱 #5: 生成下游产物前缺乏完整性校验（看似成功，下游静默失败）

**场景**: 导出 Excel/CSV/PDF、生成对账文件、推送第三方接口、批量通知等"产生下游消费产物"的功能，关键字段缺失时用空字符串/null/默认值兜底，文件能生成、接口能返回 200，但下游消费方（微信导入、对账系统、第三方平台）会静默失败或拒收。

### 问题根因

业务方关注"接口返回 200"和"文件生成成功"，但真实成功的判断标准在**下游消费方**：

- 微信发货模板要求 `mchId` 和 `transactionId` 必须存在，缺失会拒收
- 对账文件要求每行有完整的 `订单号 / 金额 / 时间`，缺一项整批驳回
- 物流推送要求 `快递公司` 和 `快递单号` 都存在，否则物流端报错

如果生成时缺值用 `""` / `null` / `0` 兜底，调用方会以为成功，等下游消费失败时才回头排查，浪费时间且影响业务。

### 错误示例

```java
// ❌ 错误: 关键字段缺失时静默用空值兜底，Excel 能生成但微信导入失败
public byte[] export(Long tenantId, List<Long> orderIds) {
    String mchId = miniAppConfigRepository.findByTenantId(tenantId)
        .map(TenantMiniAppConfig::getMchId)
        .orElse("");
    Map<Long, PaymentRecord> paymentMap = loadPaymentMap(tenantId, orders);

    for (TradeOrder order : orders) {
        PaymentRecord payment = paymentMap.get(order.getId());
        String transactionId = payment != null ? payment.getTransactionId() : "";
        String company = packages.stream().map(ShippingPackage::getCompany)
            .filter(StringUtils::hasText).distinct().collect(joining(";"));
        // transactionId 为空仍会写入 Excel，微信发货模板按位置导入时会拒收
        writeRow(sheet, order, mchId, transactionId, company, ...);
    }
    return workbook.toByteArray();
}
```

### 正确做法

**「必填字段一次画全 + 生成前预校验 + 缺失列出业务 ID + 整体失败」**

```java
public byte[] export(Long tenantId, List<Long> orderIds) {
    TenantMiniAppConfig config = miniAppConfigRepository.findByTenantId(tenantId)
        .orElseThrow(() -> new BusinessException("未配置小程序"));

    if (!StringUtils.hasText(config.getMchId())) {
        throw new BusinessException("小程序未配置微信支付商户号，无法导出");
    }

    Map<Long, PaymentRecord> paymentMap = loadPaymentMap(tenantId, orders);
    validateRequiredFields(orders, paymentMap);

    return buildWorkbook(orders, paymentMap, config.getMchId());
}

private void validateRequiredFields(List<TradeOrder> orders, Map<Long, PaymentRecord> paymentMap) {
    List<String> missingTxn = new ArrayList<>();
    List<String> missingPackage = new ArrayList<>();
    List<String> missingCompany = new ArrayList<>();

    for (TradeOrder order : orders) {
        PaymentRecord payment = paymentMap.get(order.getId());
        if (payment == null || !StringUtils.hasText(payment.getTransactionId())) {
            missingTxn.add(order.getOrderNumber());
        }
        List<ShippingPackage> packages = resolvePackages(order);
        if (packages.isEmpty()) {
            missingPackage.add(order.getOrderNumber());
        } else if (packages.stream().anyMatch(p -> !StringUtils.hasText(p.getCompany()))) {
            missingCompany.add(order.getOrderNumber());
        }
    }

    if (!missingTxn.isEmpty()) {
        throw new BusinessException("以下订单缺少微信支付交易单号，无法导出: " + String.join("、", missingTxn));
    }
    if (!missingPackage.isEmpty()) {
        throw new BusinessException("以下订单缺少快递单号，无法导出: " + String.join("、", missingPackage));
    }
    if (!missingCompany.isEmpty()) {
        throw new BusinessException("以下订单缺少快递公司，无法导出: " + String.join("、", missingCompany));
    }
}
```

### 必填字段三个层次（一次画全，避免 review 多轮才补全）

下手前**先列完整清单**，否则 review 一轮发现一个，会出现"修了 mchId/transactionId，下轮才发现快递公司/单号"的反复返工：

| 层次 | 含义 | 例子 |
|------|------|------|
| **业务字段** | 每条业务记录自身必填 | 订单号、金额、数量、订单状态 |
| **依赖配置** | 整个产物生成所需的全局配置 | `mchId`、API 凭证、模板 ID、签名密钥 |
| **外键关联** | 业务记录必须关联到的其他实体 | 关联的支付记录（且交易号非空）、物流单（且公司+单号都在）、收件地址 |

**判断"必填"的依据来自下游消费方文档**（微信开放平台导入文档、对账规范、第三方推送 API spec），不是来自源数据是否方便填。

### 检查清单

- [ ] 下游消费方（微信、对账、第三方 API）对哪些字段是必填的，是否查阅过其文档/规范
- [ ] 源数据中这些字段可能为空的所有路径是否都梳理清楚（积分支付、mock 数据、未配置、外键缺失）
- [ ] 缺失时是否返回明确业务错误（含具体业务 ID）而非用空字符串/null/0 兜底
- [ ] 错误信息是否包含可定位的业务标识（订单号/批次号/外部单号）
- [ ] 必填字段三层次（业务字段 + 依赖配置 + 外键关联）是否都覆盖了

### 多语言示例

完整的 Java（POI）/ Go（excelize）/ TypeScript（exceljs）实现示例见 `references/multi-lang-examples.md`。

---

## 检查清单（API 设计）

**返回值设计**:
- [ ] String 类型返回时，是否明确指定 message 参数
- [ ] `message` 字段是否只包含用户可读的提示信息
- [ ] `data` 字段是否只包含业务数据
- [ ] 空值处理是否统一（null / [] / {}）

**状态码设计**:
- [ ] HTTP 状态码是否只用于传输层（200/401/403/500）
- [ ] 业务状态码是否在响应体的 `code` 字段
- [ ] 业务失败是否返回 HTTP 200 + 业务 code

**前后端协议**:
- [ ] 前端是否正确解析 `data` 字段
- [ ] 前端是否处理了 `data: null` 的情况
- [ ] 是否有 API 文档或接口测试

**产物完整性**（生成 Excel/CSV/PDF/对账文件/批量推送时，参见陷阱 #5）:
- [ ] 必填字段三层次（业务字段 + 依赖配置 + 外键关联）是否一次画全
- [ ] 必填判断依据是否来自下游消费方文档
- [ ] 缺失时是否抛业务错误（含具体业务 ID）而非空值兜底
- [ ] 错误信息是否包含可定位的业务标识

---

## 陷阱 #6: 业务错用框架异常 → 全部变成 500

**场景**：在 Service 里用 `throw new IllegalArgumentException("系统分类不可用")` 表达业务错误，前端拿到 500 + 一坨堆栈。

### 问题根因

Spring 默认全局异常处理把 `IllegalArgumentException` / `IllegalStateException` / `RuntimeException` 等**框架/JDK 异常**都归类为"代码 bug"，返回 HTTP 500 + 通用错误。
项目通常有自定义的 `BusinessException`（或 `BizException`），全局 handler 把它处理成 HTTP 200 + 业务 code 4xx + 用户友好的 message。
**用错异常类型 → 前端拿不到正确的 message、用户看不到原因、监控告警被业务错刷屏。**

### 错误示例

```java
// ❌ 框架异常被全局 handler 处理成 500
public void updateMapping(Long id, Long categoryId) {
    ProductCategory category = repository.findById(categoryId)
        .orElseThrow(() -> new IllegalArgumentException("系统分类不存在"));
    if (category.getStatus() != ACTIVE) {
        throw new IllegalArgumentException("系统分类不可用");  // 500 + 堆栈
    }
}
```

### 正确做法

```java
// ✅ 用项目自定义业务异常
public void updateMapping(Long id, Long categoryId) {
    ProductCategory category = repository.findById(categoryId)
        .orElseThrow(() -> new BusinessException("系统分类不存在"));
    if (category.getStatus() != ACTIVE) {
        throw new BusinessException("系统分类不可用");  // 200 + code 4xx + 友好 message
    }
}
```

### 异常类型对照表

| 场景 | 抛什么异常 | 全局 handler 处理 | HTTP 状态 |
|------|----------|------------------|----------|
| 业务规则不满足（金额超额、状态不允许） | `BusinessException` | 200 + code 4xx + 业务 message | 200 |
| 参数格式错误（手动校验） | `BusinessException` 或 `@Valid` 触发的 `MethodArgumentNotValidException` | 200 + code 400 + 字段提示 | 200 |
| 资源不存在 | `BusinessException` 或自定义 `NotFoundException` | 200 + code 404 + 业务 message | 200 |
| 无权限 | `AccessDeniedException`（Spring Security 处理） | 403 | 403 |
| 未认证 | `AuthenticationException`（Spring Security 处理） | 401 | 401 |
| 代码 bug（不可能 null、断言失败） | `IllegalStateException` / `AssertionError` | 500 + 通用错误 + 告警 | 500 |
| 外部依赖故障（远程 API 5xx、DB 断连） | 让框架异常冒泡，全局 handler 转 500 | 500 + 通用错误 + 告警 | 500 |

**核心原则**：

- **业务可预期的错** → `BusinessException`（用户可理解、不该告警）
- **代码 bug / 系统故障** → 让框架异常冒泡（应该告警、应该排查）
- **不要为了"统一抛 BusinessException"就把 NPE / 状态机违反包装成业务错** —— 那会让告警漏掉真正的 bug

### 嗅探信号

代码评审看到以下任一立即怀疑：

- Service 里 `throw new IllegalArgumentException(...)` 或 `throw new RuntimeException(...)` 包业务错
- `orElseThrow(() -> new IllegalArgumentException(...))` 表达"找不到资源"
- 前端报 500 但业务接口逻辑明显是用户输入错（应该 4xx）
- 全局异常 handler 里没有 `BusinessException` 的分支

### 检查清单

- [ ] Service 抛业务错是否用 `BusinessException`（不是 `IllegalArgumentException`）
- [ ] `orElseThrow` 是否用业务异常
- [ ] 全局异常 handler 是否区分了 `BusinessException`（200 + code 4xx） vs 其他异常（500）
- [ ] 报 500 的接口是否真的是代码 bug（而非业务错误被错误归类）

---

## 适用范围

- Java: Spring Boot REST API
- Go: Gin/Echo REST API
- Node.js: Express/Koa REST API
- Python: FastAPI/Flask REST API

---

## 规则溯源

```
> 📋 本回复遵循：`api-design-safety` - API 设计安全规范
```

</instructions>