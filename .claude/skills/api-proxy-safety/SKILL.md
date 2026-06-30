---
name: api-proxy-safety
description: 网关/代理/WAF/CDN 中间件的安全关键词匹配实现规范，防止纯子串匹配误判正常响应内容中的技术术语（如 Cloudflare、502、error）
version: v1.0
paths:
  - "**/*proxy*"
  - "**/*gateway*"
  - "**/*waf*"
  - "**/*middleware*"
  - "**/*interceptor*"
  - "**/*filter*"
  - "**/*openapi*"
  - "**/*nginx*"
  - "**/*openresty*"
  - "**/*rewrite*"
  - "**/*redirect*"
  - "**/*security*"
---

# API 代理安全关键词匹配规范

> 网关/WAF/CDN 中间件实现关键词匹配时，避免纯子串匹配导致正常响应内容被误判。

---

## 核心问题

### 纯子串匹配的误判

```go
// ❌ 误判：纯子串匹配，长正文中的正常用词也会命中
var pseudoSuccessPatterns = []string{
    "cloudflare",
    "502 bad gateway",
    "bad gateway",
    "reconnecting",
    "upstream error",
}
```

当业务响应正文包含这些关键词的**字面值**（如文章主题就是 "Cloudflare"），纯子串匹配会触发误判，导致：
- 正常响应被当作伪成功错误
- 触发站点切换 / 上游降级
- 错误标记模型/节点不可用

**关键事实**：关键词出现在长正文中 ≠ 响应存在问题。

---

## 解决方案：强/弱特征拆分 + 分层判定

将关键词按风险特征拆分为两组，并配合 HTTP 元数据做分层判定：

### 分层判定原则（推荐）

使用正文关键词匹配前，先通过 HTTP 元数据排除绝大多数正常响应：

| 判定层 | 检查项 | 优先级 |
|--------|--------|--------|
| 1. HTTP status | `2xx`=正常, `5xx`/`429`/某些`403`=错误 | 最高 |
| 2. Content-Type | `text/event-stream` 保持流式处理, `application/json` 检查 schema | ↑ |
| 3. 响应 schema / 错误字段 | JSON 中 `error.code` / `error.message` / `success:false` 等 | ↑ |
| 4. 正文关键词匹配 | 强/弱特征，仅作为**启发式证据**，不作为唯一事实 | 最低 |

> **正文关键词只是启发式证据**：正常用户内容可能包含技术术语字面值（如 Cloudflare、502、bad gateway），关键词命中不必然等于响应错误，必须结合 status/schema 做综合判断。

### 强特征（任何长度命中）

完整错误语句或 HTML 错误页特征。**这些模式极长且内容特殊，正常用户内容中几乎不可能出现**，可任意长度命中：

| 特征 | 说明 |
|------|------|
| `exceeded retry limit, last status: 429 too many requests` | 完整 429 错误句 |
| `must be enabled in your dashboard first` | 完整仪表盘引导句 |
| `unexpected status 502 bad gateway: error code: 502` | 完整 502 错误句（含 UUID） |
| `<html` / `<title>5` / `cf-ray:` | HTML 错误页特征 |

```go
var pseudoSuccessChatStrongPatterns = []string{
    "exceeded retry limit, last status: 429 too many requests",
    "must be enabled in your dashboard first",
    "unexpected status 502 bad gateway: error code: 502",
    "reconnecting...",
    "<html",
    "<title>5",
    "cf-ray:",
}
```

### 弱特征（仅 ≤512 字节内容命中）

单词级或短语级关键词。**极短内容（≤512 字节）中命中才判为错误**，避免长正文中技术术语误判：

| 特征 | 说明 |
|------|------|
| `429 too many requests` | 短版 429 |
| `502 bad gateway` / `bad gateway` | 短版 502 |
| `upstream error` / `upstream connect error` | 上游错误 |
| `just a moment` | CDN 挑战 |
| `cloudflare` | CDN 品牌名 |
| `must be enabled in your dashboard first` | 短版引导句 |

```go
var pseudoSuccessChatWeakPatterns = []string{
    "429 too many requests",
    "502 bad gateway",
    "bad gateway",
    "upstream error",
    "upstream connect error",
    "just a moment",
    "cloudflare",
    "must be enabled in your dashboard first",
}
```

### 判定逻辑

```go
func containsPseudoSuccessInChatResponse(content string) bool {
    // 先检查 HTTP status 和响应 schema（应有上层调用保证）
    // 正文关键词仅作为启发式证据

    // 强特征：任何长度命中
    for _, p := range pseudoSuccessChatStrongPatterns {
        if strings.Contains(strings.ToLower(content), p) {
            return true
        }
    }
    // 弱特征：仅 ≤512 字节命中
    if len(content) > 512 {
        return false
    }
    low := strings.ToLower(content)
    for _, p := range pseudoSuccessChatWeakPatterns {
        if strings.Contains(low, p) {
            return true
        }
    }
    return false
}
```

---

## 不同场景的匹配策略

| 场景 | 策略 | 原因 |
|------|------|------|
| **聊天响应正文**（长文本） | 强特征任意长度 + 弱特征仅 ≤512 字节命中 | 正文可能包含技术术语字面值 |
| **错误消息**（短文本） | 全量匹配，无需长度限制 | error message 本身很短，且不含正常用户内容 |
| **流式响应片段**（分块） | 参考 HTTP streaming 分类目标实现 | 等待完整块再匹配，或按内容格式切割后匹配 |

---

## 隐含缺陷判定

实现关键词匹配时，用以下问题自检：

- [ ] 匹配的关键词在正常用户内容中**是否可能出现**？
- [ ] 如果出现，是否按**正文长度**做了分级？
- [ ] 同样关键词出现在短错误消息 vs 长正常文章里，判定逻辑是否不同？
- [ ] 是否有回归测试覆盖**长正文误判**场景？

**自测案例**：

| 内容 | 长度 | 正确判定 | 说明 |
|------|------|---------|------|
| `"exceeded retry limit, last status: 429 too many requests"` | 短 | 错误 | 强特征命中 |
| `"Cloudflare（文章主题）..."` + 4657 字正文 | 长 | 正常 | 弱特征+超长→不命中 |
| `"502 Bad Gateway"`（纯错误） | 短 | 错误 | 弱特征+短→命中 |
| `"502 Bad Gateway: 配置 Nginx 反向代理时..."` + 完整博客 | 长 | 正常 | 弱特征+超长→不命中，无强特征 |

---

## 与相关 skill 的边界

| skill | 关系 |
|-------|------|
| `external-system-debugging` | 本 skill 的**上游**：面对 CDN/WAF 网关行为异常时，先走外部系统方法论抓真实数据，再回来看匹配逻辑实现是否正确 |
| `api-design-safety` | 本 skill 聚焦**代理中间件的安全匹配实现**，而非 API 本身的设计规范 |
| `ops-safety` | 本 skill 不涉及运维操作安全、危险命令等 |

---

## 规则溯源

```
> 📋 本回复遵循：`api-proxy-safety` - [章节]
```
