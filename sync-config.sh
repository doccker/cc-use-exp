#!/usr/bin/env bash
set -euo pipefail

# 同步 .claude 和 .gemini 配置到用户根目录

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 获取用户根目录
HOME_DIR="${HOME}"

# 当前脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 需要同步的目录
SYNC_DIRS=(".claude" ".gemini")

# 全局覆盖策略（空表示每次询问，yes表示全部覆盖，no表示全部跳过）
OVERWRITE_ALL=""

# 确认覆盖函数
confirm_overwrite() {
    local file="${1}"

    # 如果已设置全局策略，直接返回
    if [[ "${OVERWRITE_ALL}" == "yes" ]]; then
        return 0
    elif [[ "${OVERWRITE_ALL}" == "no" ]]; then
        return 1
    fi

    # 询问用户
    echo -e "${YELLOW}文件已存在: ${file}${NC}"
    echo -ne "是否覆盖? [y/N/a(全部覆盖)/s(全部跳过)]: "
    read -r response

    case "${response}" in
        [aA])
            OVERWRITE_ALL="yes"
            echo -e "${GREEN}后续文件将全部覆盖${NC}"
            return 0
            ;;
        [sS])
            OVERWRITE_ALL="no"
            echo -e "${GREEN}后续文件将全部跳过${NC}"
            return 1
            ;;
        [yY])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# 复制文件函数
copy_file() {
    local src="${1}"
    local dest="${2}"

    if [[ -f "${dest}" ]]; then
        if confirm_overwrite "${dest}"; then
            cp -f "${src}" "${dest}"
            echo -e "${GREEN}✓ 已覆盖: ${dest}${NC}"
        else
            echo -e "${YELLOW}✗ 已跳过: ${dest}${NC}"
        fi
    else
        cp "${src}" "${dest}"
        echo -e "${GREEN}✓ 已复制: ${dest}${NC}"
    fi
}

# 同步目录函数
sync_directory() {
    local dir_name="${1}"
    local src_dir="${SCRIPT_DIR}/${dir_name}"
    local dest_dir="${HOME_DIR}/${dir_name}"

    if [[ ! -d "${src_dir}" ]]; then
        echo -e "${YELLOW}源目录不存在，跳过: ${src_dir}${NC}"
        return
    fi

    echo -e "\n${GREEN}开始同步: ${dir_name}${NC}"

    # 创建目标目录（如果不存在）
    mkdir -p "${dest_dir}"

    # 递归处理所有文件
    while IFS= read -r -d '' file; do
        local rel_path="${file#${src_dir}/}"
        local dest_file="${dest_dir}/${rel_path}"
        local dest_subdir="$(dirname "${dest_file}")"

        # 创建子目录
        mkdir -p "${dest_subdir}"

        # 复制文件
        copy_file "${file}" "${dest_file}"
    done < <(find "${src_dir}" -type f -print0)
}

# 主流程
main() {
    echo -e "${GREEN}=== 配置同步工具 ===${NC}"
    echo -e "源目录: ${SCRIPT_DIR}"
    echo -e "目标目录: ${HOME_DIR}"

    for dir in "${SYNC_DIRS[@]}"; do
        sync_directory "${dir}"
    done

    echo -e "\n${GREEN}=== 同步完成 ===${NC}"
}

main
