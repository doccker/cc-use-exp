---
name: api-design-safety
description: 当设计或修改 REST API 响应结构、处理 API 返回值时触发。防止 API 设计缺陷导致的字段错位、类型歧义等问题。
---

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
