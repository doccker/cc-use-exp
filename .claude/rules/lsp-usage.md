# LSP 使用规则

版本：v1.0
作者：wwj
更新：2025-12

> **部署位置**: `~/.claude/rules/lsp-usage.md`
> **生效范围**: 始终生效
> **前提条件**: Claude Code v2.0.67+

---

## 1. LSP 自动调用场景

当满足以下条件时，优先使用 LSP：

| 用户意图 | 触发关键词 | LSP 操作 |
|---------|-----------|----------|
| 查找定义 | "在哪定义"、"定义在哪"、"where is defined" | Go to Definition |
| 查找引用 | "在哪调用"、"谁调用了"、"哪里用到" | Find References |
| 查找实现 | "实现在哪"、"哪些类实现了" | Find Implementations |
| 类型信息 | "是什么类型"、"返回什么" | Hover |

---

## 2. LSP 优先级

```
LSP 可用且适合 → 使用 LSP
LSP 不可用     → 回退到 Grep/Read
LSP 结果不完整 → 补充使用 Grep/Read
```

---

## 3. LSP 调用声明

使用 LSP 时，在回复中声明：

```
> 🔍 LSP: `[服务器名]` - [操作类型]
```

示例：
- `> 🔍 LSP: `gopls` - Find References`
- `> 🔍 LSP: `typescript-language-server` - Go to Definition`
- `> 🔍 LSP: `pyright` - Hover`

---

## 4. 回退声明

LSP 不可用时，声明回退原因：

```
> 🔍 LSP 不可用（[原因]），使用 Grep 替代
```

示例：
- `> 🔍 LSP 不可用（gopls 未安装），使用 Grep 替代`
- `> 🔍 LSP 不可用（依赖未安装），使用 Grep 替代`

---

## 5. 不使用 LSP 的场景

以下场景直接使用 Grep/Read：

| 场景 | 原因 |
|------|------|
| 全文搜索关键词 | LSP 不支持模糊搜索 |
| 搜索注释/字符串 | LSP 只处理代码符号 |
| 理解整体架构 | 需要读取完整文件 |
| 查看文件结构 | 需要读取文件头部 |

---

## 6. 常用 LSP 服务器

| 语言 | 服务器 | 安装命令 |
|------|--------|----------|
| Go | gopls | `go install golang.org/x/tools/gopls@latest` |
| TypeScript | typescript-language-server | `npm install -g typescript-language-server` |
| Vue | @vue/language-server | `npm install -g @vue/language-server` |
| Python | pyright | `npm install -g pyright` |
| Java | jdtls | `brew install jdtls` (macOS) |

---

## 规则溯源要求

当使用 LSP 时，在回复末尾声明：

```
> 🔍 LSP: `[服务器名]` - [操作类型]
```
