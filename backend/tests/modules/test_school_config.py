import pytest
import pytest_asyncio
from httpx import AsyncClient
from sqlalchemy import select

from core.security import create_access_token, hash_password
from modules.users.models import Role, User, UserRole, UserStatus


@pytest_asyncio.fixture
async def config_admin_token(db_session):
    result = await db_session.execute(select(Role).where(Role.name == "directivo"))
    role = result.scalar_one_or_none()
    if role is None:
        role = Role(name="directivo")
        db_session.add(role)
        await db_session.flush()
    user = User(
        email="config_admin@test.com",
        password_hash=hash_password("pass"),
        nombre="Config",
        apellido_paterno="Admin",
        status=UserStatus.activo,
    )
    db_session.add(user)
    await db_session.flush()
    db_session.add(UserRole(user_id=user.id, role_id=role.id))
    await db_session.commit()
    return create_access_token(str(user.id), ["directivo"])


@pytest.mark.asyncio
async def test_get_config_returns_null_defaults(client: AsyncClient, config_admin_token):
    response = await client.get(
        "/api/v1/config/",
        headers={"Authorization": f"Bearer {config_admin_token}"},
    )
    assert response.status_code == 200
    data = response.json()["data"]
    assert data["nombre"] is None
    assert data["cct"] is None
    assert data["turno"] is None
    assert data["direccion"] is None


@pytest.mark.asyncio
async def test_update_config(client: AsyncClient, config_admin_token):
    response = await client.put(
        "/api/v1/config/",
        json={
            "nombre": "Escuela Primaria Juarez",
            "cct": "14EPR0001A",
            "turno": "matutino",
            "direccion": "Calle Juarez 123",
        },
        headers={"Authorization": f"Bearer {config_admin_token}"},
    )
    assert response.status_code == 200
    data = response.json()["data"]
    assert data["nombre"] == "Escuela Primaria Juarez"
    assert data["cct"] == "14EPR0001A"
    assert data["turno"] == "matutino"
    assert data["direccion"] == "Calle Juarez 123"


@pytest.mark.asyncio
async def test_partial_update_config(client: AsyncClient, config_admin_token):
    await client.put(
        "/api/v1/config/",
        json={"nombre": "Inicial", "cct": "CCT001"},
        headers={"Authorization": f"Bearer {config_admin_token}"},
    )
    response = await client.put(
        "/api/v1/config/",
        json={"nombre": "Actualizado"},
        headers={"Authorization": f"Bearer {config_admin_token}"},
    )
    assert response.status_code == 200
    data = response.json()["data"]
    assert data["nombre"] == "Actualizado"
    assert data["cct"] == "CCT001"


@pytest.mark.asyncio
async def test_config_unauthenticated_returns_403(client: AsyncClient):
    response = await client.get("/api/v1/config/")
    assert response.status_code == 403
