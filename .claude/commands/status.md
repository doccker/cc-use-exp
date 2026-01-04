---
description: 显示当前加载的配置状态
---

显示当前 Claude Code 配置的加载状态，帮助诊断配置问题。

## 输出格式

```
## 当前配置状态

### Rules（始终生效）
- claude-code-defensive.md - 防御性规则
- ops-safety.md - 运维安全
- doc-sync.md - 文档同步
- bash-style.md - Bash 编写规范
- lsp-usage.md - LSP 使用规则

### Skills（按需加载）
[根据本次会话操作的文件类型列出]
- go-dev（已触发：操作了 .go 文件）
- 或：暂无触发

### LSP（语言服务器）
[检查各 LSP 服务器状态]
- gopls: ✅ 可用 / ❌ 未安装
- typescript-language-server: ✅ 可用 / ❌ 未安装
- pyright: ✅ 可用 / ❌ 未安装

### Commands（可用命令）
日常：/fix, /quick-review, /code-review, /debug
开发：/new-feature, /security-review
设计：/design-doc, /design-checklist, /requirement-doc
初始化：/project-init, /project-scan, /style-extract
诊断：/status
```

## 执行步骤

1. 列出 `~/.claude/rules/` 下所有 `.md` 文件
2. 检查本次会话是否触发了任何 Skill
3. 检查 LSP 服务器安装状态（gopls, typescript-language-server, pyright, jdtls）
4. 列出所有可用命令

## LSP 检查命令

```bash
# Go
which gopls

# TypeScript
which typescript-language-server

# Python
which pyright

# Java (macOS)
which jdtls
```
