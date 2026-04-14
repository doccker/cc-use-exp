---
name: python-dev
description: Python 开发规范，包含 PEP 8 风格、类型注解、异常处理、测试规范等
version: v3.0
paths:
  - "**/*.py"
  - "**/pyproject.toml"
  - "**/requirements.txt"
  - "**/setup.py"
  - "**/Pipfile"
---

# Python 开发规范

> 参考来源: PEP 8、Google Python Style Guide

---

## 工具链

```bash
# 格式化
black .                              # 代码格式化
isort .                              # import 排序

# 类型检查
mypy .                               # 静态类型检查
pyright .                            # 备选

# 代码检查
ruff check .                         # 快速 linter（推荐）
flake8 .                             # 传统 linter

# 测试
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
from typing import Optional, List, Dict, Union
from dataclasses import dataclass

@dataclass
class User:
    id: int
    name: str
    email: Optional[str] = None

def find_user_by_id(user_id: int) -> Optional[User]:
    """根据 ID 查找用户"""
    ...

def process_items(items: List[str]) -> Dict[str, int]:
    """处理项目列表"""
    return {item: len(item) for item in items}

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
except:  # 永远不要这样做
    pass
```

---

## 自定义异常

```python
class ServiceError(Exception):
    """服务层异常基类"""
    def __init__(self, message: str, code: str = "UNKNOWN"):
        super().__init__(message)
        self.code = code

class UserNotFoundError(ServiceError):
    """用户不存在"""
    def __init__(self, user_id: int):
        super().__init__(f"User {user_id} not found", "USER_NOT_FOUND")
        self.user_id = user_id
```

---

## 日志规范

```python
import logging

logger = logging.getLogger(__name__)

# ✅ 好：使用参数化日志
logger.debug("Finding user by id: %s", user_id)
logger.info("User %s logged in successfully", username)
logger.error("Failed to process order %s", order_id, exc_info=True)

# ❌ 差：f-string（即使不输出也会计算）
logger.debug(f"Finding user by id: {user_id}")
```

---

## 测试规范（pytest）

```python
import pytest
from unittest.mock import Mock, patch

class TestUserService:
    @pytest.fixture
    def user_service(self):
        repository = Mock()
        return UserService(repository)

    def test_find_by_id_returns_user(self, user_service):
        # given
        expected = User(id=1, name="test")
        user_service.repository.find_by_id.return_value = expected

        # when
        result = user_service.find_by_id(1)

        # then
        assert result == expected
        user_service.repository.find_by_id.assert_called_once_with(1)

    def test_find_by_id_raises_when_not_found(self, user_service):
        # given
        user_service.repository.find_by_id.return_value = None

        # when/then
        with pytest.raises(UserNotFoundError):
            user_service.find_by_id(999)

# 参数化测试
@pytest.mark.parametrize("input,expected", [
    (1, 1),
    (2, 4),
    (3, 9),
])
def test_square(input, expected):
    assert square(input) == expected
```

---

## 异步编程

```python
import asyncio
from typing import List

async def fetch_user(user_id: int) -> User:
    """异步获取用户"""
    async with aiohttp.ClientSession() as session:
        async with session.get(f"/api/users/{user_id}") as response:
            data = await response.json()
            return User(**data)

async def fetch_all_users(user_ids: List[int]) -> List[User]:
    """并发获取多个用户"""
    tasks = [fetch_user(uid) for uid in user_ids]
    return await asyncio.gather(*tasks)

# 限制并发数
async def fetch_with_limit(user_ids: List[int], limit: int = 10) -> List[User]:
    semaphore = asyncio.Semaphore(limit)

    async def fetch_one(uid: int) -> User:
        async with semaphore:
            return await fetch_user(uid)

    return await asyncio.gather(*[fetch_one(uid) for uid in user_ids])
```

---

## 项目结构

```
project/
├── src/
│   └── myproject/
│       ├── __init__.py
│       ├── models/
│       ├── services/
│       ├── repositories/
│       └── utils/
├── tests/
│   ├── __init__.py
│   ├── conftest.py
│   └── test_*.py
├── pyproject.toml
├── requirements.txt
└── README.md
```

---

## 依赖管理

```toml
# pyproject.toml (推荐)
[project]
name = "myproject"
version = "1.0.0"
dependencies = [
    "fastapi>=0.100.0",
    "sqlalchemy>=2.0.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=7.0.0",
    "black>=23.0.0",
    "mypy>=1.0.0",
]
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

```python
# ✅ 使用生成器
def read_large_file(file_path: str):
    with open(file_path, 'r') as f:
        for line in f:
            yield line.strip()

# ✅ 高效字符串拼接
result = ''.join(strings)  # 而不是 += 循环
```

---

> 📋 本回复遵循：`python-dev` - [具体章节]
