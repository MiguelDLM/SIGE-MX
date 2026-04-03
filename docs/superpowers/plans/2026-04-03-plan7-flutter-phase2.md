# Flutter Phase 2 — Mensajería, Justificantes, Eventos y Reportes PDF

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar las pantallas de mensajería (inbox/enviar), justificantes (subir/revisar), eventos (ver lista) y reportes PDF (boleta/constancia) en la app Flutter, incluyendo los endpoints de backend necesarios.

**Architecture:** Todos los endpoints ya existen excepto tres: `GET /api/v1/students/my` (para que padre/alumno descubra su student_id), `GET /api/v1/users/?role=` (para el selector de destinatarios en mensajería), y `GET /api/v1/justifications/my` (para que padre/alumno vea sus propios justificantes). El patrón Flutter sigue el mismo stack Riverpod + GoRouter de la Fase 1. Los PDFs se descargan vía Dio con el token Bearer y se abren con `open_file_x`.

**Tech Stack:** Flutter 3.x, Riverpod 2.x, GoRouter 14.x, Dio 5.x, file_picker ^8.x, open_file_x ^3.x, path_provider ^2.x (backend: FastAPI + SQLAlchemy)

---

## File Map

### Backend (modifications/additions)
| File | Acción | Responsabilidad |
|------|--------|-----------------|
| `backend/modules/students/service.py` | Modify | Añadir `list_my_students()` |
| `backend/modules/students/router.py` | Modify | Añadir `GET /api/v1/students/my` |
| `backend/modules/users/service.py` | Modify | Añadir `list_users()` con filtro de rol |
| `backend/modules/users/router.py` | Modify | Añadir `GET /api/v1/users/` |
| `backend/modules/justifications/service.py` | Modify | Añadir `list_my_justifications()` |
| `backend/modules/justifications/router.py` | Modify | Añadir `GET /api/v1/justifications/my` |
| `backend/tests/modules/test_students.py` | Modify | Tests para `/students/my` |
| `backend/tests/modules/test_users.py` | Modify | Tests para `GET /users/` |
| `backend/tests/modules/test_justifications.py` | Modify | Tests para `/justifications/my` |

### Flutter (`mobile/lib/`)
| File | Responsabilidad |
|------|-----------------|
| `pubspec.yaml` | Añadir file_picker, open_file_x, path_provider |
| `shared/models/message.dart` | DTO Message / InboxMessage |
| `shared/models/justification.dart` | DTO Justification |
| `shared/models/event.dart` | DTO Event |
| `shared/models/user_summary.dart` | DTO UserSummary (para selector de destinatarios) |
| `features/messaging/messaging_provider.dart` | FutureProviders inbox, sent; StateNotifier compose |
| `features/messaging/inbox_screen.dart` | Lista de mensajes recibidos con badge unread |
| `features/messaging/send_message_screen.dart` | Formulario enviar mensaje con búsqueda de destinatario |
| `features/justifications/justifications_provider.dart` | FutureProviders lista propia, lista admin |
| `features/justifications/justification_list_screen.dart` | Lista role-aware (padre/alumno: propios; otros: todos) |
| `features/justifications/submit_justification_screen.dart` | Formulario para padre/alumno con file_picker |
| `features/events/events_provider.dart` | FutureProvider lista de eventos |
| `features/events/events_screen.dart` | Lista de eventos con detalle expandible |
| `features/reports/reports_screen.dart` | Botones descarga boleta/constancia con Dio + open_file_x |
| `core/router/router.dart` | Modify — añadir rutas /messages, /justifications, /events, /reports actualizado |
| `features/dashboard/app_shell.dart` | Modify — añadir tab Mensajes en todos los roles |
| `test/widget/messaging_test.dart` | Test inbox vacío + badge unread |
| `test/widget/reports_test.dart` | Test botones boleta/constancia presentes |

---

### Task 1: Backend — students/my, users list, justifications/my

**Files:**
- Modify: `backend/modules/students/service.py`
- Modify: `backend/modules/students/router.py`
- Modify: `backend/modules/users/service.py`
- Modify: `backend/modules/users/router.py`
- Modify: `backend/modules/justifications/service.py`
- Modify: `backend/modules/justifications/router.py`

- [ ] **Step 1: Añadir `list_my_students` al servicio de students**

En `backend/modules/students/service.py`, añadir después de `list_students`:

```python
async def list_my_students(
    user_id: uuid.UUID, db: AsyncSession
) -> list[Student]:
    """Retorna alumnos vinculados al usuario actual.
    Para alumno: el registro Student donde user_id == user_id.
    Para padre: alumnos vinculados vía parent → student_parent.
    """
    from modules.students.models import Parent, StudentParent
    results: list[Student] = []

    # alumno directo
    direct = await db.execute(
        select(Student).where(Student.user_id == user_id)
    )
    results.extend(direct.scalars().all())

    # vía padre
    parent_result = await db.execute(
        select(Parent).where(Parent.user_id == user_id)
    )
    parent = parent_result.scalar_one_or_none()
    if parent:
        linked = await db.execute(
            select(Student)
            .join(StudentParent, StudentParent.student_id == Student.id)
            .where(StudentParent.parent_id == parent.id)
        )
        results.extend(linked.scalars().all())

    return results
```

- [ ] **Step 2: Añadir endpoint `GET /api/v1/students/my`**

En `backend/modules/students/router.py`, añadir **antes** del endpoint `GET /{student_id}` (para que no capture "my" como UUID):

```python
from core.security import get_current_user

@router.get("/my")
async def list_my_students(
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    students = await service.list_my_students(uuid.UUID(current_user["user_id"]), db)
    return {"data": [StudentResponse.model_validate(s) for s in students]}
```

- [ ] **Step 3: Añadir `list_users` al servicio de users**

En `backend/modules/users/service.py`, añadir al final:

```python
from typing import Optional

async def list_users(
    db: AsyncSession,
    role: Optional[str] = None,
) -> list[tuple[User, list[str]]]:
    """Retorna usuarios con sus roles. Si role es dado, filtra por ese rol."""
    if role:
        stmt = (
            select(User)
            .join(UserRole, UserRole.user_id == User.id)
            .join(Role, Role.id == UserRole.role_id)
            .where(Role.name == role)
            .order_by(User.apellido_paterno, User.nombre)
        )
    else:
        stmt = select(User).order_by(User.apellido_paterno, User.nombre)

    result = await db.execute(stmt)
    users = list(result.scalars().unique())
    out = []
    for u in users:
        roles = await get_user_roles(u.id, db)
        out.append((u, roles))
    return out
```

- [ ] **Step 4: Añadir endpoint `GET /api/v1/users/`**

En `backend/modules/users/router.py`, añadir al final. También añadir `from typing import Optional` y `Query` a los imports de fastapi:

```python
from typing import Optional
from fastapi import APIRouter, Depends, Query, status
from core.security import get_current_user

@router.get("/")
async def list_users(
    role: Optional[str] = Query(None),
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(get_current_user),
):
    pairs = await service.list_users(db, role)
    return {
        "data": [
            _user_to_response(user, roles)
            for user, roles in pairs
        ]
    }
```

- [ ] **Step 5: Añadir `list_my_justifications` al servicio de justificantes**

En `backend/modules/justifications/service.py`, añadir al final:

```python
async def list_my_justifications(
    user_id: uuid.UUID, db: AsyncSession
) -> list[Justification]:
    from modules.students.models import Parent, Student, StudentParent

    student_ids: list[uuid.UUID] = []

    direct = await db.execute(
        select(Student.id).where(Student.user_id == user_id)
    )
    student_ids.extend(direct.scalars().all())

    parent_result = await db.execute(
        select(Parent).where(Parent.user_id == user_id)
    )
    parent = parent_result.scalar_one_or_none()
    if parent:
        linked = await db.execute(
            select(StudentParent.student_id).where(
                StudentParent.parent_id == parent.id
            )
        )
        student_ids.extend(linked.scalars().all())

    if not student_ids:
        return []

    result = await db.execute(
        select(Justification)
        .where(Justification.student_id.in_(student_ids))
        .order_by(Justification.created_at.desc())
    )
    return list(result.scalars())
```

- [ ] **Step 6: Añadir endpoint `GET /api/v1/justifications/my`**

En `backend/modules/justifications/router.py`, añadir **al inicio** de las rutas GET (antes de `GET /`), y añadir import de `get_current_user`:

```python
from core.security import get_current_user, require_roles

@router.get("/my")
async def list_my_justifications(
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    records = await service.list_my_justifications(
        uuid.UUID(current_user["user_id"]), db
    )
    return {"data": [JustificationResponse.model_validate(r) for r in records]}
```

- [ ] **Step 7: Escribir tests para los nuevos endpoints**

Añadir al final de `backend/tests/modules/test_students.py`:

```python
@pytest.mark.asyncio
async def test_list_my_students_alumno(client: AsyncClient, admin_token, db_session):
    from modules.students.models import Student
    suffix = uuid.uuid4().hex[:6]

    # Create a user with alumno role
    resp_user = await client.post(
        "/api/v1/users/",
        json={
            "nombre": "Carlos", "apellido_paterno": "Soto",
            "email": f"alumno-{suffix}@test.mx", "password": "pass123",
            "roles": ["alumno"]
        },
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    user_id = resp_user.json()["data"]["id"]

    # Link student to that user
    student = Student(matricula=f"MY{suffix}", nombre="Carlos", user_id=uuid.UUID(user_id))
    db_session.add(student)
    await db_session.commit()

    # Login as alumno
    resp_login = await client.post(
        "/api/v1/auth/login",
        json={"email": f"alumno-{suffix}@test.mx", "password": "pass123"},
    )
    alumno_token = resp_login.json()["data"]["access_token"]

    resp = await client.get(
        "/api/v1/students/my",
        headers={"Authorization": f"Bearer {alumno_token}"},
    )
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert len(data) == 1
    assert data[0]["matricula"] == f"MY{suffix}"
```

Añadir al final de `backend/tests/modules/test_users.py`:

```python
@pytest.mark.asyncio
async def test_list_users_by_role(client: AsyncClient, admin_token):
    resp = await client.get(
        "/api/v1/users/?role=directivo",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert resp.status_code == 200
    data = resp.json()["data"]
    # All returned users must have the 'directivo' role
    for u in data:
        assert "directivo" in u["roles"]


@pytest.mark.asyncio
async def test_list_users_no_auth(client: AsyncClient):
    resp = await client.get("/api/v1/users/")
    assert resp.status_code == 401
```

Añadir al final de `backend/tests/modules/test_justifications.py`:

```python
@pytest.mark.asyncio
async def test_list_my_justifications_empty(client: AsyncClient, admin_token):
    suffix = uuid.uuid4().hex[:6]

    # Create alumno user with no student linkage
    resp_user = await client.post(
        "/api/v1/users/",
        json={
            "nombre": "Nuevo", "apellido_paterno": "Alumno",
            "email": f"alumno-jmy-{suffix}@test.mx", "password": "pass123",
            "roles": ["alumno"]
        },
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    resp_login = await client.post(
        "/api/v1/auth/login",
        json={"email": f"alumno-jmy-{suffix}@test.mx", "password": "pass123"},
    )
    token = resp_login.json()["data"]["access_token"]

    resp = await client.get(
        "/api/v1/justifications/my",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200
    assert resp.json()["data"] == []
```

- [ ] **Step 8: Ejecutar tests**

```bash
docker exec flutter-phase1-backend-1 pytest tests/modules/test_students.py tests/modules/test_users.py tests/modules/test_justifications.py -v --tb=short 2>&1 | tail -20
```

Corregir cualquier error antes de continuar.

- [ ] **Step 9: Ejecutar suite completa y commit**

```bash
docker exec flutter-phase1-backend-1 pytest tests/ -q --tb=no 2>&1 | tail -3
```

```bash
cd /home/miguel/Documents/github/SAS-school/.worktrees/flutter-phase2
git add backend/modules/students/service.py backend/modules/students/router.py \
        backend/modules/users/service.py backend/modules/users/router.py \
        backend/modules/justifications/service.py backend/modules/justifications/router.py \
        backend/tests/modules/test_students.py backend/tests/modules/test_users.py \
        backend/tests/modules/test_justifications.py
git commit -m "feat: add students/my, users list, justifications/my endpoints"
```

---

### Task 2: Flutter — pubspec y modelos compartidos

**Files:**
- Modify: `mobile/pubspec.yaml`
- Create: `mobile/lib/shared/models/message.dart`
- Create: `mobile/lib/shared/models/justification.dart`
- Create: `mobile/lib/shared/models/event.dart`
- Create: `mobile/lib/shared/models/user_summary.dart`

- [ ] **Step 1: Añadir dependencias a pubspec.yaml**

En `mobile/pubspec.yaml`, añadir bajo `dependencies:` (después de `connectivity_plus`):

```yaml
  file_picker: ^8.1.2
  open_file_x: ^3.5.4
  path_provider: ^2.1.3
```

- [ ] **Step 2: Instalar paquetes**

```bash
cd /home/miguel/Documents/github/SAS-school/.worktrees/flutter-phase2/mobile
flutter pub get 2>&1 | tail -5
```

Expected: `pubspec.lock` actualizado sin errores.

- [ ] **Step 3: Crear `lib/shared/models/user_summary.dart`**

```dart
class UserSummary {
  final String id;
  final String? nombre;
  final String? apellidoPaterno;
  final String? apellidoMaterno;
  final List<String> roles;

  const UserSummary({
    required this.id,
    this.nombre,
    this.apellidoPaterno,
    this.apellidoMaterno,
    this.roles = const [],
  });

  String get nombreCompleto => [nombre, apellidoPaterno, apellidoMaterno]
      .where((s) => s != null && s.isNotEmpty)
      .join(' ');

  factory UserSummary.fromJson(Map<String, dynamic> json) => UserSummary(
        id: json['id'] as String,
        nombre: json['nombre'] as String?,
        apellidoPaterno: json['apellido_paterno'] as String?,
        apellidoMaterno: json['apellido_materno'] as String?,
        roles: (json['roles'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
      );
}
```

- [ ] **Step 4: Crear `lib/shared/models/message.dart`**

```dart
class Message {
  final String id;
  final String? senderId;
  final String? content;
  final String? type;
  final String? createdAt;
  final bool read;

  const Message({
    required this.id,
    this.senderId,
    this.content,
    this.type,
    this.createdAt,
    this.read = false,
  });

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'] as String,
        senderId: json['sender_id'] as String?,
        content: json['content'] as String?,
        type: json['type'] as String?,
        createdAt: json['created_at'] as String?,
        read: json['read'] as bool? ?? false,
      );
}
```

- [ ] **Step 5: Crear `lib/shared/models/justification.dart`**

```dart
class Justification {
  final String id;
  final String? studentId;
  final String? fechaInicio;
  final String? fechaFin;
  final String? motivo;
  final String? archivoUrl;
  final String? status; // 'pendiente' | 'aprobado' | 'rechazado'
  final String? reviewedBy;
  final String? createdAt;

  const Justification({
    required this.id,
    this.studentId,
    this.fechaInicio,
    this.fechaFin,
    this.motivo,
    this.archivoUrl,
    this.status,
    this.reviewedBy,
    this.createdAt,
  });

  factory Justification.fromJson(Map<String, dynamic> json) => Justification(
        id: json['id'] as String,
        studentId: json['student_id'] as String?,
        fechaInicio: json['fecha_inicio'] as String?,
        fechaFin: json['fecha_fin'] as String?,
        motivo: json['motivo'] as String?,
        archivoUrl: json['archivo_url'] as String?,
        status: json['status'] as String?,
        reviewedBy: json['reviewed_by'] as String?,
        createdAt: json['created_at'] as String?,
      );
}
```

- [ ] **Step 6: Crear `lib/shared/models/event.dart`**

```dart
class Event {
  final String id;
  final String? titulo;
  final String? descripcion;
  final String? tipo; // 'academico' | 'cultural' | 'deportivo' | 'administrativo'
  final String? fechaInicio;
  final String? fechaFin;

  const Event({
    required this.id,
    this.titulo,
    this.descripcion,
    this.tipo,
    this.fechaInicio,
    this.fechaFin,
  });

  factory Event.fromJson(Map<String, dynamic> json) => Event(
        id: json['id'] as String,
        titulo: json['titulo'] as String?,
        descripcion: json['descripcion'] as String?,
        tipo: json['tipo'] as String?,
        fechaInicio: json['fecha_inicio'] as String?,
        fechaFin: json['fecha_fin'] as String?,
      );
}
```

- [ ] **Step 7: Commit**

```bash
cd /home/miguel/Documents/github/SAS-school/.worktrees/flutter-phase2
git add mobile/pubspec.yaml mobile/pubspec.lock mobile/lib/shared/models/
git commit -m "feat: add Flutter Phase 2 dependencies and shared DTOs"
```

---

### Task 3: Messaging provider + pantallas

**Files:**
- Create: `mobile/lib/features/messaging/messaging_provider.dart`
- Create: `mobile/lib/features/messaging/inbox_screen.dart`
- Create: `mobile/lib/features/messaging/send_message_screen.dart`

- [ ] **Step 1: Crear `lib/features/messaging/messaging_provider.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../shared/models/message.dart';
import '../../shared/models/user_summary.dart';

final inboxProvider = FutureProvider<List<Message>>((ref) async {
  final dio = ref.read(apiClientProvider);
  final resp = await dio.get('/api/v1/messages/inbox');
  return (resp.data['data'] as List)
      .map((j) => Message.fromJson(j as Map<String, dynamic>))
      .toList();
});

final sentProvider = FutureProvider<List<Message>>((ref) async {
  final dio = ref.read(apiClientProvider);
  final resp = await dio.get('/api/v1/messages/sent');
  return (resp.data['data'] as List)
      .map((j) => Message.fromJson(j as Map<String, dynamic>))
      .toList();
});

final usersProvider = FutureProvider.family<List<UserSummary>, String?>(
    (ref, role) async {
  final dio = ref.read(apiClientProvider);
  final resp = await dio.get(
    '/api/v1/users/',
    queryParameters: role != null ? {'role': role} : null,
  );
  return (resp.data['data'] as List)
      .map((j) => UserSummary.fromJson(j as Map<String, dynamic>))
      .toList();
});

final unreadCountProvider = Provider<int>((ref) {
  final inbox = ref.watch(inboxProvider);
  return inbox.valueOrNull?.where((m) => !m.read).length ?? 0;
});
```

- [ ] **Step 2: Crear `lib/features/messaging/inbox_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/models/message.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../../shared/widgets/error_view.dart';
import 'messaging_provider.dart';

class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inboxAsync = ref.watch(inboxProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mensajes'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Recibidos'),
              Tab(text: 'Enviados'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Nuevo mensaje',
              onPressed: () => context.push('/messages/new'),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            inboxAsync.when(
              loading: () => const LoadingIndicator(),
              error: (e, _) => ErrorView(
                message: '$e',
                onRetry: () => ref.invalidate(inboxProvider),
              ),
              data: (messages) => _MessageList(
                messages: messages,
                onTap: (m) async {
                  final dio = ref.read(
                    // mark as read then refresh
                    inboxProvider.notifier,
                  );
                  // fire-and-forget mark as read
                  ref.read(apiClientProvider).post(
                    '/api/v1/messages/${m.id}/read',
                  ).then((_) => ref.invalidate(inboxProvider)).ignore();
                  _showMessageDialog(context, m);
                },
              ),
            ),
            Consumer(builder: (ctx, ref2, _) {
              final sentAsync = ref2.watch(sentProvider);
              return sentAsync.when(
                loading: () => const LoadingIndicator(),
                error: (e, _) => ErrorView(message: '$e', onRetry: () => ref2.invalidate(sentProvider)),
                data: (messages) => _MessageList(messages: messages, onTap: (m) => _showMessageDialog(context, m)),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showMessageDialog(BuildContext context, Message m) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(_typeLabel(m.type)),
        content: Text(m.content ?? ''),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  String _typeLabel(String? type) {
    switch (type) {
      case 'directo': return 'Mensaje directo';
      case 'grupo': return 'Mensaje de grupo';
      case 'sistema': return 'Mensaje del sistema';
      default: return 'Mensaje';
    }
  }
}

class _MessageList extends StatelessWidget {
  final List<Message> messages;
  final void Function(Message) onTap;
  const _MessageList({required this.messages, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const Center(child: Text('Sin mensajes'));
    }
    return ListView.separated(
      itemCount: messages.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final m = messages[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: m.read
                ? Colors.grey.shade300
                : const Color(0xFF1976D2),
            child: Icon(
              Icons.mail_outline,
              color: m.read ? Colors.grey : Colors.white,
              size: 20,
            ),
          ),
          title: Text(
            m.content ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: m.read ? FontWeight.normal : FontWeight.bold,
            ),
          ),
          subtitle: Text(m.createdAt?.substring(0, 10) ?? ''),
          onTap: () => onTap(m),
        );
      },
    );
  }
}
```

- [ ] **Step 3: Crear `lib/features/messaging/send_message_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/models/user_summary.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../../core/api/api_client.dart';
import 'messaging_provider.dart';

class SendMessageScreen extends ConsumerStatefulWidget {
  const SendMessageScreen({super.key});

  @override
  ConsumerState<SendMessageScreen> createState() => _SendMessageScreenState();
}

class _SendMessageScreenState extends ConsumerState<SendMessageScreen> {
  final _contentCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  String _selectedType = 'directo';
  final List<UserSummary> _recipients = [];
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _contentCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersProvider(null));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo mensaje'),
        actions: [
          TextButton(
            onPressed: _sending ? null : _send,
            child: _sending
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Enviar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Type selector
          DropdownButtonFormField<String>(
            value: _selectedType,
            decoration: const InputDecoration(
              labelText: 'Tipo',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'directo', child: Text('Directo')),
              DropdownMenuItem(value: 'grupo', child: Text('Grupo')),
            ],
            onChanged: (v) => setState(() => _selectedType = v ?? 'directo'),
          ),
          const SizedBox(height: 16),
          // Recipient search
          usersAsync.when(
            loading: () => const LoadingIndicator(),
            error: (e, _) => Text('Error cargando usuarios: $e',
                style: const TextStyle(color: Colors.red)),
            data: (users) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Destinatarios',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Autocomplete<UserSummary>(
                  displayStringForOption: (u) => u.nombreCompleto,
                  optionsBuilder: (v) {
                    if (v.text.isEmpty) return const [];
                    final q = v.text.toLowerCase();
                    return users.where((u) =>
                        u.nombreCompleto.toLowerCase().contains(q));
                  },
                  onSelected: (u) {
                    if (!_recipients.any((r) => r.id == u.id)) {
                      setState(() => _recipients.add(u));
                    }
                  },
                  fieldViewBuilder: (ctx, ctrl, focusNode, onSubmit) =>
                      TextField(
                    controller: ctrl,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      hintText: 'Buscar usuario...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _recipients
                      .map((u) => Chip(
                            label: Text(u.nombreCompleto),
                            onDeleted: () =>
                                setState(() => _recipients.removeWhere(
                                    (r) => r.id == u.id)),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Message body
          TextField(
            controller: _contentCtrl,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Mensaje',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
    );
  }

  Future<void> _send() async {
    if (_contentCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Escribe un mensaje');
      return;
    }
    if (_recipients.isEmpty) {
      setState(() => _error = 'Selecciona al menos un destinatario');
      return;
    }
    setState(() { _sending = true; _error = null; });
    try {
      await ref.read(apiClientProvider).post('/api/v1/messages/', data: {
        'content': _contentCtrl.text.trim(),
        'type': _selectedType,
        'recipient_ids': _recipients.map((u) => u.id).toList(),
      });
      ref.invalidate(inboxProvider);
      ref.invalidate(sentProvider);
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _error = 'Error al enviar: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}
```

- [ ] **Step 4: Commit**

```bash
cd /home/miguel/Documents/github/SAS-school/.worktrees/flutter-phase2
git add mobile/lib/features/messaging/
git commit -m "feat: add messaging inbox and send message screens"
```

---

### Task 4: Justifications provider + pantallas

**Files:**
- Create: `mobile/lib/features/justifications/justifications_provider.dart`
- Create: `mobile/lib/features/justifications/justification_list_screen.dart`
- Create: `mobile/lib/features/justifications/submit_justification_screen.dart`

- [ ] **Step 1: Crear `lib/features/justifications/justifications_provider.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_notifier.dart';
import '../../core/auth/auth_state.dart';
import '../../shared/models/justification.dart';
import '../../shared/models/student.dart';

// For padre/alumno: their linked students
final myStudentsProvider = FutureProvider<List<Student>>((ref) async {
  final dio = ref.read(apiClientProvider);
  final resp = await dio.get('/api/v1/students/my');
  return (resp.data['data'] as List)
      .map((j) => Student.fromJson(j as Map<String, dynamic>))
      .toList();
});

// Justifications visible to current user (role-aware)
final justificationsProvider = FutureProvider<List<Justification>>((ref) async {
  final authAsync = ref.watch(authNotifierProvider);
  final auth = authAsync.valueOrNull;
  if (auth is! AuthAuthenticated) return [];

  final dio = ref.read(apiClientProvider);
  final endpoint = (auth.primaryRole == 'padre' || auth.primaryRole == 'alumno')
      ? '/api/v1/justifications/my'
      : '/api/v1/justifications/';

  final resp = await dio.get(endpoint);
  return (resp.data['data'] as List)
      .map((j) => Justification.fromJson(j as Map<String, dynamic>))
      .toList();
});
```

- [ ] **Step 2: Crear `lib/features/justifications/justification_list_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_notifier.dart';
import '../../core/auth/auth_state.dart';
import '../../shared/models/justification.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../../shared/widgets/error_view.dart';
import 'justifications_provider.dart';

class JustificationListScreen extends ConsumerWidget {
  const JustificationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authNotifierProvider);
    final justificationsAsync = ref.watch(justificationsProvider);
    final auth = authAsync.valueOrNull;
    final isPadrOrAlumno = auth is AuthAuthenticated &&
        (auth.primaryRole == 'padre' || auth.primaryRole == 'alumno');

    return Scaffold(
      appBar: AppBar(title: const Text('Justificantes')),
      floatingActionButton: isPadrOrAlumno
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Subir'),
              onPressed: () => context.push('/justifications/new'),
            )
          : null,
      body: justificationsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(justificationsProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('Sin justificantes'));
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => _JustificationTile(j: list[i], ref: ref),
          );
        },
      ),
    );
  }
}

class _JustificationTile extends ConsumerWidget {
  final Justification j;
  final WidgetRef ref;
  const _JustificationTile({required this.j, required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = _statusColor(j.status);
    final authAsync = ref.watch(authNotifierProvider);
    final auth = authAsync.valueOrNull;
    final canReview = auth is AuthAuthenticated &&
        (auth.primaryRole == 'control_escolar' ||
            auth.primaryRole == 'directivo');

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: statusColor.withOpacity(0.15),
        child: Icon(_statusIcon(j.status), color: statusColor, size: 20),
      ),
      title: Text(j.motivo ?? 'Sin motivo'),
      subtitle: Text('${j.fechaInicio ?? ''} — ${j.fechaFin ?? 'misma fecha'}'),
      trailing: canReview && j.status == 'pendiente'
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                  tooltip: 'Aprobar',
                  onPressed: () => _review(context, ref, 'aprobado'),
                ),
                IconButton(
                  icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                  tooltip: 'Rechazar',
                  onPressed: () => _review(context, ref, 'rechazado'),
                ),
              ],
            )
          : Chip(
              label: Text(j.status ?? 'pendiente'),
              backgroundColor: statusColor.withOpacity(0.15),
              labelStyle: TextStyle(color: statusColor, fontSize: 12),
            ),
    );
  }

  Future<void> _review(
      BuildContext context, WidgetRef ref, String status) async {
    try {
      await ref.read(apiClientProvider).patch(
        '/api/v1/justifications/${j.id}/review',
        data: {'status': status},
      );
      ref.invalidate(justificationsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'aprobado': return Colors.green;
      case 'rechazado': return Colors.red;
      default: return Colors.orange;
    }
  }

  IconData _statusIcon(String? status) {
    switch (status) {
      case 'aprobado': return Icons.check_circle;
      case 'rechazado': return Icons.cancel;
      default: return Icons.hourglass_empty;
    }
  }
}
```

- [ ] **Step 3: Crear `lib/features/justifications/submit_justification_screen.dart`**

```dart
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../shared/widgets/loading_indicator.dart';
import 'justifications_provider.dart';

class SubmitJustificationScreen extends ConsumerStatefulWidget {
  const SubmitJustificationScreen({super.key});

  @override
  ConsumerState<SubmitJustificationScreen> createState() =>
      _SubmitJustificationScreenState();
}

class _SubmitJustificationScreenState
    extends ConsumerState<SubmitJustificationScreen> {
  final _motivoCtrl = TextEditingController();
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  PlatformFile? _pickedFile;
  String? _selectedStudentId;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _motivoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(myStudentsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Subir justificante')),
      body: studentsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (students) => _Form(
          students: students,
          selectedStudentId: _selectedStudentId,
          onStudentChanged: (v) => setState(() => _selectedStudentId = v),
          motivoCtrl: _motivoCtrl,
          fechaInicio: _fechaInicio,
          fechaFin: _fechaFin,
          pickedFile: _pickedFile,
          sending: _sending,
          error: _error,
          onPickFile: _pickFile,
          onPickFechaInicio: () => _pickDate(context, isStart: true),
          onPickFechaFin: () => _pickDate(context, isStart: false),
          onSubmit: _submit,
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result != null) setState(() => _pickedFile = result.files.first);
  }

  Future<void> _pickDate(BuildContext context, {required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart) _fechaInicio = picked;
        else _fechaFin = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (_selectedStudentId == null) {
      setState(() => _error = 'Selecciona un alumno');
      return;
    }
    if (_fechaInicio == null) {
      setState(() => _error = 'Selecciona la fecha de inicio');
      return;
    }
    setState(() { _sending = true; _error = null; });
    try {
      final formData = FormData.fromMap({
        'student_id': _selectedStudentId,
        'fecha_inicio': _fechaInicio!.toIso8601String().substring(0, 10),
        if (_fechaFin != null)
          'fecha_fin': _fechaFin!.toIso8601String().substring(0, 10),
        if (_motivoCtrl.text.isNotEmpty) 'motivo': _motivoCtrl.text.trim(),
        if (_pickedFile != null && _pickedFile!.path != null)
          'file': await MultipartFile.fromFile(
            _pickedFile!.path!,
            filename: _pickedFile!.name,
          ),
      });
      await ref.read(apiClientProvider).post(
        '/api/v1/justifications/',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      ref.invalidate(justificationsProvider);
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _error = 'Error al enviar: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

class _Form extends StatelessWidget {
  final List students;
  final String? selectedStudentId;
  final ValueChanged<String?> onStudentChanged;
  final TextEditingController motivoCtrl;
  final DateTime? fechaInicio;
  final DateTime? fechaFin;
  final PlatformFile? pickedFile;
  final bool sending;
  final String? error;
  final VoidCallback onPickFile;
  final VoidCallback onPickFechaInicio;
  final VoidCallback onPickFechaFin;
  final VoidCallback onSubmit;

  const _Form({
    required this.students,
    required this.selectedStudentId,
    required this.onStudentChanged,
    required this.motivoCtrl,
    required this.fechaInicio,
    required this.fechaFin,
    required this.pickedFile,
    required this.sending,
    required this.error,
    required this.onPickFile,
    required this.onPickFechaInicio,
    required this.onPickFechaFin,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (students.length > 1)
          DropdownButtonFormField<String>(
            value: selectedStudentId,
            decoration: const InputDecoration(
              labelText: 'Alumno',
              border: OutlineInputBorder(),
            ),
            items: students
                .map((s) => DropdownMenuItem<String>(
                      value: s.id,
                      child: Text('${s.nombre ?? ''} ${s.apellidoPaterno ?? ''}'),
                    ))
                .toList(),
            onChanged: onStudentChanged,
          )
        else if (students.isNotEmpty)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Alumno'),
            subtitle: Text(
              '${students.first.nombre ?? ''} ${students.first.apellidoPaterno ?? ''}',
            ),
            onTap: () => onStudentChanged(students.first.id),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: Text(fechaInicio != null
                    ? fechaInicio!.toIso8601String().substring(0, 10)
                    : 'Fecha inicio *'),
                onPressed: onPickFechaInicio,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: Text(fechaFin != null
                    ? fechaFin!.toIso8601String().substring(0, 10)
                    : 'Fecha fin'),
                onPressed: onPickFechaFin,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: motivoCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Motivo (opcional)',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          icon: const Icon(Icons.attach_file),
          label: Text(pickedFile != null ? pickedFile!.name : 'Adjuntar archivo (opcional)'),
          onPressed: onPickFile,
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: sending ? null : onSubmit,
          child: sending
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Enviar justificante'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Commit**

```bash
cd /home/miguel/Documents/github/SAS-school/.worktrees/flutter-phase2
git add mobile/lib/features/justifications/
git commit -m "feat: add justifications list and submit screens"
```

---

### Task 5: Events provider + pantalla

**Files:**
- Create: `mobile/lib/features/events/events_provider.dart`
- Create: `mobile/lib/features/events/events_screen.dart`

- [ ] **Step 1: Crear `lib/features/events/events_provider.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../shared/models/event.dart';

final eventsProvider = FutureProvider<List<Event>>((ref) async {
  final dio = ref.read(apiClientProvider);
  final resp = await dio.get('/api/v1/events/');
  return (resp.data['data'] as List)
      .map((j) => Event.fromJson(j as Map<String, dynamic>))
      .toList();
});
```

- [ ] **Step 2: Crear `lib/features/events/events_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/event.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../../shared/widgets/error_view.dart';
import 'events_provider.dart';

class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Eventos')),
      body: eventsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(eventsProvider),
        ),
        data: (events) {
          if (events.isEmpty) {
            return const Center(child: Text('Sin eventos programados'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: events.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _EventCard(event: events[i]),
          );
        },
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Event event;
  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _tipoColor(event.tipo).withOpacity(0.15),
          child: Icon(_tipoIcon(event.tipo), color: _tipoColor(event.tipo)),
        ),
        title: Text(event.titulo ?? 'Evento',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(event.fechaInicio?.substring(0, 10) ?? ''),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (event.descripcion != null && event.descripcion!.isNotEmpty)
                  Text(event.descripcion!),
                if (event.fechaFin != null) ...[
                  const SizedBox(height: 4),
                  Text('Hasta: ${event.fechaFin!.substring(0, 10)}',
                      style: TextStyle(color: Colors.grey.shade600)),
                ],
                const SizedBox(height: 4),
                Chip(
                  label: Text(event.tipo ?? 'otro'),
                  backgroundColor: _tipoColor(event.tipo).withOpacity(0.1),
                  labelStyle: TextStyle(color: _tipoColor(event.tipo)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _tipoColor(String? tipo) {
    switch (tipo) {
      case 'academico': return Colors.blue;
      case 'cultural': return Colors.purple;
      case 'deportivo': return Colors.green;
      case 'administrativo': return Colors.orange;
      default: return Colors.grey;
    }
  }

  IconData _tipoIcon(String? tipo) {
    switch (tipo) {
      case 'academico': return Icons.school;
      case 'cultural': return Icons.palette;
      case 'deportivo': return Icons.sports;
      case 'administrativo': return Icons.business;
      default: return Icons.event;
    }
  }
}
```

- [ ] **Step 3: Commit**

```bash
cd /home/miguel/Documents/github/SAS-school/.worktrees/flutter-phase2
git add mobile/lib/features/events/
git commit -m "feat: add events list screen"
```

---

### Task 6: Reports screen

**Files:**
- Create: `mobile/lib/features/reports/reports_screen.dart`

- [ ] **Step 1: Crear `lib/features/reports/reports_screen.dart`**

```dart
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file_x/open_file_x.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_notifier.dart';
import '../../core/auth/auth_state.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../justifications/justifications_provider.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authNotifierProvider);
    return authAsync.when(
      loading: () => const Scaffold(body: LoadingIndicator()),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (auth) {
        if (auth is! AuthAuthenticated) return const SizedBox.shrink();
        final isPadrOrAlumno = auth.primaryRole == 'padre' ||
            auth.primaryRole == 'alumno';
        return Scaffold(
          appBar: AppBar(title: const Text('Reportes')),
          body: isPadrOrAlumno
              ? _PdfReportsBody(userId: auth.userId)
              : const Center(child: Text('Reportes — próximamente para directivos')),
        );
      },
    );
  }
}

class _PdfReportsBody extends ConsumerWidget {
  final String userId;
  const _PdfReportsBody({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(myStudentsProvider);
    return studentsAsync.when(
      loading: () => const LoadingIndicator(),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (students) {
        if (students.isEmpty) {
          return const Center(child: Text('No hay alumnos vinculados a tu cuenta'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: students.length,
          itemBuilder: (_, i) {
            final s = students[i];
            final name = '${s.nombre ?? ''} ${s.apellidoPaterno ?? ''}'.trim();
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isNotEmpty ? name : s.matricula,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(s.matricula,
                        style: TextStyle(color: Colors.grey.shade600)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _DownloadButton(
                            key: Key('boleta_${s.id}'),
                            label: 'Boleta',
                            icon: Icons.grade_outlined,
                            studentId: s.id,
                            type: 'boleta',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DownloadButton(
                            key: Key('constancia_${s.id}'),
                            label: 'Constancia',
                            icon: Icons.description_outlined,
                            studentId: s.id,
                            type: 'constancia',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _DownloadButton extends ConsumerStatefulWidget {
  final String label;
  final IconData icon;
  final String studentId;
  final String type; // 'boleta' | 'constancia'

  const _DownloadButton({
    super.key,
    required this.label,
    required this.icon,
    required this.studentId,
    required this.type,
  });

  @override
  ConsumerState<_DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends ConsumerState<_DownloadButton> {
  bool _loading = false;

  Future<void> _download() async {
    setState(() => _loading = true);
    try {
      final dio = ref.read(apiClientProvider);
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/${widget.type}_${widget.studentId}.pdf';

      await dio.download(
        '/api/v1/reports/students/${widget.studentId}/${widget.type}',
        path,
        options: Options(responseType: ResponseType.bytes),
      );

      await OpenFile.open(path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al descargar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: _loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(widget.icon),
      label: Text(widget.label),
      onPressed: _loading ? null : _download,
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
cd /home/miguel/Documents/github/SAS-school/.worktrees/flutter-phase2
git add mobile/lib/features/reports/
git commit -m "feat: add reports screen with boleta/constancia PDF download"
```

---

### Task 7: Router + AppShell — nuevas rutas y tabs

**Files:**
- Modify: `mobile/lib/core/router/router.dart`
- Modify: `mobile/lib/features/dashboard/app_shell.dart`

- [ ] **Step 1: Actualizar `lib/core/router/router.dart`**

Añadir imports de las nuevas pantallas al inicio del archivo (después de los imports existentes):

```dart
import '../../features/messaging/inbox_screen.dart';
import '../../features/messaging/send_message_screen.dart';
import '../../features/justifications/justification_list_screen.dart';
import '../../features/justifications/submit_justification_screen.dart';
import '../../features/events/events_screen.dart';
import '../../features/reports/reports_screen.dart';
```

Dentro del `ShellRoute routes: [...]`, reemplazar las rutas `/reports` y `/events` (que estaban como `_ComingSoon`) con las nuevas pantallas, y añadir las rutas de mensajería y justificantes. El bloque de rutas dentro de `ShellRoute` debe quedar así:

```dart
routes: [
  GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
  GoRoute(
    path: '/attendance',
    builder: (_, __) => const AttendanceIndexScreen(),
  ),
  GoRoute(
    path: '/attendance/take/:groupId',
    builder: (_, s) =>
        TakeAttendanceScreen(groupId: s.pathParameters['groupId']!),
  ),
  GoRoute(
    path: '/grades',
    builder: (_, __) => const GradesIndexScreen(),
  ),
  GoRoute(
    path: '/grades/capture/:evaluationId',
    builder: (_, s) => CaptureGradesScreen(
        evaluationId: s.pathParameters['evaluationId']!),
  ),
  GoRoute(
    path: '/grades/view/:studentId',
    builder: (_, s) =>
        ViewGradesScreen(studentId: s.pathParameters['studentId']!),
  ),
  GoRoute(
    path: '/messages',
    builder: (_, __) => const InboxScreen(),
  ),
  GoRoute(
    path: '/messages/new',
    builder: (_, __) => const SendMessageScreen(),
  ),
  GoRoute(
    path: '/justifications',
    builder: (_, __) => const JustificationListScreen(),
  ),
  GoRoute(
    path: '/justifications/new',
    builder: (_, __) => const SubmitJustificationScreen(),
  ),
  GoRoute(
    path: '/events',
    builder: (_, __) => const EventsScreen(),
  ),
  GoRoute(
    path: '/reports',
    builder: (_, __) => const ReportsScreen(),
  ),
  GoRoute(
    path: '/students',
    builder: (_, __) => const _ComingSoon(label: 'Alumnos'),
  ),
  GoRoute(
    path: '/groups',
    builder: (_, __) => const _ComingSoon(label: 'Grupos'),
  ),
  GoRoute(
    path: '/imports',
    builder: (_, __) => const _ComingSoon(label: 'Importar'),
  ),
],
```

- [ ] **Step 2: Actualizar `lib/features/dashboard/app_shell.dart` — añadir tab Mensajes**

En el método `_tabsForRole`, añadir `_Tab('/messages', 'Mensajes', Icons.mail_outlined)` a todos los roles y también añadir tab de Eventos y Justificantes donde corresponde:

```dart
List<_Tab> _tabsForRole(String role) {
  switch (role) {
    case 'docente':
      return [
        _Tab('/home', 'Inicio', Icons.home_outlined),
        _Tab('/attendance', 'Asistencia', Icons.checklist_outlined),
        _Tab('/grades', 'Calificaciones', Icons.grade_outlined),
        _Tab('/justifications', 'Justificantes', Icons.assignment_outlined),
        _Tab('/messages', 'Mensajes', Icons.mail_outlined),
      ];
    case 'padre':
      return [
        _Tab('/home', 'Inicio', Icons.home_outlined),
        _Tab('/attendance', 'Asistencia', Icons.checklist_outlined),
        _Tab('/grades', 'Calificaciones', Icons.grade_outlined),
        _Tab('/justifications', 'Justificantes', Icons.assignment_outlined),
        _Tab('/messages', 'Mensajes', Icons.mail_outlined),
      ];
    case 'alumno':
      return [
        _Tab('/home', 'Inicio', Icons.home_outlined),
        _Tab('/attendance', 'Mi Asistencia', Icons.checklist_outlined),
        _Tab('/grades', 'Mis Calificaciones', Icons.grade_outlined),
        _Tab('/reports', 'Reportes', Icons.picture_as_pdf_outlined),
        _Tab('/messages', 'Mensajes', Icons.mail_outlined),
      ];
    case 'directivo':
      return [
        _Tab('/home', 'Inicio', Icons.home_outlined),
        _Tab('/events', 'Eventos', Icons.event_outlined),
        _Tab('/justifications', 'Justificantes', Icons.assignment_outlined),
        _Tab('/reports', 'Reportes', Icons.picture_as_pdf_outlined),
        _Tab('/messages', 'Mensajes', Icons.mail_outlined),
      ];
    case 'control_escolar':
      return [
        _Tab('/home', 'Inicio', Icons.home_outlined),
        _Tab('/students', 'Alumnos', Icons.people_outlined),
        _Tab('/justifications', 'Justificantes', Icons.assignment_outlined),
        _Tab('/imports', 'Importar', Icons.upload_file_outlined),
        _Tab('/messages', 'Mensajes', Icons.mail_outlined),
      ];
    default:
      return [_Tab('/home', 'Inicio', Icons.home_outlined)];
  }
}
```

- [ ] **Step 3: Verificar que `flutter analyze` no reporta errores**

```bash
cd /home/miguel/Documents/github/SAS-school/.worktrees/flutter-phase2/mobile
flutter analyze 2>&1 | grep "error •" | head -10
```

Expected: sin errores (sólo info/warnings son OK).

- [ ] **Step 4: Commit**

```bash
cd /home/miguel/Documents/github/SAS-school/.worktrees/flutter-phase2
git add mobile/lib/core/router/router.dart \
        mobile/lib/features/dashboard/app_shell.dart
git commit -m "feat: add Phase 2 routes and update bottom nav for all roles"
```

---

### Task 8: Widget tests

**Files:**
- Create: `mobile/test/widget/messaging_test.dart`
- Create: `mobile/test/widget/reports_test.dart`

- [ ] **Step 1: Crear `test/widget/messaging_test.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sige_mx/features/messaging/inbox_screen.dart';
import 'package:sige_mx/features/messaging/messaging_provider.dart';
import 'package:sige_mx/shared/models/message.dart';

void main() {
  testWidgets('inbox shows empty state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inboxProvider.overrideWith((_) => Future.value(<Message>[])),
          sentProvider.overrideWith((_) => Future.value(<Message>[])),
        ],
        child: const MaterialApp(home: InboxScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sin mensajes'), findsWidgets);
  });

  testWidgets('inbox shows unread message in bold', (tester) async {
    final msgs = [
      Message(id: 'm1', content: 'Hola mundo', createdAt: '2026-04-03', read: false),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inboxProvider.overrideWith((_) => Future.value(msgs)),
          sentProvider.overrideWith((_) => Future.value(<Message>[])),
        ],
        child: const MaterialApp(home: InboxScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hola mundo'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Crear `test/widget/reports_test.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sige_mx/core/auth/auth_notifier.dart';
import 'package:sige_mx/core/auth/auth_state.dart';
import 'package:sige_mx/features/justifications/justifications_provider.dart';
import 'package:sige_mx/features/reports/reports_screen.dart';
import 'package:sige_mx/shared/models/student.dart';

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthAuthenticated(
        userId: 'u1',
        roles: ['padre'],
        primaryRole: 'padre',
      );
}

void main() {
  testWidgets('reports screen shows boleta and constancia buttons', (tester) async {
    final fakeStudents = [
      Student(
          id: 's1',
          matricula: 'A001',
          nombre: 'Laura',
          apellidoPaterno: 'García'),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),
          myStudentsProvider.overrideWith((_) => Future.value(fakeStudents)),
        ],
        child: const MaterialApp(home: ReportsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('boleta_s1')), findsOneWidget);
    expect(find.byKey(const Key('constancia_s1')), findsOneWidget);
  });
}
```

- [ ] **Step 3: Ejecutar todos los tests**

```bash
cd /home/miguel/Documents/github/SAS-school/.worktrees/flutter-phase2/mobile
flutter test test/ -v 2>&1 | tail -15
```

Expected: todos los tests pasan (7 existentes + 3 nuevos = 10 total, aunque el take_attendance podría necesitar ajuste si la apertura de Hive falla — en ese caso ver el error y resolverlo).

- [ ] **Step 4: Commit**

```bash
cd /home/miguel/Documents/github/SAS-school/.worktrees/flutter-phase2
git add mobile/test/widget/messaging_test.dart \
        mobile/test/widget/reports_test.dart
git commit -m "test: add messaging and reports widget tests"
```

---

## Self-Review Checklist

- [ ] `docker exec ... pytest tests/ -q` — todos los tests backend pasan
- [ ] `flutter test test/ -v` — todos los tests Flutter pasan
- [ ] `flutter analyze` — sin errores
- [ ] `GET /api/v1/students/my` — retorna alumno vinculado al user
- [ ] `GET /api/v1/users/?role=docente` — retorna sólo docentes
- [ ] `GET /api/v1/justifications/my` — retorna sólo justificantes propios
- [ ] Tab "Mensajes" visible en BottomNav de todos los roles
- [ ] Tab "Reportes" visible en alumno/padre; botones Boleta y Constancia con Keys correctos
- [ ] Pantalla de justificantes muestra botones Aprobar/Rechazar sólo a control_escolar/directivo
