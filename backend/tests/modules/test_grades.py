# backend/tests/modules/test_grades.py
import uuid
import pytest
import pytest_asyncio
from decimal import Decimal
from httpx import AsyncClient
import sqlalchemy

from core.security import create_access_token, hash_password
from modules.users.models import Role, User, UserRole, UserStatus
from modules.students.models import Student
from modules.subjects.models import Subject
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
    result = await db_session.execute(sqlalchemy.select(User).where(User.email == "docente_grd@test.com"))
    user = result.scalar_one_or_none()
    if not user:
        user = User(
            email="docente_grd@test.com",
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
async def subject_group_student(db_session):
    suffix = uuid.uuid4().hex[:6]
    cycle = AcademicCycle(nombre=f"2024-2025-grd-{suffix}", activo=True)
    db_session.add(cycle)
    await db_session.flush()

    group = Group(nombre="2A", grado=2, turno="matutino", ciclo_id=cycle.id)
    subject = Subject(nombre="Álgebra", clave=f"ALG-{suffix}", horas_semana=5)
    student = Student(matricula=f"GRD{suffix}", nombre="Test", apellido_paterno="Grade")
    db_session.add_all([group, subject, student])
    await db_session.commit()
    await db_session.refresh(group)
    await db_session.refresh(subject)
    await db_session.refresh(student)
    return subject, group, student


@pytest.mark.asyncio
async def test_create_evaluation(client: AsyncClient, teacher_token, subject_group_student):
    subject, group, _ = subject_group_student
    response = await client.post(
        "/api/v1/grades/evaluations/",
        json={
            "titulo": "Examen Parcial 1",
            "tipo": "examen",
            "subject_id": str(subject.id),
            "group_id": str(group.id),
            "fecha": "2024-10-15",
            "porcentaje": "30.00",
        },
        headers={"Authorization": f"Bearer {teacher_token}"},
    )
    assert response.status_code == 201
    data = response.json()["data"]
    assert data["titulo"] == "Examen Parcial 1"
    assert data["tipo"] == "examen"


@pytest.mark.asyncio
async def test_list_evaluations(client: AsyncClient, teacher_token, subject_group_student):
    subject, group, _ = subject_group_student
    await client.post(
        "/api/v1/grades/evaluations/",
        json={"titulo": "Tarea 1", "tipo": "tarea", "subject_id": str(subject.id), "group_id": str(group.id)},
        headers={"Authorization": f"Bearer {teacher_token}"},
    )
    response = await client.get(
        f"/api/v1/grades/evaluations/?group_id={group.id}",
        headers={"Authorization": f"Bearer {teacher_token}"},
    )
    assert response.status_code == 200
    assert isinstance(response.json()["data"], list)
    assert len(response.json()["data"]) >= 1


@pytest.mark.asyncio
async def test_register_grade(client: AsyncClient, teacher_token, subject_group_student):
    subject, group, student = subject_group_student
    eval_resp = await client.post(
        "/api/v1/grades/evaluations/",
        json={"titulo": "Proyecto Final", "tipo": "proyecto", "subject_id": str(subject.id), "group_id": str(group.id)},
        headers={"Authorization": f"Bearer {teacher_token}"},
    )
    evaluation_id = eval_resp.json()["data"]["id"]

    response = await client.post(
        "/api/v1/grades/",
        json={
            "evaluation_id": str(evaluation_id),
            "student_id": str(student.id),
            "calificacion": "9.50",
        },
        headers={"Authorization": f"Bearer {teacher_token}"},
    )
    assert response.status_code == 201
    data = response.json()["data"]
    assert data["calificacion"] == "9.50"


@pytest.mark.asyncio
async def test_update_grade(client: AsyncClient, teacher_token, subject_group_student):
    subject, group, student = subject_group_student
    eval_resp = await client.post(
        "/api/v1/grades/evaluations/",
        json={"titulo": "Examen Final", "tipo": "examen", "subject_id": str(subject.id), "group_id": str(group.id)},
        headers={"Authorization": f"Bearer {teacher_token}"},
    )
    evaluation_id = eval_resp.json()["data"]["id"]

    grade_resp = await client.post(
        "/api/v1/grades/",
        json={"evaluation_id": str(evaluation_id), "student_id": str(student.id), "calificacion": "7.00"},
        headers={"Authorization": f"Bearer {teacher_token}"},
    )
    grade_id = grade_resp.json()["data"]["id"]

    response = await client.put(
        f"/api/v1/grades/{grade_id}",
        json={"calificacion": "8.50", "observaciones": "Revisión de examen"},
        headers={"Authorization": f"Bearer {teacher_token}"},
    )
    assert response.status_code == 200
    assert response.json()["data"]["calificacion"] == "8.50"


@pytest.mark.asyncio
async def test_get_student_grades(client: AsyncClient, teacher_token, subject_group_student):
    subject, group, student = subject_group_student
    response = await client.get(
        f"/api/v1/grades/student/{student.id}",
        headers={"Authorization": f"Bearer {teacher_token}"},
    )
    assert response.status_code == 200
    assert isinstance(response.json()["data"], list)
