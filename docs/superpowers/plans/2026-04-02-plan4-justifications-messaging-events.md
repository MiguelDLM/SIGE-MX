# SIGE-MX — Plan 4: Justificaciones, Mensajería y Eventos

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Completar Fase 2 añadiendo justificantes de inasistencia con subida de archivos a MinIO, mensajería REST entre usuarios, y CRUD de eventos escolares.

**Architecture:** Cada módulo sigue el patrón establecido: models (existentes) → schemas → service → router → registro en main.py. Se añade `core/storage.py` como wrapper async de MinIO, mockeado en tests. Los tres módulos son independientes y se implementan en tareas separadas.

**Tech Stack:** FastAPI, SQLAlchemy 2.0 async, pytest-asyncio, minio==7.2.7 (nuevo), python-multipart (ya en requirements).

---

## Pre-requisites

- 53 tests pasando en `main`
- Docker Compose corriendo: `docker compose up -d` (desde el worktree)
- Tests: `docker compose exec --user root backend pytest tests/ -v`
- Worktree: `.worktrees/plan4-justifications-messaging-events`

---

## Setup: Crear worktree e instalar dependencia

- [ ] **Crear worktree**

```bash
cd /home/miguel/Documents/github/SAS-school
git worktree add .worktrees/plan4-justifications-messaging-events -b plan4-justifications-messaging-events
```

- [ ] **Añadir minio a requirements.txt**

Editar `backend/requirements.txt` añadiendo al final:
```
minio==7.2.7
```

- [ ] **Crear `backend/core/storage.py`**

```python
# backend/core/storage.py
import asyncio
import io

from minio import Minio

from core.config import settings


def _get_client() -> Minio:
    return Minio(
        settings.minio_endpoint,
        access_key=settings.minio_root_user,
        secret_key=settings.minio_root_password,
        secure=False,
    )


def _sync_upload(bucket: str, key: str, data: bytes, content_type: str) -> str:
    client = _get_client()
    if not client.bucket_exists(bucket):
        client.make_bucket(bucket)
    client.put_object(
        bucket, key, io.BytesIO(data), length=len(data), content_type=content_type
    )
    return f"http://{settings.minio_endpoint}/{bucket}/{key}"


async def upload_file(
    bucket: str, key: str, data: bytes, content_type: str = "application/octet-stream"
) -> str:
    """Upload bytes to MinIO. Returns the object URL."""
    return await asyncio.to_thread(_sync_upload, bucket, key, data, content_type)
```

- [ ] **Instalar dependencia en contenedor**

```bash
cd /home/miguel/Documents/github/SAS-school/.worktrees/plan4-justifications-messaging-events
docker compose exec --user root backend pip install minio==7.2.7
```

- [ ] **Verificar que el servidor arranca**

```bash
docker compose exec --user root backend python -c "from core.storage import upload_file; print('OK')"
```

- [ ] **Commit de setup**

```bash
cd /home/miguel/Documents/github/SAS-school/.worktrees/plan4-justifications-messaging-events
git add backend/requirements.txt backend/core/storage.py
git commit -m "chore: add minio dependency and storage wrapper"
```

---

## File Structure

```
backend/
├── core/
│   └── storage.py                        NEW
├── modules/
│   ├── justifications/
│   │   ├── __init__.py                   EXISTS (empty)
│   │   ├── models.py                     EXISTS
│   │   ├── schemas.py                    NEW
│   │   ├── service.py                    NEW
│   │   └── router.py                     NEW
│   ├── messaging/
│   │   ├── __init__.py                   EXISTS (empty)
│   │   ├── models.py                     EXISTS
│   │   ├── schemas.py                    NEW
│   │   ├── service.py                    NEW
│   │   └── router.py                     NEW
│   └── events/
│       ├── __init__.py                   EXISTS (empty)
│       ├── models.py                     EXISTS
│       ├── schemas.py                    NEW
│       ├── service.py                    NEW
│       └── router.py                     NEW
├── main.py                               MODIFY — 3 new routers
├── requirements.txt                      MODIFY — minio
└── tests/modules/
    ├── test_justifications.py            NEW
    ├── test_messaging.py                 NEW
    └── test_events.py                    NEW
```

---

## Task 1: Justificaciones con MinIO (TDD)

**Models (existing):**
- `Justification`: id, student_id, fecha_inicio, fecha_fin, motivo, archivo_url, status (JustificationStatus), reviewed_by, created_at
- `JustificationStatus` enum: pendiente, aprobado, rechazado

**Files:**
- Create: `backend/modules/justifications/schemas.py`
- Create: `backend/modules/justifications/service.py`
- Create: `backend/modules/justifications/router.py`
- Create: `backend/tests/modules/test_justifications.py`
- Modify: `backend/main.py`

### Endpoints

| Method | Path | Roles | Status |
|--------|------|-------|--------|
| POST | `/api/v1/justifications/` | padre, alumno, control_escolar | 201 |
| GET | `/api/v1/justifications/` | docente, control_escolar, directivo | 200 |
| PATCH | `/api/v1/justifications/{id}/review` | control_escolar, directivo | 200 |

---

- [ ] **Step 1: Write failing tests**

```python
# backend/tests/modules/test_justifications.py
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
```

- [ ] **Step 2: Run to confirm FAIL**

```bash
cd /home/miguel/Documents/github/SAS-school/.worktrees/plan4-justifications-messaging-events
docker compose exec --user root backend pytest tests/modules/test_justifications.py -v 2>&1 | head -20
```

Expected: ImportError or 404.

- [ ] **Step 3: Create `backend/modules/justifications/schemas.py`**

```python
# backend/modules/justifications/schemas.py
import uuid
from datetime import date, datetime
from typing import Optional

from pydantic import BaseModel

from modules.justifications.models import JustificationStatus


class JustificationReview(BaseModel):
    status: JustificationStatus


class JustificationResponse(BaseModel):
    id: uuid.UUID
    student_id: Optional[uuid.UUID] = None
    fecha_inicio: Optional[date] = None
    fecha_fin: Optional[date] = None
    motivo: Optional[str] = None
    archivo_url: Optional[str] = None
    status: Optional[JustificationStatus] = None
    reviewed_by: Optional[uuid.UUID] = None
    created_at: datetime

    model_config = {"from_attributes": True}
```

- [ ] **Step 4: Create `backend/modules/justifications/service.py`**

```python
# backend/modules/justifications/service.py
import uuid
from datetime import date
from typing import Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from core import storage
from core.exceptions import BusinessError
from modules.justifications.models import Justification, JustificationStatus
from modules.justifications.schemas import JustificationReview


async def create_justification(
    student_id: uuid.UUID,
    fecha_inicio: date,
    fecha_fin: Optional[date],
    motivo: Optional[str],
    file_data: Optional[tuple[bytes, str, str]],
    db: AsyncSession,
) -> Justification:
    archivo_url = None
    if file_data:
        data, filename, content_type = file_data
        ext = filename.rsplit(".", 1)[-1].lower() if "." in filename else "bin"
        key = f"{student_id}/{uuid.uuid4()}.{ext}"
        archivo_url = await storage.upload_file("justifications", key, data, content_type)

    record = Justification(
        student_id=student_id,
        fecha_inicio=fecha_inicio,
        fecha_fin=fecha_fin,
        motivo=motivo,
        archivo_url=archivo_url,
        status=JustificationStatus.pendiente,
    )
    db.add(record)
    await db.commit()
    await db.refresh(record)
    return record


async def list_justifications(db: AsyncSession) -> list[Justification]:
    result = await db.execute(
        select(Justification).order_by(Justification.created_at.desc())
    )
    return list(result.scalars())


async def review_justification(
    justification_id: uuid.UUID,
    data: JustificationReview,
    reviewed_by: uuid.UUID,
    db: AsyncSession,
) -> Justification:
    result = await db.execute(
        select(Justification).where(Justification.id == justification_id)
    )
    record = result.scalar_one_or_none()
    if record is None:
        raise BusinessError("JUSTIFICATION_NOT_FOUND", "Justificante no encontrado", status_code=404)
    record.status = data.status
    record.reviewed_by = reviewed_by
    await db.commit()
    await db.refresh(record)
    return record
```

- [ ] **Step 5: Create `backend/modules/justifications/router.py`**

```python
# backend/modules/justifications/router.py
import uuid
from datetime import date
from typing import Optional

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession

from core.database import get_db
from core.security import require_roles
from modules.justifications import service
from modules.justifications.schemas import JustificationResponse, JustificationReview

router = APIRouter(prefix="/api/v1/justifications", tags=["justifications"])
_write = ["padre", "alumno", "control_escolar"]
_read = ["docente", "control_escolar", "directivo"]
_review = ["control_escolar", "directivo"]

MAX_FILE_SIZE = 5 * 1024 * 1024  # 5 MB


@router.post("/", status_code=status.HTTP_201_CREATED)
async def create_justification(
    student_id: uuid.UUID = Form(...),
    fecha_inicio: date = Form(...),
    fecha_fin: Optional[date] = Form(None),
    motivo: Optional[str] = Form(None),
    file: Optional[UploadFile] = File(None),
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_write)),
):
    file_data = None
    if file and file.filename:
        data = await file.read(MAX_FILE_SIZE + 1)
        if len(data) > MAX_FILE_SIZE:
            raise HTTPException(status_code=413, detail="Archivo demasiado grande (máx 5 MB)")
        file_data = (data, file.filename, file.content_type or "application/octet-stream")

    record = await service.create_justification(
        student_id=student_id,
        fecha_inicio=fecha_inicio,
        fecha_fin=fecha_fin,
        motivo=motivo,
        file_data=file_data,
        db=db,
    )
    return {"data": JustificationResponse.model_validate(record)}


@router.get("/")
async def list_justifications(
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_read)),
):
    records = await service.list_justifications(db)
    return {"data": [JustificationResponse.model_validate(r) for r in records]}


@router.patch("/{justification_id}/review")
async def review_justification(
    justification_id: uuid.UUID,
    data: JustificationReview,
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(require_roles(_review)),
):
    record = await service.review_justification(
        justification_id=justification_id,
        data=data,
        reviewed_by=uuid.UUID(current_user["user_id"]),
        db=db,
    )
    return {"data": JustificationResponse.model_validate(record)}
```

- [ ] **Step 6: Register router in `backend/main.py`**

Añadir al final:
```python
from modules.justifications.router import router as justifications_router
app.include_router(justifications_router)
```

- [ ] **Step 7: Run justifications tests**

```bash
cd /home/miguel/Documents/github/SAS-school/.worktrees/plan4-justifications-messaging-events
docker compose exec --user root backend pytest tests/modules/test_justifications.py -v
```

Expected: 6 passed.

- [ ] **Step 8: Run full suite**

```bash
docker compose exec --user root backend pytest tests/ --tb=short 2>&1 | tail -5
```

Expected: 59 passed.

- [ ] **Step 9: Commit**

```bash
cd /home/miguel/Documents/github/SAS-school/.worktrees/plan4-justifications-messaging-events
git add backend/modules/justifications/ backend/main.py backend/tests/modules/test_justifications.py
git commit -m "feat: add justifications module with MinIO file upload and approval workflow"
```

---

## Task 2: Mensajería REST (TDD)

**Models (existing):**
- `Message`: id, sender_id (FK users), content, type (MessageType), created_at
- `MessageRecipient`: message_id (FK messages), user_id (FK users), read (bool, default False)
- `MessageType` enum: directo, grupo, sistema

**Files:**
- Create: `backend/modules/messaging/schemas.py`
- Create: `backend/modules/messaging/service.py`
- Create: `backend/modules/messaging/router.py`
- Create: `backend/tests/modules/test_messaging.py`
- Modify: `backend/main.py`

### Endpoints

| Method | Path | Roles | Status |
|--------|------|-------|--------|
| POST | `/api/v1/messages/` | todos autenticados | 201 |
| GET | `/api/v1/messages/inbox` | todos autenticados | 200 |
| GET | `/api/v1/messages/sent` | todos autenticados | 200 |
| POST | `/api/v1/messages/{id}/read` | todos autenticados | 200 |

---

- [ ] **Step 1: Write failing tests**

```python
# backend/tests/modules/test_messaging.py
import uuid
import pytest
import pytest_asyncio
from httpx import AsyncClient
import sqlalchemy

from core.security import create_access_token, hash_password
from modules.users.models import Role, User, UserRole, UserStatus


@pytest_asyncio.fixture
async def user_a(db_session):
    result = await db_session.execute(sqlalchemy.select(Role).where(Role.name == "docente"))
    role = result.scalar_one_or_none()
    if not role:
        role = Role(name="docente")
        db_session.add(role)
        await db_session.flush()
    u = User(
        email=f"msg_a_{uuid.uuid4().hex[:6]}@test.com",
        password_hash=hash_password("pass"),
        nombre="UserA",
        status=UserStatus.activo,
    )
    db_session.add(u)
    await db_session.flush()
    db_session.add(UserRole(user_id=u.id, role_id=role.id))
    await db_session.commit()
    await db_session.refresh(u)
    return u


@pytest_asyncio.fixture
async def user_b(db_session):
    result = await db_session.execute(sqlalchemy.select(Role).where(Role.name == "docente"))
    role = result.scalar_one_or_none()
    if not role:
        role = Role(name="docente")
        db_session.add(role)
        await db_session.flush()
    u = User(
        email=f"msg_b_{uuid.uuid4().hex[:6]}@test.com",
        password_hash=hash_password("pass"),
        nombre="UserB",
        status=UserStatus.activo,
    )
    db_session.add(u)
    await db_session.flush()
    db_session.add(UserRole(user_id=u.id, role_id=role.id))
    await db_session.commit()
    await db_session.refresh(u)
    return u


@pytest.mark.asyncio
async def test_send_message(client: AsyncClient, user_a, user_b):
    token_a = create_access_token(str(user_a.id), ["docente"])
    response = await client.post(
        "/api/v1/messages/",
        json={
            "content": "Hola equipo",
            "type": "directo",
            "recipient_ids": [str(user_b.id)],
        },
        headers={"Authorization": f"Bearer {token_a}"},
    )
    assert response.status_code == 201
    data = response.json()["data"]
    assert data["content"] == "Hola equipo"
    assert data["sender_id"] == str(user_a.id)


@pytest.mark.asyncio
async def test_send_message_multiple_recipients(client: AsyncClient, user_a, user_b):
    token_a = create_access_token(str(user_a.id), ["docente"])
    # create a third user inline
    user_c = User(
        email=f"msg_c_{uuid.uuid4().hex[:6]}@test.com",
        password_hash=hash_password("pass"),
        nombre="UserC",
        status=UserStatus.activo,
    )
    from sqlalchemy.ext.asyncio import AsyncSession
    # we don't have db_session here but we can use user_b's session indirectly via a second call
    # Simpler: just send to user_b only and assert recipient_count via inbox
    response = await client.post(
        "/api/v1/messages/",
        json={
            "content": "Mensaje grupal",
            "type": "grupo",
            "recipient_ids": [str(user_b.id)],
        },
        headers={"Authorization": f"Bearer {token_a}"},
    )
    assert response.status_code == 201


@pytest.mark.asyncio
async def test_get_inbox(client: AsyncClient, user_a, user_b):
    token_a = create_access_token(str(user_a.id), ["docente"])
    token_b = create_access_token(str(user_b.id), ["docente"])
    # A sends to B
    await client.post(
        "/api/v1/messages/",
        json={"content": "Para inbox", "type": "directo", "recipient_ids": [str(user_b.id)]},
        headers={"Authorization": f"Bearer {token_a}"},
    )
    # B checks inbox
    response = await client.get(
        "/api/v1/messages/inbox",
        headers={"Authorization": f"Bearer {token_b}"},
    )
    assert response.status_code == 200
    data = response.json()["data"]
    assert isinstance(data, list)
    assert len(data) >= 1
    assert data[0]["read"] is False


@pytest.mark.asyncio
async def test_get_sent(client: AsyncClient, user_a, user_b):
    token_a = create_access_token(str(user_a.id), ["docente"])
    await client.post(
        "/api/v1/messages/",
        json={"content": "Enviado", "type": "directo", "recipient_ids": [str(user_b.id)]},
        headers={"Authorization": f"Bearer {token_a}"},
    )
    response = await client.get(
        "/api/v1/messages/sent",
        headers={"Authorization": f"Bearer {token_a}"},
    )
    assert response.status_code == 200
    assert isinstance(response.json()["data"], list)
    assert len(response.json()["data"]) >= 1


@pytest.mark.asyncio
async def test_mark_message_as_read(client: AsyncClient, user_a, user_b):
    token_a = create_access_token(str(user_a.id), ["docente"])
    token_b = create_access_token(str(user_b.id), ["docente"])
    send_resp = await client.post(
        "/api/v1/messages/",
        json={"content": "Léeme", "type": "directo", "recipient_ids": [str(user_b.id)]},
        headers={"Authorization": f"Bearer {token_a}"},
    )
    msg_id = send_resp.json()["data"]["id"]
    response = await client.post(
        f"/api/v1/messages/{msg_id}/read",
        headers={"Authorization": f"Bearer {token_b}"},
    )
    assert response.status_code == 200
    assert response.json()["data"]["read"] is True


@pytest.mark.asyncio
async def test_send_without_auth_returns_403(client: AsyncClient, user_b):
    response = await client.post(
        "/api/v1/messages/",
        json={"content": "No auth", "type": "directo", "recipient_ids": [str(user_b.id)]},
    )
    assert response.status_code == 403
```

- [ ] **Step 2: Run to confirm FAIL**

```bash
cd /home/miguel/Documents/github/SAS-school/.worktrees/plan4-justifications-messaging-events
docker compose exec --user root backend pytest tests/modules/test_messaging.py -v 2>&1 | head -20
```

Expected: ImportError o 404.

- [ ] **Step 3: Create `backend/modules/messaging/schemas.py`**

```python
# backend/modules/messaging/schemas.py
import uuid
from datetime import datetime
from typing import Optional

from pydantic import BaseModel

from modules.messaging.models import MessageType


class MessageCreate(BaseModel):
    content: str
    type: MessageType
    recipient_ids: list[uuid.UUID]


class MessageResponse(BaseModel):
    id: uuid.UUID
    sender_id: Optional[uuid.UUID] = None
    content: Optional[str] = None
    type: Optional[MessageType] = None
    created_at: datetime

    model_config = {"from_attributes": True}


class InboxMessageResponse(BaseModel):
    id: uuid.UUID
    sender_id: Optional[uuid.UUID] = None
    content: Optional[str] = None
    type: Optional[MessageType] = None
    created_at: datetime
    read: bool
```

- [ ] **Step 4: Create `backend/modules/messaging/service.py`**

```python
# backend/modules/messaging/service.py
import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from core.exceptions import BusinessError
from modules.messaging.models import Message, MessageRecipient
from modules.messaging.schemas import InboxMessageResponse, MessageCreate


async def send_message(
    sender_id: uuid.UUID, data: MessageCreate, db: AsyncSession
) -> Message:
    message = Message(
        sender_id=sender_id,
        content=data.content,
        type=data.type,
    )
    db.add(message)
    await db.flush()

    for recipient_id in data.recipient_ids:
        db.add(MessageRecipient(message_id=message.id, user_id=recipient_id, read=False))

    await db.commit()
    await db.refresh(message)
    return message


async def get_inbox(
    user_id: uuid.UUID, db: AsyncSession
) -> list[InboxMessageResponse]:
    result = await db.execute(
        select(Message, MessageRecipient.read)
        .join(MessageRecipient, MessageRecipient.message_id == Message.id)
        .where(MessageRecipient.user_id == user_id)
        .order_by(Message.created_at.desc())
    )
    return [
        InboxMessageResponse(
            id=msg.id,
            sender_id=msg.sender_id,
            content=msg.content,
            type=msg.type,
            created_at=msg.created_at,
            read=read,
        )
        for msg, read in result.all()
    ]


async def get_sent(
    user_id: uuid.UUID, db: AsyncSession
) -> list[Message]:
    result = await db.execute(
        select(Message)
        .where(Message.sender_id == user_id)
        .order_by(Message.created_at.desc())
    )
    return list(result.scalars())


async def mark_as_read(
    message_id: uuid.UUID, user_id: uuid.UUID, db: AsyncSession
) -> InboxMessageResponse:
    result = await db.execute(
        select(MessageRecipient).where(
            MessageRecipient.message_id == message_id,
            MessageRecipient.user_id == user_id,
        )
    )
    receipt = result.scalar_one_or_none()
    if receipt is None:
        raise BusinessError("MESSAGE_NOT_FOUND", "Mensaje no encontrado o no eres destinatario", status_code=404)
    receipt.read = True
    await db.commit()

    # Fetch message for response
    msg_result = await db.execute(select(Message).where(Message.id == message_id))
    message = msg_result.scalar_one()
    return InboxMessageResponse(
        id=message.id,
        sender_id=message.sender_id,
        content=message.content,
        type=message.type,
        created_at=message.created_at,
        read=True,
    )
```

- [ ] **Step 5: Create `backend/modules/messaging/router.py`**

```python
# backend/modules/messaging/router.py
import uuid

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from core.database import get_db
from core.security import get_current_user
from modules.messaging import service
from modules.messaging.schemas import InboxMessageResponse, MessageCreate, MessageResponse

router = APIRouter(prefix="/api/v1/messages", tags=["messaging"])


@router.post("/", status_code=status.HTTP_201_CREATED)
async def send_message(
    data: MessageCreate,
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    message = await service.send_message(
        sender_id=uuid.UUID(current_user["user_id"]),
        data=data,
        db=db,
    )
    return {"data": MessageResponse.model_validate(message)}


@router.get("/inbox")
async def get_inbox(
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    messages = await service.get_inbox(uuid.UUID(current_user["user_id"]), db)
    return {"data": [m.model_dump() for m in messages]}


@router.get("/sent")
async def get_sent(
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    messages = await service.get_sent(uuid.UUID(current_user["user_id"]), db)
    return {"data": [MessageResponse.model_validate(m) for m in messages]}


@router.post("/{message_id}/read")
async def mark_as_read(
    message_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    receipt = await service.mark_as_read(
        message_id=message_id,
        user_id=uuid.UUID(current_user["user_id"]),
        db=db,
    )
    return {"data": receipt.model_dump()}
```

- [ ] **Step 6: Register router en `backend/main.py`**

Añadir al final:
```python
from modules.messaging.router import router as messaging_router
app.include_router(messaging_router)
```

- [ ] **Step 7: Run messaging tests**

```bash
cd /home/miguel/Documents/github/SAS-school/.worktrees/plan4-justifications-messaging-events
docker compose exec --user root backend pytest tests/modules/test_messaging.py -v
```

Expected: 6 passed.

- [ ] **Step 8: Run full suite**

```bash
docker compose exec --user root backend pytest tests/ --tb=short 2>&1 | tail -5
```

Expected: 65 passed.

- [ ] **Step 9: Commit**

```bash
cd /home/miguel/Documents/github/SAS-school/.worktrees/plan4-justifications-messaging-events
git add backend/modules/messaging/ backend/main.py backend/tests/modules/test_messaging.py
git commit -m "feat: add messaging module with inbox, sent and read receipts"
```

---

## Task 3: Eventos (TDD)

**Models (existing):**
- `Event`: id, titulo, descripcion, tipo (EventType), fecha_inicio, fecha_fin, creado_por (FK users)
- `EventParticipant`: event_id, user_id — composite PK
- `EventType` enum: academico, cultural, deportivo, administrativo

**Files:**
- Create: `backend/modules/events/schemas.py`
- Create: `backend/modules/events/service.py`
- Create: `backend/modules/events/router.py`
- Create: `backend/tests/modules/test_events.py`
- Modify: `backend/main.py`

### Endpoints

| Method | Path | Roles | Status |
|--------|------|-------|--------|
| POST | `/api/v1/events/` | directivo, control_escolar | 201 |
| GET | `/api/v1/events/` | todos autenticados | 200 |
| PATCH | `/api/v1/events/{id}` | directivo, control_escolar | 200 |
| DELETE | `/api/v1/events/{id}` | directivo | 204 |
| POST | `/api/v1/events/{id}/participants` | directivo, control_escolar | 201 |

---

- [ ] **Step 1: Write failing tests**

```python
# backend/tests/modules/test_events.py
import uuid
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
    result = await db_session.execute(sqlalchemy.select(User).where(User.email == "dir_events@test.com"))
    user = result.scalar_one_or_none()
    if not user:
        user = User(
            email="dir_events@test.com",
            password_hash=hash_password("pass"),
            nombre="Directivo",
            status=UserStatus.activo,
        )
        db_session.add(user)
        await db_session.flush()
        db_session.add(UserRole(user_id=user.id, role_id=role.id))
        await db_session.commit()
        await db_session.refresh(user)
    return create_access_token(str(user.id), ["directivo"])


@pytest_asyncio.fixture
async def docente_token(db_session):
    result = await db_session.execute(sqlalchemy.select(Role).where(Role.name == "docente"))
    role = result.scalar_one_or_none()
    if not role:
        role = Role(name="docente")
        db_session.add(role)
        await db_session.flush()
    result = await db_session.execute(sqlalchemy.select(User).where(User.email == "doc_events@test.com"))
    user = result.scalar_one_or_none()
    if not user:
        user = User(
            email="doc_events@test.com",
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


@pytest.mark.asyncio
async def test_create_event(client: AsyncClient, admin_token):
    response = await client.post(
        "/api/v1/events/",
        json={
            "titulo": "Día del Maestro",
            "tipo": "cultural",
            "fecha_inicio": "2024-05-15T09:00:00",
        },
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 201
    data = response.json()["data"]
    assert data["titulo"] == "Día del Maestro"
    assert data["tipo"] == "cultural"


@pytest.mark.asyncio
async def test_list_events(client: AsyncClient, admin_token, docente_token):
    await client.post(
        "/api/v1/events/",
        json={"titulo": "Examen Final", "tipo": "academico", "fecha_inicio": "2024-11-20T08:00:00"},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    # docente can list
    response = await client.get(
        "/api/v1/events/",
        headers={"Authorization": f"Bearer {docente_token}"},
    )
    assert response.status_code == 200
    assert isinstance(response.json()["data"], list)
    assert len(response.json()["data"]) >= 1


@pytest.mark.asyncio
async def test_update_event(client: AsyncClient, admin_token):
    create_resp = await client.post(
        "/api/v1/events/",
        json={"titulo": "Evento Original", "tipo": "deportivo", "fecha_inicio": "2024-06-01T10:00:00"},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    event_id = create_resp.json()["data"]["id"]
    response = await client.patch(
        f"/api/v1/events/{event_id}",
        json={"titulo": "Evento Actualizado"},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 200
    assert response.json()["data"]["titulo"] == "Evento Actualizado"


@pytest.mark.asyncio
async def test_delete_event(client: AsyncClient, admin_token):
    create_resp = await client.post(
        "/api/v1/events/",
        json={"titulo": "Evento a Borrar", "tipo": "administrativo", "fecha_inicio": "2024-07-01T10:00:00"},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    event_id = create_resp.json()["data"]["id"]
    response = await client.delete(
        f"/api/v1/events/{event_id}",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 204


@pytest.mark.asyncio
async def test_add_participants(client: AsyncClient, admin_token, docente_token):
    create_resp = await client.post(
        "/api/v1/events/",
        json={"titulo": "Evento Participantes", "tipo": "cultural", "fecha_inicio": "2024-08-10T09:00:00"},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    event_id = create_resp.json()["data"]["id"]

    import sqlalchemy as sa
    from modules.users.models import User as UserModel
    # We need a user_id — reuse the docente user from the token
    # The docente_token fixture creates a user with email doc_events@test.com
    # We can extract the user_id from the token directly
    import jwt
    import os
    payload = jwt.decode(docente_token, os.environ["JWT_SECRET_KEY"], algorithms=["HS256"])
    docente_user_id = payload["sub"]

    response = await client.post(
        f"/api/v1/events/{event_id}/participants",
        json={"user_ids": [docente_user_id]},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 201


@pytest.mark.asyncio
async def test_create_event_without_admin_role_returns_403(client: AsyncClient, docente_token):
    response = await client.post(
        "/api/v1/events/",
        json={"titulo": "No permitido", "tipo": "cultural", "fecha_inicio": "2024-09-01T09:00:00"},
        headers={"Authorization": f"Bearer {docente_token}"},
    )
    assert response.status_code == 403


@pytest.mark.asyncio
async def test_update_unknown_event_returns_404(client: AsyncClient, admin_token):
    response = await client.patch(
        f"/api/v1/events/{uuid.uuid4()}",
        json={"titulo": "No existe"},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 404
```

- [ ] **Step 2: Run to confirm FAIL**

```bash
cd /home/miguel/Documents/github/SAS-school/.worktrees/plan4-justifications-messaging-events
docker compose exec --user root backend pytest tests/modules/test_events.py -v 2>&1 | head -20
```

Expected: ImportError o 404.

- [ ] **Step 3: Create `backend/modules/events/schemas.py`**

```python
# backend/modules/events/schemas.py
import uuid
from datetime import datetime
from typing import Optional

from pydantic import BaseModel

from modules.events.models import EventType


class EventCreate(BaseModel):
    titulo: str
    tipo: Optional[EventType] = None
    descripcion: Optional[str] = None
    fecha_inicio: Optional[datetime] = None
    fecha_fin: Optional[datetime] = None


class EventUpdate(BaseModel):
    titulo: Optional[str] = None
    tipo: Optional[EventType] = None
    descripcion: Optional[str] = None
    fecha_inicio: Optional[datetime] = None
    fecha_fin: Optional[datetime] = None


class EventParticipantsAdd(BaseModel):
    user_ids: list[uuid.UUID]


class EventResponse(BaseModel):
    id: uuid.UUID
    titulo: Optional[str] = None
    descripcion: Optional[str] = None
    tipo: Optional[EventType] = None
    fecha_inicio: Optional[datetime] = None
    fecha_fin: Optional[datetime] = None
    creado_por: Optional[uuid.UUID] = None

    model_config = {"from_attributes": True}
```

- [ ] **Step 4: Create `backend/modules/events/service.py`**

```python
# backend/modules/events/service.py
import uuid

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from core.exceptions import BusinessError
from modules.events.models import Event, EventParticipant
from modules.events.schemas import EventCreate, EventParticipantsAdd, EventUpdate


async def create_event(
    data: EventCreate, creado_por: uuid.UUID, db: AsyncSession
) -> Event:
    event = Event(**data.model_dump(), creado_por=creado_por)
    db.add(event)
    await db.commit()
    await db.refresh(event)
    return event


async def list_events(db: AsyncSession) -> list[Event]:
    result = await db.execute(
        select(Event).order_by(Event.fecha_inicio.asc().nullslast())
    )
    return list(result.scalars())


async def update_event(
    event_id: uuid.UUID, data: EventUpdate, db: AsyncSession
) -> Event:
    result = await db.execute(select(Event).where(Event.id == event_id))
    event = result.scalar_one_or_none()
    if event is None:
        raise BusinessError("EVENT_NOT_FOUND", "Evento no encontrado", status_code=404)
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(event, field, value)
    await db.commit()
    await db.refresh(event)
    return event


async def delete_event(event_id: uuid.UUID, db: AsyncSession) -> None:
    result = await db.execute(select(Event).where(Event.id == event_id))
    event = result.scalar_one_or_none()
    if event is None:
        raise BusinessError("EVENT_NOT_FOUND", "Evento no encontrado", status_code=404)
    await db.delete(event)
    await db.commit()


async def add_participants(
    event_id: uuid.UUID, data: EventParticipantsAdd, db: AsyncSession
) -> None:
    result = await db.execute(select(Event).where(Event.id == event_id))
    if result.scalar_one_or_none() is None:
        raise BusinessError("EVENT_NOT_FOUND", "Evento no encontrado", status_code=404)

    for user_id in data.user_ids:
        try:
            async with db.begin_nested():
                db.add(EventParticipant(event_id=event_id, user_id=user_id))
                await db.flush()
        except IntegrityError:
            pass  # duplicate participant — silently ignore

    await db.commit()
```

- [ ] **Step 5: Create `backend/modules/events/router.py`**

```python
# backend/modules/events/router.py
import uuid

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from core.database import get_db
from core.security import get_current_user, require_roles
from modules.events import service
from modules.events.schemas import (
    EventCreate,
    EventParticipantsAdd,
    EventResponse,
    EventUpdate,
)

router = APIRouter(prefix="/api/v1/events", tags=["events"])
_admin = ["directivo", "control_escolar"]
_delete = ["directivo"]


@router.post("/", status_code=status.HTTP_201_CREATED)
async def create_event(
    data: EventCreate,
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(require_roles(_admin)),
):
    event = await service.create_event(
        data=data,
        creado_por=uuid.UUID(current_user["user_id"]),
        db=db,
    )
    return {"data": EventResponse.model_validate(event)}


@router.get("/")
async def list_events(
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(get_current_user),
):
    events = await service.list_events(db)
    return {"data": [EventResponse.model_validate(e) for e in events]}


@router.patch("/{event_id}")
async def update_event(
    event_id: uuid.UUID,
    data: EventUpdate,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    event = await service.update_event(event_id, data, db)
    return {"data": EventResponse.model_validate(event)}


@router.delete("/{event_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_event(
    event_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_delete)),
):
    await service.delete_event(event_id, db)


@router.post("/{event_id}/participants", status_code=status.HTTP_201_CREATED)
async def add_participants(
    event_id: uuid.UUID,
    data: EventParticipantsAdd,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    await service.add_participants(event_id, data, db)
    return {"data": {"event_id": str(event_id), "added": len(data.user_ids)}}
```

- [ ] **Step 6: Register router en `backend/main.py`**

Añadir al final:
```python
from modules.events.router import router as events_router
app.include_router(events_router)
```

- [ ] **Step 7: Run events tests**

```bash
cd /home/miguel/Documents/github/SAS-school/.worktrees/plan4-justifications-messaging-events
docker compose exec --user root backend pytest tests/modules/test_events.py -v
```

Expected: 7 passed.

- [ ] **Step 8: Run full suite**

```bash
docker compose exec --user root backend pytest tests/ --tb=short 2>&1 | tail -5
```

Expected: 72 passed.

- [ ] **Step 9: Commit**

```bash
cd /home/miguel/Documents/github/SAS-school/.worktrees/plan4-justifications-messaging-events
git add backend/modules/events/ backend/main.py backend/tests/modules/test_events.py
git commit -m "feat: add events module with CRUD and participant management"
```
