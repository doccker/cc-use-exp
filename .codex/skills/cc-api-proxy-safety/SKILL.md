---
name: cc-api-proxy-safety
description: 网关/代理/WAF/CDN 中间件响应判定与关键词匹配安全规范。适用于 proxy/gateway/waf/cdn/nginx/openresty/rewrite/redirect 等代码,防止把正常长正文中的 Cloudflare、502、bad gateway、error 等技术术语误判为上游错误。
---

# API 代理响应判定安全规范

网关、反向代理、WAF、CDN 中间件实现响应判定时,不要只靠正文关键词判断上游是否失败。关键词可以作为线索,不能替代 HTTP 状态、响应头、内容类型和业务响应结构。

---

## 核心原则

按以下优先级判定响应性质:

1. **传输层和 HTTP 状态**:连接失败、超时、非 2xx/3xx 状态码优先作为错误证据。
2. **响应头和内容类型**:`Content-Type`、`Server`、`Via`、`CF-Ray`、认证/限流头等比正文关键词更可靠。
3. **业务响应结构**:先解析 JSON envelope、error code、message、data 等契约字段。
4. **正文启发式**:只有在无法按结构判断时,才使用关键词或 HTML 片段,并限制长度和上下文。

**禁止**:对完整业务正文做纯 `strings.Contains(lowerBody, "cloudflare")` / `"bad gateway"` / `"error"` 判错。

---

## 强弱特征拆分

### 强特征

强特征应同时具备明确上下文,例如:

- HTTP 状态为 502/503/504/429,且正文是上游错误页或错误 envelope。
- `Content-Type: text/html`,正文包含错误页标题,且响应头或状态也指向 CDN/WAF/网关。
- 结构化 JSON 明确给出上游错误字段,例如 `{"error": {"type": "upstream_error"}}`。

不要把单个短片段直接当强特征。`<html`、`cf-ray:`、`cloudflare`、`502 bad gateway` 都可能出现在技术文章、日志展示或用户输入中。

### 弱特征

以下内容只能作为弱证据:

- CDN/网关品牌词:`cloudflare`、`openresty`、`nginx`
- 短错误短语:`bad gateway`、`502 bad gateway`、`upstream error`
- 通用错误词:`error`、`reconnecting`、`too many requests`

弱特征只有在满足以下条件时才可参与判错:

- 响应体很短,例如 `<= 512` 字节。
- 响应结构不是合法业务 payload。
- 或者它和错误 HTTP 状态、错误响应头、错误 content-type 同时出现。

---

## 判定模板

```go
func isUpstreamFailure(resp *http.Response, body []byte) bool {
    if resp == nil {
        return true
    }

    status := resp.StatusCode
    contentType := strings.ToLower(resp.Header.Get("Content-Type"))

    if status >= 500 || status == http.StatusTooManyRequests {
        low := strings.ToLower(string(body))
        return looksLikeGatewayError(contentType, low, len(body))
    }

    if isValidBusinessPayload(contentType, body) {
        return false
    }

    if len(body) > 512 {
        return false
    }

    low := strings.ToLower(string(body))
    if len(body) <= 512 && containsWeakGatewayKeyword(low) {
        return true
    }

    return false
}
```

实现时把 `looksLikeGatewayError`、`isValidBusinessPayload`、`containsWeakGatewayKeyword` 拆开测试,不要把所有条件写成一个大 `if`。

---

## 场景策略

| 场景 | 策略 |
|------|------|
| HTTP 非 2xx/3xx | 优先按状态码和响应头判错,正文用于补充分类 |
| 业务 JSON 响应 | 先解析契约字段,不要因为 `data` 或正文里有技术词就判错 |
| 长文本/文章/模型输出 | 不允许仅凭弱关键词判错 |
| 短错误消息 | 可使用弱关键词,但仍应结合调用上下文 |
| 流式响应 | 等待完整事件、完整 JSON chunk 或明确错误事件后再判定 |

---

## 回归测试

至少覆盖:

- 长正文包含 `Cloudflare` / `502 Bad Gateway` / `bad gateway` 技术术语时不误判。
- 短响应体只有 `502 Bad Gateway` 且没有业务结构时判为错误。
- `status=200` 且合法业务 JSON 中出现弱关键词时不误判。
- `status=502` 且 HTML 错误页时判为错误。
- streaming 半截 chunk 命中关键词时不立即判错。

---

## 与相关 skill 的边界

| skill | 关系 |
|-------|------|
| `cc-external-system-debugging` | 上游方法论:遇到 CDN/WAF/代理异常时先抓真实 request/response |
| `cc-api-design-safety` | 本 skill 关注代理判定逻辑,不替代 API envelope 设计规范 |
| `cc-ops-safety` | 本 skill 不处理运维审批、危险命令或生产配置变更 |

---

## 规则溯源

```
> 📋 本回复遵循：`cc-api-proxy-safety` - [章节]
```
