# backend/tests/modules/test_groups.py
import pytest
import pytest_asyncio
from httpx import AsyncClient
import sqlalchemy

from core.security import create_access_token, hash_password
from modules.users.models import Role, User, UserRole, UserStatus
from modules.academic_cycles.models import AcademicCycle
from modules.groups.models import Group
from modules.students.models import Student
from modules.teachers.models import Teacher
from modules.subjects.models import Subject


@pytest_asyncio.fixture
async def admin_token(db_session):
    result = await db_session.execute(sqlalchemy.select(Role).where(Role.name == "directivo"))
    role = result.scalar_one_or_none()
    if not role:
        role = Role(name="directivo")
        db_session.add(role)
        await db_session.flush()
    result = await db_session.execute(sqlalchemy.select(User).where(User.email == "dir_groups@test.com"))
    user = result.scalar_one_or_none()
    if not user:
        user = User(
            email="dir_groups@test.com",
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


@pytest_asyncio.fixture
async def cycle(db_session):
    c = AcademicCycle(nombre="2024-2025", activo=True)
    db_session.add(c)
    await db_session.commit()
    await db_session.refresh(c)
    return c


@pytest.mark.asyncio
async def test_create_group(client: AsyncClient, admin_token, cycle):
    response = await client.post(
        "/api/v1/groups/",
        json={
            "nombre": "1A",
            "grado": 1,
            "turno": "matutino",
            "ciclo_id": str(cycle.id),
        },
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 201
    data = response.json()["data"]
    assert data["nombre"] == "1A"
    assert data["grado"] == 1


@pytest.mark.asyncio
async def test_list_groups(client: AsyncClient, admin_token):
    response = await client.get(
        "/api/v1/groups/",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 200
    assert isinstance(response.json()["data"], list)


@pytest.mark.asyncio
async def test_assign_student_to_group(client: AsyncClient, admin_token, cycle, db_session):
    grp_resp = await client.post(
        "/api/v1/groups/",
        json={"nombre": "2B", "grado": 2, "turno": "vespertino", "ciclo_id": str(cycle.id)},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    group_id = grp_resp.json()["data"]["id"]

    student = Student(matricula="STU_GRP_001", nombre="Test", apellido_paterno="Student")
    db_session.add(student)
    await db_session.commit()
    await db_session.refresh(student)

    response = await client.post(
        f"/api/v1/groups/{group_id}/students",
        json={"student_id": str(student.id)},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 200
    assert response.json()["data"]["assigned"] is True


@pytest.mark.asyncio
async def test_assign_teacher_to_group(client: AsyncClient, admin_token, cycle, db_session):
    grp_resp = await client.post(
        "/api/v1/groups/",
        json={"nombre": "3C", "grado": 3, "turno": "matutino", "ciclo_id": str(cycle.id)},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    group_id = grp_resp.json()["data"]["id"]

    teacher = Teacher(numero_empleado="T_GRP_001", nombre="Prof", apellido_paterno="Test")
    subject = Subject(nombre="Historia", clave="HIS01")
    db_session.add_all([teacher, subject])
    await db_session.commit()
    await db_session.refresh(teacher)
    await db_session.refresh(subject)

    response = await client.post(
        f"/api/v1/groups/{group_id}/teachers",
        json={"teacher_id": str(teacher.id), "subject_id": str(subject.id)},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 200
    assert response.json()["data"]["assigned"] is True


@pytest_asyncio.fixture
async def teacher_token(db_session):
    result = await db_session.execute(sqlalchemy.select(Role).where(Role.name == "docente"))
    role = result.scalar_one_or_none()
    if not role:
        role = Role(name="docente")
        db_session.add(role)
        await db_session.flush()
    result = await db_session.execute(sqlalchemy.select(User).where(User.email == "doc_groups@test.com"))
    user = result.scalar_one_or_none()
    if not user:
        user = User(
            email="doc_groups@test.com",
            password_hash=hash_password("pass"),
            nombre="Doc",
            status=UserStatus.activo,
        )
        db_session.add(user)
        await db_session.flush()
        db_session.add(UserRole(user_id=user.id, role_id=role.id))
        await db_session.commit()
        await db_session.refresh(user)
    return create_access_token(str(user.id), ["docente"])


@pytest.mark.asyncio
async def test_list_groups_by_teacher(client: AsyncClient, admin_token, teacher_token):
    import uuid
    # Test that ?teacher_id= with unknown UUID returns empty list
    resp = await client.get(
        f"/api/v1/groups/?teacher_id={uuid.uuid4()}",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert resp.status_code == 200
    assert resp.json()["data"] == []


@pytest.mark.asyncio
async def test_list_group_students(client: AsyncClient, admin_token, db_session):
    import uuid
    suffix = uuid.uuid4().hex[:6]

    cycle = AcademicCycle(nombre=f"2024-gs-{suffix}", activo=True)
    db_session.add(cycle)
    await db_session.flush()

    group = Group(nombre="5B", grado=5, turno="vespertino", ciclo_id=cycle.id)
    db_session.add(group)
    await db_session.flush()

    student = Student(matricula=f"GS{suffix}", nombre="Ana", apellido_paterno="Ruiz")
    db_session.add(student)
    await db_session.commit()
    await db_session.refresh(group)
    await db_session.refresh(student)

    group_id = str(group.id)
    student_id = str(student.id)

    await client.post(
        f"/api/v1/groups/{group_id}/students",
        json={"student_id": student_id},
        headers={"Authorization": f"Bearer {admin_token}"},
    )

    resp = await client.get(
        f"/api/v1/groups/{group_id}/students",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert len(data) == 1
    assert data[0]["matricula"] == f"GS{suffix}"
