# SIGE-MX — Plan 2: Core School Modules

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete the PostgreSQL schema with all entities, add audit middleware, and implement Students, Teachers, Academic Cycles, Subjects, and Groups CRUD modules.

**Architecture:** Same monolito modular FastAPI pattern as Plan 1. All remaining SQLAlchemy models are created upfront in Task 1 so a single comprehensive migration runs. A central `backend/models.py` aggregates all imports so Alembic and the test suite auto-discover every table. Modules follow the same router/service/models/schemas structure established in Plan 1.

**Tech Stack:** FastAPI, SQLAlchemy 2.0 async, Alembic, PostgreSQL 16, pytest-asyncio. Follows patterns from Plan 1 — see `backend/modules/users/` as the reference implementation.

---

## Pre-requisites (already done in Plan 1)

- `backend/core/config.py`, `database.py`, `security.py`, `exceptions.py`
- `backend/modules/users/` — User, Role, UserRole models + CRUD
- `backend/modules/auth/` — login, refresh, logout, /me
- Alembic migration `9777047025db_initial_users_schema.py` applied to sige_mx DB
- Docker Compose running: `docker compose up -d`
- Tests run via: `docker compose exec --user root backend pytest tests/ -v`

---

## File Structure

```
backend/
├── models.py                          # NEW — central model registry
├── core/
│   └── audit.py                       # NEW — AuditLog model + log_audit()
├── modules/
│   ├── academic_cycles/
│   │   ├── __init__.py
│   │   ├── models.py
│   │   ├── schemas.py
│   │   ├── service.py
│   │   └── router.py
│   ├── students/
│   │   ├── __init__.py
│   │   ├── models.py
│   │   ├── schemas.py
│   │   ├── service.py
│   │   └── router.py
│   ├── teachers/
│   │   ├── __init__.py
│   │   ├── models.py
│   │   ├── schemas.py
│   │   ├── service.py
│   │   └── router.py
│   ├── subjects/
│   │   ├── __init__.py
│   │   ├── models.py
│   │   ├── schemas.py
│   │   ├── service.py
│   │   └── router.py
│   ├── groups/
│   │   ├── __init__.py
│   │   ├── models.py
│   │   ├── schemas.py
│   │   ├── service.py
│   │   └── router.py
│   # Stub model files (no routers yet — Plan 3):
│   ├── attendance/models.py
│   ├── grades/models.py
│   ├── justifications/models.py
│   ├── messaging/models.py
│   ├── events/models.py
│   └── reports/models.py
├── migrations/
│   ├── env.py                         # MODIFY — use `import models`
│   └── versions/
│       └── <hash>_full_schema.py      # NEW migration
└── tests/
    ├── conftest.py                    # MODIFY — add `import models`
    └── modules/
        ├── test_academic_cycles.py
        ├── test_students.py
        ├── test_teachers.py
        ├── test_subjects.py
        └── test_groups.py
```

---

## Task 1: All SQLAlchemy models + central registry + full schema migration

**Files:**
- Create: `backend/models.py`
- Create: `backend/core/audit.py`
- Create: `backend/modules/academic_cycles/__init__.py`, `models.py`
- Create: `backend/modules/students/__init__.py`, `models.py`
- Create: `backend/modules/teachers/__init__.py`, `models.py`
- Create: `backend/modules/subjects/__init__.py`, `models.py`
- Create: `backend/modules/groups/__init__.py`, `models.py`
- Create stub `__init__.py` + `models.py` for: `attendance`, `grades`, `justifications`, `messaging`, `events`, `reports`
- Modify: `backend/migrations/env.py`
- Modify: `backend/tests/conftest.py`
- New migration file in `backend/migrations/versions/`

- [ ] **Step 1: Create backend/core/audit.py (AuditLog model)**

```python
# backend/core/audit.py
import uuid
from datetime import datetime

from sqlalchemy import DateTime, String, func
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from core.database import Base


class AuditLog(Base):
    __tablename__ = "audit_log"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    action: Mapped[str | None] = mapped_column(String, nullable=True)
    table_name: Mapped[str | None] = mapped_column(String, nullable=True)
    record_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    old_data: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    new_data: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    timestamp: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())


async def log_audit(
    db,
    user_id: str | None,
    action: str,
    table_name: str,
    record_id: str | None = None,
    old_data: dict | None = None,
    new_data: dict | None = None,
) -> None:
    """Write one audit entry. Call from service layer after mutations."""
    entry = AuditLog(
        user_id=uuid.UUID(user_id) if user_id else None,
        action=action,
        table_name=table_name,
        record_id=uuid.UUID(record_id) if record_id else None,
        old_data=old_data,
        new_data=new_data,
    )
    db.add(entry)
    await db.flush()
```

- [ ] **Step 2: Create backend/modules/academic_cycles/models.py**

```python
# backend/modules/academic_cycles/models.py
import uuid
from datetime import date

from sqlalchemy import Boolean, Date, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from core.database import Base


class AcademicCycle(Base):
    __tablename__ = "academic_cycles"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    nombre: Mapped[str | None] = mapped_column(String, nullable=True)
    fecha_inicio: Mapped[date | None] = mapped_column(Date, nullable=True)
    fecha_fin: Mapped[date | None] = mapped_column(Date, nullable=True)
    activo: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
```

- [ ] **Step 3: Create backend/modules/students/models.py**

```python
# backend/modules/students/models.py
import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from core.database import Base


class Student(Base):
    __tablename__ = "students"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=True
    )
    matricula: Mapped[str] = mapped_column(String, unique=True, nullable=False)
    numero_seguro_social: Mapped[str | None] = mapped_column(String, nullable=True)
    tipo_sangre: Mapped[str | None] = mapped_column(String, nullable=True)
    direccion: Mapped[str | None] = mapped_column(String, nullable=True)
    municipio: Mapped[str | None] = mapped_column(String, nullable=True)
    estado: Mapped[str | None] = mapped_column(String, nullable=True)
    codigo_postal: Mapped[str | None] = mapped_column(String, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())


class Parent(Base):
    __tablename__ = "parents"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=True
    )
    ocupacion: Mapped[str | None] = mapped_column(String, nullable=True)


class StudentParent(Base):
    __tablename__ = "student_parent"

    student_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("students.id", ondelete="CASCADE"),
        primary_key=True,
    )
    parent_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("parents.id", ondelete="CASCADE"),
        primary_key=True,
    )
    parentesco: Mapped[str | None] = mapped_column(String, nullable=True)
```

- [ ] **Step 4: Create backend/modules/teachers/models.py**

```python
# backend/modules/teachers/models.py
import uuid
from datetime import date

from sqlalchemy import Date, ForeignKey, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from core.database import Base


class Teacher(Base):
    __tablename__ = "teachers"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=True
    )
    numero_empleado: Mapped[str | None] = mapped_column(
        String, unique=True, nullable=True
    )
    especialidad: Mapped[str | None] = mapped_column(String, nullable=True)
    fecha_contratacion: Mapped[date | None] = mapped_column(Date, nullable=True)
```

- [ ] **Step 5: Create backend/modules/subjects/models.py**

```python
# backend/modules/subjects/models.py
import uuid

from sqlalchemy import Integer, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from core.database import Base


class Subject(Base):
    __tablename__ = "subjects"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    nombre: Mapped[str | None] = mapped_column(String, nullable=True)
    clave: Mapped[str | None] = mapped_column(String, nullable=True)
    horas_semana: Mapped[int | None] = mapped_column(Integer, nullable=True)
```

- [ ] **Step 6: Create backend/modules/groups/models.py**

```python
# backend/modules/groups/models.py
import uuid

from sqlalchemy import ForeignKey, Integer, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from core.database import Base


class Group(Base):
    __tablename__ = "groups"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    nombre: Mapped[str | None] = mapped_column(String, nullable=True)
    grado: Mapped[int | None] = mapped_column(Integer, nullable=True)
    turno: Mapped[str | None] = mapped_column(String, nullable=True)
    ciclo_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("academic_cycles.id"), nullable=True
    )


class GroupStudent(Base):
    __tablename__ = "group_students"

    group_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("groups.id", ondelete="CASCADE"),
        primary_key=True,
    )
    student_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("students.id", ondelete="CASCADE"),
        primary_key=True,
    )


class GroupTeacher(Base):
    __tablename__ = "group_teachers"

    group_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("groups.id"), primary_key=True
    )
    teacher_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("teachers.id"), primary_key=True
    )
    subject_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True
    )
```

- [ ] **Step 7: Create stub model files for Plan 3 modules**

Create these files exactly as shown (they will get services/routers in Plan 3):

```python
# backend/modules/attendance/models.py
import enum
import uuid
from datetime import date

from sqlalchemy import Date, Enum as SAEnum, ForeignKey, String, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from core.database import Base


class AttendanceStatus(str, enum.Enum):
    presente = "presente"
    falta = "falta"
    retardo = "retardo"
    justificado = "justificado"


class Attendance(Base):
    __tablename__ = "attendance"
    __table_args__ = (UniqueConstraint("student_id", "fecha"),)

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    student_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("students.id"), nullable=False
    )
    group_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("groups.id"), nullable=False
    )
    fecha: Mapped[date] = mapped_column(Date, nullable=False)
    status: Mapped[AttendanceStatus] = mapped_column(
        SAEnum(AttendanceStatus, name="attendance_status", create_type=False),
        nullable=False,
    )
    observaciones: Mapped[str | None] = mapped_column(String, nullable=True)
```

```python
# backend/modules/grades/models.py
import enum
import uuid
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import Date, DateTime, Enum as SAEnum, ForeignKey, Numeric, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from core.database import Base


class EvaluationType(str, enum.Enum):
    examen = "examen"
    tarea = "tarea"
    proyecto = "proyecto"
    participacion = "participacion"
    otro = "otro"


class Evaluation(Base):
    __tablename__ = "evaluations"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    subject_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("subjects.id"), nullable=True
    )
    group_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("groups.id"), nullable=True
    )
    tipo: Mapped[EvaluationType | None] = mapped_column(
        SAEnum(EvaluationType, name="evaluation_type", create_type=False), nullable=True
    )
    titulo: Mapped[str | None] = mapped_column(String, nullable=True)
    descripcion: Mapped[str | None] = mapped_column(String, nullable=True)
    fecha: Mapped[date | None] = mapped_column(Date, nullable=True)
    porcentaje: Mapped[Decimal | None] = mapped_column(Numeric(5, 2), nullable=True)


class Grade(Base):
    __tablename__ = "grades"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    evaluation_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("evaluations.id"), nullable=True
    )
    student_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("students.id"), nullable=True
    )
    calificacion: Mapped[Decimal | None] = mapped_column(Numeric(5, 2), nullable=True)
    observaciones: Mapped[str | None] = mapped_column(String, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
```

```python
# backend/modules/justifications/models.py
import enum
import uuid
from datetime import date, datetime

from sqlalchemy import Date, DateTime, Enum as SAEnum, ForeignKey, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from core.database import Base


class JustificationStatus(str, enum.Enum):
    pendiente = "pendiente"
    aprobado = "aprobado"
    rechazado = "rechazado"


class Justification(Base):
    __tablename__ = "justifications"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    student_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("students.id"), nullable=True
    )
    fecha_inicio: Mapped[date | None] = mapped_column(Date, nullable=True)
    fecha_fin: Mapped[date | None] = mapped_column(Date, nullable=True)
    motivo: Mapped[str | None] = mapped_column(String, nullable=True)
    archivo_url: Mapped[str | None] = mapped_column(String, nullable=True)
    status: Mapped[JustificationStatus | None] = mapped_column(
        SAEnum(JustificationStatus, name="justification_status", create_type=False),
        nullable=True,
    )
    reviewed_by: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
```

```python
# backend/modules/messaging/models.py
import enum
import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Enum as SAEnum, ForeignKey, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from core.database import Base


class MessageType(str, enum.Enum):
    directo = "directo"
    grupo = "grupo"
    sistema = "sistema"


class Message(Base):
    __tablename__ = "messages"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    sender_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=True
    )
    content: Mapped[str | None] = mapped_column(String, nullable=True)
    type: Mapped[MessageType | None] = mapped_column(
        SAEnum(MessageType, name="message_type", create_type=False), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())


class MessageRecipient(Base):
    __tablename__ = "message_recipients"

    message_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("messages.id", ondelete="CASCADE"),
        primary_key=True,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), primary_key=True
    )
    read: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
```

```python
# backend/modules/events/models.py
import enum
import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum as SAEnum, ForeignKey, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from core.database import Base


class EventType(str, enum.Enum):
    academico = "academico"
    cultural = "cultural"
    deportivo = "deportivo"
    administrativo = "administrativo"


class Event(Base):
    __tablename__ = "events"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    titulo: Mapped[str | None] = mapped_column(String, nullable=True)
    descripcion: Mapped[str | None] = mapped_column(String, nullable=True)
    tipo: Mapped[EventType | None] = mapped_column(
        SAEnum(EventType, name="event_type", create_type=False), nullable=True
    )
    fecha_inicio: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    fecha_fin: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    creado_por: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=True
    )


class EventParticipant(Base):
    __tablename__ = "event_participants"

    event_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("events.id", ondelete="CASCADE"),
        primary_key=True,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), primary_key=True
    )
```

```python
# backend/modules/reports/models.py
import uuid
from datetime import date, datetime

from sqlalchemy import Date, DateTime, ForeignKey, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from core.database import Base


class Certificate(Base):
    __tablename__ = "certificates"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    teacher_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("teachers.id"), nullable=True
    )
    tipo: Mapped[str | None] = mapped_column(String, nullable=True)
    descripcion: Mapped[str | None] = mapped_column(String, nullable=True)
    fecha_emision: Mapped[date | None] = mapped_column(Date, nullable=True)
    archivo_url: Mapped[str | None] = mapped_column(String, nullable=True)


class Report(Base):
    __tablename__ = "reports"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    student_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("students.id"), nullable=True
    )
    generado_por: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=True
    )
    tipo: Mapped[str | None] = mapped_column(String, nullable=True)
    archivo_url: Mapped[str | None] = mapped_column(String, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
```

Also create empty `__init__.py` files for all new module directories:
```bash
mkdir -p backend/modules/academic_cycles backend/modules/students backend/modules/teachers \
  backend/modules/subjects backend/modules/groups backend/modules/attendance \
  backend/modules/grades backend/modules/justifications backend/modules/messaging \
  backend/modules/events backend/modules/reports
touch backend/modules/academic_cycles/__init__.py backend/modules/students/__init__.py \
  backend/modules/teachers/__init__.py backend/modules/subjects/__init__.py \
  backend/modules/groups/__init__.py backend/modules/attendance/__init__.py \
  backend/modules/grades/__init__.py backend/modules/justifications/__init__.py \
  backend/modules/messaging/__init__.py backend/modules/events/__init__.py \
  backend/modules/reports/__init__.py
```

- [ ] **Step 8: Create backend/models.py (central registry)**

```python
# backend/models.py
"""Central import of all SQLAlchemy models.

Import this module wherever Base.metadata needs to reflect the full schema:
  - migrations/env.py
  - tests/conftest.py

Order matters: tables with FK dependencies must be imported after their targets.
"""
# Core
import core.audit  # noqa: F401 — audit_log table

# Plan 1
import modules.users.models  # noqa: F401 — users, roles, user_roles

# Plan 2
import modules.academic_cycles.models  # noqa: F401 — academic_cycles
import modules.students.models  # noqa: F401 — students, parents, student_parent
import modules.teachers.models  # noqa: F401 — teachers
import modules.subjects.models  # noqa: F401 — subjects
import modules.groups.models  # noqa: F401 — groups, group_students, group_teachers

# Plan 3 (stub models — schema defined, routers not yet implemented)
import modules.attendance.models  # noqa: F401 — attendance
import modules.grades.models  # noqa: F401 — evaluations, grades
import modules.justifications.models  # noqa: F401 — justifications
import modules.messaging.models  # noqa: F401 — messages, message_recipients
import modules.events.models  # noqa: F401 — events, event_participants
import modules.reports.models  # noqa: F401 — certificates, reports
```

- [ ] **Step 9: Update backend/migrations/env.py — replace individual imports with `import models`**

Replace lines 9-10 in `migrations/env.py`:
```python
from core.database import Base
import modules.users.models  # noqa: F401
```
with:
```python
from core.database import Base
import models  # noqa: F401 — registers all tables with Base.metadata
```

- [ ] **Step 10: Update backend/tests/conftest.py — add `import models` before app import**

Add this line right before `from core.database import Base, get_db`:
```python
import models  # noqa: F401 — ensures all tables are in Base.metadata for test DB
```

- [ ] **Step 11: Generate full schema migration**

```bash
docker compose exec --user root backend alembic revision --autogenerate -m "full_schema"
```

Expected output:
```
Generating /app/migrations/versions/XXXX_full_schema.py ... done
```

Open the generated file and verify it contains `create_table` for: `academic_cycles`, `students`, `parents`, `student_parent`, `teachers`, `subjects`, `groups`, `group_students`, `group_teachers`, `attendance`, `evaluations`, `grades`, `justifications`, `messages`, `message_recipients`, `events`, `event_participants`, `certificates`, `reports`, `audit_log`.

Also verify the downgrade function drops all new enum types:
```python
op.execute("DROP TYPE IF EXISTS attendance_status")
op.execute("DROP TYPE IF EXISTS evaluation_type")
op.execute("DROP TYPE IF EXISTS justification_status")
op.execute("DROP TYPE IF EXISTS message_type")
op.execute("DROP TYPE IF EXISTS event_type")
```

If these `DROP TYPE` lines are missing from downgrade, add them manually.

- [ ] **Step 12: Run migration**

```bash
docker compose exec --user root backend alembic upgrade head
```

Expected: migration completes without errors.

Verify with:
```bash
docker compose exec postgres psql -U sige_user -d sige_mx -c "\dt" | grep -E "academic_cycles|students|teachers|groups|subjects|attendance|grades"
```

Expected: all 7+ tables listed.

- [ ] **Step 13: Commit**

```bash
git add backend/models.py backend/core/audit.py backend/modules/ \
  backend/migrations/ backend/tests/conftest.py
git commit -m "feat: add full SQLAlchemy schema — all 21 tables + central model registry"
```

---

## Task 2: Audit middleware

**Files:**
- Modify: `backend/core/audit.py` (add middleware class)
- Modify: `backend/main.py` (register middleware)

- [ ] **Step 1: Add audit middleware to backend/core/audit.py**

Append to the existing `backend/core/audit.py` (keep the AuditLog model and `log_audit` function, add below them):

```python
import json
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request as StarletteRequest
from starlette.responses import Response


class AuditMiddleware(BaseHTTPMiddleware):
    """Log all write operations (POST/PUT/PATCH/DELETE) to audit_log."""

    WRITE_METHODS = {"POST", "PUT", "PATCH", "DELETE"}

    async def dispatch(self, request: StarletteRequest, call_next) -> Response:
        response = await call_next(request)

        if request.method not in self.WRITE_METHODS:
            return response

        # Extract user from request state (set by get_current_user dependency)
        user_id: str | None = getattr(request.state, "user_id", None)

        # Derive table name from path: /api/v1/students/... → "students"
        parts = request.url.path.strip("/").split("/")
        table_name = parts[2] if len(parts) >= 3 else request.url.path

        async with AsyncSessionLocal() as db:
            entry = AuditLog(
                user_id=uuid.UUID(user_id) if user_id else None,
                action=f"{request.method} {request.url.path}",
                table_name=table_name,
            )
            db.add(entry)
            await db.commit()

        return response
```

Also add the missing import at the top of `core/audit.py`:
```python
from core.database import AsyncSessionLocal
```

- [ ] **Step 2: Set user_id on request.state in get_current_user**

Modify `backend/core/security.py` — update `get_current_user` to store user_id on the request:

```python
from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
```

Replace the `get_current_user` function with:

```python
async def get_current_user(
    request: Request,
    credentials: HTTPAuthorizationCredentials = Depends(_bearer),
) -> dict:
    payload = decode_token(credentials.credentials)
    if payload.get("type") != "access":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token de acceso requerido",
        )
    user = {"user_id": payload["sub"], "roles": payload.get("roles", [])}
    request.state.user_id = user["user_id"]
    return user
```

- [ ] **Step 3: Register AuditMiddleware in main.py**

Add to `backend/main.py` after existing middleware:

```python
from core.audit import AuditMiddleware
app.add_middleware(AuditMiddleware)
```

- [ ] **Step 4: Run existing tests to verify nothing broke**

```bash
docker compose exec --user root backend pytest tests/ -v --tb=short 2>&1 | tail -10
```

Expected: all 17 tests still pass.

- [ ] **Step 5: Commit**

```bash
git add backend/core/audit.py backend/core/security.py backend/main.py
git commit -m "feat: add audit middleware — logs all write operations to audit_log"
```

---

## Task 3: Academic Cycles module (TDD)

**Files:**
- Create: `backend/modules/academic_cycles/schemas.py`
- Create: `backend/modules/academic_cycles/service.py`
- Create: `backend/modules/academic_cycles/router.py`
- Create: `backend/tests/modules/test_academic_cycles.py`
- Modify: `backend/main.py`

- [ ] **Step 1: Write failing tests**

```python
# backend/tests/modules/test_academic_cycles.py
import pytest
import pytest_asyncio
from httpx import AsyncClient

from core.security import create_access_token, hash_password
from modules.users.models import Role, User, UserStatus


@pytest_asyncio.fixture
async def admin_token(db_session):
    result = await db_session.execute(
        __import__("sqlalchemy").select(Role).where(Role.name == "directivo")
    )
    role = result.scalar_one_or_none()
    if not role:
        role = Role(name="directivo")
        db_session.add(role)
        await db_session.flush()

    result = await db_session.execute(
        __import__("sqlalchemy").select(User).where(User.email == "admin_cycle@test.com")
    )
    user = result.scalar_one_or_none()
    if not user:
        from modules.users.models import UserRole
        user = User(
            email="admin_cycle@test.com",
            password_hash=hash_password("pass"),
            nombre="Admin",
            status=UserStatus.activo,
        )
        db_session.add(user)
        await db_session.flush()
        db_session.add(UserRole(user_id=user.id, role_id=role.id))
        await db_session.commit()
        await db_session.refresh(user)

    return create_access_token(str(user.id), ["directivo"])


@pytest.mark.asyncio
async def test_create_academic_cycle(client: AsyncClient, admin_token):
    response = await client.post(
        "/api/v1/academic-cycles/",
        json={
            "nombre": "2024-2025",
            "fecha_inicio": "2024-08-19",
            "fecha_fin": "2025-06-13",
            "activo": True,
        },
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 201
    data = response.json()["data"]
    assert data["nombre"] == "2024-2025"
    assert data["activo"] is True


@pytest.mark.asyncio
async def test_list_academic_cycles(client: AsyncClient, admin_token):
    response = await client.get(
        "/api/v1/academic-cycles/",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 200
    assert "data" in response.json()


@pytest.mark.asyncio
async def test_get_active_cycle(client: AsyncClient, admin_token):
    # Create one first
    await client.post(
        "/api/v1/academic-cycles/",
        json={"nombre": "Activo", "fecha_inicio": "2024-08-01", "fecha_fin": "2025-06-01", "activo": True},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    response = await client.get(
        "/api/v1/academic-cycles/active",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 200
    assert response.json()["data"]["activo"] is True


@pytest.mark.asyncio
async def test_create_cycle_without_auth_returns_403(client: AsyncClient):
    response = await client.post(
        "/api/v1/academic-cycles/",
        json={"nombre": "X"},
    )
    assert response.status_code == 403
```

- [ ] **Step 2: Run to confirm FAIL**

```bash
docker compose exec --user root backend pytest tests/modules/test_academic_cycles.py -v 2>&1 | head -15
```

Expected: 404 errors (router not registered yet).

- [ ] **Step 3: Create schemas.py**

```python
# backend/modules/academic_cycles/schemas.py
import uuid
from datetime import date
from typing import Optional

from pydantic import BaseModel


class AcademicCycleCreate(BaseModel):
    nombre: Optional[str] = None
    fecha_inicio: Optional[date] = None
    fecha_fin: Optional[date] = None
    activo: bool = True


class AcademicCycleUpdate(BaseModel):
    nombre: Optional[str] = None
    fecha_inicio: Optional[date] = None
    fecha_fin: Optional[date] = None
    activo: Optional[bool] = None


class AcademicCycleResponse(BaseModel):
    id: uuid.UUID
    nombre: Optional[str] = None
    fecha_inicio: Optional[date] = None
    fecha_fin: Optional[date] = None
    activo: bool

    model_config = {"from_attributes": True}
```

- [ ] **Step 4: Create service.py**

```python
# backend/modules/academic_cycles/service.py
import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from core.exceptions import BusinessError
from modules.academic_cycles.models import AcademicCycle
from modules.academic_cycles.schemas import AcademicCycleCreate, AcademicCycleUpdate


async def create_cycle(data: AcademicCycleCreate, db: AsyncSession) -> AcademicCycle:
    cycle = AcademicCycle(**data.model_dump())
    db.add(cycle)
    await db.commit()
    await db.refresh(cycle)
    return cycle


async def list_cycles(db: AsyncSession) -> list[AcademicCycle]:
    result = await db.execute(select(AcademicCycle).order_by(AcademicCycle.fecha_inicio.desc().nullslast()))
    return list(result.scalars())


async def get_active_cycle(db: AsyncSession) -> AcademicCycle:
    result = await db.execute(
        select(AcademicCycle).where(AcademicCycle.activo == True).limit(1)  # noqa: E712
    )
    cycle = result.scalar_one_or_none()
    if cycle is None:
        raise BusinessError("NO_ACTIVE_CYCLE", "No hay ciclo escolar activo", status_code=404)
    return cycle


async def get_cycle_by_id(cycle_id: uuid.UUID, db: AsyncSession) -> AcademicCycle:
    result = await db.execute(select(AcademicCycle).where(AcademicCycle.id == cycle_id))
    cycle = result.scalar_one_or_none()
    if cycle is None:
        raise BusinessError("CYCLE_NOT_FOUND", "Ciclo escolar no encontrado", status_code=404)
    return cycle


async def update_cycle(
    cycle_id: uuid.UUID, data: AcademicCycleUpdate, db: AsyncSession
) -> AcademicCycle:
    cycle = await get_cycle_by_id(cycle_id, db)
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(cycle, field, value)
    await db.commit()
    await db.refresh(cycle)
    return cycle
```

- [ ] **Step 5: Create router.py**

```python
# backend/modules/academic_cycles/router.py
import uuid

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from core.database import get_db
from core.security import require_roles
from modules.academic_cycles import service
from modules.academic_cycles.schemas import (
    AcademicCycleCreate,
    AcademicCycleResponse,
    AcademicCycleUpdate,
)

router = APIRouter(prefix="/api/v1/academic-cycles", tags=["academic-cycles"])
_admin = ["directivo", "control_escolar"]


@router.post("/", status_code=status.HTTP_201_CREATED)
async def create_cycle(
    data: AcademicCycleCreate,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    cycle = await service.create_cycle(data, db)
    return {"data": AcademicCycleResponse.model_validate(cycle)}


@router.get("/active")
async def get_active_cycle(
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin + ["docente"])),
):
    cycle = await service.get_active_cycle(db)
    return {"data": AcademicCycleResponse.model_validate(cycle)}


@router.get("/")
async def list_cycles(
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    cycles = await service.list_cycles(db)
    return {"data": [AcademicCycleResponse.model_validate(c) for c in cycles]}


@router.get("/{cycle_id}")
async def get_cycle(
    cycle_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    cycle = await service.get_cycle_by_id(cycle_id, db)
    return {"data": AcademicCycleResponse.model_validate(cycle)}


@router.patch("/{cycle_id}")
async def update_cycle(
    cycle_id: uuid.UUID,
    data: AcademicCycleUpdate,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    cycle = await service.update_cycle(cycle_id, data, db)
    return {"data": AcademicCycleResponse.model_validate(cycle)}
```

- [ ] **Step 6: Register router in main.py**

Add to end of `backend/main.py`:
```python
from modules.academic_cycles.router import router as cycles_router
app.include_router(cycles_router)
```

- [ ] **Step 7: Run tests**

```bash
docker compose exec --user root backend pytest tests/modules/test_academic_cycles.py -v
```

Expected: 4 passed.

- [ ] **Step 8: Commit**

```bash
git add backend/modules/academic_cycles/ backend/main.py backend/tests/modules/test_academic_cycles.py
git commit -m "feat: add academic cycles module with CRUD"
```

---

## Task 4: Students module (TDD)

**Files:**
- Create: `backend/modules/students/schemas.py`, `service.py`, `router.py`
- Create: `backend/tests/modules/test_students.py`
- Modify: `backend/main.py`

- [ ] **Step 1: Write failing tests**

```python
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
```

- [ ] **Step 2: Run to confirm FAIL**

```bash
docker compose exec --user root backend pytest tests/modules/test_students.py -v 2>&1 | head -15
```

- [ ] **Step 3: Create schemas.py**

```python
# backend/modules/students/schemas.py
import uuid
from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class StudentCreate(BaseModel):
    matricula: str
    nombre: str
    apellido_paterno: Optional[str] = None
    apellido_materno: Optional[str] = None
    numero_seguro_social: Optional[str] = None
    tipo_sangre: Optional[str] = None
    direccion: Optional[str] = None
    municipio: Optional[str] = None
    estado: Optional[str] = None
    codigo_postal: Optional[str] = None
    user_id: Optional[uuid.UUID] = None


class StudentUpdate(BaseModel):
    nombre: Optional[str] = None
    apellido_paterno: Optional[str] = None
    apellido_materno: Optional[str] = None
    direccion: Optional[str] = None
    municipio: Optional[str] = None
    estado: Optional[str] = None
    codigo_postal: Optional[str] = None


class StudentResponse(BaseModel):
    id: uuid.UUID
    matricula: str
    nombre: str
    apellido_paterno: Optional[str] = None
    apellido_materno: Optional[str] = None
    municipio: Optional[str] = None
    estado: Optional[str] = None
    created_at: datetime

    model_config = {"from_attributes": True}
```

- [ ] **Step 4: Create service.py**

```python
# backend/modules/students/service.py
import uuid

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from core.exceptions import BusinessError
from modules.students.models import Student
from modules.students.schemas import StudentCreate, StudentUpdate


async def create_student(data: StudentCreate, db: AsyncSession) -> Student:
    student = Student(**data.model_dump())
    db.add(student)
    try:
        await db.flush()
    except IntegrityError:
        await db.rollback()
        raise BusinessError(
            "DUPLICATE_MATRICULA", "La matrícula ya está registrada", status_code=409
        )
    await db.commit()
    await db.refresh(student)
    return student


async def get_student_by_id(student_id: uuid.UUID, db: AsyncSession) -> Student:
    result = await db.execute(select(Student).where(Student.id == student_id))
    student = result.scalar_one_or_none()
    if student is None:
        raise BusinessError("STUDENT_NOT_FOUND", "Alumno no encontrado", status_code=404)
    return student


async def list_students(
    db: AsyncSession, page: int = 1, size: int = 20
) -> tuple[list[Student], int]:
    from sqlalchemy import func

    total_result = await db.execute(select(func.count()).select_from(Student))
    total = total_result.scalar_one()
    result = await db.execute(
        select(Student).order_by(Student.apellido_paterno, Student.nombre)
        .offset((page - 1) * size).limit(size)
    )
    return list(result.scalars()), total


async def update_student(
    student_id: uuid.UUID, data: StudentUpdate, db: AsyncSession
) -> Student:
    student = await get_student_by_id(student_id, db)
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(student, field, value)
    await db.commit()
    await db.refresh(student)
    return student
```

- [ ] **Step 5: Create router.py**

```python
# backend/modules/students/router.py
import uuid

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from core.database import get_db
from core.security import require_roles
from modules.students import service
from modules.students.schemas import StudentCreate, StudentResponse, StudentUpdate

router = APIRouter(prefix="/api/v1/students", tags=["students"])
_admin = ["directivo", "control_escolar"]
_read = ["directivo", "control_escolar", "docente"]


@router.post("/", status_code=status.HTTP_201_CREATED)
async def create_student(
    data: StudentCreate,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    student = await service.create_student(data, db)
    return {"data": StudentResponse.model_validate(student)}


@router.get("/")
async def list_students(
    page: int = Query(1, ge=1),
    size: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_read)),
):
    students, total = await service.list_students(db, page, size)
    pages = (total + size - 1) // size
    return {
        "data": [StudentResponse.model_validate(s) for s in students],
        "total": total,
        "page": page,
        "size": size,
        "pages": pages,
    }


@router.get("/{student_id}")
async def get_student(
    student_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_read)),
):
    student = await service.get_student_by_id(student_id, db)
    return {"data": StudentResponse.model_validate(student)}


@router.patch("/{student_id}")
async def update_student(
    student_id: uuid.UUID,
    data: StudentUpdate,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    student = await service.update_student(student_id, data, db)
    return {"data": StudentResponse.model_validate(student)}
```

- [ ] **Step 6: Register router in main.py**

```python
from modules.students.router import router as students_router
app.include_router(students_router)
```

- [ ] **Step 7: Run tests**

```bash
docker compose exec --user root backend pytest tests/modules/test_students.py -v
```

Expected: 5 passed.

- [ ] **Step 8: Run full suite**

```bash
docker compose exec --user root backend pytest tests/ -v --tb=short 2>&1 | tail -5
```

Expected: all previous tests + 5 new = passing.

- [ ] **Step 9: Commit**

```bash
git add backend/modules/students/ backend/main.py backend/tests/modules/test_students.py
git commit -m "feat: add students module with CRUD and pagination"
```

---

## Task 5: Teachers module (TDD)

**Files:**
- Create: `backend/modules/teachers/schemas.py`, `service.py`, `router.py`
- Create: `backend/tests/modules/test_teachers.py`
- Modify: `backend/main.py`

- [ ] **Step 1: Write failing tests**

```python
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
```

- [ ] **Step 2: Run to confirm FAIL**

```bash
docker compose exec --user root backend pytest tests/modules/test_teachers.py -v 2>&1 | head -10
```

- [ ] **Step 3: Create schemas.py**

```python
# backend/modules/teachers/schemas.py
import uuid
from datetime import date
from typing import Optional

from pydantic import BaseModel


class TeacherCreate(BaseModel):
    numero_empleado: Optional[str] = None
    especialidad: Optional[str] = None
    nombre: str
    apellido_paterno: Optional[str] = None
    apellido_materno: Optional[str] = None
    fecha_contratacion: Optional[date] = None
    user_id: Optional[uuid.UUID] = None


class TeacherUpdate(BaseModel):
    especialidad: Optional[str] = None
    fecha_contratacion: Optional[date] = None


class TeacherResponse(BaseModel):
    id: uuid.UUID
    numero_empleado: Optional[str] = None
    especialidad: Optional[str] = None
    nombre: str
    apellido_paterno: Optional[str] = None

    model_config = {"from_attributes": True}
```

Note: `nombre` and `apellido_paterno` are not on the Teacher model — they come from the linked `User`. For simplicity in Plan 2 (before linking users to teachers), store them as extra fields. Add them to the Teacher model:

Update `backend/modules/teachers/models.py` to add name fields:

```python
# backend/modules/teachers/models.py
import uuid
from datetime import date

from sqlalchemy import Date, ForeignKey, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from core.database import Base


class Teacher(Base):
    __tablename__ = "teachers"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=True
    )
    numero_empleado: Mapped[str | None] = mapped_column(
        String, unique=True, nullable=True
    )
    especialidad: Mapped[str | None] = mapped_column(String, nullable=True)
    fecha_contratacion: Mapped[date | None] = mapped_column(Date, nullable=True)
    # Denormalized for convenience when user_id is not linked
    nombre: Mapped[str | None] = mapped_column(String, nullable=True)
    apellido_paterno: Mapped[str | None] = mapped_column(String, nullable=True)
    apellido_materno: Mapped[str | None] = mapped_column(String, nullable=True)
```

After modifying the model, generate and run a new migration:

```bash
docker compose exec --user root backend alembic revision --autogenerate -m "add_name_fields_to_teachers"
docker compose exec --user root backend alembic upgrade head
```

- [ ] **Step 4: Create service.py**

```python
# backend/modules/teachers/service.py
import uuid

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from core.exceptions import BusinessError
from modules.teachers.models import Teacher
from modules.teachers.schemas import TeacherCreate, TeacherUpdate


async def create_teacher(data: TeacherCreate, db: AsyncSession) -> Teacher:
    teacher = Teacher(**data.model_dump())
    db.add(teacher)
    try:
        await db.flush()
    except IntegrityError:
        await db.rollback()
        raise BusinessError(
            "DUPLICATE_NUMERO_EMPLEADO",
            "El número de empleado ya existe",
            status_code=409,
        )
    await db.commit()
    await db.refresh(teacher)
    return teacher


async def get_teacher_by_id(teacher_id: uuid.UUID, db: AsyncSession) -> Teacher:
    result = await db.execute(select(Teacher).where(Teacher.id == teacher_id))
    teacher = result.scalar_one_or_none()
    if teacher is None:
        raise BusinessError("TEACHER_NOT_FOUND", "Docente no encontrado", status_code=404)
    return teacher


async def list_teachers(db: AsyncSession) -> list[Teacher]:
    result = await db.execute(
        select(Teacher).order_by(Teacher.apellido_paterno, Teacher.nombre)
    )
    return list(result.scalars())


async def update_teacher(
    teacher_id: uuid.UUID, data: TeacherUpdate, db: AsyncSession
) -> Teacher:
    teacher = await get_teacher_by_id(teacher_id, db)
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(teacher, field, value)
    await db.commit()
    await db.refresh(teacher)
    return teacher
```

- [ ] **Step 5: Create router.py**

```python
# backend/modules/teachers/router.py
import uuid

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from core.database import get_db
from core.security import require_roles
from modules.teachers import service
from modules.teachers.schemas import TeacherCreate, TeacherResponse, TeacherUpdate

router = APIRouter(prefix="/api/v1/teachers", tags=["teachers"])
_admin = ["directivo", "control_escolar"]


@router.post("/", status_code=status.HTTP_201_CREATED)
async def create_teacher(
    data: TeacherCreate,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    teacher = await service.create_teacher(data, db)
    return {"data": TeacherResponse.model_validate(teacher)}


@router.get("/")
async def list_teachers(
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin + ["docente"])),
):
    teachers = await service.list_teachers(db)
    return {"data": [TeacherResponse.model_validate(t) for t in teachers]}


@router.get("/{teacher_id}")
async def get_teacher(
    teacher_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    teacher = await service.get_teacher_by_id(teacher_id, db)
    return {"data": TeacherResponse.model_validate(teacher)}


@router.patch("/{teacher_id}")
async def update_teacher(
    teacher_id: uuid.UUID,
    data: TeacherUpdate,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    teacher = await service.update_teacher(teacher_id, data, db)
    return {"data": TeacherResponse.model_validate(teacher)}
```

- [ ] **Step 6: Register router in main.py**

```python
from modules.teachers.router import router as teachers_router
app.include_router(teachers_router)
```

- [ ] **Step 7: Run tests**

```bash
docker compose exec --user root backend pytest tests/modules/test_teachers.py -v
```

Expected: 4 passed.

- [ ] **Step 8: Commit**

```bash
git add backend/modules/teachers/ backend/main.py backend/tests/modules/test_teachers.py
git commit -m "feat: add teachers module with CRUD"
```

---

## Task 6: Subjects module (TDD)

**Files:**
- Create: `backend/modules/subjects/schemas.py`, `service.py`, `router.py`
- Create: `backend/tests/modules/test_subjects.py`
- Modify: `backend/main.py`

- [ ] **Step 1: Write failing tests**

```python
# backend/tests/modules/test_subjects.py
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
    result = await db_session.execute(sqlalchemy.select(User).where(User.email == "dir_subjects@test.com"))
    user = result.scalar_one_or_none()
    if not user:
        user = User(
            email="dir_subjects@test.com",
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
async def test_create_subject(client: AsyncClient, admin_token):
    response = await client.post(
        "/api/v1/subjects/",
        json={"nombre": "Matemáticas I", "clave": "MAT01", "horas_semana": 5},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 201
    data = response.json()["data"]
    assert data["nombre"] == "Matemáticas I"
    assert data["clave"] == "MAT01"
    assert data["horas_semana"] == 5


@pytest.mark.asyncio
async def test_list_subjects(client: AsyncClient, admin_token):
    response = await client.get(
        "/api/v1/subjects/",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 200
    assert isinstance(response.json()["data"], list)


@pytest.mark.asyncio
async def test_get_subject_by_id(client: AsyncClient, admin_token):
    create_resp = await client.post(
        "/api/v1/subjects/",
        json={"nombre": "Física I", "clave": "FIS01", "horas_semana": 4},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    subject_id = create_resp.json()["data"]["id"]
    response = await client.get(
        f"/api/v1/subjects/{subject_id}",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 200
    assert response.json()["data"]["clave"] == "FIS01"
```

- [ ] **Step 2: Run to confirm FAIL**

```bash
docker compose exec --user root backend pytest tests/modules/test_subjects.py -v 2>&1 | head -10
```

- [ ] **Step 3: Create schemas.py**

```python
# backend/modules/subjects/schemas.py
import uuid
from typing import Optional

from pydantic import BaseModel


class SubjectCreate(BaseModel):
    nombre: Optional[str] = None
    clave: Optional[str] = None
    horas_semana: Optional[int] = None


class SubjectUpdate(BaseModel):
    nombre: Optional[str] = None
    clave: Optional[str] = None
    horas_semana: Optional[int] = None


class SubjectResponse(BaseModel):
    id: uuid.UUID
    nombre: Optional[str] = None
    clave: Optional[str] = None
    horas_semana: Optional[int] = None

    model_config = {"from_attributes": True}
```

- [ ] **Step 4: Create service.py**

```python
# backend/modules/subjects/service.py
import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from core.exceptions import BusinessError
from modules.subjects.models import Subject
from modules.subjects.schemas import SubjectCreate, SubjectUpdate


async def create_subject(data: SubjectCreate, db: AsyncSession) -> Subject:
    subject = Subject(**data.model_dump())
    db.add(subject)
    await db.commit()
    await db.refresh(subject)
    return subject


async def list_subjects(db: AsyncSession) -> list[Subject]:
    result = await db.execute(select(Subject).order_by(Subject.nombre))
    return list(result.scalars())


async def get_subject_by_id(subject_id: uuid.UUID, db: AsyncSession) -> Subject:
    result = await db.execute(select(Subject).where(Subject.id == subject_id))
    subject = result.scalar_one_or_none()
    if subject is None:
        raise BusinessError("SUBJECT_NOT_FOUND", "Materia no encontrada", status_code=404)
    return subject


async def update_subject(
    subject_id: uuid.UUID, data: SubjectUpdate, db: AsyncSession
) -> Subject:
    subject = await get_subject_by_id(subject_id, db)
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(subject, field, value)
    await db.commit()
    await db.refresh(subject)
    return subject
```

- [ ] **Step 5: Create router.py**

```python
# backend/modules/subjects/router.py
import uuid

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from core.database import get_db
from core.security import require_roles
from modules.subjects import service
from modules.subjects.schemas import SubjectCreate, SubjectResponse, SubjectUpdate

router = APIRouter(prefix="/api/v1/subjects", tags=["subjects"])
_admin = ["directivo", "control_escolar"]
_read = ["directivo", "control_escolar", "docente"]


@router.post("/", status_code=status.HTTP_201_CREATED)
async def create_subject(
    data: SubjectCreate,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    subject = await service.create_subject(data, db)
    return {"data": SubjectResponse.model_validate(subject)}


@router.get("/")
async def list_subjects(
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_read)),
):
    subjects = await service.list_subjects(db)
    return {"data": [SubjectResponse.model_validate(s) for s in subjects]}


@router.get("/{subject_id}")
async def get_subject(
    subject_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_read)),
):
    subject = await service.get_subject_by_id(subject_id, db)
    return {"data": SubjectResponse.model_validate(subject)}


@router.patch("/{subject_id}")
async def update_subject(
    subject_id: uuid.UUID,
    data: SubjectUpdate,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    subject = await service.update_subject(subject_id, data, db)
    return {"data": SubjectResponse.model_validate(subject)}
```

- [ ] **Step 6: Register router in main.py**

```python
from modules.subjects.router import router as subjects_router
app.include_router(subjects_router)
```

- [ ] **Step 7: Run tests**

```bash
docker compose exec --user root backend pytest tests/modules/test_subjects.py -v
```

Expected: 3 passed.

- [ ] **Step 8: Commit**

```bash
git add backend/modules/subjects/ backend/main.py backend/tests/modules/test_subjects.py
git commit -m "feat: add subjects module with CRUD"
```

---

## Task 7: Groups module (TDD)

**Files:**
- Create: `backend/modules/groups/schemas.py`, `service.py`, `router.py`
- Create: `backend/tests/modules/test_groups.py`
- Modify: `backend/main.py`

- [ ] **Step 1: Write failing tests**

```python
# backend/tests/modules/test_groups.py
import pytest
import pytest_asyncio
from httpx import AsyncClient
import sqlalchemy

from core.security import create_access_token, hash_password
from modules.users.models import Role, User, UserRole, UserStatus
from modules.academic_cycles.models import AcademicCycle
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
    # Create group
    grp_resp = await client.post(
        "/api/v1/groups/",
        json={"nombre": "2B", "grado": 2, "turno": "vespertino", "ciclo_id": str(cycle.id)},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    group_id = grp_resp.json()["data"]["id"]

    # Create student directly in DB
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
```

- [ ] **Step 2: Run to confirm FAIL**

```bash
docker compose exec --user root backend pytest tests/modules/test_groups.py -v 2>&1 | head -10
```

- [ ] **Step 3: Create schemas.py**

```python
# backend/modules/groups/schemas.py
import uuid
from typing import Optional

from pydantic import BaseModel


class GroupCreate(BaseModel):
    nombre: Optional[str] = None
    grado: Optional[int] = None
    turno: Optional[str] = None
    ciclo_id: Optional[uuid.UUID] = None


class GroupUpdate(BaseModel):
    nombre: Optional[str] = None
    grado: Optional[int] = None
    turno: Optional[str] = None
    ciclo_id: Optional[uuid.UUID] = None


class GroupResponse(BaseModel):
    id: uuid.UUID
    nombre: Optional[str] = None
    grado: Optional[int] = None
    turno: Optional[str] = None
    ciclo_id: Optional[uuid.UUID] = None

    model_config = {"from_attributes": True}


class AssignStudentRequest(BaseModel):
    student_id: uuid.UUID


class AssignTeacherRequest(BaseModel):
    teacher_id: uuid.UUID
    subject_id: uuid.UUID
```

- [ ] **Step 4: Create service.py**

```python
# backend/modules/groups/service.py
import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from core.exceptions import BusinessError
from modules.groups.models import Group, GroupStudent, GroupTeacher
from modules.groups.schemas import AssignStudentRequest, AssignTeacherRequest, GroupCreate, GroupUpdate


async def create_group(data: GroupCreate, db: AsyncSession) -> Group:
    group = Group(**data.model_dump())
    db.add(group)
    await db.commit()
    await db.refresh(group)
    return group


async def get_group_by_id(group_id: uuid.UUID, db: AsyncSession) -> Group:
    result = await db.execute(select(Group).where(Group.id == group_id))
    group = result.scalar_one_or_none()
    if group is None:
        raise BusinessError("GROUP_NOT_FOUND", "Grupo no encontrado", status_code=404)
    return group


async def list_groups(db: AsyncSession) -> list[Group]:
    result = await db.execute(select(Group).order_by(Group.grado, Group.nombre))
    return list(result.scalars())


async def update_group(
    group_id: uuid.UUID, data: GroupUpdate, db: AsyncSession
) -> Group:
    group = await get_group_by_id(group_id, db)
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(group, field, value)
    await db.commit()
    await db.refresh(group)
    return group


async def assign_student(
    group_id: uuid.UUID, data: AssignStudentRequest, db: AsyncSession
) -> dict:
    await get_group_by_id(group_id, db)
    # Check not already assigned
    existing = await db.execute(
        select(GroupStudent).where(
            GroupStudent.group_id == group_id,
            GroupStudent.student_id == data.student_id,
        )
    )
    if existing.scalar_one_or_none():
        raise BusinessError("ALREADY_ASSIGNED", "Alumno ya asignado al grupo", status_code=409)
    db.add(GroupStudent(group_id=group_id, student_id=data.student_id))
    await db.commit()
    return {"assigned": True}


async def assign_teacher(
    group_id: uuid.UUID, data: AssignTeacherRequest, db: AsyncSession
) -> dict:
    await get_group_by_id(group_id, db)
    db.add(
        GroupTeacher(
            group_id=group_id,
            teacher_id=data.teacher_id,
            subject_id=data.subject_id,
        )
    )
    await db.commit()
    return {"assigned": True}
```

- [ ] **Step 5: Create router.py**

```python
# backend/modules/groups/router.py
import uuid

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from core.database import get_db
from core.security import require_roles
from modules.groups import service
from modules.groups.schemas import (
    AssignStudentRequest,
    AssignTeacherRequest,
    GroupCreate,
    GroupResponse,
    GroupUpdate,
)

router = APIRouter(prefix="/api/v1/groups", tags=["groups"])
_admin = ["directivo", "control_escolar"]


@router.post("/", status_code=status.HTTP_201_CREATED)
async def create_group(
    data: GroupCreate,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    group = await service.create_group(data, db)
    return {"data": GroupResponse.model_validate(group)}


@router.get("/")
async def list_groups(
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin + ["docente"])),
):
    groups = await service.list_groups(db)
    return {"data": [GroupResponse.model_validate(g) for g in groups]}


@router.get("/{group_id}")
async def get_group(
    group_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin + ["docente"])),
):
    group = await service.get_group_by_id(group_id, db)
    return {"data": GroupResponse.model_validate(group)}


@router.patch("/{group_id}")
async def update_group(
    group_id: uuid.UUID,
    data: GroupUpdate,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    group = await service.update_group(group_id, data, db)
    return {"data": GroupResponse.model_validate(group)}


@router.post("/{group_id}/students")
async def assign_student(
    group_id: uuid.UUID,
    data: AssignStudentRequest,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    result = await service.assign_student(group_id, data, db)
    return {"data": result}


@router.post("/{group_id}/teachers")
async def assign_teacher(
    group_id: uuid.UUID,
    data: AssignTeacherRequest,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    result = await service.assign_teacher(group_id, data, db)
    return {"data": result}
```

- [ ] **Step 6: Register router in main.py**

```python
from modules.groups.router import router as groups_router
app.include_router(groups_router)
```

- [ ] **Step 7: Run tests**

```bash
docker compose exec --user root backend pytest tests/modules/test_groups.py -v
```

Expected: 4 passed.

- [ ] **Step 8: Run full suite**

```bash
docker compose exec --user root backend pytest tests/ --tb=short 2>&1 | tail -5
```

Expected: all tests pass (17 from Plan 1 + ~16 new = ~33 total).

- [ ] **Step 9: Commit**

```bash
git add backend/modules/groups/ backend/main.py backend/tests/modules/test_groups.py
git commit -m "feat: add groups module with student and teacher assignment"
```

---

## Deferred to Plan 3

- `modules/attendance/` — service, schemas, router (model exists)
- `modules/grades/` — service, schemas, router (model exists)
- `modules/imports/` — CSV/Excel bulk import
- `modules/justifications/`, `messaging/`, `events/`, `reports/` — Phase 2/3

---

## Next Step

**Plan 3:** Attendance module, Grades module, CSV/Excel import (Phase 1 MVP complete)
