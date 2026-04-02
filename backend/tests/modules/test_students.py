# backend/tests/modules/test_students.py
import pytest
import pytest_asyncio
from httpx import AsyncClient
import sqlalchemy

from core.security import create_access_token, hash_password
from modules.users.models import Role, User, UserRole, UserStatus


@pytest_asyncio.fixture
async def admin_token(db_session):
    result = await db_session.execute(sqlalchemy.select(Role).where(Role.name == "control_escolar"))
    role = result.scalar_one_or_none()
    if not role:
        role = Role(name="control_escolar")
        db_session.add(role)
        await db_session.flush()

    result = await db_session.execute(sqlalchemy.select(User).where(User.email == "control@test.com"))
    user = result.scalar_one_or_none()
    if not user:
        user = User(
            email="control@test.com",
            password_hash=hash_password("pass"),
            nombre="Control",
            status=UserStatus.activo,
        )
        db_session.add(user)
        await db_session.flush()
        db_session.add(UserRole(user_id=user.id, role_id=role.id))
        await db_session.commit()
        await db_session.refresh(user)
    return create_access_token(str(user.id), ["control_escolar"])


@pytest.mark.asyncio
async def test_create_student(client: AsyncClient, admin_token):
    response = await client.post(
        "/api/v1/students/",
        json={
            "matricula": "2024001",
            "nombre": "Ana",
            "apellido_paterno": "García",
            "municipio": "Monterrey",
            "estado": "Nuevo León",
        },
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 201
    data = response.json()["data"]
    assert data["matricula"] == "2024001"
    assert data["nombre"] == "Ana"


@pytest.mark.asyncio
async def test_create_duplicate_matricula_returns_409(client: AsyncClient, admin_token):
    await client.post(
        "/api/v1/students/",
        json={"matricula": "DUP001", "nombre": "X", "apellido_paterno": "Y"},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    response = await client.post(
        "/api/v1/students/",
        json={"matricula": "DUP001", "nombre": "Z", "apellido_paterno": "W"},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 409


@pytest.mark.asyncio
async def test_get_student_by_id(client: AsyncClient, admin_token):
    create_resp = await client.post(
        "/api/v1/students/",
        json={"matricula": "2024002", "nombre": "Luis", "apellido_paterno": "Pérez"},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    student_id = create_resp.json()["data"]["id"]

    response = await client.get(
        f"/api/v1/students/{student_id}",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 200
    assert response.json()["data"]["matricula"] == "2024002"


@pytest.mark.asyncio
async def test_list_students(client: AsyncClient, admin_token):
    response = await client.get(
        "/api/v1/students/",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 200
    assert isinstance(response.json()["data"], list)


@pytest.mark.asyncio
async def test_create_student_without_auth_returns_403(client: AsyncClient):
    response = await client.post(
        "/api/v1/students/",
        json={"matricula": "X", "nombre": "X", "apellido_paterno": "Y"},
    )
    assert response.status_code == 403
