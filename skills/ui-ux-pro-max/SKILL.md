---
name: ui-ux-pro-max
description: 专业级 UI/UX 设计规范，需要高质量界面设计时手动触发或描述"设计感/专业UI"时自动触发。覆盖视觉层次、配色体系、排版节奏、交互微动效、响应式适配等。日常前端开发由 frontend-dev skill + frontend-design 插件覆盖。
version: v1.1
---

# UI/UX Pro Max — 专业级界面设计规范

> 目标：生成有设计感、可直接交付的前端界面，告别 AI 模板风。

---

## 设计哲学

```
克制 > 堆砌          — 少即是多，每个元素都有存在理由
层次 > 装饰          — 用空间和对比建立信息层次，而非边框和分割线
一致 > 创意          — 系统化的设计语言优于零散的创意点缀
功能 > 形式          — 美观服务于可用性，永远不反过来
```

---

## 反 AI 风格清单

### 严格禁止

| 类别 | 禁止项 |
|------|--------|
| 配色 | 蓝紫霓虹渐变、大面积线性渐变背景、荧光色强调 |
| 效果 | 玻璃拟态(glassmorphism)、发光描边、霓虹阴影、粒子背景 |
| 布局 | 居中大卡片+圆角过度、无限堆叠的 card-in-card |
| 装饰 | 无意义几何图形、装饰性网格线、浮动气泡 |
| 图标 | 纯装饰性 emoji、图标代替文字说明 |
| 文案 | "Powered by AI"、营销式夸张用语 |

### 识别 AI 模板风的信号

- 所有卡片等宽等高、间距完全一致 → 缺乏视觉节奏
- 主色只有一个蓝/紫 → 缺乏色彩层次
- 阴影千篇一律 `shadow-lg` → 没有深度层次
- 按钮全是渐变填充 → 缺乏操作层级

---

## 配色体系

### 构建方法

```
1. 确定品牌主色（1 个）
2. 派生 5 级明暗梯度（50/100/300/500/700）
3. 选择 1 个功能强调色（CTA / 重要操作）
4. 语义色：success/warning/error/info 各 1 个
5. 中性色：gray 7 级梯度（50~900）
```

### CSS 变量模板

```css
:root {
  /* 主色梯度 */
  --color-primary-50: #f0f7ff;
  --color-primary-100: #e0efff;
  --color-primary-300: #7cb8ff;
  --color-primary-500: #2b7de9;   /* 主色 */
  --color-primary-700: #1a56a8;

  /* 中性色 */
  --color-gray-50: #fafafa;
  --color-gray-100: #f5f5f5;
  --color-gray-200: #e8e8e8;
  --color-gray-300: #d4d4d4;
  --color-gray-500: #737373;
  --color-gray-700: #404040;
  --color-gray-900: #171717;

  /* 语义色 */
  --color-success: #22c55e;
  --color-warning: #f59e0b;
  --color-error: #ef4444;
  --color-info: #3b82f6;

  /* 文字 */
  --text-primary: var(--color-gray-900);
  --text-secondary: var(--color-gray-500);
  --text-disabled: var(--color-gray-300);

  /* 背景 */
  --bg-page: var(--color-gray-50);
  --bg-card: #ffffff;
  --bg-hover: var(--color-gray-100);

  /* 边框 */
  --border-default: var(--color-gray-200);
  --border-strong: var(--color-gray-300);
}
```

### 暗色模式

```css
[data-theme="dark"] {
  --text-primary: #f5f5f5;
  --text-secondary: #a3a3a3;
  --bg-page: #0a0a0a;
  --bg-card: #171717;
  --bg-hover: #262626;
  --border-default: #2e2e2e;
  --border-strong: #404040;
}
```

---

## 排版系统

### 字号梯度（rem）

| Token | Size | 用途 |
|-------|------|------|
| --text-xs | 0.75rem | 辅助说明、标签 |
| --text-sm | 0.875rem | 次要文字、表格内容 |
| --text-base | 1rem | 正文 |
| --text-lg | 1.125rem | 小标题、强调 |
| --text-xl | 1.25rem | 区块标题 |
| --text-2xl | 1.5rem | 页面标题 |
| --text-3xl | 1.875rem | 大标题 / Hero |

### 行高

| 场景 | line-height |
|------|-------------|
| 标题 | 1.2 ~ 1.3 |
| 正文 | 1.5 ~ 1.6 |
| 紧凑（标签/按钮） | 1 ~ 1.2 |

### 字重

```
Regular (400) — 正文
Medium (500)  — 次标题、强调
Semibold (600) — 标题
Bold (700)    — 仅用于极少数 Hero 场景
```

---

## 间距系统

### 8px 基准网格

```css
:root {
  --space-1: 0.25rem;  /* 4px  — 紧凑内间距 */
  --space-2: 0.5rem;   /* 8px  — 元素内间距 */
  --space-3: 0.75rem;  /* 12px — 相关元素间距 */
  --space-4: 1rem;     /* 16px — 标准间距 */
  --space-5: 1.25rem;  /* 20px */
  --space-6: 1.5rem;   /* 24px — 区块内间距 */
  --space-8: 2rem;     /* 32px — 区块间距 */
  --space-10: 2.5rem;  /* 40px */
  --space-12: 3rem;    /* 48px — 大区块分隔 */
  --space-16: 4rem;    /* 64px — 页面级分隔 */
}
```

### 间距使用原则

| 关系 | 间距 |
|------|------|
| 同组元素（label + input） | space-1 ~ space-2 |
| 相关元素（表单字段之间） | space-3 ~ space-4 |
| 区块内填充 | space-4 ~ space-6 |
| 区块之间 | space-8 ~ space-12 |
| 页面级留白 | space-12 ~ space-16 |

---

## 视觉层次

### 建立层次的 5 种手段（按优先级）

```
1. 大小对比    — 标题 vs 正文字号差 ≥ 1.5 倍
2. 色彩权重    — 深色 = 重要，浅色 = 辅助
3. 空白分隔    — 用留白代替分割线
4. 位置关系    — 重要信息靠上靠左（LTR 布局）
5. 视觉修饰    — 最后手段：边框、背景色、图标
```

### 信息密度控制

| 场景 | 策略 |
|------|------|
| 后台表格/列表 | 紧凑模式，行高 40~48px，减少留白 |
| 详情页/表单 | 舒适模式，合理分组+留白 |
| 营销/落地页 | 宽松模式，大量留白突出核心信息 |
| 仪表盘 | 混合模式，卡片紧凑 + 卡片间宽松 |

---

## 阴影系统

### 层级化阴影

```css
:root {
  --shadow-xs: 0 1px 2px rgba(0, 0, 0, 0.04);
  --shadow-sm: 0 1px 3px rgba(0, 0, 0, 0.06), 0 1px 2px rgba(0, 0, 0, 0.04);
  --shadow-md: 0 4px 6px rgba(0, 0, 0, 0.05), 0 2px 4px rgba(0, 0, 0, 0.04);
  --shadow-lg: 0 10px 15px rgba(0, 0, 0, 0.06), 0 4px 6px rgba(0, 0, 0, 0.04);
  --shadow-xl: 0 20px 25px rgba(0, 0, 0, 0.08), 0 8px 10px rgba(0, 0, 0, 0.04);
}
```

### 使用规则

| 元素 | 阴影 | 说明 |
|------|------|------|
| 普通卡片 | shadow-xs 或 border | 平面感，不浮起 |
| 悬浮卡片 | hover: shadow-md | 交互反馈 |
| 下拉菜单/弹窗 | shadow-lg | 明确浮层关系 |
| 模态框 | shadow-xl | 最高层级 |

---

## 圆角系统

```css
:root {
  --radius-sm: 4px;    /* 按钮、输入框、标签 */
  --radius-md: 8px;    /* 卡片、弹窗 */
  --radius-lg: 12px;   /* 大卡片、图片容器 */
  --radius-xl: 16px;   /* 模态框、特殊容器 */
  --radius-full: 9999px; /* 胶囊按钮、头像 */
}
```

**原则**：同一页面圆角不超过 3 种尺寸，保持一致性。

---

## 交互微动效

### 原则

```
1. 有目的 — 每个动效都传达状态变化
2. 快速   — 200~300ms，不拖沓
3. 自然   — ease-out 为主，模拟物理惯性
```

### 常用 Timing

```css
:root {
  --duration-fast: 150ms;     /* hover、focus */
  --duration-normal: 250ms;   /* 展开/收起、淡入淡出 */
  --duration-slow: 350ms;     /* 页面切换、模态框 */

  --ease-default: cubic-bezier(0.4, 0, 0.2, 1);   /* 通用 */
  --ease-in: cubic-bezier(0.4, 0, 1, 1);           /* 退出 */
  --ease-out: cubic-bezier(0, 0, 0.2, 1);          /* 进入 */
  --ease-spring: cubic-bezier(0.34, 1.56, 0.64, 1); /* 弹性（慎用） */
}
```

### 状态过渡模板

```css
/* 按钮 hover */
.btn {
  transition: background-color var(--duration-fast) var(--ease-default),
              box-shadow var(--duration-fast) var(--ease-default),
              transform var(--duration-fast) var(--ease-default);
}
.btn:hover {
  transform: translateY(-1px);
  box-shadow: var(--shadow-sm);
}
.btn:active {
  transform: translateY(0);
}

/* 卡片 hover */
.card {
  transition: box-shadow var(--duration-normal) var(--ease-default);
}
.card:hover {
  box-shadow: var(--shadow-md);
}

/* 淡入 */
.fade-enter {
  opacity: 0;
  transform: translateY(8px);
}
.fade-enter-active {
  transition: opacity var(--duration-normal) var(--ease-out),
              transform var(--duration-normal) var(--ease-out);
}
```

### 禁止的动效

- ❌ 超过 500ms 的动画（用户感知为"卡"）
- ❌ 旋转、弹跳、脉冲等花哨效果
- ❌ 页面加载时的入场动画（除首屏 Hero）
- ❌ 无限循环动画（除 loading 指示器）

---

## 响应式设计

### 断点

```css
/* Mobile First */
--bp-sm: 640px;    /* 大屏手机 */
--bp-md: 768px;    /* 平板 */
--bp-lg: 1024px;   /* 笔记本 */
--bp-xl: 1280px;   /* 桌面 */
--bp-2xl: 1536px;  /* 大屏 */
```

### 适配策略

| 元素 | 方案 |
|------|------|
| 布局 | Grid/Flex 自适应，避免固定宽度 |
| 字号 | clamp() 流式缩放 |
| 间距 | 移动端减半或使用较小 token |
| 导航 | lg 以下折叠为汉堡菜单 |
| 表格 | md 以下转为卡片列表 |
| 图片 | srcset + sizes，或 picture 元素 |

### 流式字号示例

```css
h1 { font-size: clamp(1.5rem, 2vw + 1rem, 2.5rem); }
h2 { font-size: clamp(1.25rem, 1.5vw + 0.75rem, 1.875rem); }
```

---

## 组件设计模式

### 按钮层级

```
Primary（主操作）   — 实心填充主色，每页最多 1~2 个
Secondary（次操作） — 描边/浅色背景
Tertiary（辅助）    — 纯文字按钮，无背景无边框
Danger（危险操作）  — 红色系，需二次确认
```

### 表单设计

| 规则 | 说明 |
|------|------|
| Label 始终可见 | 不依赖 placeholder 传达字段含义 |
| 错误提示就近 | 在输入框下方，红色小字 |
| 必填标记 | `*` 在 label 后，颜色 --color-error |
| 分组 | 相关字段用标题/间距分组，不用边框围起来 |
| 操作区 | 主按钮靠右（或靠左，全站统一） |

### 空状态设计

```
1. 简洁插图或图标（不要大面积灰色区域）
2. 一句话说明当前状态
3. 一个明确的行动按钮（如有）
4. 不要用 "Oops!" 等拟人化表达
```

### 加载状态

```
骨架屏（Skeleton）  — 首选，保持布局稳定
Spinner             — 仅用于局部操作（按钮内、小区域）
进度条              — 文件上传等可量化进度
```

---

## 无障碍基础

| 规则 | 要求 |
|------|------|
| 颜色对比度 | 正文 ≥ 4.5:1，大字 ≥ 3:1（WCAG AA） |
| 焦点可见 | focus-visible 样式清晰可辨 |
| 键盘导航 | Tab 顺序合理，可键盘操作所有交互 |
| 语义化 HTML | 正确使用 heading 层级、landmark 元素 |
| Alt 文本 | 功能性图片必须有 alt |

---

## 代码输出要求

### 生成页面/组件时必须

1. **使用 CSS 变量** — 不硬编码颜色/间距/字号
2. **响应式** — 至少覆盖移动端 + 桌面端
3. **交互状态完整** — hover / focus / active / disabled
4. **语义化标签** — 不滥用 div
5. **暗色模式** — 提供 `[data-theme="dark"]` 变量覆盖

### 生成顺序

```
1. 定义设计 tokens（CSS 变量）
2. 搭建页面结构（HTML / Template）
3. 实现布局（Grid / Flex）
4. 填充组件内容
5. 添加交互状态和微动效
6. 响应式适配
```

### 样式组织

```
/* 1. CSS 变量 / Tokens */
/* 2. Reset / Base */
/* 3. Layout */
/* 4. Components */
/* 5. Utilities（极少量） */
/* 6. 响应式覆盖 */
```

---

## 设计评审检查清单

在生成 UI 代码后，自查以下项目：

- [ ] 视觉层次清晰：标题、正文、辅助文字 3 级以上
- [ ] 间距节奏感：不是所有间距都一样
- [ ] 配色克制：主色点缀，不是大面积铺色
- [ ] 没有 AI 模板风信号（见反 AI 风格清单）
- [ ] 交互状态完整：hover、focus、disabled、loading、empty、error
- [ ] 响应式基本可用
- [ ] 对比度达标
- [ ] 无多余装饰性元素

---

## 规则溯源

```
> 📋 本回复遵循：`ui-ux-pro-max` - [具体章节]
```
