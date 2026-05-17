# Rust 风格

- 模块/文件 snake_case，类型/Trait UpperCamelCase，常量 SCREAMING_SNAKE_CASE。
- 禁止 `common`、`util`、`base` 等无意义模块名；按职责命名。
- `pub(crate)` 优先于 `pub`，只在确实跨 crate 时才暴露。
- 优先实现 `From`/`TryFrom`，不要手写 `to_xxx`（除非有副作用）。
- newtype 模式用领域名（`UserId(i64)`），不带 `Wrapper` 后缀。
- 迭代器优先于显式循环（`filter`/`map`/`collect`）。
- 函数参数：只读字符串用 `&str`、只读切片用 `&[T]`、路径用 `&Path`。
