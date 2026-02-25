---
paths: "**/*.{go,java,vue,tsx,jsx,ts,js,py}"
---
# 文件行数限制

> 控制单文件复杂度，减少 token 消耗，提升可维护性。

---

## 行数上限

| 语言 | 上限 | 说明 |
|------|------|------|
| Java | 300 行 | Spring 分层清晰，超过说明职责过多 |
| Go | 400 行 | 错误处理导致偏长，但超过 400 应拆分 |
| Vue | 200 行 | 样式已抽到 assets/styles，模板+逻辑 200 行足够 |
| TSX/JSX | 200 行 | 同 Vue |
| TypeScript/JS | 300 行 | 工具类、服务类 |
| Python | 300 行 | 模块化拆分 |

## 超限时的处理

**新建文件时**：预估超限则提前拆分，不要写完再拆

**修改现有文件时**：
- 不强制重构现有大文件
- 新增功能如果会导致超限，拆到新文件

## 拆分指引

| 语言 | 拆分方式 |
|------|---------|
| Java | Service 拆分职责、提取 Helper/Converter 类 |
| Go | 按功能拆分同包文件（如 `user_query.go`、`user_update.go`） |
| Vue | 提取子组件、composables、样式到 assets/styles |
| TS/JS | 提取工具函数、常量、类型到独立文件 |
