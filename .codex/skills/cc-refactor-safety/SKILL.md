---
name: cc-refactor-safety
description: 当用户要求重构代码（提取组件、合并重复逻辑、重命名变量、优化结构）时触发。提供重构安全检查清单，防止丢失原始上下文。
---

# 重构安全规范

## 触发场景

- 用户说"重构"、"提取"、"合并"、"优化结构"、"简化代码"
- 涉及表格列、数据结构、配置项的修改
- 合并条件分支（if/else/switch）

---

## 重构流程

### 1. 读取原始代码（必须）

**不要凭记忆或推测重构**，必须完整读取原始代码：

```bash
# 读取完整文件
Read: file_path="src/views/Order.vue"

# 如果是条件分支，读取所有分支的代码
Grep: pattern="if.*健康云" -A 50 -B 5
Grep: pattern="else" -A 50 -B 5
```

**常见错误**：
- ❌ 只读一个分支，推测其他分支
- ❌ 凭记忆重构表格列
- ❌ 假设两个条件分支结构相似

---

### 2. 制作对比清单

#### 表格重构示例

**原始代码（健康云租户）**：
```
列1: 订单编号
列2: 订单日期
列3: 材料名称
列4: 材料数量
列5: 单价
列6: 金额
```

**原始代码（非健康云租户）**：
```
列1: 订单编号
列2: 创建时间
列3: 材料名称
列4: 单价
列5: 金额
```

**对比清单**：

| 健康云 | 非健康云 | 状态 |
|--------|---------|------|
| 订单编号 | 订单编号 | ✅ 一致 |
| 订单日期 | 创建时间 | ⚠️ 名称不同 |
| 材料名称 | 材料名称 | ✅ 一致 |
| 材料数量 | - | ❌ 非健康云无此列 |
| 单价 | 单价 | ✅ 一致 |
| 金额 | 金额 | ✅ 一致 |

#### 数据结构重构示例

**原始接口**：
```typescript
interface Order {
  id: string
  date: string
  items: Item[]
  total: number
}
```

**重构后接口**：
```typescript
interface Order {
  id: string
  createdAt: string  // 重命名：date → createdAt
  items: Item[]
  total: number
}
```

**对比清单**：
- ✅ 字段数量一致（4 个）
- ⚠️ 字段重命名：date → createdAt
- ✅ 字段顺序一致
- ✅ 字段类型一致

---

### 3. 验证检查点

重构完成后，必须逐项检查：

#### 表格重构检查

- [ ] 列数一致（原始 6 列 → 重构后 6 列）
- [ ] 列顺序一致（第 1 列是订单编号，第 2 列是日期...）
- [ ] 列名一致（或有明确映射关系）
- [ ] 没有遗漏列
- [ ] 没有多余列

#### 条件分支检查

- [ ] 所有 if/else/switch 分支都已处理
- [ ] 每个分支的逻辑与原始代码一致
- [ ] 没有假设某个分支与另一个分支相似

#### 数据结构检查

- [ ] 字段数量一致
- [ ] 字段类型一致
- [ ] 字段顺序一致（如果顺序重要）
- [ ] 没有遗漏字段

---

### 4. 输出格式

重构完成后，输出对比清单：

```markdown
## 重构对比

### 原始结构（健康云租户）
- 列1: 订单编号
- 列2: 订单日期
- 列3: 材料名称
- 列4: 材料数量
- 列5: 单价
- 列6: 金额

### 原始结构（非健康云租户）
- 列1: 订单编号
- 列2: 创建时间
- 列3: 材料名称
- 列4: 单价
- 列5: 金额

### 重构后结构
- 列1: 订单编号
- 列2: 日期（健康云显示"订单日期"，非健康云显示"创建时间"）
- 列3: 材料名称
- 列4: 材料数量（仅健康云显示）
- 列5: 单价
- 列6: 金额

### 变更说明
- 合并：订单日期 + 创建时间 → 日期（条件显示）
- 条件显示：材料数量仅在健康云租户显示
- 删除：无
- 新增：无
```

---

## 常见陷阱

### 1. 假设驱动重构

**错误示例**：
```javascript
// 只读了健康云租户的代码
if (isHealthCloud) {
  columns = ['订单编号', '订单日期', '材料名称', '材料数量', '单价', '金额']
}

// ❌ 假设非健康云租户只是列名不同
else {
  columns = ['订单编号', '创建时间', '材料名称', '材料数量', '单价', '金额']
}
```

**正确做法**：
```javascript
// 读取两个分支的原始代码
if (isHealthCloud) {
  columns = ['订单编号', '订单日期', '材料名称', '材料数量', '单价', '金额']
} else {
  // 非健康云租户没有"材料数量"列
  columns = ['订单编号', '创建时间', '材料名称', '单价', '金额']
}
```

### 2. 记忆重构

**错误示例**：
```javascript
// ❌ 凭记忆重构，没有读取原始代码
const columns = ['订单编号', '材料名称', '单价', '金额', '订单日期']
```

**正确做法**：
```javascript
// ✅ 读取原始代码，确认列顺序
Read: file_path="src/views/Order.vue"
// 原始代码：['订单编号', '订单日期', '材料名称', '材料数量', '单价', '金额']
const columns = ['订单编号', '订单日期', '材料名称', '材料数量', '单价', '金额']
```

### 3. 跳过验证

**错误示例**：
```javascript
// 重构完成，直接提交
// ❌ 没有验证列数、列顺序、列名
```

**正确做法**：
```markdown
## 验证清单
- [x] 列数一致：原始 6 列 → 重构后 6 列
- [x] 列顺序一致：订单编号、订单日期、材料名称、材料数量、单价、金额
- [x] 列名一致：完全一致
- [x] 没有遗漏列
- [x] 没有多余列
```

### 5. 提取子模块导致循环依赖

**场景**：从大服务/组件拆分子模块时，子模块需要回调父模块的方法

#### ⚠️ 预检流程（拆分前必须执行）

**先提取共享方法，再拆分子服务**：
```
拆分前：
1. 扫描父服务，识别被多个子服务调用的工具方法
2. 将这些方法提取到独立 Helper/Utils 类
3. 然后再拆分子服务（此时子服务依赖 Helper，不依赖父服务）

❌ 错误顺序：拆分子服务 → 发现循环依赖 → 修复
✅ 正确顺序：提取共享方法 → 拆分子服务 → 无循环依赖
```

#### ⚠️ 重复模式警告

**如果第一个子服务提取时已出现循环依赖，后续所有子服务提取必须先检查相同问题**：
```
真实案例：
- ReportService → 提取 ReportInvoiceService → 循环依赖（resolveTenantIds）
- ReportService → 提取 ReportPaymentService → 同样的循环依赖！
根因：resolveTenantIds() 留在 ReportService，所有子服务都需要它
修复：应在第一次发现时就提取 TenantHelper，避免后续重复犯错
```

**错误示例**：
```java
// ❌ ReportService 拆分出 ReportInvoiceService
// 但 ReportInvoiceService 又需要调用 ReportService.resolveTenantIds()
@Service
@RequiredArgsConstructor
public class ReportInvoiceService {
    private final ReportService reportService; // 循环依赖！
}
```

**正确做法（按优先级）**：
```java
// ✅ 方案1：提取公共方法到独立工具类（推荐）
@Component
public class TenantHelper {
    public List<Long> resolveTenantIds(Long tenantId) { ... }
}

// ✅ 方案2：@Lazy 字段注入（应急）
@Service
public class ReportInvoiceService {
    @Autowired @Lazy
    private ReportService reportService;
}

// ✅ 方案3：函数式回调
public void process(Function<Long, List<Long>> tenantResolver) { ... }
```

**检查清单**：
- [ ] **预检**：父服务中是否有被多个子服务调用的工具方法？是 → 先提取到独立类
- [ ] **重复检查**：本次拆分是否与之前的拆分有相同的回调依赖？
- [ ] 画依赖图：拆分后是否存在 A → B → A 的循环？
- [ ] 依赖方向是否单向：父 → 子（禁止子 → 父）
- [ ] Spring Boot 3.x 默认禁止构造器循环依赖

**不仅限于 Spring**：
- Go：包级循环引用（编译错误）→ 提取公共包
- Vue：组件循环引用 → 异步组件或提取公共逻辑到 composables
- TypeScript：模块循环引用 → 提取公共模块

---

### 6. 提取状态管理时的初始化冲突

**场景**：将组件内的 state 提取到自定义 Hook/composable/Service 时，封装的 open 方法添加了初始化逻辑，覆盖了调用方预设的状态

**真实案例**：
```tsx
// 重构前：调用方直接控制状态，时序正确
setMarkPaidText(selectedOrderNumbers)  // 1. 设置订单号
setMarkPaidModalVisible(true)          // 2. 打开弹窗 ✅

// 重构后：提取到 useOrderModals hook
const openMarkPaidModal = () => {
  setMarkPaidText('')           // ❌ 清空了调用方刚设置的值！
  setMarkPaidModalVisible(true)
}

// 调用方：
setMarkPaidText(selectedOrderNumbers)  // 1. 设置订单号
openMarkPaidModal()                    // 2. 内部又清空了 → 弹窗空白
```

**正确做法**：
```tsx
// ✅ 方案1：open 方法接受参数
const openMarkPaidModal = (initialText?: string) => {
  if (initialText !== undefined) setMarkPaidText(initialText)
  setMarkPaidModalVisible(true)
}

// ✅ 方案2：初始化放在 close 而非 open
const closeMarkPaidModal = () => {
  setMarkPaidText('')  // 关闭时清空是安全的
  setMarkPaidModalVisible(false)
}
```

**检查清单**：
- [ ] 提取 open/show 方法时，检查调用方是否在 open 之前设置了状态
- [ ] open 方法中的初始化逻辑是否会覆盖调用方预设的值
- [ ] 初始化/清空逻辑应放在 close 而非 open
- [ ] 如果 open 需要初始化，应通过参数传入而非内部硬编码

**适用范围**：
- React：useState → useXxxModal hook
- Vue：ref → useXxxDialog composable
- Java：Service 方法添加默认值逻辑

---

### 7. UI 组件重构时的布局结构丢失

**场景**：重构 Modal/Dialog/Drawer 等容器组件时，将复杂的 title/header/footer 简化，导致按钮布局和功能丢失

**真实案例**：
```tsx
// 重构前：title 包含条件渲染的按钮
<Modal
  title={
    <div className="flex justify-between">
      <span>发票详情</span>
      {!editMode && <Button icon={<EditOutlined />}>编辑发票</Button>}
      {editMode && (
        <Space>
          <Button icon={<CloseOutlined />}>取消</Button>
          <Button type="primary" icon={<SaveOutlined />}>保存</Button>
        </Space>
      )}
    </div>
  }
  footer={[
    <Button key="download" type="primary" icon={<DownloadOutlined />}>
      下载原始PDF
    </Button>,
    <Button key="close">关闭</Button>,
  ]}
/>

// ❌ 重构后：title 简化为纯文本，footer 按钮被替换
<Modal
  title={`发票详情 - ${invoice?.invoiceNumber}`}  // 丢失编辑/取消/保存按钮
  footer={[
    <button key="edit">编辑</button>,   // 降级为原生 button + 丢失"下载PDF"
    <button key="close">关闭</button>,
  ]}
/>
```

**检查清单**：
- [ ] title/header/footer 的 JSX 结构是否与原始代码一致
- [ ] 条件渲染的按钮（`{condition && <Button>}`）是否都保留
- [ ] 按钮数量是否一致（重构前 N 个 → 重构后 N 个）
- [ ] 组件库组件是否保持（Ant Design `<Button>` 不能降级为 `<button>`）
- [ ] 功能按钮是否遗漏（如"下载"、"导出"等）

**适用范围**：
- React：Modal、Dialog、Drawer 的 title/footer
- Vue：el-dialog、el-drawer 的 header/footer 插槽
- 任何包含条件渲染按钮的 UI 容器组件

---

### 8. 复杂渲染逻辑被简化替换

**场景**：重构表格列或组件时，将复杂的 render 函数（JSON 解析、条件格式化、diff 对比）替换为简单文本显示，导致功能降级

**真实案例**：
```tsx
// 重构前：~80 行的复杂 render，从 beforeValue/afterValue JSON 解析渲染 diff
{
  title: '变更详情',
  key: 'changeDetails',
  render: (_, record) => {
    const oldValues = JSON.parse(record.beforeValue)
    const newValues = JSON.parse(record.afterValue)
    // ... 字段对比、颜色标记、条件渲染（新增/删除/更新）
    return <div>{changedKeys.map(key => (
      <div>{translateFieldName(key)}: {oldValue} → {newValue}</div>
    ))}</div>
  }
}

// ❌ 重构后：简化为读取一个数据库中为空的字段
{
  title: '变更摘要',
  dataIndex: 'changeSummary',  // 数据库中此字段为空！
  render: (val) => val || '-'  // 全部显示 -
}
```

**检查清单**：
- [ ] 原始 render 函数超过 20 行或包含 JSON 解析？→ 不能简化为简单文本
- [ ] 重构后使用的字段（changeSummary）在数据库中是否有数据？
- [ ] 渲染效果是否等价（颜色标记、diff 对比、条件显示）
- [ ] 数据源是否一致（beforeValue/afterValue vs changeSummary）

**适用范围**：
- 表格列的 render 函数重构
- 列表项的自定义渲染重构
- 任何包含 JSON 解析、条件格式化的渲染逻辑

---

### 4. 字段名推测重构（极其隐蔽）

**场景**：类型定义中有多个相似字段，重构时选错了

**错误示例**：
```typescript
// 类型定义
interface InvoiceHistory {
  changedAt?: string  // 可选字段
  createdAt: string   // 必填字段
  changeType?: string // 错误字段
  operationType: string // 正确字段
}

// ❌ 根据类型定义推测，选择了可选字段
dataIndex: 'changedAt'  // 可能为 undefined → Invalid Date
dataIndex: 'changeType' // 字段不存在 → 显示为空

// ❌ 枚举映射不完整
typeMap: {
  CREATE: { text: '创建', color: 'green' },
  UPDATE: { text: '更新', color: 'blue' },
  DELETE: { text: '删除', color: 'red' },
  // 遗漏了 UPLOAD、OCR_START、OCR_SUCCESS 等 7 个类型
}
```

**正确做法**：
```typescript
// ✅ 查看原始代码的实际使用
git show HEAD~1:src/components/InvoiceHistoryTab.tsx

// 原始代码使用 createdAt（必填）和 operationType（正确）
dataIndex: 'createdAt'
dataIndex: 'operationType'

// 原始代码有 10 个枚举类型
typeMap: {
  UPLOAD: { text: '上传发票', color: 'blue' },
  OCR_START: { text: '开始OCR', color: 'cyan' },
  OCR_SUCCESS: { text: 'OCR成功', color: 'green' },
  OCR_FAILED: { text: 'OCR失败', color: 'red' },
  OCR_RETRY: { text: '重试OCR', color: 'orange' },
  MANUAL_EDIT: { text: '手动编辑', color: 'orange' },
  LINK_ORDER: { text: '关联订单', color: 'purple' },
  UNLINK_ORDER: { text: '取消关联', color: 'magenta' },
  FIELD_CONFIRM: { text: '确认字段', color: 'green' },
  DELETE: { text: '删除发票', color: 'red' },
}

// ✅ 防御性编程
render: (val: string) => {
  if (!val) return '-'
  try {
    return new Date(val).toLocaleString('zh-CN')
  } catch {
    return val
  }
}
```

**检查清单**：
- [ ] 查看原始代码的实际字段名（不要只看类型定义）
- [ ] 优先使用必填字段，避免可选字段
- [ ] 枚举映射必须完整（对照原始代码逐个检查）
- [ ] 运行时测试（TypeScript 无法检测字段名错误）
- [ ] 防御性编程（if (!val) return '-'）

**为什么 TypeScript 无法检测**：
```typescript
// ❌ TypeScript 不会报错（changedAt 在类型定义中存在）
dataIndex: 'changedAt'  // 类型检查通过
render: (val: string) => new Date(val).toLocaleString()
// 运行时：val 为 undefined → Invalid Date
```

---

## 陷阱 #9: 散弹式修复（Shotgun Fix）

**场景**: 同一个问题在多个文件中重复出现，修复时逐个文件加相同的补丁代码，而不是抽取共享逻辑

### 问题根因

当一个横切关注点（如图片 URL 补全、金额格式化、权限校验）散落在多个 Service 中时，修复者容易"哪里报错修哪里"，最终在 5+ 个文件里各写一份几乎相同的方法。

### 错误示例

```java
// ❌ 错误: 7 个 Service 各写一份 resolveImageUrl
// ProductService.java
private String resolveImageUrl(String url) {
    if (url == null || url.startsWith("http")) return url;
    return minioService.getPresignedUrl(url, 60 * 24 * 7);
}

// MiniProductService.java — 又写一份
private String resolveImageUrl(String url) { /* 同样逻辑 */ }

// CartService.java — 又写一份
private String resolveImageUrl(String url) { /* 同样逻辑 */ }
```

### 正确做法

```java
// ✅ 正确: 先全局扫描，再抽取共享工具，一次性补齐
// 第 1 步: 全局扫描受影响的位置
// Grep: pattern="getImageUrl|mainImage|imageUrl" type="java"

// 第 2 步: 抽取共享工具类
@Component
public class ImageUrlResolver {
    private final MinioService minioService;

    public String resolve(String imageUrl) {
        if (imageUrl == null || imageUrl.isBlank()) return imageUrl;
        if (imageUrl.startsWith("http://") || imageUrl.startsWith("https://")) {
            return imageUrl;
        }
        return minioService.getPresignedUrl(imageUrl, 60 * 24 * 7);
    }
}

// 第 3 步: 所有 Service 统一注入并使用
```

### 识别信号

| 信号 | 说明 |
|------|------|
| 同一个 private 方法在 3+ 个类里出现 | 应抽成共享工具 |
| 修复一个接口后，用户又报另一个接口同样的问题 | 应先全局扫描再一次性修 |
| 修复 diff 里有 5+ 个文件的相同改动模式 | 应抽取公共逻辑 |

### 检查清单

- [ ] 修复前是否先做了全局扫描（grep），确认所有受影响的位置
- [ ] 同一修复模式是否出现在 3+ 个文件中（如果是，应抽取共享方法）
- [ ] 是否一次性补齐所有受影响的链路（而非等用户逐个报）
- [ ] 新增的共享工具方法是否有明确的职责边界和命名

---

## 陷阱 #10: 位置对应集合的去重/过滤错位

**场景**: 多条 list 在最终输出中按索引位置一一对应（如 `[公司, 单号]` / `[姓名, 年龄]` / `[字段名, 字段值]` / `[问题, 答案]`），重构时只对其中一条 `distinct()` / `filter()` / `sorted()`，其他不动 → 长度变了，索引错位，输出数据彻底乱套。

### 问题根因

代码里两条 `List` 看似独立，但语义上是 zip 关系。开发者以为"去重让结果更干净"，但实际上破坏了"第 i 个公司对应第 i 个单号"的隐式契约。这种错误特别隐蔽：

- 单元测试经常没覆盖（多包裹同公司的情况）
- 编译/类型检查不会报错（两条 list 类型一致）
- 测试数据巧合地都不重复时，根本看不出来
- 只有真实业务数据出现重复时才爆雷（`顺丰:1, 圆通:2, 顺丰:3` → 公司 `顺丰;圆通`、单号 `1;2;3`）

### 错误示例（来自真实 review）

```java
// ❌ 错误: companies 去重，numbers 不去重，破坏索引对应
List<String> companies = packages.stream()
    .map(ShippingPackage::getCompany)
    .filter(StringUtils::hasText)
    .distinct()
    .collect(Collectors.toList());
List<String> numbers = packages.stream()
    .map(ShippingPackage::getTrackingNo)
    .collect(Collectors.toList());

writeRow(sheet, "快递公司", String.join(";", companies));
writeRow(sheet, "快递单号", String.join(";", numbers));
// packages = [顺丰:SF1, 圆通:YT2, 顺丰:SF3]
// companies = "顺丰;圆通" (2 段)
// numbers   = "SF1;SF2;SF3" (3 段)
// 微信侧导入时按位置匹配 → 圆通 ↔ SF2，顺丰 ↔ SF3，物流错乱
```

### 正确做法

#### 方案 A：对齐操作（最小改动）

要么两条 list 一起 distinct/filter，要么都不动：

```java
// ✅ 都不去重，保留所有包裹按顺序对应
List<String> companies = packages.stream()
    .map(ShippingPackage::getCompany)
    .collect(Collectors.toList());
List<String> numbers = packages.stream()
    .map(ShippingPackage::getTrackingNo)
    .collect(Collectors.toList());

if (companies.stream().distinct().count() == 1) {
    writeRow(sheet, "快递公司", companies.get(0));
} else {
    writeRow(sheet, "快递公司", String.join(";", companies));
}
writeRow(sheet, "快递单号", String.join(";", numbers));
```

#### 方案 B：改用配对结构（推荐，从根上消除问题）

把"两条并行 list"改成"一条 list of Pair/Record"，索引对应关系由语言保证：

```java
public record ShippingPackage(String company, String trackingNo) {}

List<ShippingPackage> packages = order.getPackages();

String companyValue = packages.size() == 1
    ? packages.get(0).company()
    : packages.stream().map(ShippingPackage::company).collect(joining(";"));
String numberValue = packages.stream()
    .map(ShippingPackage::trackingNo)
    .collect(joining(";"));
```

任何后续操作（filter、sorted、partition）都作用在整个 record 上，不会出现单字段被改而其他字段不动的情况。

### 何时用哪个

| 场景 | 推荐方案 |
|------|---------|
| 现有代码只是临时拼接，改动成本高 | 方案 A：对齐操作 |
| 这两个字段在多处一起出现，或后续可能加更多字段 | 方案 B：配对结构 |
| 字段超过 3 个还按位置对应 | 必须用方案 B（再多就读不懂了） |

### 检查清单

- [ ] 是否存在 2 条以上的 list 在最终输出/拼接时按索引位置对应
- [ ] 重构时是否只对其中一条做了 distinct/filter/sorted（破坏对齐）
- [ ] 是否考虑过改用 `List<Pair>` / `List<Record>` 从根上消除并行 list
- [ ] 测试数据是否覆盖了"重复值"场景（同公司多包裹、同名多记录）

### 多语言示例

完整的 Java（Stream + Record）/ Go（slice + struct）/ TypeScript（Array + interface）实现示例见 `references/multi-lang-examples.md`。

---

## 规则溯源

```
> 📋 本回复遵循：`refactor-safety` - [章节]
```
