---
name: bash-style
description: Bash 脚本与系统命令规范。禁止行尾注释，强制使用 tee/heredoc 写入，提升命令执行的可维护性。
---
<instructions>

# Bash 与系统命令规范

> 参考来源: Google Shell Style Guide

---

## 🚫 严格禁止

### 1. 禁止行尾注释
- ❌ `curl -X POST ... # 发送请求`
- ✅ 注释必须独占一行，放在代码上方

### 2. 禁止隐式路径
- ❌ `rm test.txt`
- ✅ 优先使用变量或绝对路径：`rm "${WORK_DIR}/test.txt"`

---

## 🛠️ 脚本编写原则

- **防御性头声明**：所有 `.sh` 文件首行必须包含 `set -euo pipefail`。
- **变量引用**：必须为所有变量引用加双引号（`"${VAR}"`），防止空格溢出。
- **安全写入**：禁止在大段脚本中使用 `cat <<EOF > file`。优先使用 `write_file` (工具) 或分步 `tee` 写入。

```bash
# ✅ 良好的脚本头
#!/usr/bin/env bash
set -euo pipefail
```

---

## 💻 命令输出与日志

- 复杂命令必须使用 `tee -a "${LOG_FILE}"` 同时记录到屏幕和日志。
- 循环操作必须打印当前进度索引（如 `[1/50] Processing...`）。

---

> 📋 本回复遵循：`bash-style` - [章节]

</instructions>