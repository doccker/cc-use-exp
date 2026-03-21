"""
源代码扫描与收集模块

职责：项目语言检测、源文件收集、已有文档解析
"""

import re
import json
import fnmatch
from pathlib import Path

# ============== 语言配置 ==============

# 语言配置：扩展名 -> (语言名, 优先目录列表, 排除模式列表)
LANGUAGE_CONFIG = {
    'java': {
        'extensions': ['.java'],
        'priority_dirs': [
            'src/main/java/**/controller',
            'src/main/java/**/service',
            'src/main/java/**/entity',
            'src/main/java/**/repository',
            'src/main/java/**/config',
            'src/main/java/**/security',
            'src/main/java/**/dto',
            'src/main/java',
        ],
        'exclude_patterns': ['*Test.java', '*IT.java', '*Tests.java'],
        'exclude_dirs': ['target', 'build', '.gradle'],
    },
    'typescript': {
        'extensions': ['.ts', '.tsx', '.vue'],
        'priority_dirs': [
            'src/api',
            'src/stores',
            'src/pages',
            'src/views',
            'src/components',
            'src/hooks',
            'src/utils',
            'src/layouts',
            'frontend/src/api',
            'frontend/src/stores',
            'frontend/src/pages',
            'frontend/src/views',
            'frontend/src/components',
            'frontend/src',
            'src',
        ],
        'exclude_patterns': ['*.spec.ts', '*.test.ts', '*.spec.tsx', '*.test.tsx', '*.d.ts'],
        'exclude_dirs': ['node_modules', 'dist', 'build', '.next'],
    },
    'cpp': {
        'extensions': ['.cpp', '.cc', '.cxx', '.hpp', '.h'],
        'priority_dirs': ['src', 'include', 'lib'],
        'exclude_patterns': ['*_test.cpp', '*_test.cc', '*_test.h'],
        'exclude_dirs': ['build', 'cmake-build-debug', 'cmake-build-release', 'test', 'tests'],
    },
    'ruby': {
        'extensions': ['.rb'],
        'priority_dirs': ['app/controllers', 'app/models', 'app/services', 'lib', 'app'],
        'exclude_patterns': ['*_spec.rb', '*_test.rb'],
        'exclude_dirs': ['spec', 'test', 'vendor'],
    },
    'rust': {
        'extensions': ['.rs'],
        'priority_dirs': ['src'],
        'exclude_patterns': ['*_test.rs'],
        'exclude_dirs': ['target', 'tests'],
    },
    'go': {
        'extensions': ['.go'],
        'priority_dirs': ['cmd', 'internal', 'pkg', '.'],
        'exclude_patterns': ['*_test.go'],
        'exclude_dirs': ['vendor', 'testdata'],
    },
    'python': {
        'extensions': ['.py'],
        'priority_dirs': ['src', 'app', 'lib', '.'],
        'exclude_patterns': ['test_*.py', '*_test.py', 'conftest.py'],
        'exclude_dirs': ['tests', 'test', '__pycache__', '.venv', 'venv', '.pytest_cache'],
    },
}

# 项目检测文件
PROJECT_DETECT = {
    'pom.xml': 'java',
    'build.gradle': 'java',
    'package.json': 'typescript',
    'Cargo.toml': 'rust',
    'Gemfile': 'ruby',
    'go.mod': 'go',
    'CMakeLists.txt': 'cpp',
    'requirements.txt': 'python',
    'pyproject.toml': 'python',
}


def find_existing_docx(output_dir):
    """查找已有的 .docx 文件"""
    if not output_dir.exists():
        return []
    return list(output_dir.glob('*-源代码*.docx'))


def parse_used_files_from_docx(docx_path):
    """从已有的 .docx 文件中解析已使用的文件列表"""
    from docx import Document

    used_files = set()
    try:
        doc = Document(docx_path)
        for para in doc.paragraphs:
            text = para.text.strip()
            if '==========' in text:
                match = re.search(r'={5,}\s*(.+?)\s*={5,}', text)
                if match:
                    filename = match.group(1).strip()
                    if filename:
                        used_files.add(filename)
    except Exception as e:
        print(f"警告: 解析 {docx_path} 失败: {e}")

    return used_files


def detect_project_languages(project_root):
    """检测项目使用的语言"""
    detected = set()
    root = Path(project_root)

    for filename, lang in PROJECT_DETECT.items():
        if (root / filename).exists():
            detected.add(lang)

    for subdir in ['frontend', 'client', 'web', 'app', 'ui']:
        subpath = root / subdir
        if subpath.exists():
            for filename, lang in PROJECT_DETECT.items():
                if (subpath / filename).exists():
                    detected.add(lang)

    if not detected:
        for ext_lang, config in LANGUAGE_CONFIG.items():
            for ext in config['extensions']:
                if list(root.rglob(f'*{ext}'))[:1]:
                    detected.add(ext_lang)
                    break

    return list(detected)


def read_project_info(project_root):
    """读取项目名称和版本"""
    root = Path(project_root)
    name, version = None, None

    for claude_path in [root / '.claude' / 'CLAUDE.md', root / 'CLAUDE.md']:
        if claude_path.exists():
            content = claude_path.read_text(encoding='utf-8')
            name_match = re.search(r'^#\s+(.+?)(?:\s*[-–—]|\n)', content, re.MULTILINE)
            if name_match:
                name = name_match.group(1).strip()
            version_match = re.search(r'版本[：:]\s*[vV]?([\d.]+)', content)
            if version_match:
                version = f"V{version_match.group(1)}"
            if name:
                break

    if not name:
        pkg_path = root / 'package.json'
        if pkg_path.exists():
            try:
                pkg = json.loads(pkg_path.read_text(encoding='utf-8'))
                name = pkg.get('name', '').replace('-', ' ').replace('_', ' ').title()
                version = f"V{pkg.get('version', '1.0')}"
            except (json.JSONDecodeError, OSError):
                pass

    if not name:
        pom_path = root / 'pom.xml'
        if pom_path.exists():
            try:
                content = pom_path.read_text(encoding='utf-8')
                art_match = re.search(r'<artifactId>([^<]+)</artifactId>', content)
                ver_match = re.search(r'<version>([^<]+)</version>', content)
                if art_match:
                    name = art_match.group(1).replace('-', ' ').replace('_', ' ').title()
                if ver_match:
                    version = f"V{ver_match.group(1)}"
            except OSError:
                pass

    return name, version or 'V1.0'


def should_exclude(filepath, config):
    """检查文件是否应该排除"""
    path = Path(filepath)

    for exclude_dir in config.get('exclude_dirs', []):
        if exclude_dir in path.parts:
            return True

    filename = path.name
    for pattern in config.get('exclude_patterns', []):
        if fnmatch.fnmatch(filename, pattern):
            return True

    return False


def collect_source_files(project_root, languages):
    """收集源代码文件"""
    root = Path(project_root)
    files = []

    for lang in languages:
        config = LANGUAGE_CONFIG.get(lang, {})
        extensions = config.get('extensions', [])
        priority_dirs = config.get('priority_dirs', ['.'])

        for pdir in priority_dirs:
            if '**' in pdir:
                base, pattern = pdir.split('**')
                base_path = root / base.rstrip('/')
                if base_path.exists():
                    for subdir in base_path.iterdir():
                        if subdir.is_dir() and subdir.name.endswith(pattern.lstrip('/')):
                            for ext in extensions:
                                for f in sorted(subdir.rglob(f'*{ext}')):
                                    if not should_exclude(f, config):
                                        files.append((f.name, lang, f))
            else:
                dir_path = root / pdir
                if dir_path.exists() and dir_path.is_dir():
                    for ext in extensions:
                        for f in sorted(dir_path.rglob(f'*{ext}')):
                            if not should_exclude(f, config):
                                files.append((f.name, lang, f))

    seen = set()
    unique_files = []
    for name, lang, path in files:
        if path not in seen:
            seen.add(path)
            unique_files.append((name, lang, path))

    return unique_files


def read_file_lines(filepath):
    """读取文件内容"""
    try:
        content = Path(filepath).read_text(encoding='utf-8')
        lines = content.split('\n')
        while lines and lines[-1].strip() == '':
            lines.pop()
        return lines
    except (OSError, UnicodeDecodeError):
        return []
