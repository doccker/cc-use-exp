# 功能级授权 — 多语言完整示例

> 配套 `SKILL.md` 陷阱 #5「功能级授权 ≠ 数据级隔离」。
> 演示 endpoint 入口处独立校验"该租户/角色/订阅是否启用该功能"的实现方式。
>
> **优先用方案 A（直接 if 校验）；3 个以上 endpoint 同样限制再考虑方案 B（AOP/middleware）。**

---

## 一、Java（Spring Boot）

### 方案 A：endpoint 入口直接校验（**优先**，1-2 个 endpoint 用）

```java
@RestController
@RequestMapping("/orders/miniapp-shipping-template")
public class MiniappShippingTemplateExportController {

    private final TenantMiniAppConfigRepository configRepository;
    private final MiniappShippingTemplateExportService service;

    @PostMapping("/export")
    public ResponseEntity<byte[]> export(@RequestBody @Valid ExportRequest req) {
        Long tenantId = TenantContext.getTenantId();

        TenantMiniAppConfig config = configRepository.findByTenantId(tenantId)
            .orElseThrow(() -> new BusinessException(403, "未启用小程序发货模板导出"));
        if (!"YMHW".equalsIgnoreCase(config.getTenantCode())) {
            throw new BusinessException(403, "仅鱼米好物租户支持导出小程序发货模板");
        }

        byte[] excel = service.export(tenantId, req.getOrderIds());
        return ResponseEntity.ok()
            .header("Content-Disposition", "attachment; filename=miniapp-shipping.xlsx")
            .body(excel);
    }
}
```

### 方案 B：自定义注解 + AOP（多个 endpoint 复用同一限制时用）

```java
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface RequireTenantCode {
    String[] value();
    String message() default "该功能未对当前租户开放";
}

@Aspect
@Component
@RequiredArgsConstructor
public class TenantCodeAuthAspect {

    private final TenantMiniAppConfigRepository configRepository;

    @Before("@annotation(annotation)")
    public void check(JoinPoint joinPoint, RequireTenantCode annotation) {
        Long tenantId = TenantContext.getTenantId();
        TenantMiniAppConfig config = configRepository.findByTenantId(tenantId)
            .orElseThrow(() -> new BusinessException(403, annotation.message()));

        Set<String> allowed = Arrays.stream(annotation.value())
            .map(String::toUpperCase)
            .collect(Collectors.toSet());
        if (!allowed.contains(config.getTenantCode().toUpperCase())) {
            throw new BusinessException(403, annotation.message());
        }
    }
}

@PostMapping("/export")
@RequireTenantCode(value = "YMHW", message = "仅鱼米好物租户支持导出小程序发货模板")
public ResponseEntity<byte[]> export(@RequestBody @Valid ExportRequest req) {
    return ResponseEntity.ok().body(service.export(TenantContext.getTenantId(), req.getOrderIds()));
}
```

---

## 二、Go（Gin）

### 方案 A：endpoint 入口直接校验（**优先**）

```go
type ExportRequest struct {
    OrderIDs []int64 `json:"orderIds" binding:"required,min=1"`
}

func (h *MiniappShippingHandler) Export(c *gin.Context) {
    tenantID := middleware.GetTenantID(c)

    var config TenantMiniAppConfig
    if err := h.db.Where("tenant_id = ?", tenantID).First(&config).Error; err != nil {
        c.JSON(http.StatusForbidden, gin.H{
            "code": 403, "message": "未启用小程序发货模板导出",
        })
        return
    }
    if !strings.EqualFold(config.TenantCode, "YMHW") {
        c.JSON(http.StatusForbidden, gin.H{
            "code": 403, "message": "仅鱼米好物租户支持导出小程序发货模板",
        })
        return
    }

    var req ExportRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"code": 400, "message": err.Error()})
        return
    }

    excel, err := h.svc.Export(c.Request.Context(), tenantID, req.OrderIDs)
    if err != nil {
        _ = c.Error(err)
        return
    }
    c.Header("Content-Disposition", "attachment; filename=miniapp-shipping.xlsx")
    c.Data(http.StatusOK, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", excel)
}
```

### 方案 B：middleware 工厂（多个 endpoint 复用）

```go
func RequireTenantCode(db *gorm.DB, allowed ...string) gin.HandlerFunc {
    allowedSet := make(map[string]struct{}, len(allowed))
    for _, code := range allowed {
        allowedSet[strings.ToUpper(code)] = struct{}{}
    }

    return func(c *gin.Context) {
        tenantID := middleware.GetTenantID(c)
        var config TenantMiniAppConfig
        if err := db.Where("tenant_id = ?", tenantID).First(&config).Error; err != nil {
            c.AbortWithStatusJSON(http.StatusForbidden, gin.H{
                "code": 403, "message": "该功能未对当前租户开放",
            })
            return
        }
        if _, ok := allowedSet[strings.ToUpper(config.TenantCode)]; !ok {
            c.AbortWithStatusJSON(http.StatusForbidden, gin.H{
                "code": 403, "message": "该功能未对当前租户开放",
            })
            return
        }
        c.Next()
    }
}

router.POST("/orders/miniapp-shipping-template/export",
    RequireTenantCode(db, "YMHW"),
    handler.Export,
)
```

---

## 三、TypeScript（Express / NestJS）

### 方案 A：Express handler 直接校验（**优先**）

```typescript
import { Router, Request, Response } from 'express';
import { TenantMiniAppConfigRepository } from './repositories';

router.post('/orders/miniapp-shipping-template/export', async (req: Request, res: Response) => {
  const tenantId = (req as any).tenantId as number;
  const config = await TenantMiniAppConfigRepository.findByTenantId(tenantId);
  if (!config) {
    return res.status(403).json({ code: 403, message: '未启用小程序发货模板导出' });
  }
  if (config.tenantCode.toUpperCase() !== 'YMHW') {
    return res.status(403).json({ code: 403, message: '仅鱼米好物租户支持导出小程序发货模板' });
  }

  const excel = await exportService.export(tenantId, req.body.orderIds);
  res.setHeader('Content-Disposition', 'attachment; filename=miniapp-shipping.xlsx');
  res.send(excel);
});
```

### 方案 B：NestJS Guard + Decorator（多个 endpoint 复用）

```typescript
import { SetMetadata, CanActivate, ExecutionContext, Injectable, ForbiddenException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';

export const RequireTenantCode = (...codes: string[]) =>
  SetMetadata('require-tenant-code', codes);

@Injectable()
export class TenantCodeGuard implements CanActivate {
  constructor(
    private reflector: Reflector,
    private configRepo: TenantMiniAppConfigRepository,
  ) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const allowed = this.reflector.get<string[]>('require-tenant-code', ctx.getHandler());
    if (!allowed?.length) return true;

    const req = ctx.switchToHttp().getRequest();
    const tenantId = req.tenantId as number;
    const config = await this.configRepo.findByTenantId(tenantId);

    if (!config || !allowed.map(c => c.toUpperCase()).includes(config.tenantCode.toUpperCase())) {
      throw new ForbiddenException('该功能未对当前租户开放');
    }
    return true;
  }
}

@Controller('orders/miniapp-shipping-template')
@UseGuards(TenantCodeGuard)
export class MiniappShippingController {
  @Post('export')
  @RequireTenantCode('YMHW')
  async export(@Body() req: ExportRequest) {
    return this.service.export(req.orderIds);
  }
}
```

---

## 四、方案选择速查

| 场景 | 推荐方案 |
|------|---------|
| 1-2 个 endpoint 专属，逻辑简单 | 方案 A：endpoint 入口直接 if 校验 |
| 3+ 个 endpoint 同样的租户/角色限制 | 方案 B：注解 + AOP / middleware 工厂 / NestJS Guard |
| 复杂权限组合（角色 + 数据范围 + 操作） | RBAC/ABAC 框架（Spring Security / Casbin / Cerbos） |
