---
name: python-dev
description: >-
  Python 开发规范。当用户操作 .py、pyproject.toml、requirements.txt、setup.py 文件，
  或涉及 FastAPI、Django、Flask、pytest、asyncio 开发时触发。
  包含 PEP 8 风格、类型注解、异常处理、测试规范、异步编程、性能优化等。
---

# Python 开发规范

> 参考来源: PEP 8、Google Python Style Guide

---

## 工具链

```bash
black .                              # 代码格式化
isort .                              # import 排序
mypy .                               # 静态类型检查
ruff check .                         # 快速 linter（推荐）
pytest -v                            # 运行测试
pytest --cov=src                     # 覆盖率
```

---

## 命名约定

| 类型 | 规则 | 示例 |
|------|------|------|
| 模块/包 | 小写下划线 | `user_service.py` |
| 类名 | 大驼峰 | `UserService`, `HttpClient` |
| 函数/变量 | 小写下划线 | `get_user_by_id`, `user_name` |
| 常量 | 全大写下划线 | `MAX_RETRY_COUNT` |
| 私有 | 单下划线前缀 | `_internal_method` |

---

## 类型注解

```python
from typing import Optional, List, Dict
from dataclasses import dataclass

@dataclass
class User:
    id: int
    name: str
    email: Optional[str] = None

def find_user_by_id(user_id: int) -> Optional[User]:
    ...

# Python 3.10+ 可用新语法
def greet(name: str | None = None) -> str:
    return f"Hello, {name or 'World'}"
```

---

## 异常处理

```python
# ✅ 好：捕获具体异常
try:
    user = repository.find_by_id(user_id)
except DatabaseError as e:
    logger.error(f"Failed to find user {user_id}: {e}")
    raise ServiceError(f"Database error: {e}") from e

# ✅ 好：上下文管理器
with open("file.txt", "r") as f:
    content = f.read()

# ❌ 差：裸 except
try:
    do_something()
except:
    pass
```

---

## 测试规范（pytest）

```python
import pytest
from unittest.mock import Mock

class TestUserService:
    @pytest.fixture
    def user_service(self):
        repository = Mock()
        return UserService(repository)

    def test_find_by_id_returns_user(self, user_service):
        expected = User(id=1, name="test")
        user_service.repository.find_by_id.return_value = expected
        result = user_service.find_by_id(1)
        assert result == expected

# 参数化测试
@pytest.mark.parametrize("input,expected", [
    (1, 1), (2, 4), (3, 9),
])
def test_square(input, expected):
    assert square(input) == expected
```

---

## 异步编程

```python
import asyncio

async def fetch_user(user_id: int) -> User:
    async with aiohttp.ClientSession() as session:
        async with session.get(f"/api/users/{user_id}") as response:
            data = await response.json()
            return User(**data)

# 限制并发数
async def fetch_with_limit(user_ids: list[int], limit: int = 10) -> list[User]:
    semaphore = asyncio.Semaphore(limit)
    async def fetch_one(uid: int) -> User:
        async with semaphore:
            return await fetch_user(uid)
    return await asyncio.gather(*[fetch_one(uid) for uid in user_ids])
```

---

## 性能优化

| 场景 | 方案 |
|------|------|
| 大数据处理 | 使用生成器 `yield` |
| 字符串拼接 | 使用 `''.join()` |
| 查找操作 | 使用 `set` 或 `dict` |
| 并发 I/O | 使用 `asyncio` |
| CPU 密集 | 使用 `multiprocessing` |

---

## 项目结构

```
project/
├── src/
│   └── myproject/
│       ├── __init__.py
│       ├── models/
│       ├── services/
│       └── utils/
├── tests/
│   ├── conftest.py
│   └── test_*.py
├── pyproject.toml
└── README.md
```
