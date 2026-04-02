# backend/tests/modules/test_attendance.py
import uuid
import pytest
import pytest_asyncio
from datetime import date
from httpx import AsyncClient
import sqlalchemy

from core.security import create_access_token, hash_password
from modules.users.models import Role, User, UserRole, UserStatus
from modules.students.models import Student
from modules.groups.models import Group
from modules.academic_cycles.models import AcademicCycle


@pytest_asyncio.fixture
async def teacher_token(db_session):
    result = await db_session.execute(sqlalchemy.select(Role).where(Role.name == "docente"))
    role = result.scalar_one_or_none()
    if not role:
        role = Role(name="docente")
        db_session.add(role)
        await db_session.flush()
    result = await db_session.execute(sqlalchemy.select(User).where(User.email == "docente_att@test.com"))
    user = result.scalar_one_or_none()
    if not user:
        user = User(
            email="docente_att@test.com",
            password_hash=hash_password("pass"),
            nombre="Docente",
            status=UserStatus.activo,
        )
        db_session.add(user)
        await db_session.flush()
        db_session.add(UserRole(user_id=user.id, role_id=role.id))
        await db_session.commit()
        await db_session.refresh(user)
    return create_access_token(str(user.id), ["docente"])


@pytest_asyncio.fixture
async def group_and_student(db_session):
    cycle = AcademicCycle(nombre="2024-2025", activo=True)
    db_session.add(cycle)
    await db_session.flush()

    group = Group(nombre="1A", grado=1, turno="matutino", ciclo_id=cycle.id)
    db_session.add(group)
    await db_session.flush()

    student = Student(matricula=f"ATT-{uuid.uuid4().hex[:8]}", nombre="Test", apellido_paterno="Student")
    db_session.add(student)
    await db_session.commit()
    await db_session.refresh(group)
    await db_session.refresh(student)
    return group, student


@pytest.mark.asyncio
async def test_register_attendance(client: AsyncClient, teacher_token, group_and_student):
    group, student = group_and_student
    response = await client.post(
        "/api/v1/attendance/",
        json={
            "student_id": str(student.id),
            "group_id": str(group.id),
            "fecha": "2024-09-02",
            "status": "presente",
        },
        headers={"Authorization": f"Bearer {teacher_token}"},
    )
    assert response.status_code == 201
    data = response.json()["data"]
    assert data["status"] == "presente"
    assert data["fecha"] == "2024-09-02"


@pytest.mark.asyncio
async def test_duplicate_attendance_returns_409(client: AsyncClient, teacher_token, group_and_student):
    group, student = group_and_student
    payload = {
        "student_id": str(student.id),
        "group_id": str(group.id),
        "fecha": "2024-09-03",
        "status": "presente",
    }
    await client.post("/api/v1/attendance/", json=payload, headers={"Authorization": f"Bearer {teacher_token}"})
    response = await client.post("/api/v1/attendance/", json=payload, headers={"Authorization": f"Bearer {teacher_token}"})
    assert response.status_code == 409


@pytest.mark.asyncio
async def test_list_attendance_by_group(client: AsyncClient, teacher_token, group_and_student):
    group, student = group_and_student
    await client.post(
        "/api/v1/attendance/",
        json={"student_id": str(student.id), "group_id": str(group.id), "fecha": "2024-09-04", "status": "falta"},
        headers={"Authorization": f"Bearer {teacher_token}"},
    )
    response = await client.get(
        f"/api/v1/attendance/group/{group.id}?fecha=2024-09-04",
        headers={"Authorization": f"Bearer {teacher_token}"},
    )
    assert response.status_code == 200
    assert isinstance(response.json()["data"], list)
    assert len(response.json()["data"]) >= 1


@pytest.mark.asyncio
async def test_update_attendance(client: AsyncClient, teacher_token, group_and_student):
    group, student = group_and_student
    create_resp = await client.post(
        "/api/v1/attendance/",
        json={"student_id": str(student.id), "group_id": str(group.id), "fecha": "2024-09-05", "status": "presente"},
        headers={"Authorization": f"Bearer {teacher_token}"},
    )
    att_id = create_resp.json()["data"]["id"]
    response = await client.put(
        f"/api/v1/attendance/{att_id}",
        json={"status": "retardo", "observaciones": "Llegó tarde"},
        headers={"Authorization": f"Bearer {teacher_token}"},
    )
    assert response.status_code == 200
    assert response.json()["data"]["status"] == "retardo"


@pytest.mark.asyncio
async def test_register_attendance_without_auth_returns_403(client: AsyncClient, group_and_student):
    group, student = group_and_student
    response = await client.post(
        "/api/v1/attendance/",
        json={"student_id": str(student.id), "group_id": str(group.id), "fecha": "2024-09-06", "status": "presente"},
    )
    assert response.status_code == 403
