# Rust 项目结构

- 后端 Web 项目按职责拆 `.rs` 文件，不堆 `lib.rs`/`main.rs`。
- 典型布局：`main.rs`（仅 bootstrap）/ `config.rs` / `error.rs` / `db.rs` / `api.rs` / `service/` / `models.rs`。
- `main.rs` 只做：日志初始化、读配置、建路由、启服务、信号处理。
- 公共代码只有在跨模块复用确实成立时才抽到独立模块；不要为抽象而抽象。
- 同模块拆文件优先按职责（api/service/db），不要用无语义的文件名分组。
- `Cargo.lock` 二进制项目必须提交，库项目不提交。
- features 显式声明，禁止盲依赖默认值；TLS 选 `rustls` 避免 `openssl`。
