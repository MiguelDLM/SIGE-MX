# SIGE-MX — Plan 1: Backend Foundation + Auth

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up Docker Compose infrastructure, async FastAPI app, PostgreSQL schema, JWT auth, and RBAC for SIGE-MX Phase 1 MVP.

**Architecture:** Monolito modular FastAPI. `core/` maneja config, DB session, seguridad JWT/Argon2 y RBAC. Los módulos `users` y `auth` son los primeros módulos de dominio. Todos los tests corren contra una base de datos PostgreSQL de prueba real — sin mocks de BD.

**Tech Stack:** Python 3.12, FastAPI 0.111, SQLAlchemy 2.0 async + asyncpg, Alembic, PostgreSQL 16, Redis 7, argon2-cffi, python-jose[cryptography], pydantic-settings 2.x, pytest-asyncio 0.23, httpx

---

## Estructura de archivos

```
/
├── docker-compose.yml
├── docker-compose.override.yml
├── .env.example
├── .gitignore
├── nginx/
│   └── nginx.conf
└── backend/
    ├── Dockerfile
    ├── requirements.txt
    ├── alembic.ini
    ├── main.py
    ├── core/
    │   ├── __init__.py
    │   ├── config.py
    │   ├── database.py
    │   ├── security.py
    │   └── exceptions.py
    ├── modules/
    │   ├── __init__.py
    │   ├── users/
    │   │   ├── __init__.py
    │   │   ├── models.py
    │   │   ├── schemas.py
    │   │   ├── service.py
    │   │   └── router.py
    │   └── auth/
    │       ├── __init__.py
    │       ├── schemas.py
    │       ├── service.py
    │       └── router.py
    ├── migrations/
    │   ├── env.py
    │   ├── script.py.mako
    │   └── versions/
    │       └── 001_initial_schema.py
    └── tests/
        ├── conftest.py
        ├── test_health.py
        ├── test_security.py
        └── modules/
            ├── test_auth.py
            └── test_users.py
```

---

## Task 1: Infraestructura Docker Compose

**Files:**
- Create: `docker-compose.yml`
- Create: `docker-compose.override.yml`
- Create: `.env.example`
- Create: `.gitignore`
- Create: `nginx/nginx.conf`
- Create: `backend/Dockerfile`
- Create: `backend/requirements.txt`

- [ ] **Step 1: Crear docker-compose.yml**

```yaml
# docker-compose.yml
version: "3.9"

services:
  backend:
    build: ./backend
    ports:
      - "8000:8000"
    env_file: .env
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    volumes:
      - ./backend:/app

  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 5s
      timeout: 5s
      retries: 10

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 5s
      retries: 5

  minio:
    image: minio/minio:latest
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: ${MINIO_ROOT_USER}
      MINIO_ROOT_PASSWORD: ${MINIO_ROOT_PASSWORD}
    volumes:
      - minio_data:/data
    ports:
      - "9000:9000"
      - "9001:9001"

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/conf.d/default.conf
    depends_on:
      - backend

volumes:
  postgres_data:
  minio_data:
```

- [ ] **Step 2: Crear .env.example**

```bash
# .env.example
# Copiar a .env y completar valores reales

# Database
POSTGRES_DB=sige_mx
POSTGRES_USER=sige_user
POSTGRES_PASSWORD=changeme_strong_password
DATABASE_URL=postgresql+asyncpg://sige_user:changeme_strong_password@postgres:5432/sige_mx
TEST_DATABASE_URL=postgresql+asyncpg://sige_user:changeme_strong_password@localhost:5432/sige_mx_test

# Redis
REDIS_URL=redis://redis:6379/0

# JWT — generar con: python -c "import secrets; print(secrets.token_hex(32))"
JWT_SECRET_KEY=changeme_use_256_bit_random_key
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=15
REFRESH_TOKEN_EXPIRE_DAYS=7

# MinIO
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=changeme_strong_password
MINIO_ENDPOINT=minio:9000

# App
APP_ENV=development
```

- [ ] **Step 3: Crear .gitignore**

```
# .gitignore
.env
__pycache__/
*.pyc
*.pyo
.pytest_cache/
.ruff_cache/
*.egg-info/
dist/
.venv/
venv/
.superpowers/
*.log
```

- [ ] **Step 4: Crear nginx/nginx.conf**

```nginx
# nginx/nginx.conf
server {
    listen 80;

    location /api/ {
        proxy_pass http://backend:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location /health {
        proxy_pass http://backend:8000;
    }
}
```

- [ ] **Step 5: Crear backend/Dockerfile**

```dockerfile
# backend/Dockerfile
FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
```

- [ ] **Step 6: Crear backend/requirements.txt**

```
fastapi==0.111.0
uvicorn[standard]==0.29.0
sqlalchemy[asyncio]==2.0.30
asyncpg==0.29.0
alembic==1.13.1
pydantic-settings==2.2.1
pydantic[email]==2.7.1
python-jose[cryptography]==3.3.0
argon2-cffi==23.1.0
redis[asyncio]==5.0.4
openpyxl==3.1.2
httpx==0.27.0
pytest==8.2.0
pytest-asyncio==0.23.6
anyio==4.3.0
```

- [ ] **Step 7: Copiar .env.example a .env y completar valores**

```bash
cp .env.example .env
# Editar .env con valores reales (contraseñas fuertes, JWT_SECRET_KEY aleatorio)
python -c "import secrets; print(secrets.token_hex(32))"
# Pegar el resultado como JWT_SECRET_KEY en .env
```

- [ ] **Step 8: Verificar que Docker Compose levanta**

```bash
docker compose up --build -d
docker compose ps
```

Expected output: todos los servicios con estado `healthy` o `running`.

```bash
docker compose logs backend
```

Expected: `INFO: Application startup complete.` (puede fallar aún si main.py no existe — se corrige en Task 2).

- [ ] **Step 9: Commit**

```bash
git add docker-compose.yml .env.example .gitignore nginx/backend/Dockerfile backend/requirements.txt
git commit -m "chore: add Docker Compose infrastructure and project skeleton"
```

---

## Task 2: FastAPI skeleton + health endpoint + setup de tests

**Files:**
- Create: `backend/main.py`
- Create: `backend/core/__init__.py`
- Create: `backend/modules/__init__.py`
- Create: `backend/tests/conftest.py`
- Create: `backend/tests/test_health.py`

- [ ] **Step 1: Crear backend/main.py**

```python
# backend/main.py
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(
    title="SIGE-MX API",
    description="Sistema Integral de Gestión Escolar",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health", tags=["health"])
async def health_check():
    return {"status": "ok"}
```

- [ ] **Step 2: Crear archivos __init__.py vacíos**

```bash
touch backend/core/__init__.py
touch backend/modules/__init__.py
touch backend/tests/__init__.py
mkdir -p backend/tests/modules
touch backend/tests/modules/__init__.py
```

- [ ] **Step 3: Crear backend/tests/conftest.py**

```python
# backend/tests/conftest.py
import os
import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy.pool import NullPool

# Configurar variables de entorno antes de importar módulos de la app
os.environ.setdefault("DATABASE_URL", "postgresql+asyncpg://sige_user:changeme_strong_password@localhost:5432/sige_mx")
os.environ.setdefault("TEST_DATABASE_URL", "postgresql+asyncpg://sige_user:changeme_strong_password@localhost:5432/sige_mx_test")
os.environ.setdefault("REDIS_URL", "redis://localhost:6379/0")
os.environ.setdefault("JWT_SECRET_KEY", "test-secret-key-for-testing-only-not-production")
os.environ.setdefault("JWT_ALGORITHM", "HS256")
os.environ.setdefault("ACCESS_TOKEN_EXPIRE_MINUTES", "15")
os.environ.setdefault("REFRESH_TOKEN_EXPIRE_DAYS", "7")
os.environ.setdefault("POSTGRES_DB", "sige_mx")
os.environ.setdefault("POSTGRES_USER", "sige_user")
os.environ.setdefault("POSTGRES_PASSWORD", "changeme_strong_password")
os.environ.setdefault("MINIO_ROOT_USER", "minioadmin")
os.environ.setdefault("MINIO_ROOT_PASSWORD", "changeme_strong_password")
os.environ.setdefault("MINIO_ENDPOINT", "localhost:9000")
os.environ.setdefault("APP_ENV", "test")

from core.database import Base, get_db
from main import app

TEST_DATABASE_URL = os.environ["TEST_DATABASE_URL"]

test_engine = create_async_engine(TEST_DATABASE_URL, poolclass=NullPool)
TestSessionLocal = async_sessionmaker(test_engine, expire_on_commit=False)


@pytest_asyncio.fixture(scope="session", autouse=True)
async def setup_test_db():
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)
    yield
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)


@pytest_asyncio.fixture
async def db_session() -> AsyncSession:
    async with TestSessionLocal() as session:
        yield session
        await session.rollback()


@pytest_asyncio.fixture
async def client(db_session: AsyncSession) -> AsyncClient:
    async def override_get_db():
        yield db_session

    app.dependency_overrides[get_db] = override_get_db
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        yield ac
    app.dependency_overrides.clear()
```

- [ ] **Step 4: Crear backend/tests/test_health.py**

```python
# backend/tests/test_health.py
import pytest


@pytest.mark.asyncio
async def test_health_check(client):
    response = await client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
```

- [ ] **Step 5: Crear backend/pytest.ini**

```ini
# backend/pytest.ini
[pytest]
asyncio_mode = auto
testpaths = tests
```

- [ ] **Step 6: Crear base de datos de test (ejecutar desde host con postgres corriendo)**

```bash
docker compose exec postgres psql -U sige_user -c "CREATE DATABASE sige_mx_test;"
```

Expected output: `CREATE DATABASE`

- [ ] **Step 7: Ejecutar tests desde dentro del contenedor backend**

```bash
docker compose exec backend pytest tests/test_health.py -v
```

Expected output:
```
tests/test_health.py::test_health_check PASSED
1 passed in 0.XXs
```

- [ ] **Step 8: Commit**

```bash
git add backend/main.py backend/core/__init__.py backend/modules/__init__.py backend/tests/ backend/pytest.ini
git commit -m "feat: add FastAPI app skeleton with health endpoint and test infrastructure"
```

---

## Task 3: Core config + database

**Files:**
- Create: `backend/core/config.py`
- Create: `backend/core/database.py`
- Create: `backend/core/exceptions.py`

- [ ] **Step 1: Crear backend/core/config.py**

```python
# backend/core/config.py
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    database_url: str
    test_database_url: str = ""
    redis_url: str = "redis://localhost:6379/0"

    jwt_secret_key: str
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 15
    refresh_token_expire_days: int = 7

    minio_root_user: str = "minioadmin"
    minio_root_password: str = "minioadmin"
    minio_endpoint: str = "localhost:9000"

    app_env: str = "development"


settings = Settings()
```

- [ ] **Step 2: Crear backend/core/database.py**

```python
# backend/core/database.py
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase

from core.config import settings


engine = create_async_engine(settings.database_url, echo=settings.app_env == "development")
AsyncSessionLocal = async_sessionmaker(engine, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


async def get_db() -> AsyncSession:
    async with AsyncSessionLocal() as session:
        yield session
```

- [ ] **Step 3: Crear backend/core/exceptions.py**

```python
# backend/core/exceptions.py
from fastapi import HTTPException, Request
from fastapi.responses import JSONResponse


class BusinessError(HTTPException):
    def __init__(self, code: str, message: str, status_code: int = 400):
        self.error_code = code
        super().__init__(status_code=status_code, detail=message)


async def business_error_handler(request: Request, exc: BusinessError) -> JSONResponse:
    return JSONResponse(
        status_code=exc.status_code,
        content={"error": {"code": exc.error_code, "message": exc.detail}},
    )


async def http_exception_handler(request: Request, exc: HTTPException) -> JSONResponse:
    return JSONResponse(
        status_code=exc.status_code,
        content={"error": {"code": "HTTP_ERROR", "message": exc.detail}},
    )
```

- [ ] **Step 4: Registrar handlers en main.py**

Reemplazar `backend/main.py` con:

```python
# backend/main.py
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from core.exceptions import BusinessError, business_error_handler, http_exception_handler

app = FastAPI(
    title="SIGE-MX API",
    description="Sistema Integral de Gestión Escolar",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.add_exception_handler(BusinessError, business_error_handler)
app.add_exception_handler(HTTPException, http_exception_handler)


@app.get("/health", tags=["health"])
async def health_check():
    return {"status": "ok"}
```

- [ ] **Step 5: Ejecutar tests para verificar que nada se rompió**

```bash
docker compose exec backend pytest tests/test_health.py -v
```

Expected: `1 passed`

- [ ] **Step 6: Commit**

```bash
git add backend/core/config.py backend/core/database.py backend/core/exceptions.py backend/main.py
git commit -m "feat: add core config, database session, and exception handlers"
```

---

## Task 4: SQLAlchemy models (Users, Roles) + Alembic

**Files:**
- Create: `backend/modules/users/models.py`
- Create: `backend/modules/users/__init__.py`
- Create: `backend/alembic.ini`
- Create: `backend/migrations/env.py`
- Create: `backend/migrations/script.py.mako`

- [ ] **Step 1: Crear backend/modules/users/__init__.py (vacío)**

```bash
touch backend/modules/users/__init__.py
```

- [ ] **Step 2: Crear backend/modules/users/models.py**

```python
# backend/modules/users/models.py
import enum
import uuid
from datetime import date, datetime

from sqlalchemy import Date, DateTime, Enum as SAEnum, ForeignKey, Integer, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from core.database import Base


class UserStatus(str, enum.Enum):
    activo = "activo"
    inactivo = "inactivo"
    suspendido = "suspendido"


class User(Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    email: Mapped[str | None] = mapped_column(String, unique=True, nullable=True)
    password_hash: Mapped[str] = mapped_column(String, nullable=False)
    telefono: Mapped[str | None] = mapped_column(String, nullable=True)
    nombre: Mapped[str] = mapped_column(String, nullable=False)
    apellido_paterno: Mapped[str | None] = mapped_column(String, nullable=True)
    apellido_materno: Mapped[str | None] = mapped_column(String, nullable=True)
    curp: Mapped[str | None] = mapped_column(String, unique=True, nullable=True)
    fecha_nacimiento: Mapped[date | None] = mapped_column(Date, nullable=True)
    status: Mapped[UserStatus] = mapped_column(
        SAEnum(UserStatus, name="user_status", create_type=False),
        default=UserStatus.activo,
        nullable=False,
    )
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, server_default=func.now(), onupdate=func.now()
    )

    roles: Mapped[list["UserRole"]] = relationship("UserRole", back_populates="user")


class Role(Base):
    __tablename__ = "roles"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String, unique=True, nullable=False)

    user_roles: Mapped[list["UserRole"]] = relationship("UserRole", back_populates="role")


class UserRole(Base):
    __tablename__ = "user_roles"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    role_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("roles.id"), primary_key=True
    )

    user: Mapped["User"] = relationship("User", back_populates="roles")
    role: Mapped["Role"] = relationship("Role", back_populates="user_roles")
```

- [ ] **Step 3: Crear backend/alembic.ini**

```ini
# backend/alembic.ini
[alembic]
script_location = migrations
prepend_sys_path = .
version_path_separator = os
sqlalchemy.url = driver://user:pass@localhost/dbname

[loggers]
keys = root,sqlalchemy,alembic

[handlers]
keys = console

[formatters]
keys = generic

[logger_root]
level = WARN
handlers = console
qualname =

[logger_sqlalchemy]
level = WARN
handlers =
qualname = sqlalchemy.engine

[logger_alembic]
level = INFO
handlers =
qualname = alembic

[handler_console]
class = StreamHandler
args = (sys.stderr,)
level = NOTSET
formatter = generic

[formatter_generic]
format = %(levelname)-5.5s [%(name)s] %(message)s
datefmt = %H:%M:%S
```

- [ ] **Step 4: Inicializar Alembic y crear migrations/env.py**

Ejecutar dentro del contenedor:
```bash
docker compose exec backend alembic init migrations
```

Reemplazar el contenido de `backend/migrations/env.py` con:

```python
# backend/migrations/env.py
import asyncio
import os
from logging.config import fileConfig

from alembic import context
from sqlalchemy.ext.asyncio import create_async_engine

# Importar todos los modelos para que Alembic los detecte
from core.database import Base
import modules.users.models  # noqa: F401

config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata

DATABASE_URL = os.environ.get("DATABASE_URL", config.get_main_option("sqlalchemy.url"))


def run_migrations_offline() -> None:
    context.configure(
        url=DATABASE_URL,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )
    with context.begin_transaction():
        context.run_migrations()


def do_run_migrations(connection):
    context.configure(connection=connection, target_metadata=target_metadata)
    with context.begin_transaction():
        context.run_migrations()


async def run_migrations_online() -> None:
    connectable = create_async_engine(DATABASE_URL)
    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)
    await connectable.dispose()


if context.is_offline_mode():
    run_migrations_offline()
else:
    asyncio.run(run_migrations_online())
```

- [ ] **Step 5: Crear la migración inicial**

```bash
docker compose exec backend alembic revision --autogenerate -m "initial_users_schema"
```

Expected output:
```
Generating /app/migrations/versions/XXXX_initial_users_schema.py ... done
```

- [ ] **Step 6: Revisar el archivo generado**

Abrir `backend/migrations/versions/XXXX_initial_users_schema.py` y verificar que contiene `create_table` para `users`, `roles`, `user_roles`. Si el autogenerate creó el enum `user_status`, verificar que esté correcto.

- [ ] **Step 7: Correr la migración**

```bash
docker compose exec backend alembic upgrade head
```

Expected output:
```
INFO  [alembic.runtime.migration] Running upgrade  -> XXXX, initial_users_schema
```

- [ ] **Step 8: Verificar tablas en PostgreSQL**

```bash
docker compose exec postgres psql -U sige_user -d sige_mx -c "\dt"
```

Expected output: tablas `users`, `roles`, `user_roles`, `alembic_version`.

- [ ] **Step 9: Commit**

```bash
git add backend/modules/users/ backend/alembic.ini backend/migrations/
git commit -m "feat: add User/Role SQLAlchemy models and initial Alembic migration"
```

---

## Task 5: Core security (JWT + Argon2) + tests

**Files:**
- Create: `backend/core/security.py`
- Create: `backend/tests/test_security.py`

- [ ] **Step 1: Escribir tests que fallan primero**

```python
# backend/tests/test_security.py
import pytest
from core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    verify_password,
)


def test_hash_password_returns_different_hash_each_time():
    h1 = hash_password("password123")
    h2 = hash_password("password123")
    assert h1 != h2  # Argon2 usa salt aleatorio


def test_verify_password_correct():
    h = hash_password("mi_contraseña")
    assert verify_password("mi_contraseña", h) is True


def test_verify_password_incorrect():
    h = hash_password("mi_contraseña")
    assert verify_password("incorrecta", h) is False


def test_create_access_token_contains_user_id_and_roles():
    token = create_access_token("user-abc", ["docente", "directivo"])
    payload = decode_token(token)
    assert payload["sub"] == "user-abc"
    assert payload["roles"] == ["docente", "directivo"]
    assert payload["type"] == "access"


def test_create_refresh_token_type_is_refresh():
    token = create_refresh_token("user-abc")
    payload = decode_token(token)
    assert payload["sub"] == "user-abc"
    assert payload["type"] == "refresh"
    assert "roles" not in payload


def test_decode_invalid_token_raises_401():
    from fastapi import HTTPException
    with pytest.raises(HTTPException) as exc_info:
        decode_token("token.invalido.xxx")
    assert exc_info.value.status_code == 401
```

- [ ] **Step 2: Ejecutar tests para confirmar que fallan**

```bash
docker compose exec backend pytest tests/test_security.py -v
```

Expected: `ERROR` o `ImportError: cannot import name 'hash_password' from 'core.security'`

- [ ] **Step 3: Crear backend/core/security.py**

```python
# backend/core/security.py
from datetime import datetime, timedelta, timezone

from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError, VerificationError, InvalidHashError
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt

from core.config import settings

_ph = PasswordHasher()
_bearer = HTTPBearer()


def hash_password(password: str) -> str:
    return _ph.hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    try:
        return _ph.verify(password_hash, password)
    except (VerifyMismatchError, VerificationError, InvalidHashError):
        return False


def create_access_token(user_id: str, roles: list[str]) -> str:
    expire = datetime.now(timezone.utc) + timedelta(
        minutes=settings.access_token_expire_minutes
    )
    return jwt.encode(
        {"sub": user_id, "roles": roles, "exp": expire, "type": "access"},
        settings.jwt_secret_key,
        algorithm=settings.jwt_algorithm,
    )


def create_refresh_token(user_id: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(
        days=settings.refresh_token_expire_days
    )
    return jwt.encode(
        {"sub": user_id, "exp": expire, "type": "refresh"},
        settings.jwt_secret_key,
        algorithm=settings.jwt_algorithm,
    )


def decode_token(token: str) -> dict:
    try:
        return jwt.decode(
            token, settings.jwt_secret_key, algorithms=[settings.jwt_algorithm]
        )
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Token inválido o expirado"
        )


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(_bearer),
) -> dict:
    payload = decode_token(credentials.credentials)
    if payload.get("type") != "access":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Token de acceso requerido"
        )
    return {"user_id": payload["sub"], "roles": payload.get("roles", [])}


def require_roles(allowed_roles: list[str]):
    """Dependencia FastAPI: verifica que el usuario tenga al menos uno de los roles permitidos."""

    async def checker(current_user: dict = Depends(get_current_user)) -> dict:
        if not any(r in allowed_roles for r in current_user["roles"]):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Permisos insuficientes",
            )
        return current_user

    return checker
```

- [ ] **Step 4: Ejecutar tests y verificar que pasan**

```bash
docker compose exec backend pytest tests/test_security.py -v
```

Expected output:
```
tests/test_security.py::test_hash_password_returns_different_hash_each_time PASSED
tests/test_security.py::test_verify_password_correct PASSED
tests/test_security.py::test_verify_password_incorrect PASSED
tests/test_security.py::test_create_access_token_contains_user_id_and_roles PASSED
tests/test_security.py::test_create_refresh_token_type_is_refresh PASSED
tests/test_security.py::test_decode_invalid_token_raises_401 PASSED
6 passed in 0.XXs
```

- [ ] **Step 5: Commit**

```bash
git add backend/core/security.py backend/tests/test_security.py
git commit -m "feat: add JWT and Argon2 security module with tests"
```

---

## Task 6: Users module (schemas + service + router)

**Files:**
- Create: `backend/modules/users/schemas.py`
- Create: `backend/modules/users/service.py`
- Create: `backend/modules/users/router.py`
- Create: `backend/tests/modules/test_users.py`

- [ ] **Step 1: Escribir tests que fallan**

```python
# backend/tests/modules/test_users.py
import pytest
from httpx import AsyncClient

from core.security import create_access_token, hash_password
from modules.users.models import Role, User, UserRole, UserStatus


@pytest_asyncio.fixture
async def directivo_user(db_session):
    role = Role(name="directivo")
    db_session.add(role)
    await db_session.flush()

    user = User(
        email="directivo@test.com",
        password_hash=hash_password("password123"),
        nombre="Admin",
        apellido_paterno="Test",
        status=UserStatus.activo,
    )
    db_session.add(user)
    await db_session.flush()

    db_session.add(UserRole(user_id=user.id, role_id=role.id))
    await db_session.commit()
    await db_session.refresh(user)
    return user, role


@pytest_asyncio.fixture
async def directivo_token(directivo_user):
    user, _ = directivo_user
    return create_access_token(str(user.id), ["directivo"])


@pytest.mark.asyncio
async def test_create_user_as_directivo(client: AsyncClient, directivo_token, db_session):
    response = await client.post(
        "/api/v1/users/",
        json={
            "email": "docente1@school.mx",
            "password": "Segura123!",
            "nombre": "Carlos",
            "apellido_paterno": "Lopez",
            "roles": ["docente"],
        },
        headers={"Authorization": f"Bearer {directivo_token}"},
    )
    assert response.status_code == 201
    data = response.json()["data"]
    assert data["email"] == "docente1@school.mx"
    assert data["nombre"] == "Carlos"
    assert "password" not in data
    assert "password_hash" not in data


@pytest.mark.asyncio
async def test_create_user_without_auth_returns_403(client: AsyncClient):
    # HTTPBearer retorna 403 cuando no hay header Authorization
    response = await client.post(
        "/api/v1/users/",
        json={"email": "x@x.com", "password": "pass", "nombre": "X", "roles": []},
    )
    assert response.status_code == 403


@pytest.mark.asyncio
async def test_get_user_by_id(client: AsyncClient, directivo_token, directivo_user):
    user, _ = directivo_user
    response = await client.get(
        f"/api/v1/users/{user.id}",
        headers={"Authorization": f"Bearer {directivo_token}"},
    )
    assert response.status_code == 200
    assert response.json()["data"]["email"] == "directivo@test.com"


@pytest.mark.asyncio
async def test_create_duplicate_email_returns_409(
    client: AsyncClient, directivo_token, directivo_user
):
    response = await client.post(
        "/api/v1/users/",
        json={
            "email": "directivo@test.com",
            "password": "pass",
            "nombre": "Otro",
            "roles": [],
        },
        headers={"Authorization": f"Bearer {directivo_token}"},
    )
    assert response.status_code == 409
```

Agregar al inicio del archivo:
```python
import pytest_asyncio
```

- [ ] **Step 2: Ejecutar tests para confirmar que fallan**

```bash
docker compose exec backend pytest tests/modules/test_users.py -v
```

Expected: `ImportError` o `404` en los endpoints.

- [ ] **Step 3: Crear backend/modules/users/schemas.py**

```python
# backend/modules/users/schemas.py
import uuid
from datetime import date, datetime
from typing import Optional

from pydantic import BaseModel, EmailStr, field_validator


class UserCreate(BaseModel):
    email: Optional[EmailStr] = None
    password: str
    telefono: Optional[str] = None
    nombre: str
    apellido_paterno: Optional[str] = None
    apellido_materno: Optional[str] = None
    curp: Optional[str] = None
    fecha_nacimiento: Optional[date] = None
    roles: list[str] = []


class UserUpdate(BaseModel):
    telefono: Optional[str] = None
    nombre: Optional[str] = None
    apellido_paterno: Optional[str] = None
    apellido_materno: Optional[str] = None
    status: Optional[str] = None


class UserResponse(BaseModel):
    id: uuid.UUID
    email: Optional[str]
    telefono: Optional[str]
    nombre: str
    apellido_paterno: Optional[str]
    apellido_materno: Optional[str]
    curp: Optional[str]
    status: str
    created_at: datetime
    roles: list[str] = []

    model_config = {"from_attributes": True}
```

- [ ] **Step 4: Crear backend/modules/users/service.py**

```python
# backend/modules/users/service.py
import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.exc import IntegrityError

from core.exceptions import BusinessError
from core.security import hash_password
from modules.users.models import Role, User, UserRole, UserStatus
from modules.users.schemas import UserCreate, UserUpdate


async def create_user(data: UserCreate, db: AsyncSession) -> User:
    user = User(
        email=data.email,
        password_hash=hash_password(data.password),
        telefono=data.telefono,
        nombre=data.nombre,
        apellido_paterno=data.apellido_paterno,
        apellido_materno=data.apellido_materno,
        curp=data.curp,
        fecha_nacimiento=data.fecha_nacimiento,
        status=UserStatus.activo,
    )
    db.add(user)
    try:
        await db.flush()
    except IntegrityError:
        await db.rollback()
        raise BusinessError("DUPLICATE_EMAIL", "El email ya está registrado", status_code=409)

    for role_name in data.roles:
        role_result = await db.execute(select(Role).where(Role.name == role_name))
        role = role_result.scalar_one_or_none()
        if role is None:
            role = Role(name=role_name)
            db.add(role)
            await db.flush()
        db.add(UserRole(user_id=user.id, role_id=role.id))

    await db.commit()
    await db.refresh(user)
    return user


async def get_user_by_id(user_id: uuid.UUID, db: AsyncSession) -> User:
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user is None:
        raise BusinessError("USER_NOT_FOUND", "Usuario no encontrado", status_code=404)
    return user


async def get_user_roles(user_id: uuid.UUID, db: AsyncSession) -> list[str]:
    result = await db.execute(
        select(Role.name)
        .join(UserRole, Role.id == UserRole.role_id)
        .where(UserRole.user_id == user_id)
    )
    return list(result.scalars())
```

- [ ] **Step 5: Crear backend/modules/users/router.py**

```python
# backend/modules/users/router.py
import uuid

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from core.database import get_db
from core.security import require_roles
from modules.users import service
from modules.users.schemas import UserCreate, UserResponse, UserUpdate

router = APIRouter(prefix="/api/v1/users", tags=["users"])

_admin_roles = ["directivo", "control_escolar"]


@router.post("/", status_code=status.HTTP_201_CREATED)
async def create_user(
    data: UserCreate,
    db: AsyncSession = Depends(get_db),
    _=Depends(require_roles(_admin_roles)),
):
    user = await service.create_user(data, db)
    roles = await service.get_user_roles(user.id, db)
    response_data = UserResponse.model_validate(user)
    response_data.roles = roles
    return {"data": response_data}


@router.get("/{user_id}")
async def get_user(
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _=Depends(require_roles(_admin_roles)),
):
    user = await service.get_user_by_id(user_id, db)
    roles = await service.get_user_roles(user.id, db)
    response_data = UserResponse.model_validate(user)
    response_data.roles = roles
    return {"data": response_data}
```

- [ ] **Step 6: Registrar el router en main.py**

Agregar al final de `backend/main.py`:

```python
from modules.users.router import router as users_router
app.include_router(users_router)
```

- [ ] **Step 7: Ejecutar tests**

```bash
docker compose exec backend pytest tests/modules/test_users.py -v
```

Expected:
```
tests/modules/test_users.py::test_create_user_as_directivo PASSED
tests/modules/test_users.py::test_create_user_without_auth_returns_401 PASSED
tests/modules/test_users.py::test_get_user_by_id PASSED
tests/modules/test_users.py::test_create_duplicate_email_returns_409 PASSED
4 passed
```

- [ ] **Step 8: Commit**

```bash
git add backend/modules/users/ backend/main.py
git commit -m "feat: add users module with CRUD and role assignment"
```

---

## Task 7: Auth module (login + refresh + logout)

**Files:**
- Create: `backend/modules/auth/__init__.py`
- Create: `backend/modules/auth/schemas.py`
- Create: `backend/modules/auth/service.py`
- Create: `backend/modules/auth/router.py`
- Create: `backend/tests/modules/test_auth.py`

- [ ] **Step 1: Escribir tests que fallan**

```python
# backend/tests/modules/test_auth.py
import pytest
import pytest_asyncio
from httpx import AsyncClient

from core.security import hash_password
from modules.users.models import Role, User, UserRole, UserStatus


@pytest_asyncio.fixture
async def test_user(db_session):
    role = Role(name="docente")
    db_session.add(role)
    await db_session.flush()

    user = User(
        email="login_test@school.mx",
        password_hash=hash_password("Password123!"),
        nombre="Test",
        apellido_paterno="User",
        status=UserStatus.activo,
    )
    db_session.add(user)
    await db_session.flush()
    db_session.add(UserRole(user_id=user.id, role_id=role.id))
    await db_session.commit()
    await db_session.refresh(user)
    return user


@pytest.mark.asyncio
async def test_login_success(client: AsyncClient, test_user):
    response = await client.post(
        "/api/v1/auth/login",
        json={"email": "login_test@school.mx", "password": "Password123!"},
    )
    assert response.status_code == 200
    data = response.json()["data"]
    assert "access_token" in data
    assert "refresh_token" in data
    assert data["token_type"] == "bearer"


@pytest.mark.asyncio
async def test_login_wrong_password(client: AsyncClient, test_user):
    response = await client.post(
        "/api/v1/auth/login",
        json={"email": "login_test@school.mx", "password": "WrongPassword"},
    )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_login_nonexistent_email(client: AsyncClient):
    response = await client.post(
        "/api/v1/auth/login",
        json={"email": "noexiste@test.com", "password": "any"},
    )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_refresh_token(client: AsyncClient, test_user):
    # Login primero
    login_resp = await client.post(
        "/api/v1/auth/login",
        json={"email": "login_test@school.mx", "password": "Password123!"},
    )
    refresh_token = login_resp.json()["data"]["refresh_token"]

    response = await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": refresh_token},
    )
    assert response.status_code == 200
    assert "access_token" in response.json()["data"]


@pytest.mark.asyncio
async def test_access_protected_route_with_token(client: AsyncClient, test_user):
    login_resp = await client.post(
        "/api/v1/auth/login",
        json={"email": "login_test@school.mx", "password": "Password123!"},
    )
    access_token = login_resp.json()["data"]["access_token"]

    response = await client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {access_token}"},
    )
    assert response.status_code == 200
    assert response.json()["data"]["email"] == "login_test@school.mx"


@pytest.mark.asyncio
async def test_logout_invalidates_refresh_token(client: AsyncClient, test_user):
    login_resp = await client.post(
        "/api/v1/auth/login",
        json={"email": "login_test@school.mx", "password": "Password123!"},
    )
    refresh_token = login_resp.json()["data"]["refresh_token"]

    # Logout
    await client.post(
        "/api/v1/auth/logout",
        json={"refresh_token": refresh_token},
        headers={"Authorization": f"Bearer {login_resp.json()['data']['access_token']}"},
    )

    # Intentar refrescar con token revocado
    response = await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": refresh_token},
    )
    assert response.status_code == 401
```

- [ ] **Step 2: Ejecutar tests para confirmar que fallan**

```bash
docker compose exec backend pytest tests/modules/test_auth.py -v
```

Expected: `404` o `ImportError`.

- [ ] **Step 3: Crear backend/modules/auth/__init__.py (vacío)**

```bash
touch backend/modules/auth/__init__.py
```

- [ ] **Step 4: Crear backend/modules/auth/schemas.py**

```python
# backend/modules/auth/schemas.py
from pydantic import BaseModel, EmailStr


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class AccessTokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class RefreshRequest(BaseModel):
    refresh_token: str
```

- [ ] **Step 5: Crear backend/modules/auth/service.py**

```python
# backend/modules/auth/service.py
from datetime import timedelta

import redis.asyncio as aioredis
from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from core.config import settings
from core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    verify_password,
)
from modules.users.models import Role, User, UserRole, UserStatus


async def _get_redis():
    client = aioredis.from_url(settings.redis_url, decode_responses=True)
    try:
        yield client
    finally:
        await client.aclose()


async def login(email: str, password: str, db: AsyncSession) -> dict:
    result = await db.execute(select(User).where(User.email == email))
    user = result.scalar_one_or_none()

    if user is None or not verify_password(password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Credenciales inválidas",
        )
    if user.status != UserStatus.activo:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Usuario inactivo o suspendido",
        )

    roles_result = await db.execute(
        select(Role.name)
        .join(UserRole, Role.id == UserRole.role_id)
        .where(UserRole.user_id == user.id)
    )
    roles = list(roles_result.scalars())

    return {
        "access_token": create_access_token(str(user.id), roles),
        "refresh_token": create_refresh_token(str(user.id)),
        "token_type": "bearer",
    }


async def refresh_access_token(refresh_token: str, db: AsyncSession, redis_client) -> dict:
    if await redis_client.get(f"blacklist:{refresh_token}"):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Token revocado"
        )

    payload = decode_token(refresh_token)
    if payload.get("type") != "refresh":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Tipo de token inválido"
        )

    user_id = payload["sub"]
    roles_result = await db.execute(
        select(Role.name)
        .join(UserRole, Role.id == UserRole.role_id)
        .where(UserRole.user_id == user_id)
    )
    roles = list(roles_result.scalars())

    return {
        "access_token": create_access_token(user_id, roles),
        "token_type": "bearer",
    }


async def logout(refresh_token: str, redis_client) -> dict:
    try:
        payload = decode_token(refresh_token)
    except HTTPException:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Token inválido"
        )

    ttl = int(timedelta(days=settings.refresh_token_expire_days).total_seconds())
    await redis_client.setex(f"blacklist:{refresh_token}", ttl, "1")
    return {"message": "Sesión cerrada correctamente"}


async def get_me(user_id: str, db: AsyncSession) -> User:
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Usuario no encontrado")
    return user
```

- [ ] **Step 6: Crear backend/modules/auth/router.py**

```python
# backend/modules/auth/router.py
import redis.asyncio as aioredis
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from core.config import settings
from core.database import get_db
from core.security import get_current_user
from modules.auth import service
from modules.auth.schemas import AccessTokenResponse, LoginRequest, RefreshRequest, TokenResponse
from modules.users.schemas import UserResponse

router = APIRouter(prefix="/api/v1/auth", tags=["auth"])


async def get_redis():
    client = aioredis.from_url(settings.redis_url, decode_responses=True)
    try:
        yield client
    finally:
        await client.aclose()


@router.post("/login")
async def login(
    data: LoginRequest,
    db: AsyncSession = Depends(get_db),
):
    tokens = await service.login(data.email, data.password, db)
    return {"data": tokens}


@router.post("/refresh")
async def refresh(
    data: RefreshRequest,
    db: AsyncSession = Depends(get_db),
    redis_client=Depends(get_redis),
):
    tokens = await service.refresh_access_token(data.refresh_token, db, redis_client)
    return {"data": tokens}


@router.post("/logout")
async def logout(
    data: RefreshRequest,
    current_user: dict = Depends(get_current_user),
    redis_client=Depends(get_redis),
):
    result = await service.logout(data.refresh_token, redis_client)
    return {"data": result}


@router.get("/me")
async def get_me(
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    user = await service.get_me(current_user["user_id"], db)
    return {"data": UserResponse.model_validate(user)}
```

- [ ] **Step 7: Registrar router de auth en main.py**

Agregar a `backend/main.py`:

```python
from modules.auth.router import router as auth_router
app.include_router(auth_router)
```

- [ ] **Step 8: Ejecutar todos los tests**

```bash
docker compose exec backend pytest tests/ -v
```

Expected output:
```
tests/test_health.py::test_health_check PASSED
tests/test_security.py::test_hash_password_returns_different_hash_each_time PASSED
tests/test_security.py::test_verify_password_correct PASSED
tests/test_security.py::test_verify_password_incorrect PASSED
tests/test_security.py::test_create_access_token_contains_user_id_and_roles PASSED
tests/test_security.py::test_create_refresh_token_type_is_refresh PASSED
tests/test_security.py::test_decode_invalid_token_raises_401 PASSED
tests/modules/test_users.py::test_create_user_as_directivo PASSED
tests/modules/test_users.py::test_create_user_without_auth_returns_401 PASSED
tests/modules/test_users.py::test_get_user_by_id PASSED
tests/modules/test_users.py::test_create_duplicate_email_returns_409 PASSED
tests/modules/test_auth.py::test_login_success PASSED
tests/modules/test_auth.py::test_login_wrong_password PASSED
tests/modules/test_auth.py::test_login_nonexistent_email PASSED
tests/modules/test_auth.py::test_refresh_token PASSED
tests/modules/test_auth.py::test_access_protected_route_with_token PASSED
tests/modules/test_auth.py::test_logout_invalidates_refresh_token PASSED
17 passed
```

- [ ] **Step 9: Commit final**

```bash
git add backend/modules/auth/ backend/main.py
git commit -m "feat: add auth module with login, refresh token, logout and /me endpoint"
```

---

## Task 8: Verificación integral

- [ ] **Step 1: Levantar stack completo**

```bash
docker compose up -d
docker compose ps
```

Expected: todos los servicios `healthy`.

- [ ] **Step 2: Verificar documentación automática**

Abrir `http://localhost:8000/docs` en el navegador. Deben aparecer los endpoints:
- `GET /health`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/refresh`
- `POST /api/v1/auth/logout`
- `GET /api/v1/auth/me`
- `POST /api/v1/users/`
- `GET /api/v1/users/{user_id}`

- [ ] **Step 3: Smoke test manual con curl**

```bash
# Crear usuario directivo inicial (requiere acceso directo a BD)
docker compose exec postgres psql -U sige_user -d sige_mx -c "
  INSERT INTO roles (name) VALUES ('directivo') ON CONFLICT DO NOTHING;
"

# (Alternativamente, crear via script seed)
```

- [ ] **Step 4: Ejecutar suite completa de tests una última vez**

```bash
docker compose exec backend pytest tests/ -v --tb=short
```

Expected: `17 passed, 0 failed`

- [ ] **Step 5: Commit de cierre del plan**

```bash
git add .
git commit -m "chore: Plan 1 complete — backend foundation with auth and RBAC"
```

---

## Deferred al Plan 2

- `core/audit.py` — middleware de auditoría automática (requiere tabla `audit_log`)
- Modelos SQLAlchemy y migración del schema completo (students, teachers, groups, subjects, attendance, grades, etc.) — se incluyen todos en Plan 2 para generar una sola migración comprehensiva

---

## Siguiente paso

**Plan 2:** Schema completo + audit middleware + módulos Students, Teachers, Groups, Subjects.
