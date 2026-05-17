# Rust 风格细则

> 配合 `SKILL.md` 使用。本文聚焦命名细节、类型设计模式与日常 idioms。

---

## 命名细则

### API Guidelines 命名约定

| 类型 | 规则 | 反例 |
|------|------|------|
| 转换方法 | `as_xxx`（无消耗借用）/ `to_xxx`（有代价借用）/ `into_xxx`（消耗所有权） | `get_xxx_as`, `convert_to` |
| Getter | 不加 `get_` 前缀：`fn name(&self)` | `fn get_name()` |
| Setter | 用 `set_xxx`，返回 `&mut Self` 可链式 | - |
| 布尔判断 | `is_xxx` / `has_xxx` / `should_xxx` | `flag`, `enabled_or_not` |
| 构造器 | `new` 默认，多个用 `with_xxx` / `from_xxx` | `create`, `make` |
| iterator | 实现 `IntoIterator` + 方法名 `iter` / `iter_mut` / `into_iter` | `get_iter` |

### 类型命名

- **泛型参数**：单字母仅用 `T/U/V/K/V`（容器场景），其余用 `Req`/`Resp`/`Ctx` 等可读名
- **生命周期**：默认 `'a`、`'b`；语义化时用 `'src`、`'ctx`、`'static`
- **newtype** 包装：直接用领域名，不带 `Wrapper` 后缀

```rust
// ✅
pub struct UserId(pub i64);
pub struct Email(String);

// ❌
pub struct UserIdWrapper(i64);
pub struct EmailString(String);
```

---

## 模块可见性

```rust
// 默认 pub(crate)，只有跨 crate 才用 pub
pub(crate) fn helper() { }

// 测试专用 API：用 #[cfg(test)] 或 pub(crate) 配合 #[doc(hidden)]
#[cfg(test)]
pub(crate) fn test_only() { }
```

**re-export 在 `lib.rs` / `main.rs`**：

```rust
mod api;
mod service;
mod error;

pub use error::AppError;     // 对外暴露的稳定 API
pub(crate) use service::*;    // crate 内复用
```

---

## `From` / `TryFrom` 实现规范

**优先实现 `From`/`TryFrom`**，不要手写 `to_xxx` 方法（除非有副作用或语义不对称）：

```rust
// ✅
impl From<UserRow> for User {
    fn from(row: UserRow) -> Self {
        User { id: row.id, name: row.name }
    }
}

impl TryFrom<&str> for Email {
    type Error = AppError;
    fn try_from(s: &str) -> Result<Self, Self::Error> {
        if s.contains('@') { Ok(Email(s.into())) }
        else { Err(AppError::BadRequest("invalid email".into())) }
    }
}
```

**有 `From`，自动获得 `Into`**，handler 里直接 `.into()`：

```rust
let user: User = row.into();
```

---

## newtype 模式

**何时用**：领域类型不能用裸 `i64` / `String` 混用时。

```rust
pub struct UserId(pub i64);
pub struct OrderId(pub i64);

// 编译期阻止类型混淆：UserId 不能传给要 OrderId 的函数
fn fetch_order(id: OrderId) -> Order { ... }
```

**派生派对**：

```rust
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, serde::Serialize, serde::Deserialize)]
pub struct UserId(pub i64);
```

---

## 迭代器优先于显式循环

```rust
// ❌ 显式循环
let mut result = Vec::new();
for x in &items {
    if x.active {
        result.push(x.name.clone());
    }
}

// ✅ 迭代器
let result: Vec<_> = items.iter()
    .filter(|x| x.active)
    .map(|x| x.name.clone())
    .collect();
```

**常用组合**：

| 操作 | 方法 |
|------|------|
| 累加 | `.sum()` / `.product()` / `.fold(init, f)` |
| 分组 | `.chunks(n)` / `.windows(n)` |
| 去重 | `.collect::<HashSet<_>>()` |
| 排序后去重 | `.sort(); .dedup();` |
| 配对 | `.zip(other)` |
| 累计枚举 | `.enumerate()` |
| 提前终止 | `.find(pred)` / `.any(pred)` / `.all(pred)` |
| 错误传播 | `.collect::<Result<Vec<_>, _>>()` |

---

## 字符串处理

| 场景 | 选择 |
|------|------|
| 参数：只读 | `&str` |
| 参数：需要所有权 | `String` |
| 参数：两种来源混合 | `impl Into<String>` |
| 字段：可借用静态 | `Cow<'static, str>` |
| 拼接：多次 | `String::with_capacity` + `push_str` |
| 格式化：一次 | `format!()` |

```rust
// ✅ 大量拼接预分配
let mut s = String::with_capacity(items.len() * 16);
for item in &items {
    s.push_str(&item.name);
    s.push(',');
}
```

---

## 派生与序列化

**标配派生**：

```rust
// 值类型
#[derive(Debug, Clone)]
pub struct User { ... }

// 可比较/可作 key
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct UserId(pub i64);

// API DTO
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UserDto {
    pub user_id: i64,
    pub display_name: String,
}
```

**`#[serde(rename_all = "camelCase")]`**：与前端约定一致，避免逐字段 `rename`。

**可选字段**：

```rust
#[derive(serde::Deserialize)]
pub struct UpdateUser {
    #[serde(default)]
    pub name: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub email: Option<String>,
}
```

---

## Trait 设计

**优先泛型 `<T: Trait>`（静态分发）**，性能敏感场景避免 `Box<dyn Trait>`：

```rust
// ✅ 静态分发，零成本
fn process<R: Repo>(repo: &R) { ... }

// ⚠️ 动态分发，有 vtable 开销，但参数类型可异构
fn process(repo: &dyn Repo) { ... }
```

**`async fn` in trait**：edition 2024 原生支持，老 edition 需要 `async-trait` crate。

**Trait 命名**：

- 行为：`Reader` / `Writer` / `Display`
- 转换：`From` / `Into` / `TryFrom`
- 标记：`Send` / `Sync` / `Sized`

---

## 常用 lints 推荐

`Cargo.toml`：

```toml
[lints.rust]
unsafe_code = "deny"
missing_docs = "warn"           # 库 crate 加

[lints.clippy]
all = "warn"
pedantic = "warn"               # 严格模式，新项目建议
nursery = "warn"
unwrap_used = "deny"
expect_used = "deny"
panic = "deny"
todo = "warn"
dbg_macro = "warn"
print_stdout = "warn"           # 防止误用 println! 替代日志
```
