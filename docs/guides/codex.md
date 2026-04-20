### 7.3 网络与代理配置（国内用户必看）

如果在使用过程中遇到 `gpt-5.4` 会话频繁 `reconnecting`、连接超时，或安装/执行扩展明显卡顿，这通常是网络原因导致。

本项目提供了一份可直接参考的代理配置模板 `.codex/.env`。

**使用方法**：
1. 打开项目内模板文件：
   ```bash
   cat .codex/.env
   ```
2. 按你本地代理客户端（如 Clash Verge）的实际端口修改文件内容：
   ```env
   HTTP_PROXY="http://127.0.0.1:你的端口"
   HTTPS_PROXY="http://127.0.0.1:你的端口"
   NO_PROXY="localhost,127.0.0.1"
   ```
3. 选择生效范围：
   - 复制到 `~/.codex/.env`：让其他项目也复用这份全局代理配置
   - 保留在当前项目的 `.codex/.env`：只对当前项目生效
4. 注意同步边界：`tools/sync-config.sh` 不会自动把该文件同步到 `~/.codex/.env`，避免覆盖你本机已有代理配置。

---

# Part 3: Codex 配置

> **定位**：Codex 采用”极薄全局 AGENTS + 审批 rules + 渐进式 skills”的通用方案。项目内 `.codex/` 是权威源，用户级是部署产物。

## 1. 快速开始

### 1.0 一键安装（推荐）

**方式 1：会话内安装**

在 Codex 会话中执行：

```bash
$skill-installer install https://github.com/doccker/cc-use-exp/.codex/skills/cc-skill-installer
```

**方式 2：Shell 脚本**

在终端执行：
```bash
bash <(curl -sL https://raw.githubusercontent.com/doccker/cc-use-exp/main/tools/install-codex.sh)
```

> **说明**：
> - 方式 1 需要在 Codex 会话中执行，适合已经在使用 Codex 的用户
> - 方式 2 可以在任何终端执行，无需进入 Codex 会话
> - 两种方式都会自动同步配置到 `~/.codex/` 和 `~/.agents/skills/`

---

### 1.1 手动同步（开发者）

首次使用或更新 `.codex/` 后，在项目根目录执行：

- **macOS/Linux**: `./tools/sync-config.sh`
- **Windows**: `tools\sync-config.bat`

脚本会把 `.codex/` 分发到 Codex 官方支持的用户级入口：

| 类型 | 用户级落点 | 作用 |
|------|-----------|------|
| Global AGENTS | `~/.codex/AGENTS.md` | 极薄全局原则，常驻加载 |
| Rules | `~/.codex/rules/` | 审批与危险命令控制 |
| Instructions | `~/.codex/instructions/` | 供 profile 通过 `model_instructions_file` 引用 |
| Skills | `~/.agents/skills/` | 渐进式披露，按需加载 |

**为什么不是直接复制到 `~/.codex/`？**

因为 `~/.codex/` 同时还是 Codex 的运行态目录，会包含认证、历史、日志和缓存。项目只同步受管配置，不覆盖运行态文件。

---

### 1.2 启用 `cc-custom-instructions`

`cc-custom-instructions` 不是日常开发默认 profile。

推荐只在需要专用说明文件的授权场景下启用，例如：

- CTF / 靶场 / challenge 环境分析
- 受控网站或 API 的逆向排查、交互链路还原
- 普通 `cc-balanced` / `cc-deep` 工作流不适合承载的专门研究任务

如果你希望使用项目内 `model_instructions_file` 对应的专用 profile，按以下步骤操作：

1. 编辑 `.codex/instructions/custom.md`
2. 执行 `./tools/sync-config.sh` 或 `tools\sync-config.bat`
3. 使用 `codex -p cc-custom-instructions`

这样会让 `cc-custom-instructions` profile 挂接 `.codex/instructions/custom.md`，并通过同步后的 `~/.codex/instructions/custom.md` 生效。
普通修 Bug、日常重构、代码审查、提交信息生成等场景，仍优先使用 `cc-balanced`、`cc-deep` 或对应 workflow skills。

---

### 1.3 零费力（自动生效）- Global AGENTS + Rules

**你需要做什么：同步一次配置，然后正常使用 Codex**

这些内容在 Codex 启动后自动生效：

| 组件 | 用户级位置 | 作用 |
|------|-----------|------|
| Global AGENTS | `~/.codex/AGENTS.md` | 极薄全局原则：先读代码、最小改动、验证、分层、默认简体中文交流 |
| Rules | `~/.codex/rules/*.rules` | 审批、危险命令控制、默认安全边界 |
| Instructions | `~/.codex/instructions/*.md` | 供专用 profile 通过 `model_instructions_file` 挂接说明文件 |
| Profiles | `~/.codex/config.toml` | 提供 `cc-fast-api`、`cc-balanced`、`cc-deep`、`cc-custom-instructions` 等预设模式 |

**效果示例**：
- Codex 会优先先读代码、配置和脚本，再下结论
- 默认使用简体中文回复，代码、命令、日志和报错保持原文
- 遇到危险命令或越权执行时，会进入审批控制
- 只读排查命令会尽量低摩擦放行，例如 `docker ps`、`kubectl get pods`、`systemctl status nginx`
- 可以按任务复杂度切换 `codex -p cc-balanced` 或 `codex -p cc-deep`

---

### 1.4 低费力（自动触发）- Implicit Skills

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
| `cc-api-design-safety` | 设计或修改 REST API 响应结构 | 防止泛型重载歧义、响应字段语义混淆 |
| `cc-storage-url-safety` | 使用 MinIO/OSS/S3 等对象存储 | URL 策略选择、Bucket 配置、安全性检查 |

**效果示例**：
- 写 Go、Java、Python 或前端代码时，会自动带上对应语言规范
- 修改脚本或命令片段时，会补充 Bash 风格约束
- 涉及部署、数据库、服务操作时，会优先考虑安全和回滚

---

### 1.5 中费力（显式调用）- Workflow Skills

**你需要做什么：在 Codex 对话里输入 `$skill-name`**

Codex 的显式 workflow skill 不走 Claude Code 的 `/命令` 风格。本项目统一按 Codex Skills 的显式调用方式使用，例如：`$commit-msg`、`$optimize perf`、`$new-feature 用户导出功能`。其中 `review` 和 `status` 为避免与 Codex 内置能力混淆，保留 `cc-` 前缀：`$cc-review`、`$cc-status`。

注意：`$review quick` 更可能命中 Codex 内置 review 能力，而不是本仓库定义的 `cc-review` skill。若你希望使用本项目约定的中文化审查格式和输出结构，请明确使用 `$cc-review quick`。

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
| 授权 CTF / 靶场等专用研究场景 | 编辑 `custom.md` 后执行 `codex -p cc-custom-instructions` | ⭐⭐ |
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

Codex 配置按多层拆分：

| 层级 | 位置 | 说明 |
|------|------|------|
| 常驻最小层 | `.codex/global/AGENTS.md` | 只保留跨项目都成立的总纲 |
| 审批控制层 | `.codex/global/rules/` | 只放允许/提示/禁止执行的命令规则 |
| 说明文件层 | `.codex/instructions/*.md` | 供 profile 通过 `model_instructions_file` 引用的说明文件 |
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
| `new-feature` | 需求澄清 → 设计 → 实现 → 验证，任务状态持久化到项目内 `.codex/tasks/`，已完成任务会归档到 `.codex/tasks/archived/` |
| `project-init` | 初始化新仓库：生成项目级 `AGENTS.md`，并按需落脚手架模板 |

> 说明：Codex 相关脚手架模板不再集中放在根 `.codex/templates/`；`project-init` 需要的 `AGENTS.md`、Docker、compose、restart 等资源跟随 skill 放在 `cc-project-init/assets/`，这样同步后即可直接使用。

### Profile 模式

项目内还维护了 4 个 Codex profile：

| Profile | 用途 | 建议配置 |
|---------|------|---------|
| `cc-fast-api` | API key 环境下的快模式 | `codex-mini-latest` |
| `cc-balanced` | 日常主力 | `gpt-5.3-codex` + `medium` |
| `cc-deep` | 复杂审查、深度分析 | `gpt-5.4` + `high` |
| `cc-custom-instructions` | 授权 CTF / 靶场 / 专用研究任务使用的说明文件 profile | `gpt-5.4` + `high` + `./instructions/custom.md` |

使用方式：

```bash
codex -p cc-fast-api
codex exec -p cc-balanced "review this change"
codex -p cc-deep
codex -p cc-custom-instructions
```

> 说明：这里的 `cc-fast-api` 是**项目自定义的快 profile**，适合 API key 场景；它不是把用户默认配置切到官方 Fast mode credits。这样可以在不动顶层默认配置的前提下，按需切换速度与深度。

### 自定义说明文件

如果你需要为某个专用 profile 挂接完整的 `model_instructions_file`，推荐沿用当前约定：

1. 在 `.codex/instructions/` 下维护说明文件，例如 `custom.md`
2. 在 `.codex/profiles/*.toml` 中通过相对路径引用，例如 `model_instructions_file = "./instructions/custom.md"`
3. 执行 `./tools/sync-config.sh` 或 `tools\sync-config.bat`
4. 使用 `codex -p cc-custom-instructions`

这样项目内路径和用户级 `~/.codex/instructions/` 的相对引用可以保持一致，不需要写绝对路径。
推荐只在授权的 CTF / 靶场 / challenge 研究场景中启用，不作为通用开发 profile 常驻使用。

![Chrome 插件独立配置界面（可指定自定义模型）](../../pic/codex-unlock.png)

## 4. 目录结构

```text
.codex/
├── .env
├── global/
│   ├── AGENTS.md
│   └── rules/
│       ├── cc-safe-default.rules
│       └── cc-dangerous-ops.rules
├── instructions/
│   ├── README.md
│   └── custom.md
├── manifests/
├── profiles/
├── skills/
├── tasks/
└── templates/
```


---

## 附录：GitHub Copilot 支持

项目现已支持 GitHub Copilot，重点覆盖 Copilot coding agent 场景。

当前采用的配置载体：

- `.github/copilot-instructions.md`：仓库级 Copilot 指令
- `.github/instructions/*.instructions.md`：按路径细分的补充说明
- `AGENTS.md`：供支持 agent instructions 的场景复用

如需安装用户级兜底配置，可执行：

```bash
bash <(curl -sL https://raw.githubusercontent.com/doccker/cc-use-exp/main/tools/install-copilot.sh)
```

同步后目标位置为：

- `~/.github/copilot-instructions.md`
- `~/.github/instructions/`
- `~/.github/AGENTS.md`（若仓库存在）
