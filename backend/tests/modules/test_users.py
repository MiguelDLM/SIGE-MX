import pytest
import pytest_asyncio
from httpx import AsyncClient
from sqlalchemy import select

from core.security import create_access_token, hash_password
from modules.users.models import Role, User, UserRole, UserStatus


@pytest_asyncio.fixture
async def directivo_role(db_session):
    result = await db_session.execute(select(Role).where(Role.name == "directivo"))
    role = result.scalar_one_or_none()
    if role is None:
        role = Role(name="directivo")
        db_session.add(role)
        await db_session.flush()
    return role


@pytest_asyncio.fixture
async def directivo_user(db_session, directivo_role):
    result = await db_session.execute(
        select(User).where(User.email == "directivo@test.com")
    )
    user = result.scalar_one_or_none()
    if user is None:
        user = User(
            email="directivo@test.com",
            password_hash=hash_password("password123"),
            nombre="Admin",
            apellido_paterno="Test",
            status=UserStatus.activo,
        )
        db_session.add(user)
        await db_session.flush()
        result2 = await db_session.execute(
            select(UserRole).where(
                UserRole.user_id == user.id, UserRole.role_id == directivo_role.id
            )
        )
        if result2.scalar_one_or_none() is None:
            db_session.add(UserRole(user_id=user.id, role_id=directivo_role.id))
        await db_session.commit()
        await db_session.refresh(user)
    return user


@pytest_asyncio.fixture
async def directivo_token(directivo_user):
    return create_access_token(str(directivo_user.id), ["directivo"])


@pytest.mark.asyncio
async def test_create_user_as_directivo(client: AsyncClient, directivo_token):
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
    # HTTPBearer returns 403 when no Authorization header is present
    response = await client.post(
        "/api/v1/users/",
        json={"email": "x@x.com", "password": "pass", "nombre": "X", "roles": []},
    )
    assert response.status_code == 403


@pytest.mark.asyncio
async def test_get_user_by_id(client: AsyncClient, directivo_token, directivo_user):
    response = await client.get(
        f"/api/v1/users/{directivo_user.id}",
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


@pytest_asyncio.fixture
async def admin_token(db_session):
    result = await db_session.execute(select(Role).where(Role.name == "directivo"))
    role = result.scalar_one_or_none()
    if role is None:
        role = Role(name="directivo")
        db_session.add(role)
        await db_session.flush()
    result = await db_session.execute(select(User).where(User.email == "admin_list@test.com"))
    user = result.scalar_one_or_none()
    if user is None:
        user = User(
            email="admin_list@test.com",
            password_hash=hash_password("pass"),
            nombre="Admin",
            apellido_paterno="List",
            status=UserStatus.activo,
        )
        db_session.add(user)
        await db_session.flush()
        db_session.add(UserRole(user_id=user.id, role_id=role.id))
        await db_session.commit()
        await db_session.refresh(user)
    return create_access_token(str(user.id), ["directivo"])


@pytest.mark.asyncio
async def test_list_users_by_role(client: AsyncClient, admin_token):
    resp = await client.get(
        "/api/v1/users/?role=directivo",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert resp.status_code == 200
    data = resp.json()["data"]
    for u in data:
        assert "directivo" in u["roles"]


@pytest.mark.asyncio
async def test_list_users_no_auth(client: AsyncClient):
    resp = await client.get("/api/v1/users/")
    assert resp.status_code in (401, 403)


@pytest.mark.asyncio
async def test_update_user_name(client: AsyncClient, directivo_token, directivo_user):
    response = await client.patch(
        f"/api/v1/users/{directivo_user.id}",
        json={"nombre": "AdminRenombrado"},
        headers={"Authorization": f"Bearer {directivo_token}"},
    )
    assert response.status_code == 200
    assert response.json()["data"]["nombre"] == "AdminRenombrado"


@pytest.mark.asyncio
async def test_deactivate_user(client: AsyncClient, directivo_token, directivo_user):
    response = await client.delete(
        f"/api/v1/users/{directivo_user.id}",
        headers={"Authorization": f"Bearer {directivo_token}"},
    )
    assert response.status_code == 204


@pytest.mark.asyncio
async def test_deactivate_nonexistent_user_returns_404(
    client: AsyncClient, directivo_token
):
    import uuid
    response = await client.delete(
        f"/api/v1/users/{uuid.uuid4()}",
        headers={"Authorization": f"Bearer {directivo_token}"},
    )
    assert response.status_code == 404
