# backend/tests/modules/test_imports.py
import io
import csv
import pytest
import pytest_asyncio
from httpx import AsyncClient
import sqlalchemy

from core.security import create_access_token, hash_password
from modules.users.models import Role, User, UserRole, UserStatus


@pytest_asyncio.fixture
async def control_token(db_session):
    result = await db_session.execute(sqlalchemy.select(Role).where(Role.name == "control_escolar"))
    role = result.scalar_one_or_none()
    if not role:
        role = Role(name="control_escolar")
        db_session.add(role)
        await db_session.flush()
    result = await db_session.execute(sqlalchemy.select(User).where(User.email == "ctrl_import@test.com"))
    user = result.scalar_one_or_none()
    if not user:
        user = User(
            email="ctrl_import@test.com",
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


def make_csv(rows: list[dict], fieldnames: list[str]) -> bytes:
    buf = io.StringIO()
    writer = csv.DictWriter(buf, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(rows)
    return buf.getvalue().encode("utf-8")


@pytest.mark.asyncio
async def test_import_students_csv(client: AsyncClient, control_token):
    csv_content = make_csv(
        [
            {"nombre": "Ana", "apellido_paterno": "García", "matricula": "IMP001"},
            {"nombre": "Luis", "apellido_paterno": "Pérez", "matricula": "IMP002"},
        ],
        fieldnames=["nombre", "apellido_paterno", "matricula"],
    )
    response = await client.post(
        "/api/v1/imports/students",
        files={"file": ("students.csv", csv_content, "text/csv")},
        headers={"Authorization": f"Bearer {control_token}"},
    )
    assert response.status_code == 200
    data = response.json()["data"]
    assert data["total"] == 2
    assert data["importados"] == 2
    assert data["errores"] == 0


@pytest.mark.asyncio
async def test_import_students_with_invalid_rows(client: AsyncClient, control_token):
    csv_content = make_csv(
        [
            {"nombre": "Valid", "apellido_paterno": "Row", "matricula": "IMP003"},
            {"nombre": "", "apellido_paterno": "Missing", "matricula": "IMP004"},  # nombre vacío = inválido
        ],
        fieldnames=["nombre", "apellido_paterno", "matricula"],
    )
    response = await client.post(
        "/api/v1/imports/students",
        files={"file": ("students.csv", csv_content, "text/csv")},
        headers={"Authorization": f"Bearer {control_token}"},
    )
    assert response.status_code == 200
    data = response.json()["data"]
    assert data["total"] == 2
    assert data["importados"] == 1
    assert data["errores"] == 1


@pytest.mark.asyncio
async def test_import_students_duplicate_matricula(client: AsyncClient, control_token):
    csv_content = make_csv(
        [{"nombre": "Dup", "apellido_paterno": "Test", "matricula": "IMP_DUP_001"}],
        fieldnames=["nombre", "apellido_paterno", "matricula"],
    )
    # First import
    await client.post(
        "/api/v1/imports/students",
        files={"file": ("s.csv", csv_content, "text/csv")},
        headers={"Authorization": f"Bearer {control_token}"},
    )
    # Second import — duplicate matricula becomes error
    response = await client.post(
        "/api/v1/imports/students",
        files={"file": ("s.csv", csv_content, "text/csv")},
        headers={"Authorization": f"Bearer {control_token}"},
    )
    assert response.status_code == 200
    data = response.json()["data"]
    assert data["errores"] == 1
    assert data["importados"] == 0


@pytest.mark.asyncio
async def test_import_teachers_csv(client: AsyncClient, control_token):
    csv_content = make_csv(
        [{"nombre": "Prof", "apellido_paterno": "Smith", "numero_empleado": "EIMP001", "especialidad": "Física"}],
        fieldnames=["nombre", "apellido_paterno", "numero_empleado", "especialidad"],
    )
    response = await client.post(
        "/api/v1/imports/teachers",
        files={"file": ("teachers.csv", csv_content, "text/csv")},
        headers={"Authorization": f"Bearer {control_token}"},
    )
    assert response.status_code == 200
    data = response.json()["data"]
    assert data["total"] == 1
    assert data["importados"] == 1


@pytest.mark.asyncio
async def test_download_student_template(client: AsyncClient, control_token):
    response = await client.get(
        "/api/v1/imports/template/students",
        headers={"Authorization": f"Bearer {control_token}"},
    )
    assert response.status_code == 200
    assert "application/vnd.openxmlformats" in response.headers["content-type"]


@pytest.mark.asyncio
async def test_import_without_auth_returns_403(client: AsyncClient):
    csv_content = make_csv(
        [{"nombre": "X", "apellido_paterno": "Y", "matricula": "Z"}],
        fieldnames=["nombre", "apellido_paterno", "matricula"],
    )
    response = await client.post(
        "/api/v1/imports/students",
        files={"file": ("s.csv", csv_content, "text/csv")},
    )
    assert response.status_code == 403
