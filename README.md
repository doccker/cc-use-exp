<div align="center">

# AI 编码助手配置中心

<!-- 封面图 -->
<img src="./cover.svg" alt="AI 编码助手配置中心" width="100%" style="max-width: 800px" />

> 保留你熟悉的 CLI/IDE，让 Claude Code、Gemini CLI、Codex 和 Cursor 开箱即用
>
> 按费力度从低到高，用最少操作获得最大帮助

[![version](https://img.shields.io/badge/version-1.0.20-blue.svg)](https://github.com/doccker/cc-use-exp)
[![license](https://img.shields.io/badge/license-PolyForm%20NC-green.svg)](./LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude_Code-Config-orange.svg)](https://docs.anthropic.com/claude-code)
[![Gemini CLI](https://img.shields.io/badge/Gemini_CLI-Config-purple.svg)](https://github.com/google-gemini/gemini-cli)
[![Codex](https://img.shields.io/badge/Codex-Config-black.svg)](https://developers.openai.com/codex/)
[![Cursor](https://img.shields.io/badge/Cursor-Config-blue.svg)](https://www.cursor.com/)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/doccker/cc-use-exp/pulls)
[![GitHub stars](https://img.shields.io/github/stars/doccker/cc-use-exp)](https://github.com/doccker/cc-use-exp/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/doccker/cc-use-exp)](https://github.com/doccker/cc-use-exp/network)
[![GitHub watchers](https://img.shields.io/github/watchers/doccker/cc-use-exp)](https://github.com/doccker/cc-use-exp/watchers)

</div>

---

## 解决什么问题

AI 编码助手（Claude Code、Gemini CLI、Codex、Cursor 等）正在改变开发方式，但实际使用中普遍存在以下痛点：

| 痛点 | 表现 |
|------|------|
| 每次重复交代 | AI 没有持久记忆，每个 session 都要重新说明技术栈、编码规范、项目结构 |
| 配置文件碎片化 | Claude 要 `CLAUDE.md`，Codex 要 `AGENTS.md`，Cursor 要 `.cursor/rules/`，Gemini 要 `GEMINI.md`，各自维护一份 |
| 规则写了但没用好 | 配置文件越写越长，token 消耗飙升，模型注意力被稀释，反而降低代码质量 |
| AI 常见翻车 | 修改测试来适配 bug、过度重构、生成 AI 模板风 UI、用保留字做 SQL 别名、忽略并发安全 |
| 缺乏防护机制 | 没有规则约束时，AI 会执行危险命令、删除文件、跳过测试、中途放弃任务 |

本项目提供一套经过实战验证的配置模板，一次配置，四个工具同时生效：

- 分层加载（rules 常驻 + skills 按需 + commands 显式调用），控制 token 消耗
- 内置防御性规则，防止 AI 常见翻车行为
- 开箱即用的开发命令（`/fix`、`/review`、`/optimize`、`/new-feature` 等）
- 同时覆盖 Claude Code、Gemini CLI、Codex、Cursor 四套配置，一键同步

---

<details>
<summary><strong>📑 目录导航</strong></summary>

- [解决什么问题](#解决什么问题)
- [项目定位](#项目定位)
- [快速部署](#快速部署)
- **Part 1: Claude Code**
  - [快速开始](#1-快速开始)
  - [常见场景速查](#2-常见场景速查)
  - [ToolSearch 支持](#3-toolsearch-支持)
  - [目录结构](#6-目录结构)
- **Part 2: Gemini CLI**
  - [快速开始](#1-快速开始-1)
  - [前端场景速查](#2-前端场景速查)
- **Part 3: Codex**
- **Part 4: Cursor**
  - [快速开始](#1-快速开始-2)
  - [Commands](#14-主动调用---commands)
  - [目录结构](#4-目录结构-1)
- [参考资料](#参考资料)
- [社区与支持](#社区与支持)
- [许可声明](#许可声明)

</details>

---

## 项目定位

### 使用架构

```
本项目                      用户目录                               其他项目
├── .claude/  ──覆盖──>    ~/.claude/  <──读取──                 .claude/ (空)
├── .gemini/  ──覆盖──>    ~/.gemini/  <──读取──                 .gemini/ (空)
├── .codex/   ──增量部署──> ~/.codex/ + ~/.agents/skills/ <──读取── .codex/ (空)
└── .cursor/  ──增量部署──> ~/.cursor/rules/ + ~/.cursor/skills/ <──读取── .cursor/ (空)
```

- **本项目**：配置开发/维护环境，不参与实际业务开发
- **用户目录**：实际生效的配置
- **其他项目**：配置目录为空，自动使用用户目录配置

### 四套配置的关系

| 目录 | 服务对象 | 说明 |
|------|---------|------|
| `.claude/` | Claude Code | Anthropic 的 CLI 工具 |
| `.gemini/` | Gemini CLI | Google 的 CLI 工具 |
| `.codex/` | Codex | OpenAI 的 CLI 工具，项目内维护权威源，部署时分发到 `~/.codex/` 和 `~/.agents/skills/` |
| `.cursor/` | Cursor | AI IDE，增量部署到 `~/.cursor/rules/` 和 `~/.cursor/skills/` |

**四者相互独立**：
- Claude Code 只读取 `~/.claude/`，不读取 `~/.gemini/`
- Gemini CLI 只读取 `~/.gemini/`，不读取 `~/.claude/`
- Codex 的全局入口是 `~/.codex/AGENTS.md`、`~/.codex/rules/` 和 `~/.agents/skills/`
- Cursor 读取 `~/.cursor/rules/`（用户级规则）和 `~/.cursor/skills/`（用户级技能）
- 配置内容可能相似（如禁止行为、技术栈偏好），但这不是重复，而是各自需要的独立配置

### 配置能力差异

| 特性 | Claude Code | Gemini CLI | Codex | Cursor |
|------|-------------|------------|-------|--------|
| 主配置文件 | `.claude/CLAUDE.md` | `.gemini/GEMINI.md` | `.codex/global/AGENTS.md` → `~/.codex/AGENTS.md` | 无（规则即配置） |
| 规则目录 | `.claude/rules/` ✅ | `.gemini/rules/` ✅（通过 @import） | `.codex/global/rules/` → `~/.codex/rules/` | `.cursor/rules/` ✅（.mdc 格式） |
| 技能目录 | `.claude/skills/` ✅ | `.gemini/skills/` ✅（v0.24.0+） | `.codex/skills/` → `~/.agents/skills/` | `.cursor/skills/` ✅ |
| 命令目录 | `.claude/commands/` (.md) | `.gemini/commands/` (.toml) | 无独立命令目录，使用显式 workflow skills | `.cursor/commands/` (.md) |
| 命令格式 | Markdown | TOML | `SKILL.md` + `agents/openai.yaml` | Markdown（部署为 SKILL.md） |

**规则同步方式**：
- Claude Code：规则拆分到 `rules/` 目录，按文件组织；技能放 `skills/` 按需加载
- Gemini CLI：核心规则在 `GEMINI.md`；详细规范通过 `skills/` 按需激活（v0.24.0+）
- Codex：全局仅保留极薄 `AGENTS.md` 和审批 `rules`；绝大多数通用规范放进 `skills`，通过渐进式披露按需加载
- Cursor：规则用 `.mdc` 格式支持 `alwaysApply` / `globs` / 智能匹配；技能通过 `description` 语义匹配按需加载

> 如需在多个工具间同步规则（如禁止行尾注释），需分别在 `.claude/rules/bash-style.md`、`.gemini/GEMINI.md`、`.cursor/rules/bash-style.mdc` 中维护。

---

## 支持的工具

| 工具 | 配置目录 | 部署位置 | 状态 |
|------|---------|---------|------|
| Claude Code | `.claude/` | `~/.claude/` | ✅ 完整支持 |
| Gemini CLI | `.gemini/` | `~/.gemini/` | ✅ 完整支持 |
| Codex | `.codex/` | `~/.codex/` + `~/.agents/skills/` | ✅ 完整支持（增量部署） |
| Cursor | `.cursor/` | `~/.cursor/rules/` + `~/.cursor/skills/` | ✅ 完整支持（增量部署） |

---

## 快速部署

### 一键同步（推荐）

**macOS/Linux**：
```bash
./tools/sync-config.sh
```

**Windows**：
```cmd
tools\sync-config.bat
```

脚本会自动同步四套配置：

- `.claude/` → `~/.claude/`
- `.gemini/` → `~/.gemini/`
- `.codex/global/AGENTS.md` → `~/.codex/AGENTS.md`（受管区块合并）
- `.codex/global/rules/` → `~/.codex/rules/`
- `.codex/skills/` → `~/.agents/skills/`
- `.codex/profiles/*.toml` → `~/.codex/config.toml`（受管区块合并）
- `.cursor/rules/` → `~/.cursor/rules/`（增量同步，manifest 管理）
- `.cursor/skills/` + `.cursor/commands/` → `~/.cursor/skills/`（增量同步，manifest 管理）

其中 Codex 采用**增量部署**：

- 不会整体覆盖 `~/.codex/`
- 不会动 `auth.json`、`history.jsonl`、日志、sqlite、cache 等运行态文件
- 只维护当前项目负责的 `AGENTS` 受管区块、`cc-*` rules 和 `cc-*` skills

各工具的部署特性：

- **Claude Code**：同步到 `~/.claude/`，并保留历史对话记录和个人配置
- **Gemini CLI**：同步到 `~/.gemini/`，并保留认证信息（如 `oauth_creds.json`）和运行时数据
- **Codex**：对 `~/.codex/AGENTS.md` 和 `~/.codex/config.toml` 使用受管区块合并；只管理 `~/.codex/rules/` 与 `~/.agents/skills/` 下当前项目同步出去的 `cc-*` 内容；不改用户已有默认模型、provider 或 `base_url`
- **Cursor**：增量同步到 `~/.cursor/rules/` 和 `~/.cursor/skills/`；通过 manifest 文件（`.cc-use-exp-managed`）追踪管理的文件；不动 MCP 配置、插件、设置等运行态文件

---

# Part 1: Claude Code 配置

---

## 1. 快速开始

### 1.1 零费力（自动生效）- Rules

**你需要做什么：什么都不用做**

这些规则始终自动加载，在后台默默保护你：

| 规则 | 作用 | 触发场景 |
|------|------|---------|
| `claude-code-defensive.md` | 防止测试篡改、过度工程化、中途放弃 | 始终生效 |
| `ops-safety.md` | 危险命令确认、回滚方案、风险提示 | 始终生效（详细规范见 skills） |
| `doc-sync.md` | 配置/结构变更时提醒更新文档 | 修改配置时 |
| `bash-style.md` | Bash 核心规范：禁止行尾注释 | 始终生效（详细规范见 skills） |
| `date-calc.md` | 日期加减保持日不变，禁止默认月末对齐 | 始终生效 |

**效果示例**：
- Claude 不会修改测试来适配错误代码
- 执行 `sysctl` 等危险命令前会提示风险和回滚方案
- 新增命令后会提醒你更新 README

### 1.2 低费力（自动触发）- Skills

**你需要做什么：正常写代码**

操作相关文件时自动加载对应的开发规范：

| 技能 | 触发条件 | 提供的帮助 |
|------|---------|-----------|
| `go-dev` | 操作 `.go` 文件 | 命名约定、错误处理、并发编程、测试规范 |
| `java-dev` | 操作 `.java` 文件 | 命名约定、异常处理、Spring 规范、不可变集合、线程池、代码模式 |
| `frontend-dev` | 操作 `.vue/.tsx/.css` 等 | UI 风格约束、Vue/React 规范、TypeScript |
| `python-dev` | 操作 `.py` 文件 | 类型注解、Pydantic、pytest、uv 工具链 |
| `bash-style` | 操作 `.sh/Dockerfile/Makefile/.md` 等 | 注释规范、tee 写入、heredoc、脚本规范 |
| `ops-safety` | 执行系统命令、服务器运维 | 风险说明、回滚方案、问题排查原则 |
| `redis-safety` | 操作 Redis 相关代码 | 禁用 KEYS、SCAN 替代、Pipeline、TTL 规范 |
| `size-check` | `/size-check` 或描述"简化代码" | 代码简化审查、全项目文件行数扫描 |

**效果示例**：
- 写 Go 代码时，自动遵循 Effective Go 规范
- 写 Vue 组件时，自动使用 Composition API + TypeScript
- 不操作这些文件时，不消耗额外 token

### 1.3 中费力（显式调用）- Commands

**你需要做什么：输入 `/命令名`**

#### 高频命令（日常使用）

| 命令 | 用途 | 使用示例 |
|------|------|---------|
| `/fix` | 快速修复 Bug | `/fix 登录接口返回 500` |
| `/fix debug` | 复杂问题排查（复现→假设→验证→修复） | `/fix debug 定时任务不执行` |
| `/review` | 正式代码审查 | `/review` |
| `/review quick` | 快速审查（git diff + 简要意见） | `/review quick` |
| `/commit-msg` | 生成 git commit message | `/commit-msg` 或 `/commit-msg all` |

#### 中频命令（按需使用）

| 命令 | 用途 | 使用示例 |
|------|------|---------|
| `/review security` | 安全审查当前分支代码 | `/review security` |
| `/optimize` | 系统优化（UX/性能/代码/安全/语法糖/最佳实践） | `/optimize` 或 `/optimize perf` |
| `/new-feature` | 新功能全流程（需求→设计→实现） | `/new-feature 用户导出功能` |
| `/design doc` | 生成技术设计文档框架 | `/design doc 用户权限模块` |
| `/requirement doc` | 生成需求文档框架 | `/requirement doc 报表功能` |

#### 低频命令（特定场景）

| 命令 | 用途 | 使用示例 |
|------|------|---------|
| `/requirement interrogate` | 需求极刑审问，挖掘逻辑漏洞 | `/requirement interrogate 用户要导出数据` |
| `/design checklist` | 生成设计质量检查清单 | `/design checklist` |
| `/project-init` | 为新项目初始化 Claude Code 配置 | `/project-init` |
| `/project-scan` | 扫描项目生成配置（CLAUDE.md/restart.sh/ignore/Docker） | `/project-scan` |
| `/style-extract` | 从代码或设计图提取样式变量 | `/style-extract` |
| `/ruanzhu` | 生成软著源代码 DOCX 文件 | `/ruanzhu "系统名称" 60` |
| `/check-toolsearch` | 检查 ToolSearch/WebSearch 是否可用 | `/check-toolsearch` |
| `/status` | 显示当前配置状态（Rules/Skills/LSP） | `/status` |

### 1.4 Claude Code 推荐插件（声明式安装）

本项目通过 `.claude/plugins.json` 声明了推荐的插件。

| 插件 | 用途 |
|------|------|
| `context7` | 精准第三方库文档查询 |
| `frontend-design` | 生成高质量前端界面代码 |
| `gopls-lsp` | Go 语言 LSP 支持 |
| `jdtls-lsp` | Java 语言 LSP 支持 |
| `playwright` | 浏览器自动化测试 |
| `pyright-lsp` | Python 语言 LSP 支持 |
| `security-guidance` | 代码安全审计指导 |
| `typescript-lsp` | TypeScript/JS LSP 支持 |
| `claude-hud` | 终端状态栏实时显示 context 用量 |
| `superpowers` | 结构化开发框架：TDD、调试、头脑风暴 |
| `code-review` | 多审查者代码审查 + 置信度评分 |

**推荐安装方式：**
运行 `./tools/sync-config.sh`，脚本会自动检测缺失的插件并引导你一键安装。

**手动安装：**
```bash
claude plugin install context7@claude-plugins-official
claude plugin install frontend-design@claude-plugins-official
# ... 其他插件同理
```

---

## 2. 常见场景速查

| 场景 | 推荐方式 | 费力度 |
|------|---------|--------|
| 日常写代码 | 直接写，Rules + Skills 自动生效 | ⭐ |
| 修个小 Bug | `/fix 问题描述` | ⭐⭐ |
| 提交前快速看看 | `/review quick` | ⭐⭐ |
| 生成 commit message | `/commit-msg` | ⭐⭐ |
| 正式代码审查 | `/review` | ⭐⭐ |
| 复杂 Bug 排查 | `/fix debug 问题描述` | ⭐⭐⭐ |
| 安全审查 | `/review security` | ⭐⭐⭐ |
| 系统优化评估 | `/optimize` | ⭐⭐⭐ |
| 开发新功能 | `/new-feature 功能名` | ⭐⭐⭐ |
| 新项目初始化 | `/project-init` | ⭐⭐⭐ |

```
遇到 Bug？
├─ 简单 Bug → /fix 问题描述
└─ 复杂 Bug → /fix debug 问题描述

代码审查？
├─ 快速看看 → /review quick
├─ 正式审查 → /review
└─ 安全审查 → /review security

新功能？
├─ 完整流程 → /new-feature 功能名
└─ 只要设计 → /design doc 模块名

系统优化？
├─ 全量评估 → /optimize
├─ 仅性能 → /optimize perf
├─ 仅代码质量 → /optimize code
└─ 仅 UX → /optimize ux
```

---

## 3. ToolSearch 支持

### 什么是 ToolSearch

ToolSearch 让 Claude Code 按需搜索工具定义，而不是把所有工具定义塞进上下文。好处：

- **大幅减少 token 占用** —— MCP 工具多的用户，tools 块动辄占据数万甚至数十万 tokens
- **模型表现更好** —— 上下文更干净，模型注意力不被大量工具定义稀释
- **对话轮次更多** —— 同样的上下文窗口可以增加数轮对话

### 谁需要关注

| 用户类型 | 是否需要操作 |
|---------|------------|
| 官方 API 直连 | 无需操作，自动支持 |
| 第三方中转地址 | 需要执行补丁脚本 |

### 使用方法

**1. 检查当前状态**

```bash
# 在 Claude Code 中执行
/check-toolsearch
```

**2. 如果不可用，执行补丁**

```bash
python tools/patch-toolsearch.py          # 交互式选择
python tools/patch-toolsearch.py --auto   # 自动补丁所有安装
python tools/patch-toolsearch.py --check  # 仅检查状态
python tools/patch-toolsearch.py --restore # 从备份恢复
```

**3. 重启 Claude Code 生效**

> **注意**：Claude Code 更新后补丁会被覆盖，需重新执行。脚本支持自动探测 bun/npm/pnpm/VS Code/Cursor 安装。

---

## 4. 最佳实践

### 4.1 让自动化为你工作

- **不要干预 Rules**：它们在后台保护你，比如防止 Claude 修改测试
- **不要手动加载 Skills**：操作相关文件时自动生效
- **相信防御机制**：复杂任务会自动要求确认计划后再执行

### 4.2 避免的做法

- ❌ 不要绕过 Rules 的保护机制
- ❌ 不要在简单任务上使用复杂命令
- ❌ 不要忽略文档同步提醒

### 4.3 上下文管理（省 token）

- 一个 session 一个任务，避免"顺便再帮我..."加速上下文膨胀
- 旁路问题用 `/btw`，问答不写入对话历史，不消耗上下文
- 长任务在 60-70% 时主动 `/compact`，compact 前先把关键决策记到任务文件
- 大文件用 Grep 定位 + Read 局部读取，避免整文件加载

---

## 5. 常见问题

### Q: 为什么 Claude 总是先说明计划再执行？

A: 这是 `claude-code-defensive.md` 规则的要求。复杂任务（超过 3 个步骤或涉及多个文件）必须先说明计划，等你确认后再执行。这是为了防止 Claude 盲目修改代码。

### Q: 为什么执行系统命令时 Claude 会问很多问题？

A: 这是 `ops-safety.md` 规则的要求。危险命令（如 sysctl、iptables）必须说明影响范围、风险等级和回滚方案。这是为了防止误操作导致系统故障。

### Q: 为什么 Claude 提醒我更新文档？

A: 这是 `doc-sync.md` 规则的要求。当你修改了配置（commands/skills/rules）或项目结构时，会提醒你同步更新相关文档，保持文档与代码一致。

### Q: 如何添加新的语言支持？

A: 在 `.claude/skills/` 下创建新目录（如 `rust-dev/`），添加 `SKILL.md` 文件定义触发条件和规范内容，然后更新本文档。

---

## 6. 目录结构

```
.claude/
├── CLAUDE.md                     # 核心配置：身份、偏好、技术栈
├── rules/                        # 规则：始终加载（精简版）
│   ├── claude-code-defensive.md  # 防御性规则
│   ├── ops-safety.md             # 运维安全（核心）
│   ├── doc-sync.md               # 文档同步
│   ├── bash-style.md             # Bash 核心规范
│   └── date-calc.md              # 日期计算规则
├── skills/                       # 技能：按需加载（完整版）
│   ├── go-dev/
│   ├── java-dev/
│   ├── frontend-dev/
│   ├── python-dev/
│   ├── bash-style/               # Bash 完整规范
│   ├── ops-safety/               # 运维安全完整规范
│   ├── redis-safety/             # Redis 安全与性能规范
│   ├── size-check/               # 代码简化 + 文件行数扫描
│   └── ruanzhu/                  # 软著源代码生成
├── commands/                     # 命令：显式调用
│   ├── fix.md                    # 快速修复 / 系统化调试
│   ├── review.md                 # 代码审查（full/quick/security）
│   ├── design.md                 # 技术设计（doc/checklist）
│   ├── requirement.md            # 需求分析（doc/interrogate）
│   ├── optimize.md               # 系统优化（full/ux/perf/code）
│   ├── check-toolsearch.md      # ToolSearch 可用性检查
│   ├── ruanzhu.md                # 软著源代码 DOCX 生成
│   ├── status.md
│   └── ...
└── templates/                    # 模板文件
    └── ruanzhu/                  # 软著生成脚本

tools/                            # 工具脚本（不同步到 ~/.claude/）
├── patch-toolsearch.py           # ToolSearch 域名限制解除补丁
├── sync-config.sh                # 配置同步脚本（macOS/Linux）
└── sync-config.bat               # 配置同步脚本（Windows）
```

### 核心概念

| 类型 | 加载时机 | 触发方式 | 适用场景 |
|------|---------|---------|---------|
| **Rules** | 始终加载 | 自动生效 | 核心约束、防御规则 |
| **Skills** | 按需加载 | 根据文件类型自动触发 | 语言规范、领域知识 |
| **Commands** | 调用时加载 | 用户输入 `/命令名` | 明确的工作流任务 |

### Rules 与 Skills 的关键区别

> **重要**：Rules 的 `paths` frontmatter 只是语义提示，**不影响加载**。

| 特性 | Rules | Skills |
|------|-------|--------|
| 加载时机 | 每次对话启动时**全部加载** | 启动时仅加载名称和描述 |
| 内容加载 | 完整内容立即加载 | 匹配时才加载完整内容 |
| `paths` 作用 | 条件应用（不节省 tokens） | N/A |
| Token 消耗 | 始终消耗 | 按需消耗 |

**最佳实践**：
- Rules 保持精简（核心禁止项），详细规范放 Skills
- 例如 `bash-style`：rules 放 37 行核心规则，skills 放 200+ 行完整规范

### 设计理念

1. **按需加载**：语言规范用 Skills，只在操作相关文件时加载，节省 tokens
2. **规则溯源**：每次回复声明依据的规则/技能，便于追踪和调整
3. **简洁优先**：CLAUDE.md 只放身份/偏好，具体约束放 rules

---

## 7. 开发指南

### LSP 服务器配置（v2.0.67+ 支持）

> **前提**：需安装 `@anthropic-ai/claude-code@2.0.67` 或更高版本。

#### 安装命令

```bash
# Go
go install golang.org/x/tools/gopls@latest

# TypeScript/JavaScript + Vue
npm install -g typescript typescript-language-server @vue/language-server

# Python
npm install -g pyright

# Java (macOS)
brew install jdtls
```

#### LSP 使用策略

LSP 的核心优势是"精准打击"——查找定义时只返回相关代码，而非整个文件，可节省大量 Token。

| 场景 | 建议 | 原因 |
|------|------|------|
| 查找定义/引用 | 优先用 LSP | 精准定位，节省 ~99% Token |
| 理解模块整体逻辑 | 读取完整文件 | 避免"管中窥豹"，获取完整上下文 |
| 大型项目导航 | LSP + 选择性读文件 | 混合策略最优 |

#### 注意事项

- **环境就绪**：使用前确保依赖已安装（`npm install` / `go mod download`）
- **避免过度依赖**：复杂逻辑需要读取完整文件上下文
- **LSP 失败时**：退回到读取文件的方式

### 修改现有配置

1. 在 `.claude/` 下修改对应文件
2. 在本项目目录启动 Claude Code 测试
3. 验证功能符合预期
4. 复制到 `~/.claude/` 正式使用

### 新增命令（Command）

1. 创建 `.claude/commands/<name>.md`
2. 编写 frontmatter（description）和内容
3. 测试 `/<name>` 命令
4. 更新本文档的命令列表

**命令模板**：

```markdown
---
description: 命令的简要描述
---

命令的详细说明和执行逻辑。

## 输入

「$ARGUMENTS」— 用户输入的参数

## 流程

### 第 1 步：...
### 第 2 步：...

## 输出格式

...
```

### 新增技能（Skill）

1. 创建 `.claude/skills/<name>/SKILL.md`
2. 编写 frontmatter（name、description）和内容
3. 可选：添加 `references/` 目录存放详细参考
4. 测试触发是否正确
5. 更新本文档的技能列表

**技能模板**：

```markdown
---
name: skill-name
description: 当用户操作 xxx 文件时触发。提供 xxx 开发规范。
---

# 技能名称

## 核心规范

...

## 详细参考

详细内容见 `references/` 目录。
```

### 测试验证

```bash
# 在本项目目录启动 Claude Code
cd /path/to/cc-use-exp
claude

# 测试命令
> /fix 测试问题

# 测试技能（操作相关文件类型）
> 帮我看看这个 Go 代码有什么问题

# 检查配置加载
> /memory
```

---

# Part 2: Gemini CLI 配置（前端设计）

> **定位**：Gemini CLI 专注于前端设计和开发，技术栈为 Vue 3 + TypeScript + Element Plus。

---

## 1. 快速开始

### 1.1 零费力（自动生效）- GEMINI.md

**你需要做什么：什么都不用做**

GEMINI.md 自动加载，提供以下保护：

| 规则 | 作用 |
|------|------|
| UI 风格约束 | 禁止霓虹渐变、玻璃拟态、赛博风 |
| 代码质量 | 完整实现，禁止 MVP/占位/TODO |
| 中文交流 | 统一使用中文回复和注释 |
| MCP 工具指南 | 规范工具调用，避免滥用 |

**效果示例**：
- Gemini 不会生成"AI 风格"的炫酷 UI
- 默认使用 Element Plus 主题，保持企业后台风格
- 自动使用 Composition API + TypeScript

### 1.2 低费力（自动触发）- Skills

**你需要做什么：正常写代码**

修改对应语言的文件或调整页面布局时，Gemini 会自动激活对应技能（共享 Claude Code 技能库）：

| 技能 | 触发条件 | 提供的帮助 |
|------|---------|-----------|
| `frontend-safety` | 修改 Vue/React 组件、调整布局、创建覆盖层 | 数据绑定保护、布局一致性、覆盖层定位规范 |
| `go-dev` | 操作 `.go` 文件 | 命名约定、错误处理、并发编程、测试规范 |
| `java-dev` | 操作 `.java` 文件 | 命名约定、异常处理、Spring 规范、Java 最佳实践 |
| `python-dev` | 操作 `.py` 文件 | 类型注解、Pydantic、pytest、uv 工具链 |
| `bash-style` | 操作 `.sh/Dockerfile/Makefile/.md` 等 | 注释规范、tee 写入、heredoc、脚本规范 |
| `ops-safety` | 执行系统命令、服务器运维 | 风险说明、回滚方案、问题排查原则 |

**效果示例**：
- 修改 Vue 组件时，自动保护数据绑定和事件不被意外修改
- 调整布局时，确保间距使用 4px 倍数、与其他页面一致
- 开发 Go 或 Java 代码时，Gemini CLI 同样能提供专业的编码规范支持

### 1.3 中费力（显式调用）- Commands

**你需要做什么：输入 `/命令名`**

| 命令 | 用途 | 使用示例 |
|------|------|---------|
| `/layout` | 重构页面布局 | `/layout src/views/Home.vue` |
| `/layout-check` | 检查页面布局一致性 | `/layout-check src/views/` |
| `/vue-split` | 拆分大型 Vue 文件 | `/vue-split src/views/Home.vue` |
| `/fix` | 快速修复前端 Bug | `/fix 按钮点击无响应` |
| `/review` | 审查前端代码 | `/review` |
| `/review quick` | 快速审查 | `/review quick` |
| `/commit-msg` | 生成 git commit message | `/commit-msg` 或 `/commit-msg all` |
| `/fix debug` | 复杂问题排查 | `/fix debug 表格数据不显示` |

### 1.4 Gemini CLI 推荐扩展（声明式安装）

本项目通过 `.gemini/extensions.json` 声明了推荐的扩展。

| 扩展 | 用途 | 安装地址 |
|------|------|---------|
| `context7` | 提供精准的第三方库文档查询和代码示例（Context7 增强） | [GitHub](https://github.com/upstash/context7) |
| `chrome-devtools-mcp` | 用于前端页面真机调试、Lighthouse 审计与性能监控 | [GitHub](https://github.com/ChromeDevTools/chrome-devtools-mcp) |

**推荐安装方式：**
运行 `./tools/sync-config.sh`，脚本会自动检测缺失的扩展并引导你一键安装。

**手动一键安装：**
```bash
gemini extensions install https://github.com/upstash/context7 && \
gemini extensions install https://github.com/ChromeDevTools/chrome-devtools-mcp
```

更多扩展请访问：[Gemini Extensions 商店](https://geminicli.com/extensions/)

---

## 2. 前端场景速查

| 场景 | 推荐方式 | 费力度 |
|------|---------|--------|
| 写 Vue 组件 | 直接写，规则自动生效 | ⭐ |
| 页面布局重构 | `/layout 文件路径` | ⭐⭐ |
| 布局一致性检查 | `/layout-check` | ⭐⭐ |
| Vue 文件过大 | `/vue-split 文件路径` | ⭐⭐ |
| 修复样式问题 | `/fix 问题描述` | ⭐⭐ |
| 组件代码审查 | `/review` | ⭐⭐ |
| 查 Vue/Element 文档 | 让 Gemini 调用 Context7 | ⭐ |
| 响应式适配 | 描述断点需求 | ⭐⭐ |
| 复杂交互调试 | `/fix debug 问题描述` | ⭐⭐⭐ |

```
布局问题？
├─ 简单调整 → /fix 问题描述
├─ 整体重构 → /layout 文件路径
└─ 一致性检查 → /layout-check

组件开发？
├─ 新组件 → 描述需求，让 Gemini 生成
└─ 改现有 → 先 /review，再修改

样式问题？
├─ 单个元素 → /fix 样式描述
└─ 整体风格 → 检查是否符合 Element Plus 规范
```

---

## 3. 最佳实践

### 3.1 UI 风格约束

**后台管理系统（默认风格）**

| 要素 | 要求 |
|------|------|
| 主题 | Element Plus 默认主题 |
| 配色 | 黑白灰为主 + 1 个主色点缀 |
| 布局 | 标准后台布局（侧边栏 + 顶栏 + 内容区） |
| 动效 | 克制，仅保留必要交互反馈 |

**严格禁止**：
- ❌ 蓝紫色霓虹渐变、发光描边
- ❌ 玻璃拟态（glassmorphism）
- ❌ 赛博风、暗黑科技风
- ❌ 大面积渐变、装饰性几何图形
- ❌ UI 文案中使用 emoji

### 3.2 Vue 组件规范

```vue
<!-- ✅ 推荐写法 -->
<script setup lang="ts">
import { ref, computed } from 'vue'
import type { User } from '@/types'

const props = defineProps<{
  userId: number
}>()

const loading = ref(false)
const user = ref<User | null>(null)
</script>

<template>
  <div class="user-card">
    <!-- 内容 -->
  </div>
</template>

<style scoped>
.user-card {
  padding: 16px;
}
</style>
```

### 3.3 MCP 工具使用

| 工具 | 使用场景 | 技巧 |
|------|---------|------|
| Context7 | 查 Vue/Element Plus 文档 | 先 `resolve-library-id`，再查文档 |
| Desktop Commander | 批量修改组件文件 | 设置路径范围，避免全仓扫描 |
| Sequential-Thinking | 复杂页面设计 | 规划前必用 |

**Context7 查询示例**：
```
帮我查一下 Element Plus 的 Table 组件如何实现可编辑单元格
```

### 3.4 避免的做法

- ❌ 不要让 Gemini 自由发挥 UI 设计
- ❌ 不要忽略 Element Plus 现有组件
- ❌ 不要在简单问题上用复杂命令
- ❌ 不要跳过代码审查直接提交

---

## 4. 常见问题

### Q: Gemini 生成的 UI 太花哨怎么办？

A: GEMINI.md 中已有 UI 风格约束。如果还是生成花哨样式，可以明确说：
```
请使用 Element Plus 默认主题，保持简洁的后台管理风格，不要使用渐变和装饰性元素
```

### Q: 如何让 Gemini 查最新的 Vue 文档？

A: Gemini 会自动调用 Context7 查询文档。你也可以直接说：
```
帮我查一下 Vue 3 的 defineModel 怎么用
```

### Q: /layout 命令支持什么输入？

A: 支持以下输入方式：
- 文件路径：`/layout src/views/Home.vue`
- URL：`/layout https://example.com`
- 描述需求：`/layout 把这个页面改成左右两栏布局`

### Q: 组件太复杂，Gemini 生成不完整怎么办？

A: 分步骤处理：
1. 先让 Gemini 生成组件框架
2. 逐个功能点完善
3. 最后 `/review` 检查

---

## 5. 目录结构

```
.gemini/
├── .env.example        # 网络代理配置模板（需重命名为 .env）
├── GEMINI.md           # 核心规则（通过 @import 引入 rules）
├── settings.json       # 用户设置
├── policies/           # 安全策略（允许 git 等命令执行）
│   ├── git-rules.toml
│   └── help-rules.toml
├── rules/              # 规则：通过 @import 始终加载
│   ├── defensive.md        # 防御性编码规范
│   ├── doc-sync.md         # 文档同步规范
│   ├── ops-safety.md       # 运维安全规范
│   ├── file-size-limit.md  # 文件行数限制
│   └── frontend-style.md   # 前端规范补充
├── skills/             # 技能：按需激活（v0.24.0+）
│   ├── bash-style/
│   ├── frontend-safety/
│   ├── go-dev/
│   ├── java-dev/
│   ├── ops-safety/
│   └── python-dev/
└── commands/           # 自定义命令（.toml 格式）
    ├── layout.toml         # 布局重构
    ├── layout-check.toml   # 布局一致性检查
    ├── vue-split.toml      # Vue 文件拆分
    ├── fix.toml            # 快速修复
    ├── debug.toml          # 系统化调试
    ├── code-review.toml    # 正式审查
    ├── quick-review.toml   # 快速审查
    └── commit-msg.toml     # 生成 commit message
```

---

## 6. 配置层级

Gemini CLI 支持层级配置，优先级从低到高：

1. 系统默认 → `/etc/gemini-cli/`
2. **用户全局** → `~/.gemini/`
3. **项目级** → `<project>/.gemini/`
4. 环境变量
5. 命令行参数

GEMINI.md 同样支持层级：
- 全局：`~/.gemini/GEMINI.md`
- 项目：`<project>/GEMINI.md`
- 子目录：`<subdir>/GEMINI.md`

---

## 7. 认证配置

Gemini CLI 需要认证才能使用，支持两种认证方式。

### 认证方式对比

| 方式 | 适用场景 | 优点 | 缺点 |
|------|---------|------|------|
| **OAuth 登录** | edu 账号、企业账号 | 配额更高、无需管理密钥 | 首次需浏览器认证 |
| **API Key** | 个人账号、自动化场景 | 配置简单、无需浏览器 | 免费配额有限 |

> **建议**：edu 账号或企业账号优先使用 OAuth 登录，可获得更高的使用配额。

### 方式 A：OAuth 登录（推荐 edu/企业账号）

首次启动时会自动跳转浏览器认证：

```bash
gemini
# 浏览器会打开 Google 登录页面
# 登录后授权即可，之后会自动保存凭证
```

认证信息保存在 `~/.gemini/` 目录下，后续启动无需重复认证。

### 方式 B：API Key（推荐个人账号）

#### 获取 API Key

1. 访问 [Google AI Studio](https://aistudio.google.com/app/apikey)
2. 登录 Google 账号
3. 点击 "Create API Key" 创建密钥
4. 复制生成的密钥

#### 配置 API Key

```bash
# 将密钥写入 ~/.gemini/.env（推荐）
echo 'GEMINI_API_KEY="你的API密钥"' >> ~/.gemini/.env
```

或者添加到 shell 配置文件：

```bash
# ~/.zshrc 或 ~/.bashrc
export GEMINI_API_KEY="你的API密钥"

# 重新加载配置
source ~/.zshrc
```

### 验证认证

```bash
gemini
# 如果不再跳转浏览器认证，说明配置成功
```

> **注意**：API Key 是敏感信息，请勿提交到代码仓库或分享给他人。

### 7.3 网络与代理配置（国内用户必看）

如果在使用过程中遇到 `gemini-3.1-pro-preview` 等大模型连接超时，或 npx 安装/执行 MCP 扩展极度卡顿，这通常是网络原因导致。

本项目提供了一份防污染的代理配置模板 `.gemini/.env.example`。

**使用方法**：
1. 复制模板并重命名为 `.env`：
   ```bash
   cp .gemini/.env.example .gemini/.env
   ```
2. 修改 `.env` 文件，填入你本地科学上网客户端（如 Clash Verge）的代理端口：
   ```env
   HTTP_PROXY=http://127.0.0.1:你的端口
   HTTPS_PROXY=http://127.0.0.1:你的端口
   # 默认已配置 NO_PROXY 排除 localhost 和 .npmmirror.com 以实现直连加速
   NO_PROXY=localhost,127.0.0.1,.npmmirror.com
   ```
*(注：`.gemini/.env` 已被加入 `.gitignore`，不会泄露你的个人网络环境)*

---

# Part 3: Codex 配置

> **定位**：Codex 采用“极薄全局 AGENTS + 审批 rules + 渐进式 skills”的通用方案。项目内 `.codex/` 是权威源，用户级是部署产物。

## 1. 快速开始

首次使用或更新 `.codex/` 后，在项目根目录执行：

- **macOS/Linux**: `./tools/sync-config.sh`
- **Windows**: `tools\sync-config.bat`

脚本会把 `.codex/` 分发到 Codex 官方支持的用户级入口：

| 类型 | 用户级落点 | 作用 |
|------|-----------|------|
| Global AGENTS | `~/.codex/AGENTS.md` | 极薄全局原则，常驻加载 |
| Rules | `~/.codex/rules/` | 审批与危险命令控制 |
| Skills | `~/.agents/skills/` | 渐进式披露，按需加载 |

**为什么不是直接复制到 `~/.codex/`？**

因为 `~/.codex/` 同时还是 Codex 的运行态目录，会包含认证、历史、日志和缓存。项目只同步受管配置，不覆盖运行态文件。

### 1.1 零费力（自动生效）- Global AGENTS + Rules

**你需要做什么：同步一次配置，然后正常使用 Codex**

这些内容在 Codex 启动后自动生效：

| 组件 | 用户级位置 | 作用 |
|------|-----------|------|
| Global AGENTS | `~/.codex/AGENTS.md` | 极薄全局原则：先读代码、最小改动、验证、分层 |
| Rules | `~/.codex/rules/*.rules` | 审批、危险命令控制、默认安全边界 |
| Profiles | `~/.codex/config.toml` | 提供 `cc-fast-api`、`cc-balanced`、`cc-deep` 三种预设模式 |

**效果示例**：
- Codex 会优先先读代码、配置和脚本，再下结论
- 遇到危险命令或越权执行时，会进入审批控制
- 可以按任务复杂度切换 `codex -p cc-balanced` 或 `codex -p cc-deep`

### 1.2 低费力（自动触发）- Implicit Skills

**你需要做什么：正常描述任务，或直接操作相关语言文件**

这些技能允许隐式触发，适合日常编码和环境敏感场景：

| 技能 | 触发条件 | 提供的帮助 |
|------|---------|-----------|
| `cc-core-defensive` | 普通编码任务 | 最小改动、边界控制、定向验证 |
| `cc-go-dev` | Go 场景 | 错误处理、包结构、并发、测试 |
| `cc-java-dev` | Java / Spring 场景 | 异常、集合、服务分层、测试 |
| `cc-frontend-dev` | React / Vue / TS / CSS 场景 | UI 规范、组件边界、样式、前端测试 |
| `cc-python-dev` | Python 场景 | 类型注解、Pydantic、pytest、uv |
| `cc-bash-style` | Shell / Dockerfile / Makefile / 命令片段 | 注释、heredoc、tee、脚本规范 |
| `cc-ops-safety` | 系统命令、容器、部署、数据库操作 | 风险说明、回滚方案、影响面控制 |

**效果示例**：
- 写 Go、Java、Python 或前端代码时，会自动带上对应语言规范
- 修改脚本或命令片段时，会补充 Bash 风格约束
- 涉及部署、数据库、服务操作时，会优先考虑安全和回滚

### 1.3 中费力（显式调用）- Workflow Skills

**你需要做什么：在 Codex 对话里输入 `$skill-name`**

Codex 的显式 workflow skill 不走 Claude Code 的 `/命令` 风格。本项目统一按 Codex Skills 的显式调用方式使用，例如：`$commit-msg`、`$optimize perf`、`$new-feature 用户导出功能`。其中 `review` 和 `status` 为避免与 Codex 内置能力混淆，保留 `cc-` 前缀：`$cc-review`、`$cc-status`。

如果刚同步完 skills 但没看到新入口，重启 Codex 即可。

#### 高频 skill（日常使用）

| 场景 | Claude Code | Codex |
|------|-------------|-------|
| 修个小 Bug | `/fix 登录接口返回 500` | `$fix 登录接口返回 500` |
| 快速代码审查 | `/review quick` | `$cc-review quick` |
| 正式代码审查 | `/review` | `$cc-review` |
| 生成 commit message | `/commit-msg` 或 `/commit-msg all` | `$commit-msg` 或 `$commit-msg all` |

#### 中频 skill（按需使用）

| 场景 | Claude Code | Codex |
|------|-------------|-------|
| 安全审查 | `/review security` | `$cc-review security` |
| 系统优化 | `/optimize` 或 `/optimize perf` | `$optimize` 或 `$optimize perf` |
| 新功能全流程 | `/new-feature 用户导出功能` | `$new-feature 用户导出功能` |
| 技术设计 | `/design doc 用户权限模块` | `$design doc 用户权限模块` |
| 需求澄清 | `/requirement interrogate 用户要导出数据` | `$requirement interrogate 用户要导出数据` |
| 代码体量/复杂度扫描 | `/size-check` | `$size-check` |

#### 低频 skill（特定场景）

| 场景 | Claude Code | Codex |
|------|-------------|-------|
| 新项目初始化 | `/project-init` | `$project-init` |
| 检查配置状态 | `/status` | `$cc-status` |

## 2. 常见场景速查

| 场景 | 推荐方式 | 费力度 |
|------|---------|--------|
| 日常写代码 | 直接描述任务，Global AGENTS + Rules + Implicit Skills 自动生效 | ⭐ |
| 修个小 Bug | `$fix 问题描述` | ⭐⭐ |
| 提交前快速看看 | `$cc-review quick` | ⭐⭐ |
| 生成 commit message | `$commit-msg` | ⭐⭐ |
| 正式代码审查 | `$cc-review` | ⭐⭐ |
| 安全审查 | `$cc-review security` | ⭐⭐⭐ |
| 系统优化评估 | `$optimize` | ⭐⭐⭐ |
| 开发新功能 | `$new-feature 功能名` | ⭐⭐⭐ |
| 新项目初始化 | `$project-init` | ⭐⭐⭐ |
| 检查 Codex 配置是否生效 | `$cc-status` | ⭐⭐ |

```text
遇到 Bug？
├─ 简单 Bug → $fix 问题描述
└─ 复杂问题排查 → $fix debug 问题描述

代码审查？
├─ 快速看看 → $cc-review quick
├─ 正式审查 → $cc-review
└─ 安全审查 → $cc-review security

新功能？
├─ 完整流程 → $new-feature 功能名
└─ 只要设计 → $design doc 模块名

系统优化？
├─ 全量评估 → $optimize
├─ 仅性能 → $optimize perf
├─ 仅代码质量 → $optimize code
└─ 仅 UX → $optimize ux

配置是否生效？
└─ 查看状态 → $cc-status
```

## 3. 渐进式披露设计

Codex 配置按三层拆分：

| 层级 | 位置 | 说明 |
|------|------|------|
| 常驻最小层 | `.codex/global/AGENTS.md` | 只保留跨项目都成立的总纲 |
| 审批控制层 | `.codex/global/rules/` | 只放允许/提示/禁止执行的命令规则 |
| 主规范层 | `.codex/skills/` | 绝大多数规范通过 skills 按需加载 |
| 模式切换层 | `.codex/profiles/*.toml` | 以具名 profile 提供 fast / balanced / deep 模式，不改用户默认值 |

skills 又分为两类：

- **隐式技能**：如 `cc-core-defensive`、`cc-go-dev`、`cc-frontend-dev`，普通编码场景可自动命中
- **显式 workflow skills**：目录仍保留 `cc-*` 前缀，但显式调用名尽量使用短名，如 `fix`、`design`、`requirement`、`size-check`、`commit-msg`、`optimize`、`new-feature`、`project-init`；`review` 和 `status` 暂保留 `cc-*` 以避免与 Codex 内置命令混淆

新增的显式 workflow skills 主要覆盖：

| Skill | 用途 |
|------|------|
| `commit-msg` | 分析 staged 或 all diff，生成结构化 commit message |
| `optimize` | 做 `full/ux/perf/code` 四种模式的优化扫描，默认只输出报告 |
| `cc-status` | 检查项目权威源、用户级配置、profiles 和同步缺口 |
| `new-feature` | 需求澄清 → 设计 → 实现 → 验证，任务状态持久化到项目内 `.codex/tasks/` |
| `project-init` | 初始化新仓库：生成项目级 `AGENTS.md`，并按需落脚手架模板 |

> 说明：Codex 相关脚手架模板不再集中放在根 `.codex/templates/`；`project-init` 需要的 `AGENTS.md`、Docker、compose、restart 等资源跟随 skill 放在 `cc-project-init/assets/`，这样同步后即可直接使用。

### Profile 模式

项目内还维护了 3 个 Codex profile：

| Profile | 用途 | 建议配置 |
|---------|------|---------|
| `cc-fast-api` | API key 环境下的快模式 | `codex-mini-latest` |
| `cc-balanced` | 日常主力 | `gpt-5.3-codex` + `medium` |
| `cc-deep` | 复杂审查、深度分析 | `gpt-5.4` + `xhigh` |

使用方式：

```bash
codex -p cc-fast-api
codex exec -p cc-balanced "review this change"
codex -p cc-deep
```

> 说明：这里的 `cc-fast-api` 是**项目自定义的快 profile**，适合 API key 场景；它不是把用户默认配置切到官方 Fast mode credits。这样可以在不动顶层默认配置的前提下，按需切换速度与深度。

## 4. 目录结构

```text
.codex/
├── global/
│   ├── AGENTS.md
│   └── rules/
│       ├── cc-safe-default.rules
│       └── cc-dangerous-ops.rules
├── profiles/
│   ├── cc-fast-api.toml
│   ├── cc-balanced.toml
│   └── cc-deep.toml
├── skills/
│   ├── cc-core-defensive/
│   ├── cc-bash-style/
│   ├── cc-ops-safety/
│   ├── cc-go-dev/
│   ├── cc-java-dev/
│   ├── cc-frontend-dev/
│   ├── cc-python-dev/
│   ├── cc-fix/
│   ├── cc-review/
│   ├── cc-design/
│   ├── cc-requirement/
│   ├── cc-size-check/
│   ├── cc-commit-msg/
│   ├── cc-optimize/
│   ├── cc-status/
│   ├── cc-new-feature/
│   └── cc-project-init/
├── templates/
├── tasks/
└── manifests/
    └── sync-map.md
```

### 关键原则

- `.codex/` 是项目级权威源
- `~/.codex/` 和 `~/.agents/skills/` 是部署产物
- `~/.codex/config.toml` 只增量合并本项目的具名 profiles，不覆盖用户当前默认值
- `AGENTS.md` 必须薄，语言与流程细节交给 skills
- rules 只负责审批和危险动作控制，不承载编码规范

---

# Part 4: Cursor 配置

> **定位**：Cursor 采用"rules 常驻/条件加载 + skills 按需语义匹配"的方案。增量部署到 `~/.cursor/rules/` 和 `~/.cursor/skills/`。

---

## 1. 快速开始

首次使用或更新 `.cursor/` 后，在项目根目录执行：

- **macOS/Linux**: `./tools/sync-config.sh`
- **Windows**: `tools\sync-config.bat`

脚本会把 `.cursor/` 分发到 Cursor 的用户级目录：

| 类型 | 用户级落点 | 作用 |
|------|-----------|------|
| Rules | `~/.cursor/rules/` | 常驻或条件加载的规则 |
| Skills | `~/.cursor/skills/` | 按需语义匹配的技能 |
| Commands | `~/.cursor/skills/` | `/命令` 式技能（通过 Skills 机制实现） |
| Templates | `~/.cursor/templates/` | 命令依赖的模板文件 |

### 1.1 零费力（自动生效）- Rules

**你需要做什么：同步一次配置，然后正常使用 Cursor**

这些规则在 Cursor 中自动生效：

| 规则 | 类型 | 作用 |
|------|------|------|
| `defensive.mdc` | Always Apply | 防止测试篡改、过度工程化、中途放弃 |
| `ops-safety.mdc` | Glob 匹配 | 操作 .sh/Dockerfile 时触发运维安全规则 |
| `bash-style.mdc` | Glob 匹配 | 操作 .sh/Dockerfile/Makefile 时触发 Bash 规范 |
| `doc-sync.mdc` | Glob 匹配 | 修改配置文件时提醒更新文档 |
| `date-calc.mdc` | Glob 匹配 | 操作代码文件时触发日期计算规则 |
| `file-size-limit.mdc` | Glob 匹配 | 操作代码文件时触发行数限制规则 |

**Cursor 规则类型说明**：

| 类型 | frontmatter | 行为 |
|------|-------------|------|
| Always Apply | `alwaysApply: true` | 每次会话都加载 |
| Glob 匹配 | `globs: "**/*.go"` | 匹配文件时加载 |
| 智能匹配 | `description` 必填 | Agent 根据描述决定是否应用 |
| 手动引用 | 无特殊标记 | 仅在 @ 提及规则时应用 |

### 1.2 低费力（自动触发）- Skills

**你需要做什么：正常写代码**

Cursor Agent 会根据技能的 `description` 语义匹配，自动加载对应技能：

| 技能 | 触发条件 | 提供的帮助 |
|------|---------|-----------|
| `go-dev` | 操作 `.go` 文件 | 命名约定、错误处理、并发编程、测试规范 |
| `java-dev` | 操作 `.java` 文件 | 命名约定、异常处理、Spring 规范、并发安全 |
| `frontend-dev` | 操作 `.vue/.tsx/.css` 等 | UI 风格约束、Vue/React 规范、TypeScript |
| `python-dev` | 操作 `.py` 文件 | 类型注解、pytest、异步编程 |
| `bash-style` | 操作 `.sh/Dockerfile/Makefile` 等 | 注释规范、tee 写入、heredoc |
| `ops-safety` | 执行系统命令、服务器运维 | 风险说明、回滚方案 |
| `redis-safety` | 操作 Redis 相关代码 | 禁用 KEYS、SCAN 替代、Pipeline |
| `size-check` | 描述"简化代码"、"检查文件大小" | 代码简化审查、文件行数扫描 |
| `ruanzhu` | 执行 `/ruanzhu` 或描述"软著" | 软著源代码 DOCX 生成规范 |
| `ui-ux-pro-max` | 描述"设计感"、"专业UI" | 配色、排版、动效、响应式、无障碍 |

### 1.3 Cursor 与其他工具的差异

| 特性 | Claude Code / Gemini | Codex | Cursor |
|------|---------------------|-------|--------|
| 规则格式 | Markdown + `paths` | `.rules` 审批文件 | `.mdc`（Markdown Config） |
| 技能触发 | `paths` 文件匹配 | 隐式/显式 | `description` 语义匹配 |
| 命令系统 | `/command` 或 `$skill` | `$skill-name` | `/command`（通过 Skills 实现） |
| 部署方式 | 覆盖式 / 增量 | 受管区块合并 + 增量 | 增量（manifest 管理） |

### 1.4 主动调用 - Commands

**你需要做什么：在 Cursor 对话中输入 `/命令名`**

命令通过 Skills 机制实现，以 `/` 前缀触发：

| 命令 | 分类 | 说明 |
|------|------|------|
| `/fix [问题]` | 日常 | 快速修复或系统化调试（`/fix debug`） |
| `/review` | 日常 | 代码审查（`/review quick`、`/review security`） |
| `/commit-msg` | 日常 | 分析变更生成结构化 commit message |
| `/new-feature [功能]` | 开发 | 新功能全流程（审问 → 设计 → 实现），支持中断恢复 |
| `/design [功能]` | 开发 | 技术设计文档（`/design checklist` 质量检查） |
| `/requirement [功能]` | 开发 | 需求文档（`/requirement interrogate` 极刑审问） |
| `/optimize` | 开发 | 系统优化扫描（`/optimize ux/perf/code`） |
| `/style-extract` | 开发 | 从代码或设计图提取样式变量 |
| `/project-init` | 初始化 | 为新项目生成 Cursor 配置脚手架 |
| `/project-scan` | 初始化 | 扫描项目生成全套配置 |
| `/ruanzhu` | 工具 | 软著源代码 DOCX 生成 |
| `/status` | 诊断 | 显示当前配置加载状态 |

---

## 2. 常见场景速查

| 场景 | 推荐方式 | 费力度 |
|------|---------|--------|
| 日常写代码 | 直接写，Rules + Skills 自动生效 | ⭐ |
| 修个小 Bug | `/fix 问题描述` | ⭐ |
| 正式代码审查 | `/review` 或 `/review quick` | ⭐⭐ |
| 写 Go 代码 | 直接写，go-dev 自动加载 | ⭐ |
| 写 Vue 组件 | 直接写，frontend-dev 自动加载 | ⭐ |
| 生成 commit | `/commit-msg` | ⭐ |
| 新功能开发 | `/new-feature 功能描述` | ⭐⭐ |
| 系统优化 | `/optimize` 或 `/optimize perf` | ⭐⭐ |
| 执行系统命令 | 描述操作，ops-safety 自动触发 | ⭐⭐ |
| 代码瘦身 | 描述"简化代码"或"检查文件大小" | ⭐⭐ |

---

## 3. 最佳实践

### 3.1 规则分层

- **Always Apply**（`defensive`）：核心防御规则，每次对话都加载
- **Glob 匹配**：按文件类型触发，不操作相关文件时不消耗 token
- **Skills**：更详细的规范，由 Agent 根据语义按需加载
- **Commands**：显式 `/命令` 调用，按需触发工作流

### 3.2 与其他工具共用

本项目的 Cursor 配置与 Claude Code、Gemini CLI、Codex 各自独立。规则内容语义一致，但格式适配各工具的原生机制。

### 3.3 避免的做法

- ❌ 不要手动修改 `~/.cursor/rules/` 和 `~/.cursor/skills/` 中由本项目同步的文件（会被同步覆盖，以 manifest 文件 `.cc-use-exp-managed` 追踪）
- ❌ 不要把其他规则设为 Always Apply（除 `defensive` 外，其他规则按需加载更省 token）
- ✅ 添加个人规则/技能时，避免与本项目文件同名

---

## 4. 目录结构

```
.cursor/
├── rules/                       # 规则：.mdc 格式
│   ├── defensive.mdc            # 防御性规则（Always Apply）
│   ├── ops-safety.mdc           # 运维安全（Glob 匹配）
│   ├── bash-style.mdc           # Bash 核心规范（Glob 匹配）
│   ├── doc-sync.mdc             # 文档同步（Glob 匹配）
│   ├── date-calc.mdc            # 日期计算（Glob 匹配）
│   └── file-size-limit.mdc      # 文件行数限制（Glob 匹配）
├── skills/                      # 技能：SKILL.md 格式（自动语义匹配）
│   ├── go-dev/
│   ├── java-dev/
│   ├── frontend-dev/
│   ├── python-dev/
│   ├── bash-style/
│   ├── ops-safety/
│   ├── redis-safety/
│   ├── size-check/
│   ├── ruanzhu/
│   └── ui-ux-pro-max/
├── commands/                    # 命令：单 .md 文件（/命令 触发）
│   ├── fix.md                   # /fix
│   ├── review.md                # /review
│   ├── commit-msg.md            # /commit-msg
│   ├── new-feature.md           # /new-feature
│   ├── design.md                # /design
│   ├── requirement.md           # /requirement
│   ├── optimize.md              # /optimize
│   ├── style-extract.md         # /style-extract
│   ├── project-init.md          # /project-init
│   ├── project-scan.md          # /project-scan
│   ├── ruanzhu.md               # /ruanzhu
│   └── status.md                # /status
└── templates/                   # 模板文件
    └── ruanzhu/                 # 软著生成脚本
```

### 部署映射

| 项目内 | 部署目标 | 方式 |
|--------|---------|------|
| `.cursor/rules/*.mdc` | `~/.cursor/rules/` | 增量复制，manifest 管理 |
| `.cursor/skills/*` | `~/.cursor/skills/` | 增量复制，manifest 管理 |
| `.cursor/commands/*.md` | `~/.cursor/skills/{name}/SKILL.md` | 单文件 → 目录，manifest 管理 |
| `.cursor/templates/*` | `~/.cursor/templates/` | 增量复制 |

---

## 参考资料

### Claude Code

- [Claude Code 官方文档](https://docs.anthropic.com/claude-code)

### Gemini CLI

- [Gemini CLI 官方文档](https://geminicli.com/docs/)
- [Gemini CLI GitHub](https://github.com/google-gemini/gemini-cli)
- [Gemini CLI 认证指南](https://geminicli.com/docs/get-started/authentication/)
- [Vue 3 官方文档](https://vuejs.org/)
- [Element Plus 文档](https://element-plus.org/)

### Codex

- [OpenAI Codex 文档](https://developers.openai.com/codex/)
- [Codex 配置基础](https://developers.openai.com/codex/config-basic)
- [Codex Skills](https://developers.openai.com/codex/skills)
- [Codex AGENTS.md 指南](https://developers.openai.com/codex/guides/agents-md)
- [Codex Rules](https://developers.openai.com/codex/rules)

### Cursor

- [Cursor 官方文档](https://docs.cursor.com/)
- [Cursor Rules 配置](https://docs.cursor.com/context/rules)
- [Cursor Agent Skills](https://docs.cursor.com/agent/skills)

---

## 社区与支持

### GitHub

- [Issues](https://github.com/doccker/cc-use-exp/issues) - 报告问题
- [Pull Requests](https://github.com/doccker/cc-use-exp/pulls) - 贡献代码

### 联系作者

<img src="./wx-hao.png" alt="微信 wechat" width="400" />

---

## 许可声明

本项目采用 `PolyForm Noncommercial 1.0.0`：

| 用途 | 条款 |
|------|------|
| **非商业用途** | 可使用、修改、分发本项目 |
| **商业用途** | 不在本许可证授权范围内，需单独获得商业授权 |
| **转载/二次开发** | 需附带许可证文本或其 URL，并保留项目提供的 `NOTICE` |

这是一份 `source-available` 非商用许可证，不属于 OSI 定义下的开源许可证。

商业授权咨询：`作者`

详见 [LICENSE](./LICENSE)
  
项目附带的 [NOTICE](./NOTICE) 用于保留版权与出处信息。

### 许可 FAQ

| 场景 | 当前建议 |
|------|---------|
| 个人学习、研究、实验、业余项目 | 通常属于非商业用途，可在本许可证下使用 |
| 学校、公益组织、公共研究机构使用 | 通常属于非商业用途，可在本许可证下使用 |
| 公司内部评估、内部工具、团队日常使用 | 建议按商业用途处理，先联系作者获取商业授权 |
| 面向客户交付、代开发、SaaS 托管、付费咨询或付费培训 | 建议按商业用途处理，先联系作者获取商业授权 |
| 二次开发后公开发布 | 可以，但需附带许可证文本或其 URL，并保留 `NOTICE` |
| 拿不准是否属于商业用途 | 不要自行假设，先联系 `作者` 确认 |

> 说明：这里的 FAQ 是项目维护者对当前许可策略的使用指引，不替代正式法律意见。若你希望未来允许“企业内部免费使用”，可以考虑改用 `PolyForm Internal Use` 或 `PolyForm Small Business` 这类更贴近该目标的标准许可证。

---

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=doccker/cc-use-exp&type=Date)](https://star-history.com/#doccker/cc-use-exp&Date)

## Contributors

<a href="https://github.com/doccker/cc-use-exp/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=doccker/cc-use-exp" />
</a>
