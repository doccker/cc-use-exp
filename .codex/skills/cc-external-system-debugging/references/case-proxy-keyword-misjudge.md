# 案例：OpenResty 代理关键词子串匹配误判正常文章内容

> 关键词：代理网关、关键词过滤、纯子串匹配、强弱特征拆分、长正文误判

---

## 问题

正常长文章大纲响应被代理判定为伪成功错误内容。响应主题包含 "OpenResty + Cloudflare 防御",正文是合法业务 JSON,但代理关键词命中后触发站点切换和模型不可用标记。

## 根因

代理判定函数对 `message.content` 做纯子串匹配,关键词包含 `cloudflare`、`502 bad gateway`、`bad gateway` 等常见技术术语。

这些词既可能出现在真实错误页,也可能出现在用户文章、日志解释、教程标题或模型正常输出中。只看正文关键词,没有结合 HTTP status、headers、Content-Type、业务 JSON 结构和正文长度,就会把正常长内容误判为上游错误。

## 修复方向

1. 先抓真实 request/response,保留 status、headers、原始 body 和业务解析结果。
2. 先按 HTTP 状态、响应头、Content-Type、业务 envelope 判定。
3. 关键词只作为启发式证据,并拆分强弱特征。
4. 弱特征只在短响应体、非业务 payload 或伴随错误状态/错误头时参与判错。

## 回归测试

- 长正文含 `Cloudflare` 不误判。
- 长正文含 `502 Bad Gateway` 教程标题不误判。
- 短响应体 `502 Bad Gateway` 判错。
- `status=502` 且 HTML 错误页判错。
- `status=200` 且合法业务 JSON 内含技术术语不误判。

## 参考

- `cc-api-proxy-safety` — 代理响应判定与关键词匹配规范
- `cc-external-system-debugging` — 外部黑盒系统先抓真实数据的方法论
