---
name: payment-callback-safety
description: >-
  当代码涉及支付回调、webhook 通知、notify_url、微信支付/支付宝回调处理时触发。
  防止回调伪造、重放攻击、金额篡改等支付安全问题。
---
<instructions>

# 支付回调安全规范

当系统涉及第三方支付回调（微信支付、支付宝等）或 webhook 通知时，防止伪造、篡改和重放攻击。

---

## 陷阱 #1: 回调未验证平台签名

**场景**: 收到支付回调后直接解密/解析并处理，未验证请求确实来自支付平台

### 问题根因

支付回调地址暴露在公网，任何人都可以伪造请求。如果不验签，攻击者可以构造假的"支付成功"通知。

### 错误示例

```java
// ❌ 错误: 直接解密处理，未验签
@PostMapping("/payment/callback/wechat")
public String wechatCallback(@RequestBody String body) {
    JsonNode json = objectMapper.readTree(body);
    // 直接尝试解密 resource
    String decrypted = decryptAesGcm(ciphertext, apiV3Key, nonce, aad);
    processPayment(decrypted);  // 谁发来的都处理
    return "{\"code\":\"SUCCESS\"}";
}
```

### 正确做法

```java
// ✅ 正确: 先验签，再解密，再处理
@PostMapping("/payment/callback/wechat")
public String wechatCallback(
    @RequestBody String body,
    @RequestHeader("Wechatpay-Signature") String signature,
    @RequestHeader("Wechatpay-Timestamp") String timestamp,
    @RequestHeader("Wechatpay-Nonce") String nonce,
    @RequestHeader("Wechatpay-Serial") String serial) {

    // 1. 用微信支付平台公钥验签（不是商户私钥）
    String message = timestamp + "\n" + nonce + "\n" + body + "\n";
    PublicKey platformKey = loadPlatformPublicKey(serial);
    if (!verifySignature(message, signature, platformKey)) {
        return "{\"code\":\"FAIL\",\"message\":\"验签失败\"}";
    }

    // 2. 验签通过后再解密和处理
    String decrypted = decryptAesGcm(ciphertext, apiV3Key, nonce, aad);
    processPayment(decrypted);
    return "{\"code\":\"SUCCESS\"}";
}
```

### 关键区分

| 密钥/证书 | 用途 | 持有方 |
|-----------|------|--------|
| 商户私钥 | 商户请求微信时签名 | 商户 |
| 商户 API 证书 | 商户身份标识 | 商户 |
| 微信支付平台公钥/证书 | 验证微信回调签名 | 微信平台签发，商户持有公钥 |
| API V3 Key | 解密回调通知体 | 商户 |

### 检查清单

- [ ] 回调入口是否在解密前先验证平台签名
- [ ] 验签使用的是平台公钥/证书，而非商户私钥
- [ ] 是否按 `Wechatpay-Serial` 匹配对应平台证书（支持证书轮换）
- [ ] 验签失败是否直接拒绝，不继续处理

---

## 陷阱 #2: 未做防重放校验

**场景**: 攻击者截获一份真实的支付成功回调，重复发送给系统

### 问题根因

合法的旧回调报文签名仍然有效，仅靠验签无法防止重放。

### 错误示例

```java
// ❌ 错误: 验签通过就直接处理，不检查是否重复
if (verifySignature(message, signature, platformKey)) {
    processPayment(decrypted);  // 同一笔单可能被处理多次
}
```

### 正确做法

```java
// ✅ 正确: 三层防重放
// 第 1 层: 时间戳窗口
long callbackTime = Long.parseLong(timestamp);
long now = Instant.now().getEpochSecond();
if (Math.abs(now - callbackTime) > 300) {  // 5 分钟窗口
    return "{\"code\":\"FAIL\",\"message\":\"timestamp expired\"}";
}

// 第 2 层: 按 transaction_id 幂等
String transactionId = payData.get("transaction_id").asText();
if (paymentRecordRepository.existsByTransactionIdAndStatus(
        transactionId, "SUCCESS")) {
    log.info("重复通知，已处理: transactionId={}", transactionId);
    return "{\"code\":\"SUCCESS\"}";  // 返回成功，让平台停止重试
}

// 第 3 层: 订单状态机幂等
TradeOrder order = orderRepository.findByOrderNumber(outTradeNo);
if (order.getPaymentStatus() == PaymentStatus.PAID) {
    log.info("订单已支付，跳过: orderId={}", order.getId());
    return "{\"code\":\"SUCCESS\"}";
}
```

### 检查清单

- [ ] 是否校验回调时间戳窗口（建议 5 分钟）
- [ ] 是否按 transaction_id 做幂等判重
- [ ] 是否检查订单当前状态（防止已支付订单被重复处理）
- [ ] 重复通知是否返回成功（让平台停止重试）

---

## 陷阱 #3: 信任回调中的金额

**场景**: 直接使用回调报文中的金额作为入账依据，未与本地订单金额校验

### 问题根因

即使验签通过，也应以本地订单金额为准做一致性校验，防止订单错配或极端情况下的金额不一致。

### 错误示例

```java
// ❌ 错误: 直接用回调金额入账
int paidAmount = payData.get("amount").get("total").asInt();
order.setPaidAmount(paidAmount);  // 不校验是否与下单金额一致
order.setStatus("PAID");
```

### 正确做法

```java
// ✅ 正确: 回调金额必须与本地订单金额严格一致
int callbackAmountFen = payData.get("amount").get("total").asInt();
int expectedAmountFen = order.getTotalAmount()
    .multiply(BigDecimal.valueOf(100)).intValue();

if (callbackAmountFen != expectedAmountFen) {
    log.error("金额不一致: callback={}, expected={}, orderId={}",
        callbackAmountFen, expectedAmountFen, order.getId());
    // 标记异常，不入账
    paymentRecord.setReconcileStatus("MISMATCHED");
    paymentRecord.setReconcileErrorMessage("金额不一致");
    return;
}
```

### 检查清单

- [ ] 回调金额是否与本地订单应付金额做了严格比对
- [ ] 金额比对的口径是否与下单请求一致（同一个字段）
- [ ] 金额不一致时是否拒绝入账并记录异常
- [ ] 是否有封装方法明确"微信支付金额口径"（防止后续改动导致口径分叉）

---

## 陷阱 #4: 回调与对账走不同的校验逻辑

**场景**: 回调链路有完整校验，但"手动对账"链路跳过了部分校验

### 问题根因

对账补单和回调处理本质上都是"确认支付成功"，如果走不同的校验逻辑，容易在对账链路留下安全缺口。

### 错误示例

```java
// ❌ 错误: 回调有完整校验
public void handleCallback(JsonNode payData, TradeOrder order) {
    validateAmount(payData, order);
    validateMchId(payData, config);
    validateAppId(payData, config);
    processPayment(order, transactionId);
}

// ❌ 错误: 对账直接补单，跳过校验
public void reconcile(PaymentRecord record) {
    JsonNode queryResult = queryWechatOrder(outTradeNo);
    if ("SUCCESS".equals(tradeState)) {
        processPayment(order, transactionId);  // 没有校验金额/商户号
    }
}
```

### 正确做法

```java
// ✅ 正确: 抽取统一校验函数，回调和对账都复用
public void validatePaymentResult(
    JsonNode payData, TradeOrder order, TenantConfig config) {
    // 1. out_trade_no 一致
    // 2. transaction_id 非空
    // 3. appid 一致
    // 4. mchid 一致
    // 5. 金额一致
    // 任何一项不通过都抛异常
}

// 回调链路
public void handleCallback(JsonNode payData, TradeOrder order, TenantConfig config) {
    validatePaymentResult(payData, order, config);
    processPayment(order, transactionId);
}

// 对账链路
public void reconcile(PaymentRecord record) {
    JsonNode queryResult = queryWechatOrder(outTradeNo);
    validatePaymentResult(queryResult, order, config);  // 同一套校验
    processPayment(order, transactionId);
}
```

### 检查清单

- [ ] 回调和对账是否复用同一套支付结果校验逻辑
- [ ] 对账补单是否也校验了金额、商户号、AppID
- [ ] "人工点击对账按钮"本身是否不算支付成功依据
- [ ] 对账是否只信任支付平台订单查询 API 的真实返回

---

## 陷阱 #5: 占位/TODO 实现上线

**场景**: 支付查询、对账等关键逻辑使用占位实现，但未被发现就上线了

### 错误示例

```java
// ❌ 错误: 占位实现，返回假数据
private JsonNode queryWechatOrderStatus(PaymentRecord record) {
    // TODO: 接入微信支付订单查询 V3 API
    log.warn("微信订单查询 API 待实现: orderId={}", record.getOrderId());
    return objectMapper.createObjectNode()
        .put("trade_state", "NOTPAY")
        .put("trade_state_desc", "未支付(占位)");
}
```

### 正确做法

```java
// ✅ 正确: 占位实现必须明确失败，不能返回看似正常的假数据
private JsonNode queryWechatOrderStatus(PaymentRecord record) {
    throw new UnsupportedOperationException(
        "微信订单查询 API 未实现，请先完成接入");
}
```

### 检查清单

- [ ] 支付相关的 TODO/占位实现是否会抛异常而非返回假数据
- [ ] 是否有日志或监控能发现占位逻辑被触发
- [ ] 上线前是否检查了支付链路中的所有 TODO

---

## 检查清单（支付回调安全）

**验签与防伪**:
- [ ] 回调是否验证了平台签名
- [ ] 验签使用的是平台公钥/证书（非商户私钥）
- [ ] 是否支持平台证书轮换（按 serial 匹配）

**防重放**:
- [ ] 是否校验时间戳窗口
- [ ] 是否按 transaction_id 做幂等
- [ ] 是否检查订单状态机

**业务校验**:
- [ ] 金额是否与本地订单严格一致
- [ ] out_trade_no 是否与本地订单号一致
- [ ] appid / mchid 是否与租户配置一致
- [ ] 回调与对账是否复用同一套校验

**实现完整性**:
- [ ] 支付链路是否有占位/TODO 实现
- [ ] 占位实现是否会明确失败（而非返回假数据）

---

## 适用范围

- 微信支付 API v3
- 支付宝开放平台
- Stripe Webhooks
- PayPal IPN/Webhooks
- 其他第三方支付/webhook 通知

---

## 规则溯源

```
> 📋 本回复遵循：`payment-callback-safety` - [章节名]
```

</instructions>