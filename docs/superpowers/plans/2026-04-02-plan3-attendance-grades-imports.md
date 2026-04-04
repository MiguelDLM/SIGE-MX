# SIGE-MX — Plan 3: Attendance, Grades & CSV/Excel Import

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete Fase 1 MVP by adding the Attendance module, Grades module, and CSV/Excel bulk import for students and teachers.

**Architecture:** All models already exist (from Plan 2). Each task adds schemas + service + router to an existing stub module and registers the router in `main.py`. The import module is new (`modules/imports/`) with a stateless two-step flow: upload returns preview+validation, `?confirm=true` performs the atomic insert. Tests use the same pytest/asyncio fixtures from `tests/conftest.py`.

**Tech Stack:** FastAPI, SQLAlchemy 2.0 async, pytest-asyncio, openpyxl (already in requirements.txt), python-multipart (already in requirements.txt), csv (stdlib).

---

## Pre-requisites (already done in Plans 1 & 2)

- All models exist: `Attendance`, `Evaluation`, `Grade` with correct FK constraints
- `openpyxl==3.1.2` and `python-multipart==0.0.9` in `requirements.txt`
- Docker Compose running: `docker compose up -d` (from worktree dir)
- Tests run via: `docker compose exec --user root backend pytest tests/ -v`
- 37 tests currently passing

---

## File Structure

```
backend/
├── modules/
│   ├── attendance/
│   │   ├── __init__.py          (exists, empty)
│   │   ├── models.py            (exists — Attendance, AttendanceStatus)
│   │   ├── schemas.py           NEW
│   │   ├── service.py           NEW
│   │   └── router.py            NEW
│   ├── grades/
│   │   ├── __init__.py          (exists, empty)
│   │   ├── models.py            (exists — Evaluation, Grade, EvaluationType)
│   │   ├── schemas.py           NEW
│   │   ├── service.py           NEW
│   │   └── router.py            NEW
│   └── imports/
│       ├── __init__.py          NEW (empty)
│       ├── schemas.py           NEW — ImportPreview, ImportResult
│       ├── parsers.py           NEW — parse_csv(), parse_xlsx(), validate_student_row(), validate_teacher_row()
│       ├── service.py           NEW — preview_students(), import_students(), preview_teachers(), import_teachers()
│       └── router.py            NEW — upload endpoints + template download
├── main.py                      MODIFY — register 3 new routers
└── tests/modules/
    ├── test_attendance.py       NEW
    ├── test_grades.py           NEW
    └── test_imports.py          NEW
```

---

## Task 1: Attendance module (TDD)

**Files:**
- Create: `backend/modules/attendance/schemas.py`
- Create: `backend/modules/attendance/service.py`
- Create: `backend/modules/attendance/router.py`
- Create: `backend/tests/modules/test_attendance.py`
- Modify: `backend/main.py`

### Endpoints

| Method | Path | Roles | Description |
|--------|------|-------|-------------|
| POST | `/api/v1/attendance/` | docente, control_escolar, directivo | Registrar asistencia |
| PUT | `/api/v1/attendance/{attendance_id}` | docente, control_escolar, directivo | Actualizar registro |
| GET | `/api/v1/attendance/group/{group_id}` | docente, control_escolar, directivo | Lista por grupo + fecha |
| GET | `/api/v1/attendance/student/{student_id}` | control_escolar, directivo | Historial por alumno |

---

- [ ] **Step 1: Write failing tests**

```python
# backend/tests/modules/test_attendance.py
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

    student = Student(matricula="ATT001", nombre="Test", apellido_paterno="Student")
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
```

- [ ] **Step 2: Run to confirm FAIL**

```bash
docker compose exec --user root backend pytest tests/modules/test_attendance.py -v 2>&1 | head -15
```

Expected: ImportError or 404 (router not registered).

- [ ] **Step 3: Create `backend/modules/attendance/schemas.py`**

```python
# backend/modules/attendance/schemas.py
import uuid
from datetime import date
from typing import Optional

from pydantic import BaseModel

from modules.attendance.models import AttendanceStatus


class AttendanceCreate(BaseModel):
    student_id: uuid.UUID
    group_id: uuid.UUID
    fecha: date
    status: AttendanceStatus
    observaciones: Optional[str] = None


class AttendanceUpdate(BaseModel):
    status: Optional[AttendanceStatus] = None
    observaciones: Optional[str] = None


class AttendanceResponse(BaseModel):
    id: uuid.UUID
    student_id: uuid.UUID
    group_id: uuid.UUID
    fecha: date
    status: AttendanceStatus
    observaciones: Optional[str] = None

    model_config = {"from_attributes": True}
```

- [ ] **Step 4: Create `backend/modules/attendance/service.py`**

```python
# backend/modules/attendance/service.py
import uuid
from datetime import date

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from core.exceptions import BusinessError
from modules.attendance.models import Attendance
from modules.attendance.schemas import AttendanceCreate, AttendanceUpdate


async def register_attendance(data: AttendanceCreate, db: AsyncSession) -> Attendance:
    record = Attendance(**data.model_dump())
    db.add(record)
    try:
        await db.flush()
    except IntegrityError:
        await db.rollback()
        raise BusinessError(
            "DUPLICATE_ATTENDANCE",
            "Ya existe un registro de asistencia para este alumno en esta fecha",
            status_code=409,
        )
    await db.commit()
    await db.refresh(record)
    return record


async def update_attendance(
    attendance_id: uuid.UUID, data: AttendanceUpdate, db: AsyncSession
) -> Attendance:
    result = await db.execute(select(Attendance).where(Attendance.id == attendance_id))
    record = result.scalar_one_or_none()
    if record is None:
        raise BusinessError("ATTENDANCE_NOT_FOUND", "Registro de asistencia no encontrado", status_code=404)
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(record, field, value)
    await db.commit()
    await db.refresh(record)
    return record


async def list_attendance_by_group(
    group_id: uuid.UUID, fecha: date, db: AsyncSession
) -> list[Attendance]:
    result = await db.execute(
        select(Attendance)
        .where(Attendance.group_id == group_id, Attendance.fecha == fecha)
        .order_by(Attendance.student_id)
    )
    return list(result.scalars())


async def list_attendance_by_student(
    student_id: uuid.UUID, db: AsyncSession
) -> list[Attendance]:
    result = await db.execute(
        select(Attendance)
        .where(Attendance.student_id == student_id)
        .order_by(Attendance.fecha.desc())
    )
    return list(result.scalars())
```

- [ ] **Step 5: Create `backend/modules/attendance/router.py`**

```python
# backend/modules/attendance/router.py
import uuid
from datetime import date

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from core.database import get_db
from core.security import require_roles
from modules.attendance import service
from modules.attendance.schemas import AttendanceCreate, AttendanceResponse, AttendanceUpdate

router = APIRouter(prefix="/api/v1/attendance", tags=["attendance"])
_write = ["docente", "control_escolar", "directivo"]
_read = ["docente", "control_escolar", "directivo"]
_admin_read = ["control_escolar", "directivo"]


@router.post("/", status_code=status.HTTP_201_CREATED)
async def register_attendance(
    data: AttendanceCreate,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_write)),
):
    record = await service.register_attendance(data, db)
    return {"data": AttendanceResponse.model_validate(record)}


@router.put("/{attendance_id}")
async def update_attendance(
    attendance_id: uuid.UUID,
    data: AttendanceUpdate,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_write)),
):
    record = await service.update_attendance(attendance_id, data, db)
    return {"data": AttendanceResponse.model_validate(record)}


@router.get("/group/{group_id}")
async def list_by_group(
    group_id: uuid.UUID,
    fecha: date = Query(..., description="Fecha en formato YYYY-MM-DD"),
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_read)),
):
    records = await service.list_attendance_by_group(group_id, fecha, db)
    return {"data": [AttendanceResponse.model_validate(r) for r in records]}


@router.get("/student/{student_id}")
async def list_by_student(
    student_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin_read)),
):
    records = await service.list_attendance_by_student(student_id, db)
    return {"data": [AttendanceResponse.model_validate(r) for r in records]}
```

- [ ] **Step 6: Register router in `backend/main.py`**

Add at the bottom of `backend/main.py`:
```python
from modules.attendance.router import router as attendance_router
app.include_router(attendance_router)
```

- [ ] **Step 7: Run tests**

```bash
docker compose exec --user root backend pytest tests/modules/test_attendance.py -v
```

Expected: 5 passed.

- [ ] **Step 8: Run full suite**

```bash
docker compose exec --user root backend pytest tests/ --tb=short 2>&1 | tail -5
```

Expected: 42 passed.

- [ ] **Step 9: Commit**

```bash
git add backend/modules/attendance/ backend/main.py backend/tests/modules/test_attendance.py
git commit -m "feat: add attendance module with daily register and group/student views"
```

---

## Task 2: Grades module (TDD)

**Files:**
- Create: `backend/modules/grades/schemas.py`
- Create: `backend/modules/grades/service.py`
- Create: `backend/modules/grades/router.py`
- Create: `backend/tests/modules/test_grades.py`
- Modify: `backend/main.py`

### Endpoints

| Method | Path | Roles | Description |
|--------|------|-------|-------------|
| POST | `/api/v1/grades/evaluations/` | docente, control_escolar, directivo | Crear evaluación |
| GET | `/api/v1/grades/evaluations/` | docente, control_escolar, directivo | Listar evaluaciones (filtro: group_id, subject_id) |
| POST | `/api/v1/grades/` | docente, control_escolar, directivo | Registrar calificación |
| PUT | `/api/v1/grades/{grade_id}` | docente, control_escolar, directivo | Actualizar calificación |
| GET | `/api/v1/grades/student/{student_id}` | control_escolar, directivo | Calificaciones de un alumno |

---

- [ ] **Step 1: Write failing tests**

```python
# backend/tests/modules/test_grades.py
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
    cycle = AcademicCycle(nombre="2024-2025-grd", activo=True)
    db_session.add(cycle)
    await db_session.flush()

    group = Group(nombre="2A", grado=2, turno="matutino", ciclo_id=cycle.id)
    subject = Subject(nombre="Álgebra", clave="ALG01", horas_semana=5)
    student = Student(matricula="GRD001", nombre="Test", apellido_paterno="Grade")
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
```

- [ ] **Step 2: Run to confirm FAIL**

```bash
docker compose exec --user root backend pytest tests/modules/test_grades.py -v 2>&1 | head -15
```

Expected: ImportError or 404.

- [ ] **Step 3: Create `backend/modules/grades/schemas.py`**

```python
# backend/modules/grades/schemas.py
import uuid
from datetime import date, datetime
from decimal import Decimal
from typing import Optional

from pydantic import BaseModel

from modules.grades.models import EvaluationType


class EvaluationCreate(BaseModel):
    titulo: Optional[str] = None
    tipo: Optional[EvaluationType] = None
    subject_id: Optional[uuid.UUID] = None
    group_id: Optional[uuid.UUID] = None
    descripcion: Optional[str] = None
    fecha: Optional[date] = None
    porcentaje: Optional[Decimal] = None


class EvaluationResponse(BaseModel):
    id: uuid.UUID
    titulo: Optional[str] = None
    tipo: Optional[EvaluationType] = None
    subject_id: Optional[uuid.UUID] = None
    group_id: Optional[uuid.UUID] = None
    fecha: Optional[date] = None
    porcentaje: Optional[Decimal] = None

    model_config = {"from_attributes": True}


class GradeCreate(BaseModel):
    evaluation_id: uuid.UUID
    student_id: uuid.UUID
    calificacion: Optional[Decimal] = None
    observaciones: Optional[str] = None


class GradeUpdate(BaseModel):
    calificacion: Optional[Decimal] = None
    observaciones: Optional[str] = None


class GradeResponse(BaseModel):
    id: uuid.UUID
    evaluation_id: Optional[uuid.UUID] = None
    student_id: Optional[uuid.UUID] = None
    calificacion: Optional[Decimal] = None
    observaciones: Optional[str] = None
    created_at: datetime

    model_config = {"from_attributes": True}
```

- [ ] **Step 4: Create `backend/modules/grades/service.py`**

```python
# backend/modules/grades/service.py
import uuid
from typing import Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from core.exceptions import BusinessError
from modules.grades.models import Evaluation, Grade
from modules.grades.schemas import EvaluationCreate, GradeCreate, GradeUpdate


async def create_evaluation(data: EvaluationCreate, db: AsyncSession) -> Evaluation:
    evaluation = Evaluation(**data.model_dump())
    db.add(evaluation)
    await db.commit()
    await db.refresh(evaluation)
    return evaluation


async def list_evaluations(
    db: AsyncSession,
    group_id: Optional[uuid.UUID] = None,
    subject_id: Optional[uuid.UUID] = None,
) -> list[Evaluation]:
    stmt = select(Evaluation).order_by(Evaluation.fecha.desc().nullslast())
    if group_id:
        stmt = stmt.where(Evaluation.group_id == group_id)
    if subject_id:
        stmt = stmt.where(Evaluation.subject_id == subject_id)
    result = await db.execute(stmt)
    return list(result.scalars())


async def create_grade(data: GradeCreate, db: AsyncSession) -> Grade:
    grade = Grade(**data.model_dump())
    db.add(grade)
    await db.commit()
    await db.refresh(grade)
    return grade


async def update_grade(
    grade_id: uuid.UUID, data: GradeUpdate, db: AsyncSession
) -> Grade:
    result = await db.execute(select(Grade).where(Grade.id == grade_id))
    grade = result.scalar_one_or_none()
    if grade is None:
        raise BusinessError("GRADE_NOT_FOUND", "Calificación no encontrada", status_code=404)
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(grade, field, value)
    await db.commit()
    await db.refresh(grade)
    return grade


async def list_grades_by_student(
    student_id: uuid.UUID, db: AsyncSession
) -> list[Grade]:
    result = await db.execute(
        select(Grade)
        .where(Grade.student_id == student_id)
        .order_by(Grade.created_at.desc())
    )
    return list(result.scalars())
```

- [ ] **Step 5: Create `backend/modules/grades/router.py`**

```python
# backend/modules/grades/router.py
import uuid
from typing import Optional

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from core.database import get_db
from core.security import require_roles
from modules.grades import service
from modules.grades.schemas import (
    EvaluationCreate,
    EvaluationResponse,
    GradeCreate,
    GradeResponse,
    GradeUpdate,
)

router = APIRouter(prefix="/api/v1/grades", tags=["grades"])
_write = ["docente", "control_escolar", "directivo"]
_read = ["docente", "control_escolar", "directivo"]


@router.post("/evaluations/", status_code=status.HTTP_201_CREATED)
async def create_evaluation(
    data: EvaluationCreate,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_write)),
):
    evaluation = await service.create_evaluation(data, db)
    return {"data": EvaluationResponse.model_validate(evaluation)}


@router.get("/evaluations/")
async def list_evaluations(
    group_id: Optional[uuid.UUID] = Query(None),
    subject_id: Optional[uuid.UUID] = Query(None),
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_read)),
):
    evaluations = await service.list_evaluations(db, group_id, subject_id)
    return {"data": [EvaluationResponse.model_validate(e) for e in evaluations]}


@router.post("/", status_code=status.HTTP_201_CREATED)
async def create_grade(
    data: GradeCreate,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_write)),
):
    grade = await service.create_grade(data, db)
    return {"data": GradeResponse.model_validate(grade)}


@router.put("/{grade_id}")
async def update_grade(
    grade_id: uuid.UUID,
    data: GradeUpdate,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_write)),
):
    grade = await service.update_grade(grade_id, data, db)
    return {"data": GradeResponse.model_validate(grade)}


@router.get("/student/{student_id}")
async def get_student_grades(
    student_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_read)),
):
    grades = await service.list_grades_by_student(student_id, db)
    return {"data": [GradeResponse.model_validate(g) for g in grades]}
```

- [ ] **Step 6: Register router in `backend/main.py`**

Add at the bottom:
```python
from modules.grades.router import router as grades_router
app.include_router(grades_router)
```

- [ ] **Step 7: Run tests**

```bash
docker compose exec --user root backend pytest tests/modules/test_grades.py -v
```

Expected: 5 passed.

- [ ] **Step 8: Run full suite**

```bash
docker compose exec --user root backend pytest tests/ --tb=short 2>&1 | tail -5
```

Expected: 47 passed.

- [ ] **Step 9: Commit**

```bash
git add backend/modules/grades/ backend/main.py backend/tests/modules/test_grades.py
git commit -m "feat: add grades module with evaluations and grade capture"
```

---

## Task 3: CSV/Excel Import module (TDD)

**Files:**
- Create: `backend/modules/imports/__init__.py`
- Create: `backend/modules/imports/schemas.py`
- Create: `backend/modules/imports/parsers.py`
- Create: `backend/modules/imports/service.py`
- Create: `backend/modules/imports/router.py`
- Create: `backend/tests/modules/test_imports.py`
- Modify: `backend/main.py`
- Modify: `backend/models.py` (add imports module — no new tables, just for discovery consistency)

### Flow

- `POST /api/v1/imports/students` (multipart `file`) → validates + previews first 5 rows + inserts all valid rows atomically → `{total, importados, errores, preview}`
- `POST /api/v1/imports/teachers` (multipart `file`) → same flow for docentes
- `GET /api/v1/imports/template/students` → download `.xlsx` template
- `GET /api/v1/imports/template/teachers` → download `.xlsx` template

### Expected CSV/XLSX columns

**Students:** `nombre` (req), `apellido_paterno` (req), `matricula` (req), `apellido_materno`, `municipio`, `estado`, `codigo_postal`, `tipo_sangre`

**Teachers:** `nombre` (req), `apellido_paterno` (req), `numero_empleado` (req), `apellido_materno`, `especialidad`

---

- [ ] **Step 1: Write failing tests**

```python
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
```

- [ ] **Step 2: Run to confirm FAIL**

```bash
docker compose exec --user root backend pytest tests/modules/test_imports.py -v 2>&1 | head -15
```

Expected: ImportError or 404.

- [ ] **Step 3: Create `backend/modules/imports/__init__.py`** (empty file)

- [ ] **Step 4: Create `backend/modules/imports/schemas.py`**

```python
# backend/modules/imports/schemas.py
from typing import Any
from pydantic import BaseModel


class RowError(BaseModel):
    row: int
    field: str
    message: str


class ImportResult(BaseModel):
    total: int
    importados: int
    errores: int
    error_details: list[RowError]
    preview: list[dict[str, Any]]
```

- [ ] **Step 5: Create `backend/modules/imports/parsers.py`**

```python
# backend/modules/imports/parsers.py
import csv
import io
from typing import Any

import openpyxl


def parse_file(content: bytes, filename: str) -> list[dict[str, Any]]:
    """Parse CSV or XLSX file and return list of row dicts (header = keys)."""
    if filename.endswith(".xlsx") or filename.endswith(".xls"):
        return _parse_xlsx(content)
    return _parse_csv(content)


def _parse_csv(content: bytes) -> list[dict[str, Any]]:
    text = content.decode("utf-8-sig")  # handle BOM
    reader = csv.DictReader(io.StringIO(text))
    return [row for row in reader]


def _parse_xlsx(content: bytes) -> list[dict[str, Any]]:
    wb = openpyxl.load_workbook(io.BytesIO(content), read_only=True, data_only=True)
    ws = wb.active
    rows = list(ws.iter_rows(values_only=True))
    if not rows:
        return []
    headers = [str(h).strip() if h is not None else "" for h in rows[0]]
    result = []
    for row in rows[1:]:
        result.append({headers[i]: (str(v).strip() if v is not None else "") for i, v in enumerate(row)})
    return result


def validate_student_row(row: dict[str, Any], row_num: int) -> list[dict]:
    """Return list of error dicts for a student row. Empty list = valid."""
    errors = []
    for field in ("nombre", "apellido_paterno", "matricula"):
        if not row.get(field, "").strip():
            errors.append({"row": row_num, "field": field, "message": f"Campo '{field}' es requerido"})
    return errors


def validate_teacher_row(row: dict[str, Any], row_num: int) -> list[dict]:
    """Return list of error dicts for a teacher row. Empty list = valid."""
    errors = []
    for field in ("nombre", "apellido_paterno", "numero_empleado"):
        if not row.get(field, "").strip():
            errors.append({"row": row_num, "field": field, "message": f"Campo '{field}' es requerido"})
    return errors


def build_student_template_xlsx() -> bytes:
    """Return bytes of an .xlsx template for student import."""
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "Alumnos"
    headers = ["nombre", "apellido_paterno", "apellido_materno", "matricula",
               "municipio", "estado", "codigo_postal", "tipo_sangre"]
    ws.append(headers)
    ws.append(["Ana", "García", "López", "2024001", "Monterrey", "Nuevo León", "64000", "O+"])
    buf = io.BytesIO()
    wb.save(buf)
    return buf.getvalue()


def build_teacher_template_xlsx() -> bytes:
    """Return bytes of an .xlsx template for teacher import."""
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "Docentes"
    headers = ["nombre", "apellido_paterno", "apellido_materno", "numero_empleado", "especialidad"]
    ws.append(headers)
    ws.append(["Carlos", "Mendoza", "Ruiz", "EMP001", "Matemáticas"])
    buf = io.BytesIO()
    wb.save(buf)
    return buf.getvalue()
```

- [ ] **Step 6: Create `backend/modules/imports/service.py`**

```python
# backend/modules/imports/service.py
from typing import Any

from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from modules.imports.parsers import (
    build_student_template_xlsx,
    build_teacher_template_xlsx,
    parse_file,
    validate_student_row,
    validate_teacher_row,
)
from modules.imports.schemas import ImportResult, RowError
from modules.students.models import Student
from modules.teachers.models import Teacher

MAX_ROWS = 2000


async def import_students(
    content: bytes, filename: str, db: AsyncSession
) -> ImportResult:
    rows = parse_file(content, filename)[:MAX_ROWS]
    total = len(rows)
    error_details: list[RowError] = []
    valid_students: list[Student] = []
    preview: list[dict[str, Any]] = []

    for i, row in enumerate(rows, start=2):  # row 1 = header
        errs = validate_student_row(row, i)
        if errs:
            error_details.extend([RowError(**e) for e in errs])
            continue
        valid_students.append(
            Student(
                matricula=row["matricula"].strip(),
                nombre=row.get("nombre", "").strip() or None,
                apellido_paterno=row.get("apellido_paterno", "").strip() or None,
                apellido_materno=row.get("apellido_materno", "").strip() or None,
                municipio=row.get("municipio", "").strip() or None,
                estado=row.get("estado", "").strip() or None,
                codigo_postal=row.get("codigo_postal", "").strip() or None,
                tipo_sangre=row.get("tipo_sangre", "").strip() or None,
            )
        )
        if len(preview) < 5:
            preview.append({"row": i, "matricula": row["matricula"], "nombre": row.get("nombre")})

    importados = 0
    for student in valid_students:
        try:
            db.add(student)
            await db.flush()
            importados += 1
        except IntegrityError:
            await db.rollback()
            error_details.append(
                RowError(row=0, field="matricula", message=f"Matrícula '{student.matricula}' ya existe")
            )

    await db.commit()
    return ImportResult(
        total=total,
        importados=importados,
        errores=len(error_details),
        error_details=error_details,
        preview=preview,
    )


async def import_teachers(
    content: bytes, filename: str, db: AsyncSession
) -> ImportResult:
    rows = parse_file(content, filename)[:MAX_ROWS]
    total = len(rows)
    error_details: list[RowError] = []
    valid_teachers: list[Teacher] = []
    preview: list[dict[str, Any]] = []

    for i, row in enumerate(rows, start=2):
        errs = validate_teacher_row(row, i)
        if errs:
            error_details.extend([RowError(**e) for e in errs])
            continue
        valid_teachers.append(
            Teacher(
                numero_empleado=row["numero_empleado"].strip(),
                nombre=row.get("nombre", "").strip() or None,
                apellido_paterno=row.get("apellido_paterno", "").strip() or None,
                apellido_materno=row.get("apellido_materno", "").strip() or None,
                especialidad=row.get("especialidad", "").strip() or None,
            )
        )
        if len(preview) < 5:
            preview.append({"row": i, "numero_empleado": row["numero_empleado"], "nombre": row.get("nombre")})

    importados = 0
    for teacher in valid_teachers:
        try:
            db.add(teacher)
            await db.flush()
            importados += 1
        except IntegrityError:
            await db.rollback()
            error_details.append(
                RowError(row=0, field="numero_empleado", message=f"Número de empleado '{teacher.numero_empleado}' ya existe")
            )

    await db.commit()
    return ImportResult(
        total=total,
        importados=importados,
        errores=len(error_details),
        error_details=error_details,
        preview=preview,
    )


def get_student_template() -> bytes:
    return build_student_template_xlsx()


def get_teacher_template() -> bytes:
    return build_teacher_template_xlsx()
```

- [ ] **Step 7: Create `backend/modules/imports/router.py`**

```python
# backend/modules/imports/router.py
from fastapi import APIRouter, Depends, UploadFile, File
from fastapi.responses import Response
from sqlalchemy.ext.asyncio import AsyncSession

from core.database import get_db
from core.security import require_roles
from modules.imports import service
from modules.imports.schemas import ImportResult

router = APIRouter(prefix="/api/v1/imports", tags=["imports"])
_admin = ["directivo", "control_escolar"]

MAX_FILE_SIZE = 5 * 1024 * 1024  # 5 MB


@router.post("/students")
async def import_students(
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    content = await file.read(MAX_FILE_SIZE + 1)
    result = await service.import_students(content, file.filename or "upload.csv", db)
    return {"data": result.model_dump()}


@router.post("/teachers")
async def import_teachers(
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    content = await file.read(MAX_FILE_SIZE + 1)
    result = await service.import_teachers(content, file.filename or "upload.csv", db)
    return {"data": result.model_dump()}


@router.get("/template/students")
async def student_template(
    _: dict = Depends(require_roles(_admin)),
):
    xlsx_bytes = service.get_student_template()
    return Response(
        content=xlsx_bytes,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": "attachment; filename=plantilla_alumnos.xlsx"},
    )


@router.get("/template/teachers")
async def teacher_template(
    _: dict = Depends(require_roles(_admin)),
):
    xlsx_bytes = service.get_teacher_template()
    return Response(
        content=xlsx_bytes,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": "attachment; filename=plantilla_docentes.xlsx"},
    )
```

- [ ] **Step 8: Register router in `backend/main.py`**

Add at the bottom:
```python
from modules.imports.router import router as imports_router
app.include_router(imports_router)
```

- [ ] **Step 9: Run tests**

```bash
docker compose exec --user root backend pytest tests/modules/test_imports.py -v
```

Expected: 6 passed. If a test fails due to `IntegrityError` leaking between test runs (same matricula used twice), check that `db_session` fixture does a rollback — it does in `conftest.py`. If issues persist with duplicate key errors, investigate the session isolation.

- [ ] **Step 10: Run full suite**

```bash
docker compose exec --user root backend pytest tests/ --tb=short 2>&1 | tail -5
```

Expected: 53 passed.

- [ ] **Step 11: Commit**

```bash
git add backend/modules/imports/ backend/main.py backend/tests/modules/test_imports.py
git commit -m "feat: add CSV/Excel bulk import for students and teachers with template download"
```

---

## Deferred to Plan 4 (Fase 2)

- `modules/justifications/` — justificantes + subida de archivos a MinIO
- `modules/messaging/` — mensajes directos y grupales
- `modules/events/` — eventos escolares

---

## Next Step

**Plan 4:** Justifications (MinIO upload), Messaging, Events — Fase 2 complete.
