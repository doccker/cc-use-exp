---
name: ruanzhu
description: >-
  当用户执行 /ruanzhu 命令或请求生成软著源代码文档时触发。提供软著源代码 DOCX 生成规范。
  覆盖项目信息检测、语言扫描规则、页数控制、DOCX 格式规范等。
---

# ruanzhu 技能 - 软著源代码DOCX生成

## 强制执行规则

**必须执行以下命令，禁止任何其他操作：**

```bash
cp ~/.cursor/templates/ruanzhu/generate_docx.py ./generate_docx.py && python3 generate_docx.py $ARGUMENTS && rm generate_docx.py
```

### 禁止事项

- 自行编写生成脚本
- 在项目中创建任何 `.py` 文件
- 检测 python-docx 是否安装
- 创建 venv 或手动安装依赖
- 搜索项目中的文件
- 执行项目中已有的任何脚本

### 唯一允许的操作

执行上面的 bash 命令（一条命令，用 && 连接）

### 执行后状态

- 生成 `docs/ruanzhu/{软件名称}{版本}-源代码.docx`
- 使用 `--different` 时，生成 `{软件名称}{版本}-源代码-2.docx`（编号递增）
- 项目中**不应有任何新增的 .py 文件**
- 临时脚本 `./generate_docx.py` 已被删除

---

## 参考信息（仅供了解，不要自行实现）

以下内容已由 `generate_docx.py` 脚本实现，**不需要手动处理**：

### 项目信息检测

按优先级读取项目名称和版本：
1. README.md / CLAUDE.md：查找标题和版本信息
2. package.json：`name` + `version`
3. pom.xml：`artifactId` + `version`
4. 用户输入

### 检测项目语言

| 检测文件 | 语言 |
|---------|------|
| `pom.xml` 或 `build.gradle` | Java |
| `package.json` | JavaScript/TypeScript |
| `Cargo.toml` | Rust |
| `Gemfile` | Ruby |
| `go.mod` | Go |
| `*.cpp` 或 `CMakeLists.txt` | C++ |
| `requirements.txt` 或 `pyproject.toml` | Python |

### 源代码扫描规则

**Java**: `src/main/java/**/controller/`、`service/`、`entity/` 等，排除 `*Test.java`

**TypeScript/Vue/React**: `src/api/`、`src/stores/`、`src/pages/` 等，排除 `*.spec.ts`、`node_modules/`

**Go**: `cmd/`、`internal/`、`pkg/`，排除 `*_test.go`、`vendor/`

**Python**: `src/`、`app/`、`lib/`，排除 `test_*.py`、`__pycache__/`

**C++**: `src/`、`include/`，排除 `*_test.cpp`、`build/`

**Ruby**: `app/controllers/`、`app/models/`，排除 `*_spec.rb`

**Rust**: `src/`，排除 `tests/`、`target/`

### 页数控制

- **固定页数模式**（默认60页）：每页约57行，按优先级扫描
- **自动模式**（auto）：≤60页输出全部，>60页输出前30+后30页

### DOCX格式规范

页面 A4，边距上下2.5cm、左3.0cm、右2.5cm，字体宋体+Courier New 10pt，单倍行距。

## 错误处理

| 错误 | 处理 |
|------|------|
| 无法检测项目信息 | 提示用户输入 |
| 未检测到源代码 | 报错并列出支持的语言 |
| python-docx 未安装 | 自动 pip install 安装 |
| 代码量不足 | 警告并输出全部 |
