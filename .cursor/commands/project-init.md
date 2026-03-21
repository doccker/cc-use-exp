---
name: /project-init
id: project-init
category: 初始化
description: 为新项目初始化 Cursor 配置（生成 rules 和 skills 脚手架）
---

为当前项目生成 Cursor 配置。

## 项目信息收集

### 1. 基本信息

**项目名称**：从参数或目录名推断

**项目描述**（一句话）：
> 请描述这个项目是做什么的

### 2. 技术栈

**后端**（可多选）：
- [ ] Go + Gin
- [ ] Java + Spring Boot
- [ ] Node.js + Express
- [ ] Python + FastAPI
- [ ] 其他

**前端**（可多选）：
- [ ] Vue 3 + TypeScript
- [ ] React + TypeScript
- [ ] 无前端
- [ ] 其他

**数据库**：
- [ ] SQLite
- [ ] MySQL
- [ ] PostgreSQL
- [ ] MongoDB
- [ ] 其他

### 3. 项目约定

**启动方式**、**数据库迁移方式**、**特殊约定**

---

## 生成配置

根据收集的信息，在项目根目录生成：

1. `.cursor/rules/project.mdc` — 项目级规则（技术栈、约定、核心约束）
2. 建议从 cc-use-exp 同步通用规则和技能

### 项目规则模板

```markdown
---
description: [项目名称] 项目配置
alwaysApply: true
---
# [项目名称] 项目配置

## 技术栈

| 层级 | 技术 | 版本 |
|------|------|------|
| 后端 | [后端框架] | [版本] |
| 前端 | [前端框架] | [版本] |
| 数据库 | [数据库] | [版本] |

## 项目约定

| 约定 | 说明 |
|------|------|
| 启动方式 | [启动命令] |
| 数据库迁移 | [迁移方式] |

## 核心约束

**必须做的**：
- 发现类型错误和潜在 Bug
- 提示更优雅的写法
- 补充缺失的异常处理

**禁止做的**：
- 过度重构已工作的代码
- 添加未要求的功能
- 修改测试来匹配错误代码
```

## 完成后操作

1. 将生成的内容写入 `.cursor/rules/project.mdc`
2. 如果目录不存在，先创建 `.cursor/rules/`
3. 提示用户检查并调整
4. 建议运行 `./tools/sync-config.sh` 同步通用规则和技能
