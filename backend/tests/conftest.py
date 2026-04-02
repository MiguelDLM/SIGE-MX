import os
import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy.pool import NullPool

# Set env vars before importing app modules
os.environ.setdefault("DATABASE_URL", "postgresql+asyncpg://sige_user:changeme_strong_password@localhost:5432/sige_mx")
os.environ.setdefault("TEST_DATABASE_URL", "postgresql+asyncpg://sige_user:changeme_strong_password@postgres:5432/sige_mx_test")
os.environ.setdefault("REDIS_URL", "redis://localhost:6379/0")
os.environ.setdefault("REDIS_PASSWORD", "changeme_redis_password")
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

import models  # noqa: F401 — ensures all tables are in Base.metadata for test DB
from core.database import Base, get_db
from main import app

TEST_DATABASE_URL = os.environ["TEST_DATABASE_URL"]

test_engine = create_async_engine(TEST_DATABASE_URL, poolclass=NullPool)
TestSessionLocal = async_sessionmaker(test_engine, expire_on_commit=False)


@pytest_asyncio.fixture(scope="session", autouse=True, loop_scope="session")
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
