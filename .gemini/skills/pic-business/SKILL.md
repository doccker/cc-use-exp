---
name: pic-business
description: 商务专业风信息图生成。支持风格预设、配色、图标、布局、密度等参数化控制。手动触发。
---
<instructions>

# Pic Business — 商务专业风信息图

用户提供内容描述后，生成专业商务风格的信息图。支持参数化控制。

---

## 触发方式

用户执行 `/pic-business {内容描述}` 时触发。

可选参数（在内容描述中指定）：
- `style:` — 视觉风格预设
- `color:` — 配色主题
- `icon:` — 图标风格
- `layout:` — 布局模式
- `density:` — 内容密度

---

## 可配置参数

### 1. STYLE — 视觉风格预设

| 预设 | 说明 |
|------|------|
| Dark Corporate | 深色商务风、高端感、企业展示 |
| Consulting | 咨询公司式蓝白图表、极致专业 |
| Tech / SaaS | 科技公司蓝紫渐变、轻量大留白 |
| Pitch Deck | 投资人简洁视觉、聚焦增长与指标 |
| Minimalist Gray | 高级灰、极简、强留白 |
| Enterprise Training | 企业汇报、培训运营、产品介绍 |

未指定时自动根据内容选择最合适的风格。

### 2. COLOR_THEME — 配色主题

示例：Deep Navy + Silver、White + Electric Blue、Dark Gray + Cyan、Gradient Indigo/Blue、Minimalist Soft Gray

未指定时自动匹配 STYLE。

### 3. ICON_STYLE — 图标风格

示例：Thin-line business icons、Filled geometric icons、Abstract consulting-style blocks、Tech glyph icons

### 4. LAYOUT_MODE — 布局模式

示例：3-Section Business Overview、4-Quadrant Consulting Matrix、Vertical Timeline、Feature Comparison Table、KPI Dashboard Layout、Problem → Solution → Value Chain、SWOT / Strategy Map

### 5. CONTENT_DENSITY — 内容密度

| 级别 | 说明 |
|------|------|
| Minimal | 3–4 个要点，大量留白 |
| Standard | 5–7 个要点，正常密度（默认） |
| Rich | 8–12 个要点，结构化区块 |

---

## 生成规则

### 风格

- 画布格式：横版 16:9
- 使用 nano banana pro 模式渲染
- 禁止写实、禁止照片元素、禁止 3D 反射表面
- 商务简洁、高端、结构化布局
- 文字呈现为干净的手绘商务字体，不使用印刷字体
- 大量留白、最少杂乱、强层次感

### 内容提取

- 从用户输入中提取并重组为商务信息图形式
- 每个要点 3–8 个关键词
- 按层次分组
- 根据 LAYOUT_MODE 组织结构（未指定时智能选择）
- 包含与 STYLE 匹配的商务视觉元素：图表、流程箭头、简单图形、指标区块、策略图标

### 语言

- 默认使用与用户输入相同的语言
- 用户明确指定其他语言时切换

### 版权安全

- 如果输入提及品牌/人物，替换为抽象的商务安全替代形象

---

## 禁止事项

- 禁止长段落
- 禁止杂乱布局
- 禁止卡通/幼稚风格
- 禁止品牌 logo
- 禁止写实人物或企业照片

---

## 输出要求

1. 生成图片后保存到用户本地（当前工作目录或用户指定路径）
2. 完成后必须告知用户图片的完整保存路径
3. 输出格式示例：

```
✅ 信息图已生成

保存路径：./pic-business-{主题简称}-{时间戳}.png
风格：{所用 STYLE 预设}
配色：{所用 COLOR_THEME}
布局：{所用 LAYOUT_MODE}
内容要点：{N} 个
```

---

## 使用示例

```
/pic-business 我们的 SaaS 产品核心优势：低代码、AI 驱动、多租户隔离 style:Tech/SaaS density:Minimal
```

```
/pic-business Q3 季度业绩回顾 layout:KPI Dashboard Layout color:Deep Navy + Silver
```

---

> 📋 本回复遵循：`pic-business`

</instructions>