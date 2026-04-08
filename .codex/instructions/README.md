# .codex/instructions

本目录存放供 Codex profile 通过 `model_instructions_file` 引用的项目级说明文件。

- 只放 profile 级说明，不替代 `global/AGENTS.md`、`global/rules/` 或 `skills/` 的分层职责。
- 建议一份说明文件对应一个明确用途，避免把无关场景混在同一个文件里。
- profile 内统一使用相对路径引用，例如 `./instructions/custom.md`。
- 通过 `tools/sync-config.sh` 或 `tools\sync-config.bat` 同步后，用户级落点为 `~/.codex/instructions/`。
- 不写入项目私有绝对路径。
