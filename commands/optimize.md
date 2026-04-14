---
description: 系统优化扫描（full/ux/perf/code 四种模式）
allowed-tools: Bash(git ls-files:*), Bash(git diff:*), Bash(git status:*), Bash(git log:*), Bash(git stash:*), Bash(git checkout:*), Bash(go build:*), Bash(go test:*), Bash(go vet:*), Bash(npm run build:*), Bash(npm test:*), Bash(npx vue-tsc:*), Bash(mvn compile:*), Bash(mvn test:*), Bash(wc:*), Bash(python -m pytest:*), Read, Glob, Grep, Edit, Write, Agent, WebSearch
argument-hint: "[ux|perf|code] 默认 full 全量扫描"
---

根据参数选择扫描模式：

- `/optimize` 或 `/optimize full` → 六维全量评估
- `/optimize ux` → 仅 UX 与操作费力度
- `/optimize perf` → 仅性能与中间件评估
- `/optimize code` → 仅代码质量、语法糖与冗余

参数值：「$ARGUMENTS」

---

## 第 0 步：范围选择

使用 AskUserQuestion 询问扫描范围：

```
请选择扫描范围：

1. 全量扫描（前端 + 后端）
   扫描所有代码，token 消耗较大（项目越大消耗越多），
   适合里程碑节点或季度优化。

2. 仅后端
   只扫描 Go/Java/Python 等后端代码。

3. 仅前端
   只扫描 Vue/React/TS 等前端代码。

4. 指定目录
   用户输入目录路径，只扫描指定模块。
```

用户选择「全量扫描」时，先统计规模并提示：

```bash
# 统计文件数和行数
git ls-files --exclude-standard | head -500
git ls-files --exclude-standard | xargs wc -l 2>/dev/null | tail -1
```

输出提示：
```
⚠️ 全量扫描预估：
  - 文件数：XX 个
  - 总行数：约 XXXX 行
  - 预计消耗 tokens 较多，确认继续？(Y/N)
```

用户确认后进入第 1 步。

---

## 第 1 步：项目画像

扫描项目基本信息，输出概览表：

### 扫描内容

1. **技术栈识别**：读取 `go.mod`（Go 版本）、`package.json`（Vue/React/Node 版本）、`pom.xml`（Java 版本）、`requirements.txt`/`pyproject.toml`（Python 版本）
2. **框架识别**：Gin/Echo/Fiber、Spring Boot、Vue/React、Element Plus/Ant Design
3. **数据库**：搜索 SQLite/MySQL/PostgreSQL 连接配置
4. **已用中间件**：搜索 Redis/MQ/MinIO/ES 的 import 和配置
5. **文件规模统计**：按语言分类统计文件数和行数
6. **大文件检测**：按语言阈值（Go 400行 / Vue 200行 / Java 300行 / TS/JS 300行 / Python 300行）

### 输出格式

```markdown
## 项目概览

| 项 | 值 |
|---|---|
| 技术栈 | Go 1.22 + Gin / Vue 3.4 + Element Plus 2.7 |
| 数据库 | SQLite / MySQL |
| 已用中间件 | Redis |
| 后端文件 | XX 个，约 XXXX 行 |
| 前端文件 | XX 个，约 XXXX 行 |
| 大文件(>阈值) | X 个 |
```

---

## 第 2 步：六维评估

根据模式参数决定执行哪些维度：

| 模式 | 执行维度 |
|------|---------|
| `full` | UX + PERF + CODE + SUGAR + SEC + BEST |
| `ux` | UX |
| `perf` | PERF + BEST（中间件相关） |
| `code` | CODE + SUGAR |

---

### 维度 1：[UX] 用户体验与操作费力度

#### 前端扫描

| 检查项 | 扫描方法 | 判定标准 |
|--------|---------|---------|
| 表单防重复提交 | 搜索 `<el-form>` / `<form>` 的提交处理 | 提交函数无 loading 状态控制 → 问题 |
| 列表空状态 | 搜索 `<el-table>` / `v-for` 列表 | 无 `<el-empty>` 或 empty slot → 问题 |
| 加载状态 | 搜索 API 调用处 | 无 loading / skeleton 反馈 → 问题 |
| 错误提示 | 搜索 `catch` 块 | `console.log` 吞错误，无用户提示 → 问题 |
| 表单校验 | 搜索 `<el-form>` | 无 `:rules` 或规则为空 → 问题 |
| 批量操作 | 搜索列表页 | 仅逐条操作，无批量选择能力 → 建议 |
| 响应式布局 | 搜索 `@media` / `:span` / `:xs` | 无任何响应式处理 → 建议 |

#### 后端扫描

| 检查项 | 扫描方法 | 判定标准 |
|--------|---------|---------|
| 接口响应格式 | 搜索 handler 返回结构 | 不统一（有的 `{code,data}` 有的裸返回）→ 问题 |
| 分页支持 | 搜索列表查询接口 | 返回全量数据无分页 → 问题 |
| 参数校验 | 搜索 handler 入参 | 无 `binding:"required"` 或手动校验 → 建议 |

---

### 维度 2：[PERF] 性能与中间件评估

#### 数据库性能

| 检查项 | 扫描方法 | 判定标准 |
|--------|---------|---------|
| N+1 查询 | 搜索循环内的 DB 调用 | `for` 循环内有 `db.Find` / `db.First` → Critical |
| 全表查询 | 搜索无 Where 的 Find/Select | `db.Find(&all)` 无条件无分页 → Critical |
| 缺失索引 | 读取 model struct tag | 外键和常用查询字段无 `index` tag → Important |
| 慢查询日志 | 搜索 GORM 配置 | 未配置 `SlowThreshold` → 建议 |
| 连接池 | 搜索 DB 配置 | 未设置 `MaxOpenConns` / `MaxIdleConns` → 建议 |

#### 前端性能

| 检查项 | 扫描方法 | 判定标准 |
|--------|---------|---------|
| 路由懒加载 | 搜索 router 配置 | 使用 `import Xxx from` 而非 `() => import()` → 问题 |
| 大依赖 | 读取 package.json | 检查 moment.js / lodash 全量引入 → 建议替代 |
| 图片优化 | 搜索静态资源 | 大图片（>500KB）未压缩 → 建议 |

#### 中间件评估矩阵

对以下中间件逐一评估，输出决策表：

**Redis 决策：**
- 扫描：搜索配置表/字典表的读取频率、session 管理方式、是否有热点查询
- 必要 → 高频读低频写的数据每次查库，且 QPS > 100
- 推荐 → 有配置/字典类数据每次查库，或 session 存数据库
- 不需要 → 数据变更频繁，或访问量很小

**MinIO（对象存储）决策：**
- 扫描：搜索 `os.WriteFile` / `ioutil.WriteFile` / `multipart` / `<el-upload>` / 本地 `uploads/` 目录
- 必要 → 文件上传 + 多实例/容器化部署
- 推荐 → 文件上传 + 单机但文件量大(>1GB) 或有 CDN 需求
- 不需要 → 无文件上传，或仅头像等小图且量极小

**Elasticsearch 决策：**
- 扫描：搜索 `LIKE '%keyword%'` / `.Where("name LIKE ?")` / 前端搜索框对应的后端实现
- 必要 → 模糊搜索 + 数据量 >10w + 多字段联合搜索
- 推荐 → 模糊搜索 + 数据量 >1w，或需要搜索建议/高亮/聚合
- 不需要 → 精确查询为主，或数据量 <1w 的简单 LIKE

**MQ（消息队列）决策：**
- 扫描：搜索耗时操作（发邮件 `smtp`/`gomail`、文件处理、外部 HTTP 调用）是否在请求链路中同步执行
- 必要 → 请求链路中有 >3s 的同步阻塞操作
- 推荐 → 有异步通知、日志收集、多服务解耦需求
- 不需要 → 无明显异步场景

**输出格式：**

```markdown
## 中间件评估

| 中间件 | 当前状态 | 建议 | 理由 |
|--------|---------|------|------|
| Redis | 未使用 | 推荐引入 | GetSysConfig() 每次查库，变更频率低 |
| MinIO | 未使用 | 推荐引入 | 文件存本地 ./uploads/，容器化有风险 |
| Elasticsearch | 未使用 | 暂不需要 | 搜索场景简单，数据量 <1w |
| MQ | 未使用 | 暂不需要 | 无明显异步阻塞场景 |
```

---

### 维度 3：[CODE] 代码质量与组件抽取

| 检查项 | 扫描方法 | 判定标准 |
|--------|---------|---------|
| **前端重复组件** | 搜索相似的模板结构（相同 el- 组件组合出现 ≥2 次） | 多页面有相同布局 → 应抽取公共组件 |
| **前端重复逻辑** | 搜索相同的 API 调用 + 分页 + 搜索模式 | ≥2 处相同 CRUD 模式 → 应抽取 composable |
| **后端重复代码** | 搜索 service 层相同的 查询+校验+更新 模式 | ≥3 个 service 相同模式 → 建议泛型封装 |
| **前后端重复定义** | 对比后端 struct/DTO 和前端 interface/type | 同一实体两端各定义，字段不一致 → 问题 |
| **上帝文件** | 按语言阈值检测超大文件 | 超过阈值 → 给出拆分建议 |
| **死代码** | 搜索未被 import 的 exported 函数、未使用的组件文件 | 存在 → 建议删除 |
| **硬编码** | 搜索魔法数字、硬编码 URL、写死的配置值 | 存在 → 建议提取常量或配置 |

**组件抽取建议输出格式：**

```markdown
## 组件抽取建议

| 当前位置 | 建议抽取为 | 复用次数 | 预计减少行数 |
|---------|-----------|---------|------------|
| views/user/Detail, views/order/Detail | components/DetailCard.vue | 3 | ~100 行 |
| api/user.ts, api/order.ts 的错误处理 | utils/request.ts | 8 | ~60 行 |
| service/user.go, service/order.go CRUD | pkg/base/service.go (泛型) | 4 | ~200 行 |
```

---

### 维度 4：[SUGAR] 语法糖与现代化写法

读取项目的语言版本后，按以下检查表扫描：

#### Go（读 go.mod 的 `go 1.xx`）

| 版本要求 | 检查项 | 旧写法特征 | 新写法 |
|---------|--------|-----------|--------|
| 1.21+ | slices 包 | 手写 Contains/Filter/Map 工具函数 | `slices.Contains()` 等标准库 |
| 1.21+ | slog 结构化日志 | `log.Println` / `fmt.Println` | `slog.Info()` |
| 1.21+ | min/max 内置函数 | 手写 `if a > b { return a }` | `max(a, b)` |
| 1.22+ | range 整数 | `for i := 0; i < n; i++` | `for i := range n` |
| 1.22+ | http 路由增强 | 简单 mux + 手动路径匹配 | `http.HandleFunc("GET /api/{id}")` |
| 1.23+ | iter 迭代器 | 手写迭代逻辑 | `iter.Seq` / `iter.Seq2` |

#### Java（读 pom.xml 的 `<java.version>`）

| 版本要求 | 检查项 | 旧写法特征 | 新写法 |
|---------|--------|-----------|--------|
| 17+ | record | 纯数据 class（只有 getter/setter） | `record UserDTO(String name, int age)` |
| 17+ | sealed class | 大量 instanceof 判断 | sealed + pattern matching |
| 17+ | switch 表达式 | 多层 if-else 或 switch-case + break | `switch` 表达式 + `->` |
| 17+ | text block | 多行字符串拼接 | `"""` 文本块 |
| 21+ | virtual threads | `new Thread()` / 自建线程池处理简单任务 | `Thread.ofVirtual()` |

#### Vue / TypeScript（读 package.json 版本）

| 版本要求 | 检查项 | 旧写法特征 | 新写法 |
|---------|--------|-----------|--------|
| Vue 3.3+ | defineOptions | 单独的 `<script>` 块定义 name | `defineOptions({ name: 'Xxx' })` |
| Vue 3.4+ | defineModel | `props` + `emit('update:modelValue')` | `const model = defineModel<T>()` |
| Vue 3.5+ | useTemplateRef | `ref<HTMLElement>()` + `ref="xxx"` | `useTemplateRef('xxx')` |
| TS 5.0+ | satisfies | `as const` + 类型断言 | `satisfies` 操作符 |
| ES2023+ | 数组新方法 | `arr[arr.length - 1]` | `arr.at(-1)` / `findLast()` / `toSorted()` |
| ES2024+ | Object.groupBy | 手写 reduce 分组 | `Object.groupBy()` |

#### Python（读 pyproject.toml / runtime 版本）

| 版本要求 | 检查项 | 旧写法特征 | 新写法 |
|---------|--------|-----------|--------|
| 3.10+ | match-case | 长链 if-elif | `match` 语句 |
| 3.10+ | 联合类型语法 | `Union[int, str]` | `int \| str` |
| 3.12+ | f-string 增强 | 复杂表达式需要临时变量 | f-string 内嵌任意表达式 |

---

### 维度 5：[SEC] 安全漏洞修正

#### 静态扫描（始终执行）

| 漏洞类型 | 扫描模式 | 修正方式 |
|---------|---------|---------|
| SQL 注入 | `fmt.Sprintf("SELECT.*%s")` / 字符串拼接 SQL / MyBatis `${}` | 改用参数化查询 |
| 命令注入 | `exec.Command` 参数含用户输入且未校验 | 白名单校验 + 参数转义 |
| 路径穿越 | `filepath.Join(userInput)` 无 `filepath.Clean` + 前缀校验 | 添加路径规范化和前缀校验 |
| XSS | `v-html` / `innerHTML` 使用未转义的用户数据 | 使用 DOMPurify 或移除 v-html |
| 硬编码密钥 | `password` / `secret` / `token` / `apikey` 的字符串字面量赋值 | 移至环境变量或配置文件 |
| CORS 宽松 | `AllowAllOrigins: true` / `Access-Control-Allow-Origin: *` | 明确指定允许的 origin |
| 不安全加密 | `md5` / `sha1` 用于密码存储 / `math/rand` 用于安全场景 | bcrypt/argon2 + crypto/rand |
| 不安全反序列化 | `json.Unmarshal` 到 `interface{}` 后无类型断言 / `yaml.Unmarshal` 未限制 | 明确目标类型 |

#### 可选联网（WebSearch 可用时）

检查 `go.mod` / `package.json` / `pom.xml` 中的依赖版本，用 WebSearch 查询是否存在已知 CVE：

```
搜索格式："{依赖名} {版本} CVE vulnerability"
仅报告 CVSS >= 7.0 的高危漏洞
给出升级建议版本
```

---

### 维度 6：[BEST] 业界实践参考

| 检查项 | 扫描方法 | 判定标准 |
|--------|---------|---------|
| 依赖版本 | 读 go.mod / package.json / pom.xml | 主要依赖落后 2+ 个大版本 → 建议升级 |
| 框架最佳实践 | 检查中间件配置 | Gin 缺 Recovery/Logger、GORM 缺慢查询日志 → 问题 |
| 项目结构 | 对比目录结构 | Go: 是否符合 Standard Layout；Vue: 是否按功能拆分 |
| API 设计 | 检查路由定义 | RESTful 不规范（动词路由、状态码不对）→ 建议 |
| 错误处理 | 搜索 error 处理方式 | Go: 未包装 error 丢失上下文；前端: 无全局拦截器 → 问题 |
| 日志规范 | 搜索日志调用 | 无结构化日志、无请求 tracing → 建议 |
| 配置管理 | 搜索配置加载方式 | 硬编码配置、无环境区分 → 问题 |

---

## 第 3 步：输出报告

### 优先级排序

```
[Critical]  — SEC 安全漏洞、PERF N+1/全表扫描、功能缺陷
[Important] — UX 体验问题、CODE 重复代码、PERF 中间件建议
[Nice]      — SUGAR 语法优化、BEST 实践建议
```

### 报告模板

```markdown
# 系统优化报告

## 项目概览
（第 1 步输出）

## 评估结果

### [Critical] 必须优化
1. **[维度]** `文件:行号` — 问题描述
   → 当前写法：...
   → 建议修正：...

### [Important] 建议优化
（同上格式）

### [Nice] 锦上添花
（同上格式）

## 组件抽取建议
| 当前位置 | 建议抽取为 | 复用次数 | 预计减少行数 |
|---------|-----------|---------|------------|

## 中间件评估
| 中间件 | 当前状态 | 建议 | 理由 |
|--------|---------|------|------|

## 语法糖升级
| 文件:行号 | 当前写法 | 建议写法 | 收益 |
|----------|---------|---------|------|

## 安全漏洞
| 文件:行号 | 漏洞类型 | 风险等级 | 修正方式 |
|----------|---------|---------|---------|

## 变更风险评估
| 优化项 | 风险等级 | 前置条件 |
|--------|---------|---------|

## 建议执行顺序
1. [低风险] ...
2. [中风险] ...
3. [高风险] ...
```

---

## 第 4 步：用户选择修复范围

报告输出后，使用 AskUserQuestion：

```
请选择修复方式：

1. 修复全部 Critical（推荐）
   仅修复安全漏洞和严重性能问题。范围最小，风险最低。

2. 修复 Critical + Important
   包含体验优化和代码重构。改动较大，
   部分项可能影响现有行为。

3. 我来选择要修的项
   逐项确认是否修复。

4. 仅保留报告
   不做任何修改，仅保留报告供参考。
```

用户选择 4 则结束。选择 1/2/3 进入第 5 步。

---

## 第 5 步：逐项修复 + 逐项验证

### 改前准备

```bash
# 记录当前状态
git stash list  # 确认 stash 干净
git status      # 确认工作区状态

# 运行现有测试作为基线
# Go:
go test ./... 2>&1 | tail -20
# 前端:
npm test 2>&1 | tail -20  # 如果有
npm run build 2>&1 | tail -5
```

记录基线结果（通过数、失败数、build 状态）。

### 逐项修复流程

对每一个待修复项，按以下流程执行：

```
1. 暂存当前状态
   git stash push -m "optimize-backup-{序号}"

2. 执行修复
   Edit 相关文件

3. 验证
   ├── 有测试 → 运行相关测试，对比基线
   │   ├── 通过 → git stash drop（丢弃备份），继续下一项
   │   └── 失败 → 回滚：
   │       git checkout -- {修改的文件}
   │       git stash pop
   │       标记该项为「需人工处理」，说明失败原因
   │
   └── 无测试 → 编译/构建验证
       ├── Go: go build ./...
       ├── 前端: npx vue-tsc --noEmit（类型检查）
       ├── 通过 → 继续，但标记为「无测试覆盖，需手动验证」
       │   并给出手动验证步骤：
       │   "请手动验证：打开 XX 页面 → 执行 XX 操作 → 预期 XX"
       └── 失败 → 回滚同上
```

### 注意事项

- 一项一改，一项一验证，不批量修改
- SEC 类修复优先级最高，先改安全问题
- SUGAR 类修复风险最低，最后改
- 每完成一项，报告进度

---

## 第 6 步：最终验证 + 变更汇总

### 全量验证

```bash
# 后端
go build ./...
go vet ./...
go test ./...

# 前端
npm run build
npx vue-tsc --noEmit  # 类型检查

# Java（如有）
mvn compile
mvn test

# Python（如有）
python -m pytest
```

### 输出对比表

```markdown
## 验证结果

| 检查项 | 改前 | 改后 | 状态 |
|--------|------|------|------|
| 后端编译 | ✅ | ✅ | 通过 |
| 后端测试 | 15/15 | 15/15 | 通过 |
| 前端构建 | ✅ | ✅ | 通过 |
| 类型检查 | ✅ | ✅ | 通过 |

## 变更汇总

### 已修复
| 序号 | 维度 | 文件 | 修改内容 |
|------|------|------|---------|

### 需人工处理
| 序号 | 维度 | 文件 | 原因 |
|------|------|------|------|

### 无测试覆盖（请手动验证）
| 序号 | 文件 | 验证步骤 |
|------|------|---------|
```
