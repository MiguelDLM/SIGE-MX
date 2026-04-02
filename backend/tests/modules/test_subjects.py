# backend/tests/modules/test_subjects.py
import pytest
import pytest_asyncio
from httpx import AsyncClient
import sqlalchemy

from core.security import create_access_token, hash_password
from modules.users.models import Role, User, UserRole, UserStatus


@pytest_asyncio.fixture
async def admin_token(db_session):
    result = await db_session.execute(sqlalchemy.select(Role).where(Role.name == "directivo"))
    role = result.scalar_one_or_none()
    if not role:
        role = Role(name="directivo")
        db_session.add(role)
        await db_session.flush()
    result = await db_session.execute(sqlalchemy.select(User).where(User.email == "dir_subjects@test.com"))
    user = result.scalar_one_or_none()
    if not user:
        user = User(
            email="dir_subjects@test.com",
            password_hash=hash_password("pass"),
            nombre="Dir",
            status=UserStatus.activo,
        )
        db_session.add(user)
        await db_session.flush()
        db_session.add(UserRole(user_id=user.id, role_id=role.id))
        await db_session.commit()
        await db_session.refresh(user)
    return create_access_token(str(user.id), ["directivo"])


@pytest.mark.asyncio
async def test_create_subject(client: AsyncClient, admin_token):
    response = await client.post(
        "/api/v1/subjects/",
        json={"nombre": "Matemáticas I", "clave": "MAT01", "horas_semana": 5},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 201
    data = response.json()["data"]
    assert data["nombre"] == "Matemáticas I"
    assert data["clave"] == "MAT01"
    assert data["horas_semana"] == 5


@pytest.mark.asyncio
async def test_list_subjects(client: AsyncClient, admin_token):
    response = await client.get(
        "/api/v1/subjects/",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 200
    assert isinstance(response.json()["data"], list)


@pytest.mark.asyncio
async def test_get_subject_by_id(client: AsyncClient, admin_token):
    create_resp = await client.post(
        "/api/v1/subjects/",
        json={"nombre": "Física I", "clave": "FIS01", "horas_semana": 4},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    subject_id = create_resp.json()["data"]["id"]
    response = await client.get(
        f"/api/v1/subjects/{subject_id}",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 200
    assert response.json()["data"]["clave"] == "FIS01"
