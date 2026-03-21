#!/usr/bin/env python3
"""
软著源代码DOCX生成器

支持语言：Java, TypeScript/Vue, C++, Ruby, Rust, Go, Python

用法：
    python generate_docx.py [选项]

选项：
    --name, -n     软件名称（默认自动检测）
    --version, -v  版本号（默认 V1.0）
    --pages, -p    目标页数或 auto（默认 60）
    --root, -r     项目根目录（默认当前目录）

示例：
    python generate_docx.py
    python generate_docx.py --name "智能仓储系统" --version "V2.0"
    python generate_docx.py --pages auto

输出：docs/ruanzhu/{软件名称}{版本}-源代码.docx
依赖：python-docx（会自动安装）
"""

import re
import sys
import math
import argparse
import subprocess
from pathlib import Path

from code_scanner import (
    detect_project_languages,
    read_project_info,
    collect_source_files,
    find_existing_docx,
    parse_used_files_from_docx,
)
from docx_builder import (
    DOCX_CONFIG,
    estimate_rendered_lines,
    build_source_lines,
    generate_docx,
)


def ensure_docx_lib():
    """确保python-docx库可用"""
    try:
        import docx  # noqa: F401
        return True
    except ImportError:
        print("python-docx 未安装，正在安装...")

        result = subprocess.run(
            [sys.executable, '-m', 'pip', 'install', 'python-docx', '-q'],
            capture_output=True,
        )

        if result.returncode == 0:
            return True

        if b'externally-managed-environment' in result.stderr:
            print("检测到 Homebrew Python，使用 --break-system-packages 安装...")
            subprocess.run(
                [sys.executable, '-m', 'pip', 'install', 'python-docx', '-q', '--break-system-packages'],
                check=True,
            )
            return True

        raise RuntimeError(f"安装 python-docx 失败: {result.stderr.decode()}")


def main():
    parser = argparse.ArgumentParser(description='软著源代码DOCX生成器')
    parser.add_argument('--name', '-n', help='软件名称')
    parser.add_argument('--version', '-v', default='V1.0', help='版本号 (默认: V1.0)')
    parser.add_argument('--pages', '-p', default='60', help='目标页数或auto (默认: 60)')
    parser.add_argument('--root', '-r', default='.', help='项目根目录 (默认: 当前目录)')
    parser.add_argument('--different', '-d', action='store_true', help='生成与已有文档不同的内容')
    args = parser.parse_args()

    ensure_docx_lib()

    project_root = Path(args.root).resolve()
    print(f"项目目录: {project_root}")

    detected_name, detected_version = read_project_info(project_root)
    software_name = args.name or detected_name
    version = args.version if args.version != 'V1.0' else detected_version

    if not software_name:
        software_name = input("请输入软件名称: ").strip()
        if not software_name:
            print("错误: 未指定软件名称")
            sys.exit(1)

    print(f"软件名称: {software_name} {version}")

    languages = detect_project_languages(project_root)
    if not languages:
        print("错误: 未检测到支持的编程语言")
        print(f"支持的语言: java, typescript, cpp, ruby, rust, go, python")
        sys.exit(1)
    print(f"检测到语言: {', '.join(languages)}")

    print("扫描源代码文件...")
    source_files = collect_source_files(project_root, languages)
    print(f"找到 {len(source_files)} 个源文件")

    output_dir = project_root / 'docs' / 'ruanzhu'
    existing_docs = find_existing_docx(output_dir)
    used_files = set()
    is_different_mode = args.different

    if existing_docs and not is_different_mode:
        print(f"\n检测到已有文档: {len(existing_docs)} 个")
        for doc_path in existing_docs:
            print(f"  - {doc_path.name}")
        print("\n是否需要生成不同内容？（使用不同的源代码文件）")
        print("  1. 是（生成 -源代码-2.docx）")
        print("  2. 否（覆盖原文档）")
        choice = input("请选择 [1/2]: ").strip()
        if choice == '1':
            is_different_mode = True
            print("已选择: 生成不同内容\n")
        else:
            print("已选择: 覆盖原文档\n")

    if existing_docs and is_different_mode:
        for doc_path in existing_docs:
            doc_used = parse_used_files_from_docx(doc_path)
            used_files.update(doc_used)

        if used_files:
            print(f"已使用文件: {len(used_files)} 个")
            original_count = len(source_files)
            source_files = [
                (filename, lang, filepath)
                for filename, lang, filepath in source_files
                if filename not in used_files
            ]
            print(f"剩余可用文件: {len(source_files)} 个 (排除了 {original_count - len(source_files)} 个)")

    if not source_files:
        print("错误: 未找到源代码文件")
        sys.exit(1)

    lines_per_page = DOCX_CONFIG['lines_per_page']

    if args.pages.lower() == 'auto':
        all_lines, total_rendered = build_source_lines(source_files, float('inf'), mode='auto')
        total_pages = math.ceil(total_rendered / lines_per_page)
        print(f"总渲染行数: {total_rendered}, 总页数: {total_pages}")

        if total_pages <= 60:
            lines = all_lines
            is_split = False
        else:
            front_target = lines_per_page * 30
            back_target = lines_per_page * 30

            front = []
            front_count = 0
            for line in all_lines:
                rendered = estimate_rendered_lines(line)
                if front_count + rendered > front_target:
                    break
                front.append(line)
                front_count += rendered

            back = []
            back_count = 0
            for line in reversed(all_lines):
                rendered = estimate_rendered_lines(line)
                if back_count + rendered > back_target:
                    break
                back.insert(0, line)
                back_count += rendered

            lines = (front, back)
            is_split = True
            print(f"自动模式: 前30页 + 后30页 (省略 {total_pages - 60} 页)")
    else:
        try:
            target_pages = int(args.pages)
        except ValueError:
            print(f"错误: 页数参数无效: {args.pages}")
            sys.exit(1)
        target_rendered = target_pages * lines_per_page
        lines, total_rendered = build_source_lines(source_files, target_rendered, mode='fixed')
        actual_pages = math.ceil(total_rendered / lines_per_page)
        print(f"目标 {target_pages} 页, 实际约 {actual_pages} 页 ({total_rendered} 渲染行)")
        is_split = False
        total_pages = actual_pages

    output_dir.mkdir(parents=True, exist_ok=True)

    safe_name = re.sub(r'[<>:"/\\|?*]', '', software_name)
    base_name = f"{safe_name}{version}-源代码"

    if is_different_mode and existing_docs:
        existing_nums = [1]
        for doc_path in existing_docs:
            match = re.search(r'-源代码-(\d+)\.docx$', doc_path.name)
            if match:
                existing_nums.append(int(match.group(1)))
        next_num = max(existing_nums) + 1
        output_path = output_dir / f"{base_name}-{next_num}.docx"
    else:
        output_path = output_dir / f"{base_name}.docx"

    print(f"生成DOCX: {output_path}")
    generate_docx(lines, str(output_path), software_name, version, is_split, total_pages if is_split else 0)

    print(f"\n完成! 文件: {output_path}")
    print(f"页眉: {software_name} {version}")
    print(f"请在Word中打开确认页数")


if __name__ == '__main__':
    main()
