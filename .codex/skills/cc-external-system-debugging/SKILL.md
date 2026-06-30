---
name: cc-external-system-debugging
description: 涉及浏览器、编辑器、CDN/WAF、IM 平台、操作系统剪贴板、第三方 SaaS 等"外部黑盒系统"的代码编写或 bug 调试时触发。强制先抓真实环境数据再推理,避免连续 2 轮"凭代码推理"的修复 no-op。关键词:粘贴/复制异常、跨平台显示不一致、第三方 API 怪结果、CDN/WAF 拦截、本地复现失败、HTML→MD 转换丢属性。
---

# 外部黑盒系统调试方法论

> "代码没说谎,但黑盒系统的行为不在代码里。"

涉及代码以外的环境(浏览器、编辑器、CDN、IM 平台、第三方 API),编码和调试都必须**先抓真实数据,再做推理**。

---

## 何时触发

**写代码场景**
- 输出会被第三方平台消费的内容(HTML 推送到 CSDN/微信/Notion/钉钉/飞书)
- 集成浏览器/操作系统 API(Clipboard / Drag-Drop / File System)
- 调用经过 CDN/WAF/反代的第三方 HTTP API
- 在 IM / 富文本编辑器中渲染内容

**调试场景**
- 跨浏览器/跨设备/跨终端表现不一致
- 粘贴/复制行为异常
- 第三方 API 返回怪结果(body 空、headers 不全、200 但 error)
- 本地复现失败但线上有问题
- **连续 2 轮"凭代码推理"的修复都 no-op**(最强信号)

---

## 黑盒判定清单

| 维度 | 不是黑盒 | 是黑盒(触发本 skill)|
|------|---------|------------------|
| 控制权 | 自己写的代码 | 第三方/平台/浏览器实现 |
| 文档完备性 | 有完整 API 文档 | 文档不全或有未文档化行为 |
| 可调试性 | 能加日志、断点 | 只能从外部观察输入输出 |
| 行为可预测 | 给定输入必然得到给定输出 | 同一输入在不同环境表现不同 |

满足任意 2 项 → 走本 skill 方法论。

---

## 数据采集模板(核心)

不同黑盒类型,**第一步该让用户抓什么**:

| 黑盒类型 | 优先采集 | 工具/方法 |
|---------|---------|---------|
| 浏览器粘贴/复制 | 实际剪贴板 HTML | `navigator.clipboard.read()` 列出所有 mime + 打印 outerHTML |
| 第三方编辑器渲染 | 粘贴前 vs 粘贴后 DOM | DevTools Elements 拷 outerHTML 做 diff |
| 跨浏览器渲染 | 真机截图 + DOM 结构 | 真机/BrowserStack;不仅看效果,要拷 DOM |
| HTTP 第三方 API | 完整 request/response | `curl -v` / Charles / mitmproxy;比对 GET vs POST |
| CDN/WAF 拦截 | 中间节点信息 | `curl -I` 看 `Server` / `Via` 头;空 body + 极简 headers 强信号 |
| IM 平台(微信/钉钉/飞书) | 发送+接收两端实际渲染 | 必须真机截图;不能只看发送端 |
| 操作系统剪贴板 | 所有可用 mime type | `navigator.clipboard.read()` / macOS `pbpaste -Prefer html` |
| 移动端 webview | UA + 实际加载的 CSS/JS | Chrome DevTools 远程调试 |

⚠️ **抓数据必须保留原始格式**:HTML 用 outerHTML 而非 innerText,JSON 用原始字节,二进制用 hexdump。

---

## 调试决策流

```
Bug 现象 → 涉及外部黑盒? 
  ├─ 是 → 数据采集模板 → 基于数据做假设 → 单变量验证 → 修复 → 追加到 references/
  └─ 否 → 走通用系统化调试流程
```

**关键节点**:
1. **不要跳过数据采集**:用户描述的现象可能不准确,真实数据才是事实
2. **假设必须基于数据**:每个假设都要能引用具体的抓取结果,不能"我以为"
3. **单变量验证**:一次只改一个变量,验证假设
4. **修复后必须沉淀**:追加新案例到 `references/case-{name}.md`

---

## 反模式警示(铁律)

| ❌ 反模式 | ✅ 正确做法 |
|---------|----------|
| "我以为浏览器会保留 X 属性" | "实测这个浏览器对 X 属性的行为:[抓出来的数据]" |
| 连续 2 轮"凭代码推理"修复都 no-op,第 3 轮继续推理 | 第 3 轮**必须停下**,让用户输出真实数据 |
| 用 try-catch / 全局 polyfill 兜底掩盖未理解的行为 | 先理解黑盒实际行为,再决定该不该兜底 |
| 多个变量同时改尝试碰运气 | 单变量验证,有据可循 |
| 修好就完,案例只在脑里 | 追加 `references/case-{name}.md`,标题含系统名+症状 |
| 凭"主流编辑器/浏览器应该都支持 X" | 列出实测过的版本,未测试的标 unknown |

---

## 与其他 skill 的边界

| skill | 何时用 | 与本 skill 关系 |
|------|------|-------------|
| 通用系统化调试流程 | 通用 bug 调试 | 上游通用方法论;本 skill 在其之上加"先抓数据"硬规则 |
| `cc-api-design-safety` | 自己设计 API 时 | 主动设计;本 skill 是被动适配第三方 |

---

## 案例库

修复后追加新案例到 `references/`,**命名约定**:

| 前缀 | 用途 | 何时用 |
|------|------|------|
| `case-{system}-{symptom}.md` | **真实案例**:已发生过,含具体根因/修复/教训 | 踩过的坑沉淀 |
| `template-{system}-{symptom}.md` | **占位框架**:未来该类系统遇到 bug 时填入的模板 | 预留方向、采集模板预填 |

template- 文件踩坑填完后请改名为 `case-`,保持语义清晰。

**当前已有**:

- [CSDN paste 列表 bug](references/case-csdn-paste-list.md) — HTML→MD 丢 start 属性导致 4 个 "1." 和巨大间距
- [HTTP CDN/WAF 拦截](references/case-http-cdn-waf.md) — body 空 + headers 极简,GET 正常 POST 异常
- [代理关键词子串匹配误判](references/case-proxy-keyword-misjudge.md) — 正常长正文含 Cloudflare/502 等技术术语被代理误判为上游错误
- [浏览器粘贴行为差异(template)](references/template-browser-paste-format.md) — 待补充

---

## 规则溯源

```
> 📋 本回复遵循:`cc-external-system-debugging` - [章节]
```
