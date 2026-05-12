---
name: multi-tenant-safety
description: >-
  当代码涉及多租户隔离（TenantContext、tenantId、租户拦截器/过滤器、X-Tenant-Code）时触发。
  防止租户越权访问、数据串租户等安全问题。
---

# 多租户隔离安全规范

当系统涉及多租户架构时，防止租户间数据越权访问。

---

## 陷阱 #1: 租户上下文来源信任错误

**场景**: 拦截器/过滤器从请求头（如 `X-Tenant-Code`）设置租户上下文，但未与认证 token 中的 tenantId 做一致性校验

### 问题根因

请求头可以被客户端任意伪造。如果后端只信任请求头中的租户标识，攻击者只需修改 header 就能访问其他租户的数据。

### 错误示例

```java
// ❌ 错误: 只信任请求头，未校验 token
@Override
public boolean preHandle(HttpServletRequest request, ...) {
    String tenantCode = request.getHeader("X-Tenant-Code");
    TenantMiniAppConfig config = configRepository.findByTenantCode(tenantCode);
    TenantContext.setTenantId(config.getTenantId());  // 直接信任 header
    return true;
}
// 攻击者拿着 tenantId=1 的 token，配上 X-Tenant-Code: OTHER_TENANT
// 就能读到其他租户的数据
```

### 正确做法

```java
// ✅ 正确: header 只做路由定位，必须与 token tenantId 校验一致
@Override
public boolean preHandle(HttpServletRequest request, ...) {
    String tenantCode = request.getHeader("X-Tenant-Code");
    TenantMiniAppConfig config = configRepository.findByTenantCode(tenantCode);

    // 从认证 token 中取出 tenantId（真相源）
    Long tokenTenantId = (Long) request.getAttribute("tokenTenantId");
    if (tokenTenantId != null && !tokenTenantId.equals(config.getTenantId())) {
        response.setStatus(403);
        response.getWriter().write("{\"code\":403,\"message\":\"租户信息不匹配\"}");
        return false;
    }

    TenantContext.setTenantId(config.getTenantId());
    return true;
}
```

### 检查清单

- [ ] 租户上下文的最终来源是否以认证 token 为准
- [ ] 请求头中的租户标识是否只用于路由定位，而非直接信任
- [ ] token 中的 tenantId 与请求头租户是否做了一致性校验
- [ ] 校验不通过时是否返回 403 而非静默放行

---

## 陷阱 #2: 数据查询层缺少全局租户过滤

**场景**: 部分查询绕过了租户过滤，导致跨租户数据泄露

### 问题根因

依赖开发者在每个查询中手动加 `WHERE tenant_id = ?`，容易遗漏。

### 错误示例

```java
// ❌ 错误: 忘记加租户过滤
@Query("SELECT p FROM Product p WHERE p.categoryId = :categoryId")
List<Product> findByCategoryId(@Param("categoryId") Long categoryId);
// 返回所有租户的商品
```

### 正确做法

```java
// ✅ 方案1: JPA/Hibernate 全局过滤器（推荐）
@Entity
@FilterDef(name = "tenantFilter", parameters = @ParamDef(name = "tenantId", type = Long.class))
@Filter(name = "tenantFilter", condition = "tenant_id = :tenantId")
public class Product {
    private Long tenantId;
}

// ✅ 方案2: 基类强制携带 tenantId
public abstract class TenantAwareEntity {
    @Column(name = "tenant_id", nullable = false)
    private Long tenantId;
}

// ✅ 方案3: MyBatis 拦截器自动追加 tenant_id 条件
@Intercepts(@Signature(type = Executor.class, method = "query", ...))
public class TenantInterceptor implements Interceptor {
    // 自动在 SQL 中追加 AND tenant_id = ?
}
```

### 检查清单

- [ ] 是否有全局租户过滤机制（Hibernate Filter / MyBatis 拦截器 / 基类）
- [ ] 新增查询方法时是否自动受租户过滤保护
- [ ] 原生 SQL / @Query 是否手动加了 tenant_id 条件
- [ ] 跨租户管理接口（超级管理员）是否有独立的绕过机制

---

## 陷阱 #3: 前端未处理租户不匹配的 403

**场景**: 后端返回 403（租户不匹配），但前端没有正确处理，用户看到空白页或无提示

### 错误示例

```typescript
// ❌ 错误: 只处理 401，忽略 403
request.interceptors.response.use(
  response => response,
  error => {
    if (error.response?.status === 401) {
      clearAuth();
      redirectToLogin();
    }
    return Promise.reject(error);  // 403 被静默吞掉
  }
);
```

### 正确做法

```typescript
// ✅ 正确: 403 租户不匹配时清理登录态并跳转
request.interceptors.response.use(
  response => response,
  error => {
    const status = error.response?.status;
    const message = error.response?.data?.message || '';

    if (status === 401) {
      clearAuth();
      redirectToLogin();
    } else if (status === 403 && message.includes('租户')) {
      clearAuth();
      redirectToLogin();
      showToast('登录状态异常，请重新登录');
    }
    return Promise.reject(error);
  }
);
```

### 检查清单

- [ ] 前端是否统一处理了 403 状态码
- [ ] 租户不匹配的 403 是否清理登录态并跳转登录页
- [ ] 是否给用户明确的错误提示（而非空白页）

---

## 陷阱 #4: 租户 ID 输入框允许手动输入

**场景**: 管理后台的配置表单中，租户 ID 使用手动输入框，容易输错

### 错误示例

```tsx
// ❌ 错误: 手动输入租户 ID，容易输错
<InputNumber placeholder="请输入租户ID" />
```

### 正确做法

```tsx
// ✅ 正确: 下拉选择租户名称，提交时自动转为 tenantId
<Select
  placeholder="请选择租户"
  onChange={(value) => {
    form.setFieldsValue({ tenantId: value });
    const tenant = tenants.find(t => t.id === value);
    form.setFieldsValue({ tenantCode: tenant?.tenantCode });
  }}
>
  {tenants.map(t => (
    <Option key={t.id} value={t.id}>
      {t.tenantName} / {t.tenantCode}
    </Option>
  ))}
</Select>
```

### 检查清单

- [ ] 管理后台中租户相关字段是否使用下拉选择而非手动输入
- [ ] 下拉选项是否展示租户名称（而非只展示 ID）
- [ ] 选择租户后是否自动带出关联字段（如 tenantCode）

---

## 陷阱 #5: 功能级授权 ≠ 数据级隔离

**场景**: 仅对特定租户/角色/订阅级开放的功能，只在前端用 `isYmhwTenant` / `hasPermission` / `isPaid` 隐藏入口，后端 endpoint 没有独立的功能授权校验

### 问题根因

前端 UI 控制（按钮隐藏、菜单过滤）只是**用户体验优化**，不是安全边界。任意已登录用户只要知道 endpoint 路径，绕过 UI 直接调用接口，就能使用本不该有的能力。这与"数据层租户隔离"是两个不同维度：

- **数据层（陷阱 #1/#2）**：访问的数据范围（你的数据 vs 他人的数据）
- **业务层（本陷阱）**：可以使用的功能（你能用什么功能 vs 别人能用什么功能）

典型场景：
- 租户专属功能（如 YMHW 小程序发货模板导出，仅鱼米好物租户可用）
- 角色专属功能（仅管理员可批量删除/批量导出）
- 订阅/版本专属功能（付费版 AI 分析、企业版高级报表）
- 功能开关（feature flag 灰度发布）

### 错误示例

```java
// ❌ 错误: 后端只过滤当前租户数据，没校验"该租户是否启用该功能"
@PostMapping("/orders/miniapp-shipping-template/export")
public ResponseEntity<byte[]> export(@RequestBody ExportRequest req) {
    Long tenantId = TenantContext.getTenantId();
    // 只查当前租户的订单（数据隔离 OK），但任何已登录租户都能调用这个接口
    return service.export(tenantId, req.getOrderIds());
}
```

```tsx
// 前端通过 isYmhwTenant 隐藏入口（只是体验优化，不是安全边界）
{isYmhwTenant && <Button onClick={handleExport}>导出小程序发货模板</Button>}
```

### 正确做法

```java
// ✅ 正确: endpoint 入口处独立校验"该租户是否启用该功能"
@PostMapping("/orders/miniapp-shipping-template/export")
public ResponseEntity<byte[]> export(@RequestBody ExportRequest req) {
    Long tenantId = TenantContext.getTenantId();

    // 关键: 后端独立校验租户编码/功能开关，不依赖前端
    TenantMiniAppConfig config = configRepository.findByTenantId(tenantId)
        .orElseThrow(() -> new BusinessException(403, "未启用小程序发货模板导出"));
    if (!"YMHW".equalsIgnoreCase(config.getTenantCode())) {
        throw new BusinessException(403, "仅鱼米好物租户支持导出小程序发货模板");
    }

    return service.export(tenantId, req.getOrderIds());
}
```

### 实现策略

| 授权依据 | 实现方式 | 适用场景 |
|---------|---------|---------|
| 租户编码白名单 | endpoint 入口 if 校验 / `@RequireTenantCode` 注解 + AOP | 单个/少量租户专属 |
| 角色权限 | `@PreAuthorize("hasRole('ADMIN')")` / Spring Security / Casbin | RBAC 体系内 |
| 订阅状态 | endpoint 入口校验当前订阅是否覆盖该功能 | SaaS 分版本 |

> **优先级**：1-2 个 endpoint 用直接 if 校验（最简、可读性高）；3 个以上同样限制再考虑 AOP/middleware 抽象，避免过度工程化。

### 检查清单

- [ ] endpoint 入口是否有"该用户/租户是否启用该功能"的独立校验（不依赖前端隐藏）
- [ ] 授权依据是否明确（租户编码 / 角色 / 功能开关 / 订阅状态）
- [ ] 校验失败时是否返回 403 + 业务可读的原因（不是 500 或空白响应）
- [ ] 是否做过"绕过 UI 直接调用 API"的渗透测试（用 curl/Postman 模拟非授权租户）

### 多语言示例

完整的 Java（Spring Boot 注解 AOP）/ Go（Gin middleware）/ TypeScript（Express middleware + NestJS Guard）实现示例见 `references/multi-lang-examples.md`。

---

## 检查清单（多租户隔离）

**认证与授权**:
- [ ] 租户上下文最终来源是否以认证 token 为准
- [ ] 请求头/参数中的租户标识是否只做路由，不做信任
- [ ] token tenantId 与路由租户是否做了一致性校验
- [ ] 校验失败是否返回 403

**功能授权**（业务层，参见陷阱 #5）:
- [ ] 仅特定租户/角色/订阅级开放的功能，endpoint 入口是否有独立校验
- [ ] 是否避免了"只在前端隐藏按钮，后端无校验"的反模式
- [ ] 授权失败返回 403 + 业务可读原因
- [ ] 是否做过"绕过 UI 直接调用 API"的渗透测试

**数据隔离**:
- [ ] 是否有全局租户过滤机制
- [ ] 新增查询是否自动受租户过滤保护
- [ ] 原生 SQL 是否手动加了 tenant_id 条件
- [ ] 是否有跨租户数据泄露的测试用例

**前端处理**:
- [ ] 403 租户不匹配是否正确处理
- [ ] 租户相关配置是否使用下拉选择
- [ ] 列表页是否展示租户名称而非 ID

---

## 适用范围

- Java: Spring Boot + JPA/Hibernate / MyBatis
- Go: Gin + GORM / sqlx
- Node.js: Express + Prisma / TypeORM
- Python: FastAPI + SQLAlchemy

---

## 规则溯源

```
> 📋 本回复遵循：`multi-tenant-safety` - [章节名]
```
