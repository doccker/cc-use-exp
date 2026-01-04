---
description: 从代码或设计图提取样式变量
allowed-tools: Read, Grep, Glob
---

从 Vue 组件或设计图中提取样式规范。

## 输入

「$ARGUMENTS」

**支持的输入类型**：
| 输入 | 示例 | 说明 |
|------|------|------|
| 目录 | `web/src` | 扫描所有样式文件 |
| 文件 | `Card.vue` | 分析单个组件 |
| 图片 | `design.png` | 识别设计稿样式 |
| 空 | | 默认扫描 `web/src` |

---

## 模式 A：代码提取（目录/文件）

### A1. 扫描样式文件

查找以下文件：
- `*.vue` 中的 `<style>` 块
- `*.css` / `*.scss` 文件
- Element Plus 主题变量覆盖

### A2. 提取变量

| 类别 | 提取内容 |
|------|---------|
| 颜色 | `--el-color-*`、自定义颜色变量 |
| 字体 | `font-size`、`font-family`、`font-weight` |
| 间距 | `padding`、`margin`、`gap` 常用值 |
| 圆角 | `border-radius` 常用值 |
| 阴影 | `box-shadow` 定义 |

### A3. 输出 JSON

```json
{
  "source": "代码提取",
  "path": "[扫描路径]",
  "colors": {
    "primary": "#409EFF",
    "success": "#67C23A",
    "warning": "#E6A23C",
    "danger": "#F56C6C"
  },
  "typography": {
    "font_family": "Helvetica Neue, PingFang SC, ...",
    "font_sizes": ["12px", "14px", "16px", "18px"]
  },
  "spacing": ["4px", "8px", "12px", "16px", "24px"],
  "border_radius": {
    "small": "2px",
    "base": "4px",
    "large": "8px"
  }
}
```

### A4. 差异分析

与 `frontend-style.md` 规范对比，列出不一致的地方。

---

## 模式 B：图片识别（设计稿/截图）

### B1. 读取图片

使用 Read 工具读取图片文件，进行视觉分析。

### B2. 识别样式

从图片中识别：
- **颜色**：主色、辅助色、背景色、文字色
- **字体**：标题字号、正文字号、字重
- **间距**：元素间距、内边距规律
- **圆角**：按钮、卡片、输入框的圆角
- **阴影**：卡片阴影、弹窗阴影

### B3. 输出 CSS 变量

```css
:root {
  /* 从设计图识别 - [图片文件名] */

  /* 颜色 */
  --color-primary: #409EFF;
  --color-secondary: #909399;
  --color-text: #303133;
  --color-text-secondary: #606266;
  --color-background: #F5F7FA;

  /* 字体 */
  --font-size-title: 18px;
  --font-size-body: 14px;
  --font-size-small: 12px;

  /* 间距 */
  --spacing-xs: 4px;
  --spacing-sm: 8px;
  --spacing-md: 16px;
  --spacing-lg: 24px;

  /* 圆角 */
  --radius-sm: 2px;
  --radius-base: 4px;
  --radius-lg: 8px;

  /* 阴影 */
  --shadow-card: 0 2px 12px rgba(0, 0, 0, 0.1);
}
```

### B4. 使用建议

给出如何将识别的样式应用到项目中的建议。

---

## 输出

无论哪种模式，最终输出：
1. 提取的样式变量（JSON 或 CSS 格式）
2. 与现有规范的差异分析
3. 统一建议
