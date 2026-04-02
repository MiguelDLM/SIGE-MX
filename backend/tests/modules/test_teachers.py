# backend/tests/modules/test_teachers.py
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

    result = await db_session.execute(sqlalchemy.select(User).where(User.email == "dir_teachers@test.com"))
    user = result.scalar_one_or_none()
    if not user:
        user = User(
            email="dir_teachers@test.com",
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
async def test_create_teacher(client: AsyncClient, admin_token):
    response = await client.post(
        "/api/v1/teachers/",
        json={
            "numero_empleado": "EMP001",
            "especialidad": "Matemáticas",
            "nombre": "Carlos",
            "apellido_paterno": "Mendoza",
        },
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 201
    data = response.json()["data"]
    assert data["numero_empleado"] == "EMP001"
    assert data["especialidad"] == "Matemáticas"


@pytest.mark.asyncio
async def test_create_duplicate_numero_empleado_returns_409(client: AsyncClient, admin_token):
    await client.post(
        "/api/v1/teachers/",
        json={"numero_empleado": "EMP999", "nombre": "X", "apellido_paterno": "Y"},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    response = await client.post(
        "/api/v1/teachers/",
        json={"numero_empleado": "EMP999", "nombre": "Z", "apellido_paterno": "W"},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 409


@pytest.mark.asyncio
async def test_get_teacher_by_id(client: AsyncClient, admin_token):
    create_resp = await client.post(
        "/api/v1/teachers/",
        json={"numero_empleado": "EMP002", "nombre": "Maria", "apellido_paterno": "López"},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    teacher_id = create_resp.json()["data"]["id"]

    response = await client.get(
        f"/api/v1/teachers/{teacher_id}",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 200
    assert response.json()["data"]["numero_empleado"] == "EMP002"


@pytest.mark.asyncio
async def test_list_teachers(client: AsyncClient, admin_token):
    response = await client.get(
        "/api/v1/teachers/",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 200
    assert isinstance(response.json()["data"], list)
