#!/usr/bin/env bash
if [ -z "${BASH_VERSION:-}" ]; then
    exec /usr/bin/env bash "$0" "$@"
fi

set -euo pipefail

# 同步 .claude、.gemini、.codex 和 .cursor 配置到用户根目录
# 说明：Cursor 的 rules 同步为兼容性补充；项目内 .cursor/rules 仍是主路径。

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_line() {
    printf '%b\n' "$1"
}

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CODEX_MANAGED_START="<!-- cc-use-exp codex managed:start -->"
CODEX_MANAGED_END="<!-- cc-use-exp codex managed:end -->"
CODEX_PROFILE_START="# cc-use-exp codex profiles:start"
CODEX_PROFILE_END="# cc-use-exp codex profiles:end"

merge_managed_block() {
    local src_file="$1"
    local dst_file="$2"
    local start_marker="$3"
    local end_marker="$4"
    local tmp_file

    tmp_file="$(mktemp)"

    if [[ -f "$dst_file" ]]; then
        awk -v start="$start_marker" -v end="$end_marker" '
            $0 == start { skip = 1; next }
            $0 == end { skip = 0; next }
            !skip { print }
        ' "$dst_file" > "$tmp_file"
    fi

    if [[ -s "$tmp_file" ]]; then
        printf '\n' >> "$tmp_file"
    fi

    printf '%s\n' "$start_marker" >> "$tmp_file"
    cat "$src_file" >> "$tmp_file"
    if [[ -s "$src_file" && -n "$(tail -c 1 "$src_file" 2>/dev/null)" ]]; then
        printf '\n' >> "$tmp_file"
    fi
    printf '%s\n' "$end_marker" >> "$tmp_file"

    mv "$tmp_file" "$dst_file"
}

build_profiles_bundle() {
    local src_dir="$1"
    local profile_file
    local profile_list

    CODEX_PROFILE_BUNDLE="$(mktemp)"
    CODEX_PROFILES_SYNCED=0
    profile_list="$(mktemp)"

    find "$src_dir" -maxdepth 1 -type f -name '*.toml' | LC_ALL=C sort > "$profile_list"

    printf '# Managed Codex profiles from cc-use-exp\n' >> "$CODEX_PROFILE_BUNDLE"
    printf '# Use with: codex -p <profile-name>\n\n' >> "$CODEX_PROFILE_BUNDLE"

    while IFS= read -r profile_file; do
        [[ -n "$profile_file" ]] || continue
        CODEX_PROFILES_SYNCED=$((CODEX_PROFILES_SYNCED + 1))
        cat "$profile_file" >> "$CODEX_PROFILE_BUNDLE"
        if [[ -s "$profile_file" && -n "$(tail -c 1 "$profile_file" 2>/dev/null)" ]]; then
            printf '\n' >> "$CODEX_PROFILE_BUNDLE"
        fi
        printf '\n' >> "$CODEX_PROFILE_BUNDLE"
    done < "$profile_list"

    rm -f "$profile_list"
}

sync_managed_rules() {
    local src_dir="$1"
    local dst_dir="$2"
    local manifest_file="$dst_dir/.cc-use-exp-managed"
    local new_manifest
    local rule_file
    local rule_name
    local rule_list

    CODEX_RULES_SYNCED=0
    mkdir -p "$dst_dir"
    new_manifest="$(mktemp)"
    rule_list="$(mktemp)"

    find "$src_dir" -maxdepth 1 -type f -name '*.rules' | LC_ALL=C sort > "$rule_list"

    while IFS= read -r rule_file; do
        [[ -n "$rule_file" ]] || continue
        rule_name="$(basename "$rule_file")"
        printf '%s\n' "$rule_name" >> "$new_manifest"
        cp "$rule_file" "$dst_dir/$rule_name"
        CODEX_RULES_SYNCED=$((CODEX_RULES_SYNCED + 1))
    done < "$rule_list"

    rm -f "$rule_list"

    if [[ -f "$manifest_file" ]]; then
        while IFS= read -r rule_name; do
            [[ -n "$rule_name" ]] || continue
            if ! grep -Fxq "$rule_name" "$new_manifest"; then
                rm -f "$dst_dir/$rule_name"
            fi
        done < "$manifest_file"
    fi

    mv "$new_manifest" "$manifest_file"
}

sync_managed_instruction_files() {
    local src_dir="$1"
    local dst_dir="$2"
    local manifest_file="$dst_dir/.cc-use-exp-managed"
    local new_manifest
    local instruction_file
    local instruction_name
    local instruction_list

    CODEX_INSTRUCTIONS_SYNCED=0
    mkdir -p "$dst_dir"
    new_manifest="$(mktemp)"
    instruction_list="$(mktemp)"

    find "$src_dir" -maxdepth 1 -type f -name '*.md' | LC_ALL=C sort > "$instruction_list"

    while IFS= read -r instruction_file; do
        [[ -n "$instruction_file" ]] || continue
        instruction_name="$(basename "$instruction_file")"
        printf '%s\n' "$instruction_name" >> "$new_manifest"
        cp "$instruction_file" "$dst_dir/$instruction_name"
        CODEX_INSTRUCTIONS_SYNCED=$((CODEX_INSTRUCTIONS_SYNCED + 1))
    done < "$instruction_list"

    rm -f "$instruction_list"

    if [[ -f "$manifest_file" ]]; then
        while IFS= read -r instruction_name; do
            [[ -n "$instruction_name" ]] || continue
            if ! grep -Fxq "$instruction_name" "$new_manifest"; then
                rm -f "$dst_dir/$instruction_name"
            fi
        done < "$manifest_file"
    fi

    mv "$new_manifest" "$manifest_file"
}

sync_managed_skills() {
    local src_dir="$1"
    local dst_dir="$2"
    local manifest_file="$dst_dir/.cc-use-exp-managed"
    local new_manifest
    local skill_dir
    local skill_name
    local skill_list

    CODEX_SKILLS_SYNCED=0
    mkdir -p "$dst_dir"
    new_manifest="$(mktemp)"
    skill_list="$(mktemp)"

    find "$src_dir" -mindepth 1 -maxdepth 1 -type d | LC_ALL=C sort > "$skill_list"

    while IFS= read -r skill_dir; do
        [[ -n "$skill_dir" ]] || continue
        skill_name="$(basename "$skill_dir")"
        printf '%s\n' "$skill_name" >> "$new_manifest"
        rm -rf "$dst_dir/$skill_name"
        cp -R "$skill_dir" "$dst_dir/$skill_name"
        CODEX_SKILLS_SYNCED=$((CODEX_SKILLS_SYNCED + 1))
    done < "$skill_list"

    rm -f "$skill_list"

    if [[ -f "$manifest_file" ]]; then
        while IFS= read -r skill_name; do
            [[ -n "$skill_name" ]] || continue
            if ! grep -Fxq "$skill_name" "$new_manifest"; then
                rm -rf "$dst_dir/$skill_name"
            fi
        done < "$manifest_file"
    fi

    mv "$new_manifest" "$manifest_file"
}

print_line "${GREEN}=== 配置同步工具 ===${NC}"
print_line "源目录: ${SCRIPT_DIR}"
print_line "目标目录: ${HOME}"
printf '\n'

# --- Claude Code ---
if [[ -d "${SCRIPT_DIR}/.claude" ]]; then
    print_line "${GREEN}[Claude Code] 开始同步${NC}"

    # 确保目标目录存在
    mkdir -p ~/.claude

    # 删除旧配置目录（保留历史记录、projects 等）
    rm -rf ~/.claude/rules ~/.claude/skills ~/.claude/commands ~/.claude/templates ~/.claude/tasks ~/.claude/tools
    print_line "${YELLOW}  已清理旧配置目录${NC}"

    # 复制配置目录
    cp -r "${SCRIPT_DIR}/.claude/rules" ~/.claude/
    cp -r "${SCRIPT_DIR}/.claude/skills" ~/.claude/
    cp -r "${SCRIPT_DIR}/.claude/commands" ~/.claude/
    cp -r "${SCRIPT_DIR}/.claude/templates" ~/.claude/
    cp -r "${SCRIPT_DIR}/.claude/tasks" ~/.claude/
    [[ -d "${SCRIPT_DIR}/.claude/tools" ]] && cp -r "${SCRIPT_DIR}/.claude/tools" ~/.claude/
    cp "${SCRIPT_DIR}/.claude/CLAUDE.md" ~/.claude/

    print_line "${GREEN}  ✓ rules/ skills/ commands/ templates/ tasks/ tools/ CLAUDE.md${NC}"

    # --- Claude Code 插件检测 ---
    PLUGIN_JSON="${SCRIPT_DIR}/.claude/plugins.json"
    INSTALLED_JSON="${HOME}/.claude/plugins/installed_plugins.json"
    if ! command -v claude &>/dev/null; then
        printf '\n'
        print_line "${YELLOW}[Claude Code] 未检测到 claude 命令，跳过插件检测${NC}"
        print_line "${YELLOW}  安装方式: npm install -g @anthropic-ai/claude-code${NC}"
    elif ! command -v python3 &>/dev/null; then
        printf '\n'
        print_line "${YELLOW}[Claude Code] 未检测到 python3，跳过插件检测${NC}"
        print_line "${YELLOW}  插件检测需要 python3 解析 JSON，请安装后重试${NC}"
        print_line "${YELLOW}  macOS: brew install python3 | Ubuntu: sudo apt install python3${NC}"
    elif [[ -f "$PLUGIN_JSON" ]]; then
        printf '\n'
        print_line "${YELLOW}[Claude Code] 正在检测推荐插件...${NC}"

        # 使用 python3 解析 JSON 检查缺失插件
        MISSING_PLUGINS=$(python3 -c "
import json, sys
try:
    with open(sys.argv[1]) as f:
        recommended = json.load(f)
    installed = {}
    try:
        with open(sys.argv[2]) as f:
            installed = json.load(f).get('plugins', {})
    except (FileNotFoundError, json.JSONDecodeError):
        pass
    for p in recommended.get('recommendations', []):
        key = p['id'] + '@' + p['marketplace']
        if key not in installed:
            print(p['id'] + '|' + p['name'] + '|' + p['marketplace'])
except Exception:
    pass
" "$PLUGIN_JSON" "$INSTALLED_JSON")

        if [[ -n "$MISSING_PLUGINS" ]]; then
            print_line "${YELLOW}检测到以下推荐插件尚未安装：${NC}"
            IFS=$'\n'
            for item in $MISSING_PLUGINS; do
                IFS='|' read -r id name marketplace <<< "$item"
                print_line "  - ${YELLOW}$name${NC} ($id)"
            done

            printf '\n'
            read -p "是否现在安装上述缺失的插件？[Y/n] " confirm
            if [[ "$confirm" =~ ^[Yy]$ || "$confirm" == "" ]]; then
                IFS=$'\n'
                for item in $MISSING_PLUGINS; do
                    IFS='|' read -r id name marketplace <<< "$item"
                    print_line "${GREEN}正在安装 $name...${NC}"
                    INSTALL_OUTPUT=$(claude plugin install "${id}@${marketplace}" 2>&1) || {
                        if echo "$INSTALL_OUTPUT" | grep -qi "auth\|login\|token\|credential\|unauthorized\|forbidden"; then
                            print_line "${RED}错误: Claude Code 未认证，请先运行 'claude login' 登录${NC}"
                            break
                        elif echo "$INSTALL_OUTPUT" | grep -qi "already installed\|already exists"; then
                            print_line "${YELLOW}  $name 已安装，跳过${NC}"
                        else
                            print_line "${YELLOW}警告: $name 安装失败 — $INSTALL_OUTPUT${NC}"
                        fi
                    }
                done
                print_line "${GREEN}✓ 插件安装完成${NC}"
            else
                print_line "${YELLOW}已跳过插件安装。你可以之后手动安装。${NC}"
            fi
        else
            print_line "${GREEN}✓ 所有推荐插件已安装${NC}"
        fi
    fi
else
    print_line "${YELLOW}[Claude Code] 源目录不存在，跳过${NC}"
fi

printf '\n'

# --- Gemini CLI ---
if [[ -d "${SCRIPT_DIR}/.gemini" ]]; then
    print_line "${GREEN}[Gemini CLI] 开始同步${NC}"

    # 确保目标目录存在
    mkdir -p ~/.gemini

    # 删除旧配置目录（保留认证信息）
    rm -rf ~/.gemini/commands ~/.gemini/skills ~/.gemini/rules ~/.gemini/policies
    print_line "${YELLOW}  已清理旧配置目录${NC}"

    # 确保目标目录存在
    mkdir -p ~/.gemini/policies

    # 复制配置
    cp -r "${SCRIPT_DIR}/.gemini/commands" ~/.gemini/
    cp -r "${SCRIPT_DIR}/.gemini/skills" ~/.gemini/
    cp -r "${SCRIPT_DIR}/.gemini/rules" ~/.gemini/
    cp "${SCRIPT_DIR}/.gemini/GEMINI.md" ~/.gemini/
    cp "${SCRIPT_DIR}/.gemini/settings.json" ~/.gemini/

    # 策略同步逻辑：最新规范要求使用 policies 目录
    if [[ -d "${SCRIPT_DIR}/.gemini/policies" ]]; then
        cp -r "${SCRIPT_DIR}/.gemini/policies/"* ~/.gemini/policies/
    fi
    # 清理旧的全局策略文件以防冲突
    [ -f "${HOME}/.gemini/policy.toml" ] && rm "${HOME}/.gemini/policy.toml"
    if [[ -f "${HOME}/.gemini/policy.json" ]]; then
        mv "${HOME}/.gemini/policy.json" "${HOME}/.gemini/policy.json.bak_$(date +%F)"
    fi

    print_line "${GREEN}  ✓ commands/ skills/ rules/ policies/ GEMINI.md settings.json${NC}"

    # --- MCP 扩展检测 ---
    EXT_JSON="${SCRIPT_DIR}/.gemini/extensions.json"
    if ! command -v gemini &>/dev/null; then
        printf '\n'
        print_line "${YELLOW}[Gemini CLI] 未检测到 gemini 命令，跳过扩展检测${NC}"
        print_line "${YELLOW}  安装方式: brew install gemini-cli (详见 README)${NC}"
    elif ! command -v python3 &>/dev/null; then
        printf '\n'
        print_line "${YELLOW}[Gemini CLI] 未检测到 python3，跳过扩展检测${NC}"
        print_line "${YELLOW}  扩展检测需要 python3 解析 JSON，请安装后重试${NC}"
        print_line "${YELLOW}  macOS: brew install python3 | Ubuntu: sudo apt install python3${NC}"
    elif [[ -f "$EXT_JSON" ]]; then
        printf '\n'
        print_line "${YELLOW}[Gemini CLI] 正在检测推荐扩展...${NC}"

        # 获取当前已安装的扩展列表（gemini extensions list 输出走 stderr）
        INSTALLED_EXTS=$(gemini extensions list 2>&1 || echo "")

        # 使用 python3 解析 JSON 并检查缺失
        # 优化匹配逻辑：检查 id 是否作为独立单词出现在已安装列表中
        MISSING_EXTS=$(python3 -c "
import json, sys, re
try:
    with open(sys.argv[1]) as f:
        data = json.load(f)
    installed = sys.argv[2]
    for ext in data.get('recommendations', []):
        # 使用正则确保是完整匹配 ID
        if not re.search(r'\b' + re.escape(ext['id']) + r'\b', installed):
            print(ext['id'] + '|' + ext['name'] + '|' + ext['url'])
except Exception:
    pass
" "$EXT_JSON" "$INSTALLED_EXTS")

        if [[ -n "$MISSING_EXTS" ]]; then
            print_line "${YELLOW}检测到以下推荐扩展尚未安装：${NC}"
            IFS=$'\n'
            for item in $MISSING_EXTS; do
                IFS='|' read -r id name url <<< "$item"
                print_line "  - ${YELLOW}$name${NC} ($id)"
            done

            printf '\n'
            read -p "是否现在安装上述缺失的扩展？[Y/n] " confirm
            if [[ "$confirm" =~ ^[Yy]$ || "$confirm" == "" ]]; then
                IFS=$'\n'
                for item in $MISSING_EXTS; do
                    IFS='|' read -r id name url <<< "$item"
                    print_line "${GREEN}正在安装 $name...${NC}"
                    INSTALL_OUTPUT=$(gemini extensions install "$url" 2>&1) || {
                        if echo "$INSTALL_OUTPUT" | grep -qi "auth\|login\|token\|credential\|unauthorized\|forbidden"; then
                            print_line "${RED}错误: Gemini CLI 未认证，请先运行 'gemini auth login' 登录${NC}"
                            break
                        elif echo "$INSTALL_OUTPUT" | grep -qi "already installed\|already exists"; then
                            print_line "${YELLOW}  $name 已安装，跳过${NC}"
                        else
                            print_line "${YELLOW}警告: $name 安装失败 — $INSTALL_OUTPUT${NC}"
                        fi
                    }
                done
                print_line "${GREEN}✓ 扩展安装完成${NC}"
            else
                print_line "${YELLOW}已跳过扩展安装。你可以之后手动安装。${NC}"
            fi
        else
            print_line "${GREEN}✓ 所有推荐扩展已安装${NC}"
        fi
    fi
else
    print_line "${YELLOW}[Gemini CLI] 源目录不存在，跳过${NC}"
fi

printf '\n'

# --- Codex ---
if [[ -d "${SCRIPT_DIR}/.codex" ]]; then
    print_line "${GREEN}[Codex] 开始同步${NC}"

    mkdir -p ~/.codex ~/.codex/rules ~/.codex/instructions ~/.agents/skills

    CODEX_RULES_SYNCED=0
    CODEX_INSTRUCTIONS_SYNCED=0
    CODEX_SKILLS_SYNCED=0

    CODEX_AGENTS_SRC="${SCRIPT_DIR}/.codex/global/AGENTS.md"
    CODEX_AGENTS_DST="${HOME}/.codex/AGENTS.md"
    CODEX_RULES_SRC="${SCRIPT_DIR}/.codex/global/rules"
    CODEX_INSTRUCTIONS_SRC="${SCRIPT_DIR}/.codex/instructions"
    CODEX_SKILLS_SRC="${SCRIPT_DIR}/.codex/skills"

    if [[ -f "$CODEX_AGENTS_SRC" ]]; then
        merge_managed_block "$CODEX_AGENTS_SRC" "$CODEX_AGENTS_DST" "$CODEX_MANAGED_START" "$CODEX_MANAGED_END"
        print_line "${GREEN}  ✓ 已合并 ~/.codex/AGENTS.md 受管区块${NC}"
    else
        print_line "${YELLOW}  未找到 global/AGENTS.md，跳过 AGENTS 同步${NC}"
    fi

    if [[ -d "$CODEX_RULES_SRC" ]]; then
        sync_managed_rules "$CODEX_RULES_SRC" "${HOME}/.codex/rules"
    fi

    if [[ -d "$CODEX_INSTRUCTIONS_SRC" ]]; then
        sync_managed_instruction_files "$CODEX_INSTRUCTIONS_SRC" "${HOME}/.codex/instructions"
    fi

    if [[ -d "$CODEX_SKILLS_SRC" ]]; then
        sync_managed_skills "$CODEX_SKILLS_SRC" "${HOME}/.agents/skills"
    fi

    CODEX_PROFILES_SRC="${SCRIPT_DIR}/.codex/profiles"
    CODEX_CONFIG_DST="${HOME}/.codex/config.toml"
    CODEX_PROFILES_SYNCED=0

    if [[ -d "$CODEX_PROFILES_SRC" ]]; then
        build_profiles_bundle "$CODEX_PROFILES_SRC"
        merge_managed_block "$CODEX_PROFILE_BUNDLE" "$CODEX_CONFIG_DST" "$CODEX_PROFILE_START" "$CODEX_PROFILE_END"
        rm -f "$CODEX_PROFILE_BUNDLE"
        print_line "${GREEN}  ✓ profiles: ${CODEX_PROFILES_SYNCED} 个，已合并到 ~/.codex/config.toml${NC}"
    else
        print_line "${YELLOW}  未找到 profiles/，跳过 profile 同步${NC}"
    fi

    print_line "${GREEN}  ✓ rules: ${CODEX_RULES_SYNCED} 个，同步到 ~/.codex/rules/${NC}"
    print_line "${GREEN}  ✓ instructions: ${CODEX_INSTRUCTIONS_SYNCED} 个，同步到 ~/.codex/instructions/${NC}"
    print_line "${GREEN}  ✓ skills: ${CODEX_SKILLS_SYNCED} 个，同步到 ~/.agents/skills/${NC}"
    print_line "${YELLOW}  已保留 ~/.codex 运行态文件（auth/history/logs/cache）${NC}"
else
    print_line "${YELLOW}[Codex] 源目录不存在，跳过${NC}"
fi

printf '\n'

# --- Cursor ---
if [[ -d "${SCRIPT_DIR}/.cursor" ]]; then
    print_line "${GREEN}[Cursor] 开始同步${NC}"

    mkdir -p ~/.cursor/rules ~/.cursor/skills ~/.cursor/templates

    CURSOR_RULES_SRC="${SCRIPT_DIR}/.cursor/rules"
    CURSOR_SKILLS_SRC="${SCRIPT_DIR}/.cursor/skills"
    CURSOR_COMMANDS_SRC="${SCRIPT_DIR}/.cursor/commands"
    CURSOR_TEMPLATES_SRC="${SCRIPT_DIR}/.cursor/templates"
    CURSOR_RULES_MANIFEST="${HOME}/.cursor/rules/.cc-use-exp-managed"
    CURSOR_SKILLS_MANIFEST="${HOME}/.cursor/skills/.cc-use-exp-managed"

    CURSOR_RULES_SYNCED=0
    CURSOR_SKILLS_SYNCED=0
    CURSOR_COMMANDS_SYNCED=0

    # rules → ~/.cursor/rules/（兼容性同步；项目内 .cursor/rules 仍是主路径）
    if [[ -d "$CURSOR_RULES_SRC" ]]; then
        new_manifest="$(mktemp)"
        rule_list="$(mktemp)"

        find "$CURSOR_RULES_SRC" -maxdepth 1 -type f \( -name '*.mdc' -o -name '*.md' \) | LC_ALL=C sort > "$rule_list"

        while IFS= read -r rule_file; do
            [[ -n "$rule_file" ]] || continue
            rule_name="$(basename "$rule_file")"
            printf '%s\n' "$rule_name" >> "$new_manifest"
            cp "$rule_file" "${HOME}/.cursor/rules/$rule_name"
            CURSOR_RULES_SYNCED=$((CURSOR_RULES_SYNCED + 1))
        done < "$rule_list"

        rm -f "$rule_list"

        if [[ -f "$CURSOR_RULES_MANIFEST" ]]; then
            while IFS= read -r rule_name; do
                [[ -n "$rule_name" ]] || continue
                if ! grep -Fxq "$rule_name" "$new_manifest"; then
                    rm -f "${HOME}/.cursor/rules/$rule_name"
                fi
            done < "$CURSOR_RULES_MANIFEST"
        fi

        mv "$new_manifest" "$CURSOR_RULES_MANIFEST"
    fi

    # skills（目录） → ~/.cursor/skills/
    new_manifest="$(mktemp)"

    if [[ -d "$CURSOR_SKILLS_SRC" ]]; then
        skill_list="$(mktemp)"
        find "$CURSOR_SKILLS_SRC" -mindepth 1 -maxdepth 1 -type d | LC_ALL=C sort > "$skill_list"

        while IFS= read -r skill_dir; do
            [[ -n "$skill_dir" ]] || continue
            skill_name="$(basename "$skill_dir")"
            printf '%s\n' "$skill_name" >> "$new_manifest"
            rm -rf "${HOME}/.cursor/skills/$skill_name"
            cp -R "$skill_dir" "${HOME}/.cursor/skills/$skill_name"
            CURSOR_SKILLS_SYNCED=$((CURSOR_SKILLS_SYNCED + 1))
        done < "$skill_list"

        rm -f "$skill_list"
    fi

    # commands（.md 文件） → ~/.cursor/skills/{name}/SKILL.md
    if [[ -d "$CURSOR_COMMANDS_SRC" ]]; then
        cmd_list="$(mktemp)"
        find "$CURSOR_COMMANDS_SRC" -maxdepth 1 -type f -name '*.md' | LC_ALL=C sort > "$cmd_list"

        while IFS= read -r cmd_file; do
            [[ -n "$cmd_file" ]] || continue
            cmd_name="$(basename "$cmd_file" .md)"
            printf '%s\n' "$cmd_name" >> "$new_manifest"
            mkdir -p "${HOME}/.cursor/skills/$cmd_name"
            cp "$cmd_file" "${HOME}/.cursor/skills/$cmd_name/SKILL.md"
            CURSOR_COMMANDS_SYNCED=$((CURSOR_COMMANDS_SYNCED + 1))
        done < "$cmd_list"

        rm -f "$cmd_list"
    fi

    if [[ -f "$CURSOR_SKILLS_MANIFEST" ]]; then
        while IFS= read -r item_name; do
            [[ -n "$item_name" ]] || continue
            if ! grep -Fxq "$item_name" "$new_manifest"; then
                rm -rf "${HOME}/.cursor/skills/$item_name"
            fi
        done < "$CURSOR_SKILLS_MANIFEST"
    fi

    mv "$new_manifest" "$CURSOR_SKILLS_MANIFEST"

    # templates → ~/.cursor/templates/
    if [[ -d "$CURSOR_TEMPLATES_SRC" ]]; then
        find "$CURSOR_TEMPLATES_SRC" -mindepth 1 -maxdepth 1 -type d | LC_ALL=C sort | while IFS= read -r tpl_dir; do
            [[ -n "$tpl_dir" ]] || continue
            tpl_name="$(basename "$tpl_dir")"
            mkdir -p "${HOME}/.cursor/templates/$tpl_name"
            cp -R "$tpl_dir"/* "${HOME}/.cursor/templates/$tpl_name/" 2>/dev/null || true
        done
    fi

    print_line "${GREEN}  ✓ rules: ${CURSOR_RULES_SYNCED} 个，同步到 ~/.cursor/rules/（兼容性补充）${NC}"
    print_line "${GREEN}  ✓ skills: ${CURSOR_SKILLS_SYNCED} 个，同步到 ~/.cursor/skills/${NC}"
    print_line "${GREEN}  ✓ commands: ${CURSOR_COMMANDS_SYNCED} 个，同步到 ~/.cursor/skills/（命令式技能兼容层）${NC}"
    print_line "${GREEN}  ✓ templates: 同步到 ~/.cursor/templates/${NC}"
    print_line "${YELLOW}  项目内 .cursor/rules 仍是主路径；已保留 ~/.cursor 运行态文件（settings/extensions/cache）${NC}"
else
    print_line "${YELLOW}[Cursor] 源目录不存在，跳过${NC}"
fi

printf '\n'
print_line "${GREEN}=== 同步完成 ===${NC}"
print_line "${YELLOW}提示: 若在项目目录运行 gemini 出现 'Skill conflict detected' 警告：${NC}"
print_line "  这是由于 Gemini CLI 同时加载了全局 (~/.gemini) 和局部 (.gemini) 配置，属于预期行为。"
print_line "  局部配置将自动覆盖全局配置，不影响功能使用。"
