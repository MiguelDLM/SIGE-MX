# backend/tests/modules/test_reports.py
import uuid
import pytest
import pytest_asyncio
import sqlalchemy

from httpx import AsyncClient

from core.security import create_access_token, hash_password
from modules.users.models import Role, User, UserRole, UserStatus
from modules.students.models import Student
from modules.subjects.models import Subject
from modules.groups.models import Group, GroupStudent
from modules.academic_cycles.models import AcademicCycle
from modules.grades.models import Evaluation, Grade


@pytest_asyncio.fixture
async def ce_token(db_session):
    result = await db_session.execute(sqlalchemy.select(Role).where(Role.name == "control_escolar"))
    role = result.scalar_one_or_none()
    if not role:
        role = Role(name="control_escolar")
        db_session.add(role)
        await db_session.flush()
    result = await db_session.execute(sqlalchemy.select(User).where(User.email == "ce_rep@test.com"))
    user = result.scalar_one_or_none()
    if not user:
        user = User(
            email="ce_rep@test.com",
            password_hash=hash_password("pass"),
            nombre="Control Escolar",
            status=UserStatus.activo,
        )
        db_session.add(user)
        await db_session.flush()
        db_session.add(UserRole(user_id=user.id, role_id=role.id))
        await db_session.commit()
        await db_session.refresh(user)
    return create_access_token(str(user.id), ["control_escolar"])


@pytest_asyncio.fixture
async def student_with_grades(db_session):
    """Student enrolled in an active group with 2 graded evaluations in 1 subject."""
    suffix = uuid.uuid4().hex[:6]

    cycle = AcademicCycle(nombre=f"2024-2025-rep-{suffix}", activo=True)
    db_session.add(cycle)
    await db_session.flush()

    group = Group(nombre="3A", grado=3, turno="matutino", ciclo_id=cycle.id)
    subject = Subject(nombre="Matemáticas", clave=f"MAT-{suffix}", horas_semana=5)
    student = Student(
        matricula=f"REP{suffix}",
        nombre="Laura",
        apellido_paterno="García",
        apellido_materno="López",
    )
    db_session.add_all([group, subject, student])
    await db_session.flush()

    db_session.add(GroupStudent(group_id=group.id, student_id=student.id))
    await db_session.flush()

    eval1 = Evaluation(
        subject_id=subject.id,
        group_id=group.id,
        tipo="examen",
        titulo="Examen 1",
    )
    eval2 = Evaluation(
        subject_id=subject.id,
        group_id=group.id,
        tipo="tarea",
        titulo="Tarea 1",
    )
    db_session.add_all([eval1, eval2])
    await db_session.flush()

    db_session.add(Grade(evaluation_id=eval1.id, student_id=student.id, calificacion="8.5"))
    db_session.add(Grade(evaluation_id=eval2.id, student_id=student.id, calificacion="9.0"))
    await db_session.commit()
    await db_session.refresh(student)
    return student


@pytest_asyncio.fixture
async def student_no_grades(db_session):
    """Student enrolled in an active group but with no grades."""
    suffix = uuid.uuid4().hex[:6]

    cycle = AcademicCycle(nombre=f"2024-2025-nog-{suffix}", activo=True)
    db_session.add(cycle)
    await db_session.flush()

    group = Group(nombre="2B", grado=2, turno="vespertino", ciclo_id=cycle.id)
    student = Student(matricula=f"NOG{suffix}", nombre="Pedro", apellido_paterno="Soto")
    db_session.add_all([group, student])
    await db_session.flush()

    db_session.add(GroupStudent(group_id=group.id, student_id=student.id))
    await db_session.commit()
    await db_session.refresh(student)
    return student


@pytest.mark.asyncio
async def test_boleta_with_grades(client: AsyncClient, ce_token, student_with_grades):
    """Test 1: Boleta for student with grades returns PDF."""
    response = await client.get(
        f"/api/v1/reports/students/{student_with_grades.id}/boleta",
        headers={"Authorization": f"Bearer {ce_token}"},
    )
    assert response.status_code == 200
    assert response.headers["content-type"] == "application/pdf"
    assert response.content[:4] == b"%PDF"


@pytest.mark.asyncio
async def test_constancia_with_active_group(client: AsyncClient, ce_token, student_with_grades):
    """Test 2: Constancia for student with active group returns PDF."""
    response = await client.get(
        f"/api/v1/reports/students/{student_with_grades.id}/constancia",
        headers={"Authorization": f"Bearer {ce_token}"},
    )
    assert response.status_code == 200
    assert response.headers["content-type"] == "application/pdf"
    assert response.content[:4] == b"%PDF"


@pytest.mark.asyncio
async def test_boleta_no_grades(client: AsyncClient, ce_token, student_no_grades):
    """Test 3: Boleta for student with no grades returns PDF (empty table, no crash)."""
    response = await client.get(
        f"/api/v1/reports/students/{student_no_grades.id}/boleta",
        headers={"Authorization": f"Bearer {ce_token}"},
    )
    assert response.status_code == 200
    assert response.headers["content-type"] == "application/pdf"
    assert response.content[:4] == b"%PDF"


@pytest.mark.asyncio
async def test_boleta_student_not_found(client: AsyncClient, ce_token):
    """Test 4: Boleta for nonexistent student returns 404."""
    response = await client.get(
        f"/api/v1/reports/students/{uuid.uuid4()}/boleta",
        headers={"Authorization": f"Bearer {ce_token}"},
    )
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_constancia_student_not_found(client: AsyncClient, ce_token):
    """Test 5: Constancia for nonexistent student returns 404."""
    response = await client.get(
        f"/api/v1/reports/students/{uuid.uuid4()}/constancia",
        headers={"Authorization": f"Bearer {ce_token}"},
    )
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_boleta_no_auth(client: AsyncClient, student_with_grades):
    """Test 6: No authentication returns 403."""
    response = await client.get(
        f"/api/v1/reports/students/{student_with_grades.id}/boleta",
    )
    assert response.status_code == 403
