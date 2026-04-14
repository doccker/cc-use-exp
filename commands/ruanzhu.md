# /ruanzhu - 软著源代码DOCX生成

**立即执行以下命令，不做任何检测、搜索或判断：**

```bash
cp ~/.claude/templates/ruanzhu/generate_docx.py ./generate_docx.py && python3 generate_docx.py $ARGUMENTS && rm generate_docx.py
```

## 参数映射

| 用户输入 | $ARGUMENTS |
|---------|-----------|
| `/ruanzhu` | （空） |
| `/ruanzhu "名称"` | `--name "名称"` |
| `/ruanzhu "名称" 80` | `--name "名称" --pages 80` |
| `/ruanzhu "名称" auto` | `--name "名称" --pages auto` |

## 禁止事项

- ❌ 检测 python-docx 是否安装
- ❌ 搜索项目中的文件
- ❌ 执行项目中已有的任何脚本
- ❌ 创建 venv 或手动安装依赖
- ❌ 自行编写生成逻辑

## 唯一允许的操作

✅ 执行上面的 bash 命令（一条命令，用 && 连接）

## 说明

脚本会自动：
- 检测项目语言和源代码
- 如果已有文档，询问用户是否生成不同内容
- 生成符合软著要求的 DOCX 文件
