# Status Checks

优先检查：

1. 项目内 `.codex/global/AGENTS.md`
2. 项目内 `.codex/global/rules/`
3. 项目内 `.codex/instructions/`
4. 项目内 `.codex/skills/`
5. 项目内 `.codex/profiles/`
6. 用户级 `~/.codex/AGENTS.md`
7. 用户级 `~/.codex/rules/`
8. 用户级 `~/.codex/instructions/`
9. 用户级 `~/.agents/skills/`
10. 用户级 `~/.codex/config.toml`
11. `~/.codex/AGENTS.md` 是否包含 `cc-use-exp codex managed:start/end`
12. `~/.codex/config.toml` 是否包含 `cc-use-exp codex profiles:start/end`
13. `~/.codex/rules/.cc-use-exp-managed`
14. `~/.codex/instructions/.cc-use-exp-managed`
15. `~/.agents/skills/.cc-use-exp-managed`
16. `~/.codex/config.toml` 中被本项目 profile 引用的 `./instructions/*.md` 是否存在
17. `codex --version`

如果 `codex execpolicy check` 可用，再做规则抽样验证：

1. `docker ps` 预期 `allow`
2. `systemctl status nginx` 预期 `allow`
3. `docker compose down` 预期 `prompt`
4. `rm -rf tmp` 预期 `forbidden`

输出时建议拆成两段：

- 文件/同步状态：项目权威源、用户级部署产物、受管区块、manifest、数量差异
- 规则生效状态：抽样命令、命中规则、实际决策、是否符合预期

常见结论：

- 项目内有，用户级没有：通常是没执行同步脚本
- instructions 数量不一致：通常是没执行最新同步脚本，或用户级目录仍是旧结构
- skills 数量不一致：可能有未同步或手工残留
- profiles 缺少受管区块：通常是 `config.toml` 还没合并
- AGENTS 缺少受管区块：通常是 `AGENTS.md` 还没合并，或被手工覆盖
- rules/skills 缺少 manifest：通常是没走同步脚本，或用户级目录被手工改动
- 文件都在但抽样规则不符合预期：优先怀疑用户级 rules 不是当前项目版本，或命中了更严格的外部规则
- `codex` 不可用：先看 CLI 是否安装或 PATH 是否正确
