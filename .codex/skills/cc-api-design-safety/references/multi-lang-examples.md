# 生成下游产物前的完整性校验 — 多语言完整示例

> 配套 `SKILL.md` 陷阱 #5「生成下游产物前缺乏完整性校验」。
> 演示导出 Excel/对账文件/批量推送时，"必填字段一次画全 + 生成前预校验 + 缺失列出业务 ID + 整体失败"的实现方式。

---

## 一、Java（Spring Boot + Apache POI）

```java
@Service
@RequiredArgsConstructor
public class MiniappShippingTemplateExportService {

    private final TenantMiniAppConfigRepository configRepository;
    private final TradeOrderRepository orderRepository;
    private final PaymentRecordRepository paymentRepository;

    public byte[] export(Long tenantId, List<Long> orderIds) {
        TenantMiniAppConfig config = configRepository.findByTenantId(tenantId)
            .orElseThrow(() -> new BusinessException("未配置小程序"));
        if (!StringUtils.hasText(config.getMchId())) {
            throw new BusinessException("小程序未配置微信支付商户号，无法导出");
        }

        List<TradeOrder> orders = orderRepository.findExportable(tenantId, orderIds);
        if (orders.isEmpty()) {
            throw new BusinessException("没有可导出的订单");
        }

        Map<Long, PaymentRecord> paymentMap = paymentRepository
            .findByOrderIds(orders.stream().map(TradeOrder::getId).collect(toList()))
            .stream().collect(toMap(PaymentRecord::getOrderId, p -> p));

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
            throw new BusinessException("以下订单缺少微信支付交易单号，无法导出: "
                + String.join("、", missingTxn));
        }
        if (!missingPackage.isEmpty()) {
            throw new BusinessException("以下订单缺少快递单号，无法导出: "
                + String.join("、", missingPackage));
        }
        if (!missingCompany.isEmpty()) {
            throw new BusinessException("以下订单缺少快递公司，无法导出: "
                + String.join("、", missingCompany));
        }
    }

    private byte[] buildWorkbook(List<TradeOrder> orders, Map<Long, PaymentRecord> paymentMap, String mchId) {
        try (Workbook workbook = new XSSFWorkbook();
             ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            Sheet sheet = workbook.createSheet("小程序发货模板");
            writeHeader(sheet);
            int rowIdx = 1;
            for (TradeOrder order : orders) {
                writeRow(sheet, rowIdx++, order, paymentMap.get(order.getId()), mchId);
            }
            workbook.write(out);
            return out.toByteArray();
        } catch (IOException e) {
            throw new BusinessException("导出失败: " + e.getMessage());
        }
    }
}
```

---

## 二、Go（Gin + excelize）

```go
package shipping

import (
    "fmt"
    "strings"

    "github.com/xuri/excelize/v2"
)

type ExportService struct {
    configRepo  ConfigRepository
    orderRepo   OrderRepository
    paymentRepo PaymentRepository
}

func (s *ExportService) Export(tenantID int64, orderIDs []int64) ([]byte, error) {
    config, err := s.configRepo.FindByTenantID(tenantID)
    if err != nil {
        return nil, fmt.Errorf("未配置小程序: %w", err)
    }
    if config.MchID == "" {
        return nil, fmt.Errorf("小程序未配置微信支付商户号，无法导出")
    }

    orders, err := s.orderRepo.FindExportable(tenantID, orderIDs)
    if err != nil {
        return nil, err
    }
    if len(orders) == 0 {
        return nil, fmt.Errorf("没有可导出的订单")
    }

    paymentMap, err := s.loadPaymentMap(orders)
    if err != nil {
        return nil, err
    }

    if err := validateRequiredFields(orders, paymentMap); err != nil {
        return nil, err
    }

    return buildWorkbook(orders, paymentMap, config.MchID)
}

func validateRequiredFields(orders []TradeOrder, paymentMap map[int64]PaymentRecord) error {
    var missingTxn, missingPackage, missingCompany []string

    for _, order := range orders {
        payment, ok := paymentMap[order.ID]
        if !ok || payment.TransactionID == "" {
            missingTxn = append(missingTxn, order.OrderNumber)
        }
        packages := resolvePackages(order)
        if len(packages) == 0 {
            missingPackage = append(missingPackage, order.OrderNumber)
            continue
        }
        for _, p := range packages {
            if p.Company == "" {
                missingCompany = append(missingCompany, order.OrderNumber)
                break
            }
        }
    }

    if len(missingTxn) > 0 {
        return fmt.Errorf("以下订单缺少微信支付交易单号，无法导出: %s", strings.Join(missingTxn, "、"))
    }
    if len(missingPackage) > 0 {
        return fmt.Errorf("以下订单缺少快递单号，无法导出: %s", strings.Join(missingPackage, "、"))
    }
    if len(missingCompany) > 0 {
        return fmt.Errorf("以下订单缺少快递公司，无法导出: %s", strings.Join(missingCompany, "、"))
    }
    return nil
}

func buildWorkbook(orders []TradeOrder, paymentMap map[int64]PaymentRecord, mchID string) ([]byte, error) {
    f := excelize.NewFile()
    defer f.Close()

    sheet := "小程序发货模板"
    _, _ = f.NewSheet(sheet)
    writeHeader(f, sheet)
    for i, order := range orders {
        if err := writeRow(f, sheet, i+2, order, paymentMap[order.ID], mchID); err != nil {
            return nil, err
        }
    }

    buf, err := f.WriteToBuffer()
    if err != nil {
        return nil, fmt.Errorf("导出失败: %w", err)
    }
    return buf.Bytes(), nil
}
```

---

## 三、TypeScript（Express / NestJS + ExcelJS）

```typescript
import ExcelJS from 'exceljs';
import { Injectable } from '@nestjs/common';

class BusinessError extends Error {}

@Injectable()
export class MiniappShippingExportService {
  constructor(
    private configRepo: TenantMiniAppConfigRepository,
    private orderRepo: TradeOrderRepository,
    private paymentRepo: PaymentRecordRepository,
  ) {}

  async export(tenantId: number, orderIds: number[]): Promise<Buffer> {
    const config = await this.configRepo.findByTenantId(tenantId);
    if (!config) throw new BusinessError('未配置小程序');
    if (!config.mchId) throw new BusinessError('小程序未配置微信支付商户号，无法导出');

    const orders = await this.orderRepo.findExportable(tenantId, orderIds);
    if (orders.length === 0) throw new BusinessError('没有可导出的订单');

    const payments = await this.paymentRepo.findByOrderIds(orders.map(o => o.id));
    const paymentMap = new Map(payments.map(p => [p.orderId, p]));

    this.validateRequiredFields(orders, paymentMap);

    return this.buildWorkbook(orders, paymentMap, config.mchId);
  }

  private validateRequiredFields(orders: TradeOrder[], paymentMap: Map<number, PaymentRecord>): void {
    const missingTxn: string[] = [];
    const missingPackage: string[] = [];
    const missingCompany: string[] = [];

    for (const order of orders) {
      const payment = paymentMap.get(order.id);
      if (!payment || !payment.transactionId) {
        missingTxn.push(order.orderNumber);
      }
      const packages = this.resolvePackages(order);
      if (packages.length === 0) {
        missingPackage.push(order.orderNumber);
      } else if (packages.some(p => !p.company)) {
        missingCompany.push(order.orderNumber);
      }
    }

    if (missingTxn.length > 0) {
      throw new BusinessError(`以下订单缺少微信支付交易单号，无法导出: ${missingTxn.join('、')}`);
    }
    if (missingPackage.length > 0) {
      throw new BusinessError(`以下订单缺少快递单号，无法导出: ${missingPackage.join('、')}`);
    }
    if (missingCompany.length > 0) {
      throw new BusinessError(`以下订单缺少快递公司，无法导出: ${missingCompany.join('、')}`);
    }
  }

  private async buildWorkbook(orders: TradeOrder[], paymentMap: Map<number, PaymentRecord>, mchId: string): Promise<Buffer> {
    const workbook = new ExcelJS.Workbook();
    const sheet = workbook.addWorksheet('小程序发货模板');
    this.writeHeader(sheet);
    orders.forEach((order, idx) => {
      this.writeRow(sheet, idx + 2, order, paymentMap.get(order.id), mchId);
    });
    return Buffer.from(await workbook.xlsx.writeBuffer());
  }
}
```

---

## 四、必填字段清单模板（下手前先填这个表）

设计前先把这张表填完，避免 review 多轮才补全：

| 字段 | 层次 | 来源 | 可能为空的路径 | 缺失时怎么办 |
|------|------|------|---------------|-------------|
| `mchId` | 依赖配置 | `tenant_mini_app_config.mch_id` | 租户未配置 | 抛业务错误，提示去配置页面 |
| `transactionId` | 外键关联 | `payment_record.transaction_id`，按 `orderId` 关联 | 纯积分支付 / mock 数据 / 支付记录未回写 | 列出缺失的订单号，整体失败 |
| 快递公司 | 外键关联 | `shipping_package.company`，按订单关联 | 物流未回填 / 多包裹只填了部分 | 列出缺失的订单号，整体失败 |
| 快递单号 | 外键关联 | `shipping_package.tracking_no` | 物流未回填 | 列出缺失的订单号，整体失败 |
| 订单号 | 业务字段 | `trade_order.order_number` | 通常不会为空 | 不会发生，跳过 |

**判断"必填"的依据**：必须查阅下游消费方的官方文档（如 [微信小程序发货管理文档](https://developers.weixin.qq.com/) / 对账规范 / 第三方推送 API spec），不是看源数据是否方便填。

---

## 五、易混淆点

- **HTTP 200 ≠ 业务成功**：下游 import 失败时，调用方常误以为生成成功
- **空字符串 ≠ 没有值**：下游严格校验时，`""` 也算"提供了一个无效值"，可能比 `null` 更糟
- **校验函数要在生成产物前调用**：写完 row、生成完 workbook 才校验，意味着已经做了无效工作
- **错误信息要带业务 ID**：返回"导出失败"没用，必须返回"订单 SO20260512001、SO20260512007 缺少快递单号"
