---
name: ruanzhu
description: 当用户执行 /ruanzhu 命令或请求生成软著源代码文档时触发。提供软著源代码 DOCX 生成规范。
version: v1.3
---

# ruanzhu 技能 - 软著源代码DOCX生成

## ⚠️ 强制执行规则

**必须执行以下命令，禁止任何其他操作：**

```bash
cp ~/.claude/templates/ruanzhu/generate_docx.py ./generate_docx.py && python3 generate_docx.py $ARGUMENTS && rm generate_docx.py
```

### 禁止事项

- ❌ 自行编写生成脚本
- ❌ 在项目中创建任何 `.py` 文件
- ❌ 检测 python-docx 是否安装
- ❌ 创建 venv 或手动安装依赖
- ❌ 搜索项目中的文件
- ❌ 执行项目中已有的任何脚本

### 唯一允许的操作

✅ 执行上面的 bash 命令（一条命令，用 && 连接）

### 执行后状态

- ✅ 生成 `docs/ruanzhu/{软件名称}{版本}-源代码.docx`
- ✅ 使用 `--different` 时，生成 `{软件名称}{版本}-源代码-2.docx`（编号递增）
- ✅ 项目中**不应有任何新增的 .py 文件**
- ✅ 临时脚本 `./generate_docx.py` 已被删除

---

## 参考信息（仅供了解，不要自行实现）

以下内容已由 `generate_docx.py` 脚本实现，**不需要手动处理**：

### 项目信息检测

按优先级读取项目名称和版本：

```python
# 优先级 1: CLAUDE.md
# 查找 "# {项目名}" 或 "## 项目概述" 下的内容
# 版本：查找 "版本：" 或 "version:"

# 优先级 2: package.json
{
  "name": "project-name",
  "version": "1.0.0"
}

# 优先级 3: pom.xml
<artifactId>project-name</artifactId>
<version>1.0.0</version>

# 优先级 4: 用户输入
```

### 2. 检测项目语言

根据文件存在性判断：

| 检测文件 | 语言 |
|---------|------|
| `pom.xml` 或 `build.gradle` | Java |
| `package.json` | JavaScript/TypeScript |
| `Cargo.toml` | Rust |
| `Gemfile` | Ruby |
| `go.mod` | Go |
| `*.cpp` 或 `CMakeLists.txt` | C++ |
| `requirements.txt` 或 `pyproject.toml` | Python |

### 3. 源代码扫描规则

#### Java
```
优先目录：
  - src/main/java/**/controller/
  - src/main/java/**/service/
  - src/main/java/**/entity/
  - src/main/java/**/repository/
  - src/main/java/**/config/
  - src/main/java/**/security/
  - src/main/java/**/dto/
  - src/main/java/**/

排除：
  - *Test.java
  - *IT.java
  - *Tests.java
  - target/
```

#### TypeScript/Vue/React
```
优先目录：
  - src/api/
  - src/stores/
  - src/pages/
  - src/views/
  - src/components/
  - src/hooks/
  - src/utils/
  - src/layouts/
  - frontend/src/

排除：
  - *.spec.ts
  - *.test.ts
  - *.test.tsx
  - *.d.ts
  - node_modules/
  - dist/
```

#### C++
```
优先目录：
  - src/
  - include/
  - lib/

排除：
  - *_test.cpp
  - *_test.cc
  - test/
  - tests/
  - build/
```

#### Ruby
```
优先目录：
  - app/controllers/
  - app/models/
  - app/services/
  - lib/

排除：
  - *_spec.rb
  - *_test.rb
  - spec/
  - test/
```

#### Rust
```
优先目录：
  - src/

排除：
  - tests/
  - *_test.rs
  - target/
```

#### Go
```
优先目录：
  - cmd/
  - internal/
  - pkg/
  - ./

排除：
  - *_test.go
  - vendor/
```

#### Python
```
优先目录：
  - src/
  - app/
  - lib/
  - ./

排除：
  - test_*.py
  - *_test.py
  - tests/
  - __pycache__/
  - .venv/
```

### 4. 页数控制

#### 固定页数模式（默认60页）
- 每页约57行渲染行（考虑长行换行）
- 按优先级扫描，达到目标行数后停止
- 不足则输出全部

#### 自动模式（auto）
- 总页数 ≤ 60：输出全部
- 总页数 > 60：输出前30页 + 后30页，中间标注省略

### 5. 渲染行数计算

```python
def estimate_rendered_lines(text, usable_width_cm=15.5):
    """估算一行文本在Word中渲染需要的行数"""
    if len(text) == 0:
        return 1
    width = 0
    for ch in text:
        if ord(ch) > 127:  # 中文字符
            width += 0.35
        else:  # 英文/符号
            width += 0.18
    return max(1, int(width / usable_width_cm) + (1 if width % usable_width_cm > 0.1 else 0))
```

### 6. DOCX格式规范

```
页面：A4 (21cm x 29.7cm)
边距：上2.5cm, 下2.5cm, 左3.0cm, 右2.5cm
字体：宋体 + Courier New, 10pt
行距：单倍行距

页眉：
  - 左侧：{软件名称} {版本}（加粗）
  - 居中：第 X 页共 Y 页
  - 底部：下划线

页脚：
  - 居中：第 X 页
```

### 7. 输出

- 目录：`docs/ruanzhu/`（不存在则创建）
- 文件名：`{软件名称}{版本}-源代码.docx`
- 示例：`贸易订单管理系统V1.0-源代码.docx`

## 错误处理

| 错误 | 处理 |
|------|------|
| 无法检测项目信息 | 提示用户输入 |
| 未检测到源代码 | 报错并列出支持的语言 |
| python-docx 未安装 | 自动 pip install 安装 |
| 代码量不足 | 警告并输出全部 |
