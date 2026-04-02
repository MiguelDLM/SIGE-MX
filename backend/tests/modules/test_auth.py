import pytest
import pytest_asyncio
from httpx import AsyncClient

from core.security import hash_password
from modules.users.models import Role, User, UserRole, UserStatus


@pytest_asyncio.fixture
async def test_role(db_session):
    result = await db_session.execute(
        __import__("sqlalchemy").select(Role).where(Role.name == "docente")
    )
    existing = result.scalar_one_or_none()
    if existing:
        return existing
    role = Role(name="docente")
    db_session.add(role)
    await db_session.flush()
    return role


@pytest_asyncio.fixture
async def test_user(db_session, test_role):
    import sqlalchemy
    result = await db_session.execute(
        sqlalchemy.select(User).where(User.email == "login_test@school.mx")
    )
    existing = result.scalar_one_or_none()
    if existing:
        return existing
    user = User(
        email="login_test@school.mx",
        password_hash=hash_password("Password123!"),
        nombre="Test",
        apellido_paterno="User",
        status=UserStatus.activo,
    )
    db_session.add(user)
    await db_session.flush()
    db_session.add(UserRole(user_id=user.id, role_id=test_role.id))
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
async def test_get_me(client: AsyncClient, test_user):
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
    tokens = login_resp.json()["data"]

    await client.post(
        "/api/v1/auth/logout",
        json={"refresh_token": tokens["refresh_token"]},
        headers={"Authorization": f"Bearer {tokens['access_token']}"},
    )

    response = await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": tokens["refresh_token"]},
    )
    assert response.status_code == 401
