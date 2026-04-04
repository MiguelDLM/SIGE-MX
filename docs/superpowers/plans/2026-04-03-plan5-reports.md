# Plan 5: Reports Module (Boleta & Constancia PDF) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement two GET endpoints that generate and stream PDF documents (boleta de calificaciones and constancia de inscripción) using fpdf2, without storing files.

**Architecture:** Synchronous in-memory PDF generation using fpdf2. Service functions build the PDF bytes from DB joins and return them; router wraps them in `StreamingResponse`. No storage — generated on demand each request.

**Tech Stack:** FastAPI, SQLAlchemy 2.0 async, fpdf2==2.7.9, Python's `io.BytesIO`

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `backend/requirements.txt` | Modify | Add `fpdf2==2.7.9` |
| `backend/modules/reports/__init__.py` | Exists (empty) | No change |
| `backend/modules/reports/models.py` | Exists (stub) | No change |
| `backend/modules/reports/schemas.py` | Create | Pydantic schema `ReportMeta` (unused in PDF path, satisfies module pattern) |
| `backend/modules/reports/service.py` | Create | `generate_boleta()`, `generate_constancia()` — all PDF logic |
| `backend/modules/reports/router.py` | Create | 2 GET endpoints returning `StreamingResponse` |
| `backend/main.py` | Modify | Register `reports_router` |
| `backend/tests/modules/test_reports.py` | Create | 6 tests |

---

### Task 1: Add fpdf2 to requirements and write the failing tests

**Files:**
- Modify: `backend/requirements.txt`
- Create: `backend/tests/modules/test_reports.py`

- [ ] **Step 1: Add fpdf2 dependency**

Edit `backend/requirements.txt` — append at the end:
```
fpdf2==2.7.9
```

- [ ] **Step 2: Write all 6 failing tests**

Create `backend/tests/modules/test_reports.py` with the full content below:

```python
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
```

- [ ] **Step 3: Run tests to confirm they fail (module not found)**

```bash
cd /home/miguel/Documents/github/SAS-school/backend
python -m pytest tests/modules/test_reports.py -v 2>&1 | head -30
```

Expected: `ImportError` or `ModuleNotFoundError` — the reports router doesn't exist yet.

- [ ] **Step 4: Commit the tests and dependency**

```bash
cd /home/miguel/Documents/github/SAS-school/backend
git add requirements.txt tests/modules/test_reports.py
git commit -m "test: add failing tests for reports module (boleta and constancia)"
```

---

### Task 2: Create schemas.py

**Files:**
- Create: `backend/modules/reports/schemas.py`

- [ ] **Step 1: Create the schemas file**

Create `backend/modules/reports/schemas.py`:

```python
# backend/modules/reports/schemas.py
import uuid
from datetime import datetime

from pydantic import BaseModel


class ReportMeta(BaseModel):
    id: uuid.UUID
    student_id: uuid.UUID | None
    tipo: str | None
    created_at: datetime

    model_config = {"from_attributes": True}
```

---

### Task 3: Create service.py

**Files:**
- Create: `backend/modules/reports/service.py`

The service builds PDFs in memory using fpdf2. It performs the DB joins in Python (separate queries + grouping) for clarity.

- [ ] **Step 1: Create service.py**

Create `backend/modules/reports/service.py`:

```python
# backend/modules/reports/service.py
import io
import uuid
from datetime import date
from decimal import Decimal

from fpdf import FPDF
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from core.exceptions import BusinessError
from modules.academic_cycles.models import AcademicCycle
from modules.grades.models import Evaluation, Grade
from modules.groups.models import Group, GroupStudent
from modules.students.models import Student
from modules.subjects.models import Subject


async def _get_student_or_404(student_id: uuid.UUID, db: AsyncSession) -> Student:
    result = await db.execute(select(Student).where(Student.id == student_id))
    student = result.scalar_one_or_none()
    if student is None:
        raise BusinessError("STUDENT_NOT_FOUND", "Alumno no encontrado", status_code=404)
    return student


async def _get_active_group(student_id: uuid.UUID, db: AsyncSession) -> tuple[Group | None, AcademicCycle | None]:
    """Return (group, cycle) for the student's active group, or (None, None)."""
    stmt = (
        select(Group, AcademicCycle)
        .join(GroupStudent, GroupStudent.group_id == Group.id)
        .join(AcademicCycle, AcademicCycle.id == Group.ciclo_id)
        .where(GroupStudent.student_id == student_id)
        .where(AcademicCycle.activo == True)  # noqa: E712
    )
    result = await db.execute(stmt)
    row = result.first()
    if row is None:
        return None, None
    return row[0], row[1]


async def generate_boleta(student_id: uuid.UUID, db: AsyncSession) -> bytes:
    student = await _get_student_or_404(student_id, db)
    group, cycle = await _get_active_group(student_id, db)

    # Fetch grades with evaluation + subject info
    rows: list[tuple[Grade, Evaluation, Subject]] = []
    if group is not None:
        stmt = (
            select(Grade, Evaluation, Subject)
            .join(Evaluation, Evaluation.id == Grade.evaluation_id)
            .join(Subject, Subject.id == Evaluation.subject_id)
            .where(Grade.student_id == student_id)
            .where(Evaluation.group_id == group.id)
            .order_by(Subject.nombre, Evaluation.titulo)
        )
        result = await db.execute(stmt)
        rows = list(result.tuples())

    # Group by subject
    subjects_data: dict[str, list[tuple[str, str, Decimal | None]]] = {}
    for grade, evaluation, subject in rows:
        s_name = subject.nombre or "Sin nombre"
        if s_name not in subjects_data:
            subjects_data[s_name] = []
        subjects_data[s_name].append((
            evaluation.titulo or "",
            evaluation.tipo.value if evaluation.tipo else "",
            grade.calificacion,
        ))

    nombre_completo = " ".join(filter(None, [
        student.nombre,
        student.apellido_paterno,
        student.apellido_materno,
    ]))

    pdf = FPDF()
    pdf.add_page()
    pdf.set_auto_page_break(auto=True, margin=15)

    # Header
    pdf.set_font("Helvetica", "B", 14)
    pdf.cell(0, 8, "SISTEMA INTEGRAL DE GESTION ESCOLAR", ln=True, align="C")
    pdf.cell(0, 8, "BOLETA DE CALIFICACIONES", ln=True, align="C")
    pdf.ln(4)

    # Student info
    pdf.set_font("Helvetica", "", 10)
    pdf.cell(95, 6, f"Alumno: {nombre_completo}", border=0)
    pdf.cell(95, 6, f"Matricula: {student.matricula}", ln=True)
    pdf.cell(95, 6, f"Grupo: {group.nombre if group else 'Sin grupo'}", border=0)
    pdf.cell(95, 6, f"Ciclo: {cycle.nombre if cycle else '-'}", ln=True)
    pdf.ln(4)

    # Table header
    pdf.set_font("Helvetica", "B", 9)
    pdf.set_fill_color(220, 220, 220)
    pdf.cell(60, 7, "Materia", border=1, fill=True)
    pdf.cell(55, 7, "Evaluacion", border=1, fill=True)
    pdf.cell(45, 7, "Tipo", border=1, fill=True)
    pdf.cell(30, 7, "Cal.", border=1, fill=True, ln=True, align="C")

    pdf.set_font("Helvetica", "", 9)
    if not subjects_data:
        pdf.cell(190, 7, "(Sin calificaciones registradas)", border=1, align="C", ln=True)
    else:
        for subject_name, evaluations in subjects_data.items():
            valid_grades = [c for _, _, c in evaluations if c is not None]
            promedio = sum(valid_grades) / len(valid_grades) if valid_grades else None

            first = True
            for titulo, tipo, calificacion in evaluations:
                pdf.cell(60, 6, subject_name if first else "", border=1)
                pdf.cell(55, 6, titulo, border=1)
                pdf.cell(45, 6, tipo, border=1)
                cal_str = f"{calificacion:.2f}" if calificacion is not None else "-"
                pdf.cell(30, 6, cal_str, border=1, align="C", ln=True)
                first = False

            # Promedio row
            pdf.cell(60, 6, "", border=1)
            pdf.cell(55, 6, "", border=1)
            pdf.set_font("Helvetica", "B", 9)
            pdf.cell(45, 6, "Promedio", border=1)
            prom_str = f"{float(promedio):.2f}" if promedio is not None else "-"
            pdf.cell(30, 6, prom_str, border=1, align="C", ln=True)
            pdf.set_font("Helvetica", "", 9)

    pdf.ln(4)
    pdf.set_font("Helvetica", "I", 8)
    pdf.cell(0, 6, f"Fecha de expedicion: {date.today().strftime('%d/%m/%Y')}", ln=True)

    return bytes(pdf.output())


async def generate_constancia(student_id: uuid.UUID, db: AsyncSession) -> bytes:
    student = await _get_student_or_404(student_id, db)
    group, cycle = await _get_active_group(student_id, db)

    nombre_completo = " ".join(filter(None, [
        student.nombre,
        student.apellido_paterno,
        student.apellido_materno,
    ])).upper()

    today = date.today().strftime("%d/%m/%Y")

    pdf = FPDF()
    pdf.add_page()
    pdf.set_auto_page_break(auto=True, margin=15)

    # Header
    pdf.set_font("Helvetica", "B", 14)
    pdf.cell(0, 8, "SISTEMA INTEGRAL DE GESTION ESCOLAR", ln=True, align="C")
    pdf.cell(0, 8, "CONSTANCIA DE INSCRIPCION", ln=True, align="C")
    pdf.ln(10)

    pdf.set_font("Helvetica", "", 11)
    pdf.cell(0, 7, f"Lugar, a {today}", ln=True)
    pdf.ln(6)

    pdf.cell(0, 7, "A quien corresponda:", ln=True)
    pdf.ln(6)

    grupo_str = group.nombre if group else "sin grupo asignado"
    turno_str = group.turno if group else "-"
    ciclo_str = cycle.nombre if cycle else "-"

    body = (
        f"Se hace constar que el/la alumno/a {nombre_completo}, "
        f"con matricula {student.matricula}, se encuentra debidamente "
        f"inscrito/a en esta institucion en el grupo {grupo_str}, "
        f"turno {turno_str}, correspondiente al ciclo escolar {ciclo_str}."
    )
    pdf.set_font("Helvetica", "", 11)
    pdf.multi_cell(0, 7, body)
    pdf.ln(6)

    pdf.multi_cell(
        0, 7,
        "Se expide la presente constancia a peticion del interesado "
        "para los fines que convenga."
    )
    pdf.ln(16)

    pdf.cell(60, 0.5, "", border="T")
    pdf.ln(4)
    pdf.cell(0, 6, "Control Escolar", ln=True)

    return bytes(pdf.output())
```

---

### Task 4: Create router.py

**Files:**
- Create: `backend/modules/reports/router.py`

- [ ] **Step 1: Create the router**

Create `backend/modules/reports/router.py`:

```python
# backend/modules/reports/router.py
import io
import uuid

from fastapi import APIRouter, Depends
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession

from core.database import get_db
from core.security import require_roles
from modules.reports import service

router = APIRouter(prefix="/api/v1/reports", tags=["reports"])
_allowed = ["control_escolar", "directivo", "padre", "alumno"]


@router.get("/students/{student_id}/boleta")
async def get_boleta(
    student_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_allowed)),
):
    pdf_bytes = await service.generate_boleta(student_id, db)
    filename = f"boleta_{student_id}.pdf"
    return StreamingResponse(
        io.BytesIO(pdf_bytes),
        media_type="application/pdf",
        headers={"Content-Disposition": f"inline; filename={filename}"},
    )


@router.get("/students/{student_id}/constancia")
async def get_constancia(
    student_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_allowed)),
):
    pdf_bytes = await service.generate_constancia(student_id, db)
    filename = f"constancia_{student_id}.pdf"
    return StreamingResponse(
        io.BytesIO(pdf_bytes),
        media_type="application/pdf",
        headers={"Content-Disposition": f"inline; filename={filename}"},
    )
```

---

### Task 5: Register router in main.py and run all tests

**Files:**
- Modify: `backend/main.py`

- [ ] **Step 1: Register the reports router in main.py**

Append after the last `app.include_router` line in `backend/main.py`:

```python
from modules.reports.router import router as reports_router
app.include_router(reports_router)
```

- [ ] **Step 2: Install fpdf2 in the environment**

```bash
cd /home/miguel/Documents/github/SAS-school/backend
pip install fpdf2==2.7.9
```

Expected output: `Successfully installed fpdf2-2.7.9` (or `already satisfied`).

- [ ] **Step 3: Run the reports tests**

```bash
cd /home/miguel/Documents/github/SAS-school/backend
python -m pytest tests/modules/test_reports.py -v
```

Expected: All 6 tests PASS.

- [ ] **Step 4: Run the full test suite to check for regressions**

```bash
cd /home/miguel/Documents/github/SAS-school/backend
python -m pytest tests/ -v --tb=short 2>&1 | tail -30
```

Expected: All previously passing tests still pass; 6 new tests pass.

- [ ] **Step 5: Commit**

```bash
cd /home/miguel/Documents/github/SAS-school/backend
git add modules/reports/schemas.py modules/reports/service.py modules/reports/router.py main.py requirements.txt
git commit -m "feat: add reports module with boleta and constancia PDF generation"
```
