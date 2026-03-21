---
name: /status
id: status
category: 诊断
description: 显示当前 Cursor 配置加载状态（Rules / Skills / 可用命令）
---

显示当前 Cursor 配置的加载状态，帮助诊断配置问题。

## 输出格式

```
## 当前配置状态

### Rules（用户级 ~/.cursor/rules/）
- cc-defensive.mdc - 防御性规则（Always Apply）
- cc-ops-safety.mdc - 运维安全（Glob 匹配）
- cc-bash-style.mdc - Bash 规范（Glob 匹配）
- cc-doc-sync.mdc - 文档同步（Glob 匹配）
- cc-date-calc.mdc - 日期计算（Glob 匹配）
- cc-file-size-limit.mdc - 文件行数限制（Glob 匹配）

### Skills（用户级 ~/.cursor/skills/）
[列出已安装的 cc-* 技能]
- cc-go-dev — Go 开发规范
- cc-java-dev — Java 开发规范
- cc-frontend-dev — 前端开发规范
- cc-python-dev — Python 开发规范
- cc-bash-style — Bash 编写规范
- cc-ops-safety — 运维安全规范
- cc-redis-safety — Redis 安全规范
- cc-size-check — 代码简化与行数检查

### Commands（可用命令）
日常：/fix, /review, /review quick, /commit-msg
开发：/new-feature, /review security, /optimize
设计：/design, /design checklist, /requirement, /requirement interrogate
初始化：/project-init, /project-scan
诊断：/status
```

## 执行步骤

1. 列出 `~/.cursor/rules/` 下所有 `cc-*` 文件
2. 列出 `~/.cursor/skills/` 下所有 `cc-*` 目录
3. 检查项目级 `.cursor/rules/` 是否存在额外规则
4. 列出所有可用命令（来自 `cc-*` 命令技能）
5. 对比项目源 `.cursor/` 和用户级 `~/.cursor/`，提示是否需要重新同步
