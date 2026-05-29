---
name: python-dev
description: Python 开发规范，包含 PEP 8 风格、类型注解、异步编程、性能优化等。当操作 .py, pyproject.toml, requirements.txt 文件时自动激活。
---
<instructions>

# Python 开发规范

> 参考来源: PEP 8、Google Python Style Guide

---

## 🛠️ 工具链与格式化

- **Black** 为强制格式化标准。
- **Ruff** 为首选代码静态检查工具（其速度极快且涵盖广泛规则）。
- **MyPy / Pyright** 用于强制类型检查。

---

## 命名约定

| 类型 | 规则 | 示例 |
|------|------|------|
| 模块/包 | 小写下划线 | `user_service.py` |
| 类名 | 大驼峰 | `UserService` |
| 函数/变量 | 小写下划线 | `get_user_by_id` |
| 私有方法 | 单下划线前缀 | `_internal_logic` |

---

## 🐍 Pythonic 特色

- **类型注解 (Type Hinting)**：所有公开接口必须定义类型。Python 3.10+ 优先使用 `|` 表示联合类型（Union）。
- **生成器 (Yield)**：大数据处理必须使用生成器以降低内存消耗。
- **上下文管理器**：文件/连接/锁定操作必须使用 `with` 语句。

---

## 异步编程原则

- 并发获取多个 I/O 密集任务时，使用 `asyncio.gather(*tasks)`。
- 必须为并发量大的异步任务设置信号量 `asyncio.Semaphore(limit)`。
- 耗时的 CPU 密集任务必须使用 `multiprocessing` 剥离，防止阻塞 Event Loop。

---

## 异常处理

```python
# ✅ 捕获具体异常并记录堆栈
try:
    user = repository.find(id)
except DatabaseError as e:
    logger.error("Failed to find user %s", id, exc_info=True)
    raise ServiceError(f"DB error: {e}") from e
```

---

> 📋 本回复遵循：`python-dev` - [章节]

</instructions>