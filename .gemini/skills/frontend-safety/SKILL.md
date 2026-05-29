---
name: frontend-safety
description: 前端修改安全约束。当用户修改 Vue/React 组件、调整页面布局、创建覆盖层/蒙版组件时激活。提供数据绑定保护、布局一致性规范、覆盖层定位规范。
---
<instructions>

# 前端修改安全约束

修改 Vue/React 文件时，必须遵守以下规则，防止破坏已有功能。

## 绝对禁止修改（除非明确要求重构逻辑）

| 类型 | 说明 | 示例 |
|------|------|------|
| 数据绑定 | v-model / v-bind 的字段名 | `v-model="form.username"` |
| Props | props 定义和传递的属性名 | `:user-id="userId"` |
| 事件 | emit 事件名和 @ 绑定 | `@click="handleSubmit"` |
| 响应式变量 | ref / reactive 变量名 | `const loading = ref(false)` |
| API 调用 | 接口路径、参数、响应处理 | `api.getUser(id)` |
| 类型定义 | TypeScript interface/type | `interface User { ... }` |
| 函数名 | 已有的方法和函数名 | `function handleSubmit()` |

## 允许修改

| 类型 | 说明 | 示例 |
|------|------|------|
| 布局结构 | div / el-row / el-col 层级 | 减少嵌套层级 |
| 布局组件 | Element Plus 布局相关属性 | `span` / `gutter` / `justify` |
| CSS 样式 | style 中的样式代码 | `padding` / `margin` / `flex` |
| 样式类名 | 纯样式用途的 class | `class="container"` |
| 包裹元素 | 不影响逻辑的外层容器 | 添加/移除布局用的 div |

---

# 1. 布局稳定性与对齐规范 (Layout Stability & Alignment)

解决“按钮跳动”、“垂直堆叠”和“横向挤压”问题。

- **表格行网格化 (Grid for Rows)**：对于包含多个操作点且对齐要求极高的行（如模型列表行），**强制使用 CSS Grid**。
  - 通过 `grid-template-columns` 预定义列宽（如 `grid-template-columns: 40px minmax(200px, 1fr) 100px 120px auto;`）。
  - 这能确保 [勾选]、[名称]、[状态]、[开关]、[按钮组] 在全站不同站点卡片中保持绝对垂直对齐，不受文本长度干扰。
- **操作区右对齐**：操作按钮组应使用 `margin-left: auto` 强制推向行末，或占据 Grid 的最后一列。
- **缓存防御性样式 (Inline Override)**：若外部 CSS 修改因缓存或优先级（Naive UI 等）多次失效，允许在组件根元素使用 Vue `:style` 注入关键布局。
  - **安全性要求**：属性名必须为驼峰式（如 `whiteSpace`），字符串值必须带引号（如 `'nowrap'`），并视情况添加 `!important`。

---

# 2. UI 审美与组件一致性规范

解决“图标不居中”、“样式脱靶”和“风格不统一”问题。

- **操作舱布局 (Capsule UI)**：批量操作区（如“全选”、“批量测试”）应整合为圆角（如 30px）的深/浅色胶囊形容器，并与筛选栏保持逻辑分区。
- **选择器精准覆盖 (Scoped CSS)**：修改第三方组件样式时：
  - **并列关系**：`.menu.el-menu--collapse` 修改当前节点。
  - **嵌套关系**：`.menu :deep(.el-menu-item)` 穿透修改子节点。
- **状态颜色语义化**：
  - 响应时间：< 500ms（绿色），500-2000ms（黄色），> 2000ms（红色）。
  - 站点健康度：左侧垂直状态条颜色应与站点可用性状态联动。
- **绝对居中算法**：在收起状态（Collapse）的菜单中，必须彻底剥离默认的 `padding` 和 `margin` 偏移。
    - **公式**：容器（如 64px） - 选中块（如 44px） = 左右留白各 10px。使用 `margin: 4px auto` 强制居中。
- **视觉降噪原则**：
    - **冗余隐藏**：当侧边栏收起且支持“点击 Logo 展开”时，应主动隐藏边缘的悬浮折叠按钮，避免视觉重叠。
    - **呼吸感**：在窄空间（如 64px 侧边栏）内，背景块不宜过大（推荐 40px-44px），确保存留足够的“呼吸空间”。
    - 
---

# 3. 工程执行逻辑与数据契约

解决“点击无反应”、“事件丢失”、“TS 编译错误”及“幻觉属性”问题。

- **事件名双向契约 (Event Contract Verification)**：
  - 修改父组件监听器前，**必须** `read_file` 子组件确认 `defineEmits` 中的真实键名。
  - 修改子组件派发名前，**必须** `grep_search` 父组件确认所有引用点。
  - **禁止猜测**：严禁将 `@test` 盲目修正为 `@test-model`，除非已核实两者完全对齐。
- **类型契约审计 (Type Contract Verification) ⚠️重要**：
  - **禁止幻觉调用**：在 Vue 模板或逻辑中调用对象深层属性（如 `user.nickname`、`item.config.url`）之前，**必须**使用 `read_file` 或 `grep_search` 核实相关的 `interface / type` 定义。
  - **遵循上游**：严禁凭直觉或常理（"通常应该有这个字段"）捏造属性调用。如果需要新字段，必须先修改全局/局部的类型定义（`.ts` 文件）及后端契约，最后再修改 Vue 模板。
- **内联样式安全检查**：在 Vue 模板中使用 `:style` 时，严禁出现 `white-space: nowrap`（连字符语法在对象中是非法的），必须转换为 `whiteSpace: 'nowrap'`。
- **写入安全**：大段代码更新强制使用 `write_file`，确保符号 `${}` 不被误解析。

---

# 4. UI 诊断与重构工作流

遇到布局异常或用户反馈“挤在一起/没反应”时：

1. **协议审计**：优先检查父子组件的事件监听名是否匹配，排除“通信断裂”。
2. **结构扁平化**：移除不必要的嵌套 `div`，让 Flex/Grid 直接作用于核心交互元素。
3. **样式提权**：检查是否存在样式被第三方库覆盖的情况，必要时使用内联样式强制执行布局逻辑。
4. **响应式自愈**：在窄屏下检查 `flex-nowrap` 是否导致溢出，必要时切换为 `flex-wrap` 或使用 `overflow-x: auto`。

---

# 修改前检查清单 (Checklist)

修改前端组件前，必须确认：
- [ ] **类型审计**：调用的深层对象属性（如 `data.xxx`）是否已在 `types` 接口中被明确定义，严禁直觉猜测。
- [ ] **事件对齐**：父组件监听的 `@event` 与子组件 `emit('event')` 命名称是否 100% 匹配。
- [ ] **Grid 对齐**：复杂行布局是否已预定义 Grid 列宽以防止横向挤压。
- [ ] **内联校验**：若使用 `:style`，属性名是否为驼峰，值是否已加引号，无语法错误。
- [ ] **异步保护**：数据展示（如 `item.api_key`）是否有空值兜底，防止渲染崩溃。
- [ ] **代码完整性**：替换的代码片段是否语法完整，不含任何 `...` 占位符。

</instructions>