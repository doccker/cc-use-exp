# .codex 同步映射

本目录是项目级权威源，不直接作为 Codex 原生仓库入口使用。当前 `tools/sync-config.sh` 已按以下映射部署：

| 源路径 | 目标路径 | 策略 |
|------|------|------|
| `.codex/global/AGENTS.md` | `~/.codex/AGENTS.md` | 受管区块合并，不整文件覆盖 |
| `.codex/global/rules/*.rules` | `~/.codex/rules/` | 增量复制，文件名保留 `cc-` 前缀 |
| `.codex/instructions/*.md` | `~/.codex/instructions/` | 增量复制，清理当前项目受管文件 |
| `.codex/skills/*` | `~/.agents/skills/` | 增量复制，保留目录名 |
| `.codex/profiles/*.toml` | `~/.codex/config.toml` | 受管区块合并，只追加具名 profiles |

## 不同步内容

- `.codex/templates/`
- `.codex/tasks/`
- `.codex/manifests/`

## 明确禁止

- 不删除 `~/.codex/` 运行态文件
- 不覆盖 `~/.codex/auth.json`
- 不覆盖 `~/.codex/history.jsonl`
- 不覆盖日志、sqlite、cache
- 不改用户现有默认 provider/model/base_url
- 不写入项目私有绝对路径
- 不覆盖用户已有 profile 同名之外的其他配置
