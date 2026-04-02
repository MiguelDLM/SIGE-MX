# SIGE-MX — Plan 4 Design: Justificaciones, Mensajería y Eventos

**Date:** 2026-04-02  
**Status:** Approved  
**Fase:** 2 (post-MVP)

---

## Scope

Three independent modules that complete Fase 2 of SIGE-MX:

1. **Justificaciones** — File upload (PDF/image) to MinIO + approval workflow
2. **Mensajería** — REST-based direct/group messaging with inbox and read receipts
3. **Eventos** — School event CRUD with participant management

---

## Architecture

All modules follow the established pattern: `models.py` (exists) → `schemas.py` → `service.py` → `router.py` → registered in `main.py`.

### New dependency: MinIO client

Add `minio==7.2.7` to `requirements.txt`. Create `backend/core/storage.py` as a thin wrapper around the MinIO SDK. Tests mock `core.storage.upload_file` — no real MinIO required in test suite.

---

## Task 1: Justificaciones

### Purpose
Parents or students submit an absence justification with an optional supporting document (PDF, image). School staff review and approve or reject.

### MinIO integration
- Bucket: `justifications` (auto-created on first upload if absent)
- Object key: `{student_id}/{uuid4}.{ext}`
- `archivo_url` stores the full MinIO URL (internal, not presigned — access controlled by backend)
- `core/storage.py` exposes:
  - `async upload_file(bucket: str, key: str, data: bytes, content_type: str) -> str` — returns object URL
  - Called only from justifications service; mocked in tests

### Endpoints
| Method | Path | Roles | Status |
|--------|------|-------|--------|
| POST | `/api/v1/justifications/` | padre, alumno, control_escolar | 201 |
| GET | `/api/v1/justifications/` | control_escolar, directivo, docente | 200 |
| PATCH | `/api/v1/justifications/{id}/review` | control_escolar, directivo | 200 |

### Request shapes
- `POST`: multipart form — `file` (optional UploadFile) + `student_id`, `fecha_inicio`, `fecha_fin`, `motivo`
- `PATCH /review`: JSON — `status` (aprobado | rechazado), `reviewed_by` set from JWT token

### Business rules
- `status` defaults to `pendiente` on creation
- Only `control_escolar` and `directivo` can call `/review`
- If no file is uploaded, `archivo_url` is null
- Max file size: 5 MB

### Tests (6)
1. Create justification without file → 201, status=pendiente
2. Create justification with file → 201, archivo_url not null (mocked upload)
3. List justifications → 200, list
4. Approve justification → 200, status=aprobado
5. Reject justification → 200, status=rechazado
6. Review without auth → 403

---

## Task 2: Mensajería

### Purpose
Users send messages to one or more recipients. Inbox lists received messages. Sent lists sent messages. Messages can be marked as read.

### Design decisions
- No real-time (WebSocket deferred). REST polling is sufficient for MVP.
- `type` field: `directo` (1:1), `grupo` (1:N), `sistema` (automated)
- `sender_id` is extracted from the JWT token — not accepted as body input
- Recipients provided as list of `user_id` UUIDs in POST body

### Endpoints
| Method | Path | Roles | Status |
|--------|------|-------|--------|
| POST | `/api/v1/messages/` | all authenticated | 201 |
| GET | `/api/v1/messages/inbox` | all authenticated | 200 |
| GET | `/api/v1/messages/sent` | all authenticated | 200 |
| POST | `/api/v1/messages/{id}/read` | all authenticated | 200 |

### Request shapes
- `POST /`: `{ content: str, type: MessageType, recipient_ids: list[UUID] }`
- `POST /{id}/read`: no body — marks the calling user's receipt as read

### Business rules
- A user can only mark their own receipts as read (404 if not recipient)
- `sender_id` always set from JWT, never from body
- Inbox sorted by `created_at` desc
- Sent sorted by `created_at` desc

### Tests (6)
1. Send message to one recipient → 201
2. Send message to multiple recipients → 201, all recipients created
3. Get inbox → 200, list with ≥1 item
4. Get sent → 200, list with ≥1 item
5. Mark message as read → 200, read=True
6. Send without auth → 403

---

## Task 3: Eventos

### Purpose
School staff create and manage events (academic, cultural, sports, administrative). All authenticated users can view. Staff can add participants.

### Endpoints
| Method | Path | Roles | Status |
|--------|------|-------|--------|
| POST | `/api/v1/events/` | directivo, control_escolar | 201 |
| GET | `/api/v1/events/` | all authenticated | 200 |
| PATCH | `/api/v1/events/{id}` | directivo, control_escolar | 200 |
| DELETE | `/api/v1/events/{id}` | directivo | 204 |
| POST | `/api/v1/events/{id}/participants` | directivo, control_escolar | 201 |

### Request shapes
- `POST /events/`: `{ titulo: str, tipo: EventType, fecha_inicio: datetime, fecha_fin: datetime (optional), descripcion: optional }`
- `PATCH /{id}`: partial update, all fields optional
- `POST /{id}/participants`: `{ user_ids: list[UUID] }`
- `creado_por` set from JWT token

### Business rules
- `titulo` is required on creation
- DELETE returns 204 No Content
- Adding a participant that already exists is a no-op (ignore duplicate)
- 404 on PATCH/DELETE/add-participants for unknown event

### Tests (7)
1. Create event → 201, titulo in response
2. List events → 200, list
3. Update event → 200, updated field
4. Delete event → 204
5. Add participants → 201
6. Create without auth (non-admin role) → 403
7. Update unknown event → 404

---

## File Structure

```
backend/
├── core/
│   └── storage.py              NEW — MinIO wrapper
├── modules/
│   ├── justifications/
│   │   ├── schemas.py          NEW
│   │   ├── service.py          NEW
│   │   └── router.py           NEW
│   ├── messaging/
│   │   ├── schemas.py          NEW
│   │   ├── service.py          NEW
│   │   └── router.py           NEW
│   └── events/
│       ├── schemas.py          NEW
│       ├── service.py          NEW
│       └── router.py           NEW
├── main.py                     MODIFY — 3 new routers
└── tests/modules/
    ├── test_justifications.py  NEW
    ├── test_messaging.py       NEW
    └── test_events.py          NEW
requirements.txt                MODIFY — add minio
```

---

## Testing Strategy

- MinIO calls are mocked via `unittest.mock.patch("core.storage.upload_file", return_value="http://minio/test.pdf")`
- All other tests use the same `client` + `db_session` fixtures from `conftest.py`
- Target: 53 current → ~72 passing after Plan 4

---

## Deferred to Plan 5

- WebSocket real-time messaging
- Push notifications
- Reports module (`modules/reports/`)
- Presigned URL for direct client-to-MinIO upload
