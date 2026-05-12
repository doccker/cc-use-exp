# 位置对应集合的去重/过滤错位 — 多语言完整示例

> 配套 `SKILL.md` 陷阱 #10「位置对应集合的去重/过滤错位」。
> 演示两种修复策略：A) 对齐操作（最小改动），B) 改用配对结构（推荐，从根上消除）。
>
> **注**：本文档的方案 A 在 SKILL.md 基础版本上额外封装了"单值时不拼接"的边界判断，便于直接使用；SKILL.md 内的版本更精简，二者效果一致。

---

## 一、Java（Stream + Record）

### 错误示例

```java
// ❌ companies 去重后长度变了，与 numbers 索引错位
List<String> companies = packages.stream()
    .map(ShippingPackage::getCompany)
    .filter(StringUtils::hasText)
    .distinct()
    .collect(Collectors.toList());
List<String> numbers = packages.stream()
    .map(ShippingPackage::getTrackingNo)
    .collect(Collectors.toList());
```

### 方案 A：对齐操作（保留对应关系）

```java
// ✅ 不去重，保留索引对应
List<String> companies = packages.stream()
    .map(ShippingPackage::getCompany)
    .collect(Collectors.toList());
List<String> numbers = packages.stream()
    .map(ShippingPackage::getTrackingNo)
    .collect(Collectors.toList());

String companyValue = companies.stream().distinct().count() == 1
    ? companies.get(0)
    : String.join(";", companies);
String numberValue = String.join(";", numbers);
```

### 方案 B：配对结构（推荐）

```java
public record ShippingPackage(String company, String trackingNo) {}

List<ShippingPackage> packages = order.getPackages();

String companyValue = packages.size() == 1 || packages.stream()
        .map(ShippingPackage::company).distinct().count() == 1
    ? packages.get(0).company()
    : packages.stream().map(ShippingPackage::company).collect(joining(";"));

String numberValue = packages.stream()
    .map(ShippingPackage::trackingNo)
    .collect(joining(";"));
```

任何后续操作（filter、sorted）都作用在整个 record 上，不会破坏对应关系：

```java
List<ShippingPackage> validPackages = packages.stream()
    .filter(p -> StringUtils.hasText(p.trackingNo()))
    .toList();
```

---

## 二、Go（slice + struct）

### 错误示例

```go
// ❌ companies 去重后长度变了，与 numbers 索引错位
companySet := make(map[string]struct{})
var companies []string
for _, p := range packages {
    if p.Company != "" {
        if _, ok := companySet[p.Company]; !ok {
            companySet[p.Company] = struct{}{}
            companies = append(companies, p.Company)
        }
    }
}
var numbers []string
for _, p := range packages {
    numbers = append(numbers, p.TrackingNo)
}
```

### 方案 A：对齐操作

```go
companies := make([]string, 0, len(packages))
numbers := make([]string, 0, len(packages))
for _, p := range packages {
    companies = append(companies, p.Company)
    numbers = append(numbers, p.TrackingNo)
}

companyValue := joinUnique(companies)
numberValue := strings.Join(numbers, ";")
```

```go
func joinUnique(values []string) string {
    if len(values) == 0 {
        return ""
    }
    first := values[0]
    allSame := true
    for _, v := range values[1:] {
        if v != first {
            allSame = false
            break
        }
    }
    if allSame {
        return first
    }
    return strings.Join(values, ";")
}
```

### 方案 B：配对结构（推荐）

```go
type ShippingPackage struct {
    Company    string
    TrackingNo string
}

func formatShipping(packages []ShippingPackage) (companyValue, numberValue string) {
    if len(packages) == 0 {
        return "", ""
    }
    companies := make([]string, 0, len(packages))
    numbers := make([]string, 0, len(packages))
    for _, p := range packages {
        companies = append(companies, p.Company)
        numbers = append(numbers, p.TrackingNo)
    }
    return joinUnique(companies), strings.Join(numbers, ";")
}
```

后续 filter 也作用在整个 struct 上：

```go
valid := packages[:0]
for _, p := range packages {
    if p.TrackingNo != "" {
        valid = append(valid, p)
    }
}
```

---

## 三、TypeScript（Array + interface）

### 错误示例

```typescript
// ❌ companies 去重后长度变了，与 numbers 索引错位
const companies = [...new Set(
  packages.map(p => p.company).filter(Boolean)
)];
const numbers = packages.map(p => p.trackingNo);
```

### 方案 A：对齐操作

```typescript
const companies = packages.map(p => p.company);
const numbers = packages.map(p => p.trackingNo);

const companyValue = new Set(companies).size === 1
  ? companies[0]
  : companies.join(';');
const numberValue = numbers.join(';');
```

### 方案 B：配对结构（推荐）

```typescript
interface ShippingPackage {
  company: string;
  trackingNo: string;
}

function formatShipping(packages: ShippingPackage[]): { companyValue: string; numberValue: string } {
  if (packages.length === 0) return { companyValue: '', numberValue: '' };

  const companies = packages.map(p => p.company);
  const numbers = packages.map(p => p.trackingNo);

  const companyValue = new Set(companies).size === 1 ? companies[0] : companies.join(';');
  const numberValue = numbers.join(';');

  return { companyValue, numberValue };
}
```

后续 filter 也作用在整个对象上：

```typescript
const validPackages = packages.filter(p => p.trackingNo);
```

---

## 四、自检：识别"位置对应集合"的信号

如果代码中出现以下模式，就要警觉：

| 信号 | 例子 |
|------|------|
| 两条 list 都从同一个源 list 派生 | `xs.map(f1)` + `xs.map(f2)` |
| 两条 list 同时被 join/写入相邻列 | `String.join(";", a) + String.join(";", b)` |
| 命名是天然成对的 | `companies/numbers`、`names/ages`、`keys/values`、`questions/answers` |
| 下游消费方按位置读取 | 微信导入、Excel 列、CSV 行、键值对配置 |

只要满足"两条 list 派生自同源 + 下游按位置消费"，就说明它们是 zip 关系，**不能单独修改其中一条**。

---

## 五、单元测试要覆盖的场景

不论用方案 A 还是 B，测试必须显式覆盖：

```java
@Test
void shouldHandleSameCompanyAcrossPackages() {
    List<ShippingPackage> packages = List.of(
        new ShippingPackage("顺丰", "SF1"),
        new ShippingPackage("顺丰", "SF2")
    );
    var result = formatShipping(packages);
    assertEquals("顺丰", result.companyValue());
    assertEquals("SF1;SF2", result.numberValue());
}

@Test
void shouldPreservePositionWithMixedCompanies() {
    List<ShippingPackage> packages = List.of(
        new ShippingPackage("顺丰", "SF1"),
        new ShippingPackage("圆通", "YT2"),
        new ShippingPackage("顺丰", "SF3")
    );
    var result = formatShipping(packages);
    assertEquals("顺丰;圆通;顺丰", result.companyValue());
    assertEquals("SF1;YT2;SF3", result.numberValue());
}
```

第二个测试是**关键**——只有它能暴露 distinct 错位问题。
