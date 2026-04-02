# backend/tests/modules/test_academic_cycles.py
import pytest
import pytest_asyncio
from httpx import AsyncClient

from core.security import create_access_token, hash_password
from modules.users.models import Role, User, UserStatus


@pytest_asyncio.fixture
async def admin_token(db_session):
    import sqlalchemy
    result = await db_session.execute(
        sqlalchemy.select(Role).where(Role.name == "directivo")
    )
    role = result.scalar_one_or_none()
    if not role:
        role = Role(name="directivo")
        db_session.add(role)
        await db_session.flush()

    result = await db_session.execute(
        sqlalchemy.select(User).where(User.email == "admin_cycle@test.com")
    )
    user = result.scalar_one_or_none()
    if not user:
        from modules.users.models import UserRole
        user = User(
            email="admin_cycle@test.com",
            password_hash=hash_password("pass"),
            nombre="Admin",
            status=UserStatus.activo,
        )
        db_session.add(user)
        await db_session.flush()
        db_session.add(UserRole(user_id=user.id, role_id=role.id))
        await db_session.commit()
        await db_session.refresh(user)

    return create_access_token(str(user.id), ["directivo"])


@pytest.mark.asyncio
async def test_create_academic_cycle(client: AsyncClient, admin_token):
    response = await client.post(
        "/api/v1/academic-cycles/",
        json={
            "nombre": "2024-2025",
            "fecha_inicio": "2024-08-19",
            "fecha_fin": "2025-06-13",
            "activo": True,
        },
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 201
    data = response.json()["data"]
    assert data["nombre"] == "2024-2025"
    assert data["activo"] is True


@pytest.mark.asyncio
async def test_list_academic_cycles(client: AsyncClient, admin_token):
    response = await client.get(
        "/api/v1/academic-cycles/",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 200
    assert "data" in response.json()


@pytest.mark.asyncio
async def test_get_active_cycle(client: AsyncClient, admin_token):
    # Create one first
    await client.post(
        "/api/v1/academic-cycles/",
        json={"nombre": "Activo", "fecha_inicio": "2024-08-01", "fecha_fin": "2025-06-01", "activo": True},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    response = await client.get(
        "/api/v1/academic-cycles/active",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 200
    assert response.json()["data"]["activo"] is True


@pytest.mark.asyncio
async def test_create_cycle_without_auth_returns_403(client: AsyncClient):
    response = await client.post(
        "/api/v1/academic-cycles/",
        json={"nombre": "X"},
    )
    assert response.status_code == 403
