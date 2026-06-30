# 案例：OpenResty 代理关键词子串匹配误判正常文章内容

> 关键词：代理网关、关键词过滤、纯子串匹配、强/弱特征拆分、长正文误判

---

## 问题

正常的长文章大纲响应（4657 字节 JSON，文章主题是 "OpenResty + Cloudflare 防御"）被代理判定为「伪成功错误内容」，命中关键词后触发站点切换 + 模型标记不可用。

## 根因

`detectPseudoSuccessUpstreamErrorInChatResponse` 调用 `containsPseudoSuccessUpstreamErrorValue`，对 `message.content` 做纯子串匹配。其中 `pseudoSuccessGatewayErrorPatterns` 包含 `"cloudflare"`、`"502 bad gateway"`、`"bad gateway"` 等高频词，没有长度或上下文限制。

本次响应正文里包含 `"Cloudflare"` 字面值（文章主题就是它），被关键词命中误判。

## 修复方案

将关键词拆为两组：

| 类型 | 特征 | 判定规则 |
|------|------|---------|
| 强特征 | 完整错误句/HTML 错误页（如 `<html`、`cf-ray:`） | 任何长度命中 |
| 弱特征 | 单词/短语级（如 `cloudflare`、`bad gateway`） | 仅 ≤512 字节内容命中 |

## 通用教训

1. **纯子串匹配的关键词黑名单在长正文中必然误判**，必须要有长度或上下文限制
2. **技术术语（Cloudflare、502、bad gateway）作为正常文章主题时必然出现**，不能当错误特征
3. **短错误消息和长正文应使用不同的匹配策略**
4. 修复后必须加回归测试：长正文含关键词不误判 + 短错误消息仍能命中

## 参考

- `.claude/skills/api-proxy-safety/SKILL.md` — 关键词匹配通用规范
- `external-system-debugging/SKILL.md` — 数据采集方法论
