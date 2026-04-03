import uuid
import pytest
import pytest_asyncio
from httpx import AsyncClient
from unittest.mock import patch, AsyncMock
import sqlalchemy

from core.security import create_access_token, hash_password
from modules.users.models import Role, User, UserRole, UserStatus
from modules.students.models import Student


@pytest_asyncio.fixture
async def control_token(db_session):
    result = await db_session.execute(sqlalchemy.select(Role).where(Role.name == "control_escolar"))
    role = result.scalar_one_or_none()
    if not role:
        role = Role(name="control_escolar")
        db_session.add(role)
        await db_session.flush()
    result = await db_session.execute(sqlalchemy.select(User).where(User.email == "ctrl_just@test.com"))
    user = result.scalar_one_or_none()
    if not user:
        user = User(
            email="ctrl_just@test.com",
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


@pytest_asyncio.fixture
async def student(db_session):
    s = Student(
        matricula=f"JUST-{uuid.uuid4().hex[:8]}",
        nombre="Alumno",
        apellido_paterno="Test",
    )
    db_session.add(s)
    await db_session.commit()
    await db_session.refresh(s)
    return s


@pytest.mark.asyncio
async def test_create_justification_without_file(client: AsyncClient, control_token, student):
    response = await client.post(
        "/api/v1/justifications/",
        data={
            "student_id": str(student.id),
            "fecha_inicio": "2024-09-02",
            "motivo": "Enfermedad",
        },
        headers={"Authorization": f"Bearer {control_token}"},
    )
    assert response.status_code == 201
    data = response.json()["data"]
    assert data["status"] == "pendiente"
    assert data["archivo_url"] is None


@pytest.mark.asyncio
async def test_create_justification_with_file(client: AsyncClient, control_token, student):
    with patch(
        "modules.justifications.service.storage.upload_file",
        new_callable=AsyncMock,
        return_value="http://minio/justifications/test.pdf",
    ):
        response = await client.post(
            "/api/v1/justifications/",
            files={"file": ("doc.pdf", b"PDF content here", "application/pdf")},
            data={
                "student_id": str(student.id),
                "fecha_inicio": "2024-09-03",
                "motivo": "Cita médica",
            },
            headers={"Authorization": f"Bearer {control_token}"},
        )
    assert response.status_code == 201
    data = response.json()["data"]
    assert data["archivo_url"] == "http://minio/justifications/test.pdf"
    assert data["status"] == "pendiente"


@pytest.mark.asyncio
async def test_list_justifications(client: AsyncClient, control_token, student):
    await client.post(
        "/api/v1/justifications/",
        data={"student_id": str(student.id), "fecha_inicio": "2024-09-04", "motivo": "Viaje"},
        headers={"Authorization": f"Bearer {control_token}"},
    )
    response = await client.get(
        "/api/v1/justifications/",
        headers={"Authorization": f"Bearer {control_token}"},
    )
    assert response.status_code == 200
    assert isinstance(response.json()["data"], list)
    assert len(response.json()["data"]) >= 1


@pytest.mark.asyncio
async def test_approve_justification(client: AsyncClient, control_token, student):
    create_resp = await client.post(
        "/api/v1/justifications/",
        data={"student_id": str(student.id), "fecha_inicio": "2024-09-05", "motivo": "Doctor"},
        headers={"Authorization": f"Bearer {control_token}"},
    )
    just_id = create_resp.json()["data"]["id"]
    response = await client.patch(
        f"/api/v1/justifications/{just_id}/review",
        json={"status": "aprobado"},
        headers={"Authorization": f"Bearer {control_token}"},
    )
    assert response.status_code == 200
    assert response.json()["data"]["status"] == "aprobado"
    assert response.json()["data"]["reviewed_by"] is not None


@pytest.mark.asyncio
async def test_reject_justification(client: AsyncClient, control_token, student):
    create_resp = await client.post(
        "/api/v1/justifications/",
        data={"student_id": str(student.id), "fecha_inicio": "2024-09-06", "motivo": "Otro"},
        headers={"Authorization": f"Bearer {control_token}"},
    )
    just_id = create_resp.json()["data"]["id"]
    response = await client.patch(
        f"/api/v1/justifications/{just_id}/review",
        json={"status": "rechazado"},
        headers={"Authorization": f"Bearer {control_token}"},
    )
    assert response.status_code == 200
    assert response.json()["data"]["status"] == "rechazado"


@pytest.mark.asyncio
async def test_review_without_auth_returns_403(client: AsyncClient, student):
    response = await client.patch(
        f"/api/v1/justifications/{uuid.uuid4()}/review",
        json={"status": "aprobado"},
    )
    assert response.status_code == 403
