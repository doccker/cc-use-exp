---
name: cc-status
description: 结构化 Codex 配置状态检查工作流，适用于显式 status、配置诊断或同步结果核对场景；聚焦 Codex 配置，不复刻 Claude 的命令和 LSP 状态。
---

# CC Status

当用户明确要求 status、查看 Codex 配置状态，或排查 sync 后的生效情况时，使用本技能。

不要用于：

- Claude 或 Gemini 的状态诊断
- 正式 code review
- 变更项目代码实现

## 核心方式

1. 同时看项目内 `.codex/` 权威源和用户级 `~/.codex/`、`~/.agents/skills/` 部署产物。
2. 检查全局入口是否齐全：`AGENTS.md`、`rules/`、`instructions/`、`skills/`、`config.toml` profiles。
3. 检查 `AGENTS.md` 和 `config.toml` 是否包含受管区块，`rules/`、`instructions/` 与 `skills/` 是否保留 manifest。
4. 检查 `codex` CLI 是否可用，并报告版本。
5. 若 `codex execpolicy check` 可用，抽样验证当前 rules 的 `allow/prompt/forbidden` 是否符合预期。
6. 如果项目内与用户级数量不一致，优先判断是不是还没执行同步脚本。
7. 输出状态、缺口和下一步，不做泛泛而谈的环境描述。

## 输出要求

- 明确区分“项目权威源”和“用户级生效配置”
- 明确区分“文件已同步”与“规则已生效”
- 报告缺失项、数量差异、受管区块异常和明显异常
- 若检测不到问题，要直接说明状态正常
- 若怀疑未同步，明确建议执行 `tools/sync-config.sh`

## 按需展开

- 检查项：`references/status-checks.md`
