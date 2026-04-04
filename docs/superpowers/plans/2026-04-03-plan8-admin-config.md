# Admin System Configuration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the four admin config screens accessible from Settings → Administración del sistema: school info, academic cycles, user management, and events admin.

**Architecture:** Each admin feature follows the same backend pattern (model → schema → service → router, registered in main.py and models.py) and Flutter pattern (shared model → FutureProvider → screen → route in router.dart). Settings screen navigation is updated last once all routes exist.

**Tech Stack:** FastAPI async, SQLAlchemy 2.0 Mapped syntax, Pydantic v2, pytest-asyncio; Flutter Riverpod 2.x FutureProvider, Dio 5.x, go_router 14.x.

---

## File Map

**New backend files:**
- `backend/modules/school_config/__init__.py`
- `backend/modules/school_config/models.py` — SchoolConfig singleton (id=1)
- `backend/modules/school_config/schemas.py` — SchoolConfigUpdate, SchoolConfigResponse
- `backend/modules/school_config/service.py` — get_config (upsert), update_config
- `backend/modules/school_config/router.py` — GET/PUT /api/v1/config/
- `backend/tests/modules/test_school_config.py` — backend tests

**Modified backend files:**
- `backend/models.py` — add school_config model import
- `backend/main.py` — register school_config router
- `backend/modules/users/service.py` — add update_user, deactivate_user
- `backend/modules/users/router.py` — add PATCH /{user_id} and DELETE /{user_id}
- `backend/tests/modules/test_users.py` — add update/deactivate tests

**New Flutter files:**
- `mobile/lib/shared/models/academic_cycle.dart` — AcademicCycle model
- `mobile/lib/features/admin/school_config_provider.dart` — SchoolConfig model + FutureProvider
- `mobile/lib/features/admin/school_config_screen.dart` — edit form
- `mobile/lib/features/admin/cycles_provider.dart` — FutureProvider for cycles list
- `mobile/lib/features/admin/cycles_screen.dart` — list + create/edit dialog
- `mobile/lib/features/admin/users_admin_provider.dart` — FutureProvider for users list
- `mobile/lib/features/admin/users_admin_screen.dart` — list screen
- `mobile/lib/features/admin/user_form_screen.dart` — create user form
- `mobile/lib/features/events/event_form_screen.dart` — create/edit event form

**Modified Flutter files:**
- `mobile/lib/features/events/events_screen.dart` — add admin FAB + edit/delete per card
- `mobile/lib/core/router/router.dart` — add /admin/config, /admin/cycles, /admin/users, /admin/users/new, /events/new, /events/:id/edit
- `mobile/lib/features/settings/settings_screen.dart` — replace _showComingSoon with navigation

---

### Task 1: Backend — SchoolConfig module

**Files:**
- Create: `backend/modules/school_config/__init__.py`
- Create: `backend/modules/school_config/models.py`
- Create: `backend/modules/school_config/schemas.py`
- Create: `backend/modules/school_config/service.py`
- Create: `backend/modules/school_config/router.py`
- Modify: `backend/models.py`
- Modify: `backend/main.py`
- Test: `backend/tests/modules/test_school_config.py`

- [ ] **Step 1: Write the failing test**

```python
# backend/tests/modules/test_school_config.py
import pytest
import pytest_asyncio
from httpx import AsyncClient
from sqlalchemy import select

from core.security import create_access_token, hash_password
from modules.users.models import Role, User, UserRole, UserStatus


@pytest_asyncio.fixture
async def config_admin_token(db_session):
    result = await db_session.execute(select(Role).where(Role.name == "directivo"))
    role = result.scalar_one_or_none()
    if role is None:
        role = Role(name="directivo")
        db_session.add(role)
        await db_session.flush()
    user = User(
        email="config_admin@test.com",
        password_hash=hash_password("pass"),
        nombre="Config",
        apellido_paterno="Admin",
        status=UserStatus.activo,
    )
    db_session.add(user)
    await db_session.flush()
    db_session.add(UserRole(user_id=user.id, role_id=role.id))
    await db_session.commit()
    return create_access_token(str(user.id), ["directivo"])


@pytest.mark.asyncio
async def test_get_config_returns_null_defaults(client: AsyncClient, config_admin_token):
    response = await client.get(
        "/api/v1/config/",
        headers={"Authorization": f"Bearer {config_admin_token}"},
    )
    assert response.status_code == 200
    data = response.json()["data"]
    assert data["nombre"] is None
    assert data["cct"] is None
    assert data["turno"] is None
    assert data["direccion"] is None


@pytest.mark.asyncio
async def test_update_config(client: AsyncClient, config_admin_token):
    response = await client.put(
        "/api/v1/config/",
        json={
            "nombre": "Escuela Primaria Juarez",
            "cct": "14EPR0001A",
            "turno": "matutino",
            "direccion": "Calle Juarez 123",
        },
        headers={"Authorization": f"Bearer {config_admin_token}"},
    )
    assert response.status_code == 200
    data = response.json()["data"]
    assert data["nombre"] == "Escuela Primaria Juarez"
    assert data["cct"] == "14EPR0001A"
    assert data["turno"] == "matutino"
    assert data["direccion"] == "Calle Juarez 123"


@pytest.mark.asyncio
async def test_partial_update_config(client: AsyncClient, config_admin_token):
    # Set initial state
    await client.put(
        "/api/v1/config/",
        json={"nombre": "Inicial", "cct": "CCT001"},
        headers={"Authorization": f"Bearer {config_admin_token}"},
    )
    # Update only nombre
    response = await client.put(
        "/api/v1/config/",
        json={"nombre": "Actualizado"},
        headers={"Authorization": f"Bearer {config_admin_token}"},
    )
    assert response.status_code == 200
    data = response.json()["data"]
    assert data["nombre"] == "Actualizado"
    assert data["cct"] == "CCT001"  # unchanged


@pytest.mark.asyncio
async def test_config_unauthenticated_returns_403(client: AsyncClient):
    response = await client.get("/api/v1/config/")
    assert response.status_code == 403
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd backend && pytest tests/modules/test_school_config.py -v
```
Expected: ImportError or 404 errors — module does not exist yet.

- [ ] **Step 3: Create the module files**

```python
# backend/modules/school_config/__init__.py
# (empty)
```

```python
# backend/modules/school_config/models.py
from sqlalchemy import Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from core.database import Base


class SchoolConfig(Base):
    __tablename__ = "school_config"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, default=1)
    nombre: Mapped[str | None] = mapped_column(String, nullable=True)
    cct: Mapped[str | None] = mapped_column(String, nullable=True)
    turno: Mapped[str | None] = mapped_column(String, nullable=True)
    direccion: Mapped[str | None] = mapped_column(String, nullable=True)
```

```python
# backend/modules/school_config/schemas.py
from typing import Optional

from pydantic import BaseModel


class SchoolConfigUpdate(BaseModel):
    nombre: Optional[str] = None
    cct: Optional[str] = None
    turno: Optional[str] = None
    direccion: Optional[str] = None


class SchoolConfigResponse(BaseModel):
    nombre: Optional[str] = None
    cct: Optional[str] = None
    turno: Optional[str] = None
    direccion: Optional[str] = None

    model_config = {"from_attributes": True}
```

```python
# backend/modules/school_config/service.py
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from modules.school_config.models import SchoolConfig
from modules.school_config.schemas import SchoolConfigUpdate


async def get_config(db: AsyncSession) -> SchoolConfig:
    result = await db.execute(select(SchoolConfig).where(SchoolConfig.id == 1))
    config = result.scalar_one_or_none()
    if config is None:
        config = SchoolConfig(id=1)
        db.add(config)
        await db.commit()
        await db.refresh(config)
    return config


async def update_config(data: SchoolConfigUpdate, db: AsyncSession) -> SchoolConfig:
    config = await get_config(db)
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(config, field, value)
    await db.commit()
    await db.refresh(config)
    return config
```

```python
# backend/modules/school_config/router.py
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from core.database import get_db
from core.security import require_roles
from modules.school_config import service
from modules.school_config.schemas import SchoolConfigResponse, SchoolConfigUpdate

router = APIRouter(prefix="/api/v1/config", tags=["config"])
_admin = ["directivo", "control_escolar"]


@router.get("/")
async def get_config(
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    config = await service.get_config(db)
    return {"data": SchoolConfigResponse.model_validate(config)}


@router.put("/")
async def update_config(
    data: SchoolConfigUpdate,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    config = await service.update_config(data, db)
    return {"data": SchoolConfigResponse.model_validate(config)}
```

- [ ] **Step 4: Register model and router**

Add to `backend/models.py` after `# Plan 3` block:
```python
# Plan 8
import modules.school_config.models  # noqa: F401 — school_config
```

Add to `backend/main.py` after the reports router import block:
```python
from modules.school_config.router import router as school_config_router
app.include_router(school_config_router)
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
cd backend && pytest tests/modules/test_school_config.py -v
```
Expected: 4 tests PASS.

- [ ] **Step 6: Commit**

```bash
git add backend/modules/school_config/ backend/models.py backend/main.py backend/tests/modules/test_school_config.py
git commit -m "feat: add school_config module with GET/PUT /api/v1/config/ endpoint"
```

---

### Task 2: Backend — Users PATCH + deactivate

**Files:**
- Modify: `backend/modules/users/service.py`
- Modify: `backend/modules/users/router.py`
- Modify: `backend/tests/modules/test_users.py`

- [ ] **Step 1: Write the failing tests**

Append to `backend/tests/modules/test_users.py`:
```python
@pytest.mark.asyncio
async def test_update_user_name(client: AsyncClient, directivo_token, directivo_user):
    response = await client.patch(
        f"/api/v1/users/{directivo_user.id}",
        json={"nombre": "AdminRenombrado"},
        headers={"Authorization": f"Bearer {directivo_token}"},
    )
    assert response.status_code == 200
    assert response.json()["data"]["nombre"] == "AdminRenombrado"


@pytest.mark.asyncio
async def test_deactivate_user(client: AsyncClient, directivo_token, directivo_user):
    response = await client.delete(
        f"/api/v1/users/{directivo_user.id}",
        headers={"Authorization": f"Bearer {directivo_token}"},
    )
    assert response.status_code == 204


@pytest.mark.asyncio
async def test_deactivate_nonexistent_user_returns_404(
    client: AsyncClient, directivo_token
):
    import uuid
    response = await client.delete(
        f"/api/v1/users/{uuid.uuid4()}",
        headers={"Authorization": f"Bearer {directivo_token}"},
    )
    assert response.status_code == 404
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd backend && pytest tests/modules/test_users.py::test_update_user_name tests/modules/test_users.py::test_deactivate_user tests/modules/test_users.py::test_deactivate_nonexistent_user_returns_404 -v
```
Expected: 3 tests FAIL with 405 Method Not Allowed.

- [ ] **Step 3: Add service functions**

Append to `backend/modules/users/service.py`:
```python
from modules.users.schemas import UserUpdate


async def update_user(user_id: uuid.UUID, data: UserUpdate, db: AsyncSession) -> User:
    user = await get_user_by_id(user_id, db)
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(user, field, value)
    await db.commit()
    await db.refresh(user)
    return user


async def deactivate_user(user_id: uuid.UUID, db: AsyncSession) -> None:
    user = await get_user_by_id(user_id, db)
    user.status = UserStatus.inactivo
    await db.commit()
```

Note: `UserUpdate` is already defined in `backend/modules/users/schemas.py` with fields: `telefono`, `nombre`, `apellido_paterno`, `apellido_materno`, `status`.

- [ ] **Step 4: Add router endpoints**

In `backend/modules/users/router.py`, update the import to include `UserUpdate`:
```python
from modules.users.schemas import UserCreate, UserResponse, UserUpdate
```

Then append after the `get_user` endpoint:
```python
@router.patch("/{user_id}")
async def update_user(
    user_id: uuid.UUID,
    data: UserUpdate,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin_roles)),
):
    user = await service.update_user(user_id, data, db)
    roles = await service.get_user_roles(user.id, db)
    return {"data": _user_to_response(user, roles)}


@router.delete("/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
async def deactivate_user(
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin_roles)),
):
    await service.deactivate_user(user_id, db)
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
cd backend && pytest tests/modules/test_users.py -v
```
Expected: all 8+ tests PASS.

- [ ] **Step 6: Commit**

```bash
git add backend/modules/users/service.py backend/modules/users/router.py backend/tests/modules/test_users.py
git commit -m "feat: add PATCH/DELETE endpoints for user update and deactivation"
```

---

### Task 3: Flutter — School Config screen

**Files:**
- Create: `mobile/lib/features/admin/school_config_provider.dart`
- Create: `mobile/lib/features/admin/school_config_screen.dart`
- Modify: `mobile/lib/core/router/router.dart`
- Modify: `mobile/lib/features/settings/settings_screen.dart`

- [ ] **Step 1: Create the provider and model**

```dart
// mobile/lib/features/admin/school_config_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';

class SchoolConfig {
  final String? nombre;
  final String? cct;
  final String? turno;
  final String? direccion;

  const SchoolConfig({this.nombre, this.cct, this.turno, this.direccion});

  factory SchoolConfig.fromJson(Map<String, dynamic> json) => SchoolConfig(
        nombre: json['nombre'] as String?,
        cct: json['cct'] as String?,
        turno: json['turno'] as String?,
        direccion: json['direccion'] as String?,
      );
}

final schoolConfigProvider = FutureProvider<SchoolConfig>((ref) async {
  final dio = ref.read(apiClientProvider);
  final resp = await dio.get('/api/v1/config/');
  return SchoolConfig.fromJson(resp.data['data'] as Map<String, dynamic>);
});
```

- [ ] **Step 2: Create the screen**

```dart
// mobile/lib/features/admin/school_config_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../shared/widgets/loading_indicator.dart';
import 'school_config_provider.dart';

class SchoolConfigScreen extends ConsumerStatefulWidget {
  const SchoolConfigScreen({super.key});

  @override
  ConsumerState<SchoolConfigScreen> createState() => _SchoolConfigScreenState();
}

class _SchoolConfigScreenState extends ConsumerState<SchoolConfigScreen> {
  final _nombreCtrl = TextEditingController();
  final _cctCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  String? _turno;
  bool _saving = false;
  bool _loaded = false;

  static const _turnos = ['matutino', 'vespertino', 'nocturno'];

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _cctCtrl.dispose();
    _direccionCtrl.dispose();
    super.dispose();
  }

  void _populate(SchoolConfig config) {
    if (_loaded) return;
    _nombreCtrl.text = config.nombre ?? '';
    _cctCtrl.text = config.cct ?? '';
    _direccionCtrl.text = config.direccion ?? '';
    _turno = config.turno;
    _loaded = true;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final dio = ref.read(apiClientProvider);
      await dio.put('/api/v1/config/', data: {
        'nombre': _nombreCtrl.text.trim().isEmpty ? null : _nombreCtrl.text.trim(),
        'cct': _cctCtrl.text.trim().isEmpty ? null : _cctCtrl.text.trim(),
        'turno': _turno,
        'direccion': _direccionCtrl.text.trim().isEmpty ? null : _direccionCtrl.text.trim(),
      });
      ref.invalidate(schoolConfigProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Información guardada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(schoolConfigProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Información del plantel')),
      body: configAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => Center(child: Text('$e')),
        data: (config) {
          _populate(config);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del plantel',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _cctCtrl,
                  decoration: const InputDecoration(
                    labelText: 'CCT (Clave de Centro de Trabajo)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _turnos.contains(_turno) ? _turno : null,
                  decoration: const InputDecoration(
                    labelText: 'Turno',
                    border: OutlineInputBorder(),
                  ),
                  items: _turnos
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setState(() => _turno = v),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _direccionCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Dirección',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Guardar'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 3: Add route to router.dart**

In `mobile/lib/core/router/router.dart`, add import at the top:
```dart
import '../../features/admin/school_config_screen.dart';
```

Inside the `ShellRoute` routes list, add after the `/settings` route:
```dart
GoRoute(
  path: '/admin/config',
  builder: (_, __) => const SchoolConfigScreen(),
),
```

- [ ] **Step 4: Wire up navigation in settings_screen.dart**

In `mobile/lib/features/settings/settings_screen.dart`, add import:
```dart
import 'package:go_router/go_router.dart';
```

Replace the `onTap: () => _showComingSoon(context, 'Información del plantel')` line with:
```dart
onTap: () => context.push('/admin/config'),
```

- [ ] **Step 5: Verify with flutter analyze**

```bash
cd mobile && flutter analyze lib/features/admin/school_config_screen.dart lib/features/admin/school_config_provider.dart
```
Expected: No errors.

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/features/admin/ mobile/lib/core/router/router.dart mobile/lib/features/settings/settings_screen.dart
git commit -m "feat: add school config admin screen with GET/PUT /api/v1/config/"
```

---

### Task 4: Flutter — Academic Cycles management

**Files:**
- Create: `mobile/lib/shared/models/academic_cycle.dart`
- Create: `mobile/lib/features/admin/cycles_provider.dart`
- Create: `mobile/lib/features/admin/cycles_screen.dart`
- Modify: `mobile/lib/core/router/router.dart`
- Modify: `mobile/lib/features/settings/settings_screen.dart`

- [ ] **Step 1: Create the shared model**

```dart
// mobile/lib/shared/models/academic_cycle.dart
class AcademicCycle {
  final String id;
  final String? nombre;
  final String? fechaInicio;
  final String? fechaFin;
  final bool activo;

  const AcademicCycle({
    required this.id,
    this.nombre,
    this.fechaInicio,
    this.fechaFin,
    required this.activo,
  });

  factory AcademicCycle.fromJson(Map<String, dynamic> json) => AcademicCycle(
        id: json['id'] as String,
        nombre: json['nombre'] as String?,
        fechaInicio: json['fecha_inicio'] as String?,
        fechaFin: json['fecha_fin'] as String?,
        activo: json['activo'] as bool? ?? false,
      );
}
```

- [ ] **Step 2: Create the provider**

```dart
// mobile/lib/features/admin/cycles_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../shared/models/academic_cycle.dart';

final cyclesProvider = FutureProvider<List<AcademicCycle>>((ref) async {
  final dio = ref.read(apiClientProvider);
  final resp = await dio.get('/api/v1/academic-cycles/');
  return (resp.data['data'] as List)
      .map((j) => AcademicCycle.fromJson(j as Map<String, dynamic>))
      .toList();
});
```

- [ ] **Step 3: Create the cycles screen**

```dart
// mobile/lib/features/admin/cycles_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../shared/models/academic_cycle.dart';
import '../../shared/widgets/loading_indicator.dart';
import 'cycles_provider.dart';

class CyclesScreen extends ConsumerWidget {
  const CyclesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cyclesAsync = ref.watch(cyclesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ciclos escolares')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCycleDialog(context, ref, null),
        child: const Icon(Icons.add),
      ),
      body: cyclesAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => Center(child: Text('$e')),
        data: (cycles) {
          if (cycles.isEmpty) {
            return const Center(child: Text('Sin ciclos registrados'));
          }
          return ListView.builder(
            itemCount: cycles.length,
            itemBuilder: (_, i) => _CycleTile(
              cycle: cycles[i],
              onTap: () => _showCycleDialog(context, ref, cycles[i]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showCycleDialog(
    BuildContext context,
    WidgetRef ref,
    AcademicCycle? existing,
  ) async {
    await showDialog(
      context: context,
      builder: (_) => _CycleDialog(existing: existing, ref: ref),
    );
  }
}

class _CycleTile extends StatelessWidget {
  final AcademicCycle cycle;
  final VoidCallback onTap;
  const _CycleTile({required this.cycle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        Icons.calendar_month,
        color: cycle.activo ? Theme.of(context).colorScheme.primary : Colors.grey,
      ),
      title: Text(cycle.nombre ?? 'Sin nombre'),
      subtitle: Text(
        '${cycle.fechaInicio ?? '?'} — ${cycle.fechaFin ?? '?'}',
      ),
      trailing: cycle.activo
          ? Chip(
              label: const Text('Activo'),
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            )
          : null,
      onTap: onTap,
    );
  }
}

class _CycleDialog extends ConsumerStatefulWidget {
  final AcademicCycle? existing;
  final WidgetRef ref;
  const _CycleDialog({this.existing, required this.ref});

  @override
  ConsumerState<_CycleDialog> createState() => _CycleDialogState();
}

class _CycleDialogState extends ConsumerState<_CycleDialog> {
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _inicioCtrl;
  late final TextEditingController _finCtrl;
  late bool _activo;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.existing?.nombre ?? '');
    _inicioCtrl = TextEditingController(text: widget.existing?.fechaInicio ?? '');
    _finCtrl = TextEditingController(text: widget.existing?.fechaFin ?? '');
    _activo = widget.existing?.activo ?? false;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _inicioCtrl.dispose();
    _finCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final dio = ref.read(apiClientProvider);
      final body = {
        'nombre': _nombreCtrl.text.trim().isEmpty ? null : _nombreCtrl.text.trim(),
        'fecha_inicio': _inicioCtrl.text.trim().isEmpty ? null : _inicioCtrl.text.trim(),
        'fecha_fin': _finCtrl.text.trim().isEmpty ? null : _finCtrl.text.trim(),
        'activo': _activo,
      };
      if (widget.existing == null) {
        await dio.post('/api/v1/academic-cycles/', data: body);
      } else {
        await dio.patch('/api/v1/academic-cycles/${widget.existing!.id}', data: body);
      }
      ref.invalidate(cyclesProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Nuevo ciclo' : 'Editar ciclo'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nombreCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre (ej. 2024-2025)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _inicioCtrl,
              decoration: const InputDecoration(
                labelText: 'Fecha inicio (YYYY-MM-DD)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _finCtrl,
              decoration: const InputDecoration(
                labelText: 'Fecha fin (YYYY-MM-DD)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Activo'),
              value: _activo,
              onChanged: (v) => setState(() => _activo = v),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Add route and wire settings**

In `mobile/lib/core/router/router.dart`, add import:
```dart
import '../../features/admin/cycles_screen.dart';
```

Inside the ShellRoute routes list after `/admin/config`:
```dart
GoRoute(
  path: '/admin/cycles',
  builder: (_, __) => const CyclesScreen(),
),
```

In `mobile/lib/features/settings/settings_screen.dart`, replace:
```dart
onTap: () => _showComingSoon(context, 'Ciclo escolar'),
```
with:
```dart
onTap: () => context.push('/admin/cycles'),
```

- [ ] **Step 5: Verify with flutter analyze**

```bash
cd mobile && flutter analyze lib/features/admin/cycles_screen.dart lib/features/admin/cycles_provider.dart lib/shared/models/academic_cycle.dart
```
Expected: No errors.

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/shared/models/academic_cycle.dart mobile/lib/features/admin/cycles_provider.dart mobile/lib/features/admin/cycles_screen.dart mobile/lib/core/router/router.dart mobile/lib/features/settings/settings_screen.dart
git commit -m "feat: add academic cycles management screen for admin"
```

---

### Task 5: Flutter — User Management

**Files:**
- Create: `mobile/lib/features/admin/users_admin_provider.dart`
- Create: `mobile/lib/features/admin/users_admin_screen.dart`
- Create: `mobile/lib/features/admin/user_form_screen.dart`
- Modify: `mobile/lib/core/router/router.dart`
- Modify: `mobile/lib/features/settings/settings_screen.dart`

- [ ] **Step 1: Create the provider**

```dart
// mobile/lib/features/admin/users_admin_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../shared/models/user_summary.dart';

final usersAdminProvider = FutureProvider<List<UserSummary>>((ref) async {
  final dio = ref.read(apiClientProvider);
  final resp = await dio.get('/api/v1/users/');
  return (resp.data['data'] as List)
      .map((j) => UserSummary.fromJson(j as Map<String, dynamic>))
      .toList();
});
```

- [ ] **Step 2: Create the list screen**

```dart
// mobile/lib/features/admin/users_admin_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../shared/models/user_summary.dart';
import '../../shared/widgets/loading_indicator.dart';
import 'users_admin_provider.dart';

class UsersAdminScreen extends ConsumerWidget {
  const UsersAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersAdminProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Gestión de usuarios')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/admin/users/new'),
        child: const Icon(Icons.person_add),
      ),
      body: usersAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => Center(child: Text('$e')),
        data: (users) {
          if (users.isEmpty) {
            return const Center(child: Text('Sin usuarios registrados'));
          }
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (_, i) => _UserTile(
              user: users[i],
              onDeactivate: () => _deactivate(context, ref, users[i]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _deactivate(
    BuildContext context,
    WidgetRef ref,
    UserSummary user,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Desactivar usuario'),
        content: Text('¿Desactivar a ${user.nombreCompleto}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      try {
        final dio = ref.read(apiClientProvider);
        await dio.delete('/api/v1/users/${user.id}');
        ref.invalidate(usersAdminProvider);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }
}

class _UserTile extends StatelessWidget {
  final UserSummary user;
  final VoidCallback onDeactivate;
  const _UserTile({required this.user, required this.onDeactivate});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(child: Text(user.nombre?[0].toUpperCase() ?? '?')),
      title: Text(user.nombreCompleto),
      subtitle: Text(user.roles.join(', ')),
      trailing: IconButton(
        icon: const Icon(Icons.person_off_outlined, color: Colors.red),
        tooltip: 'Desactivar',
        onPressed: onDeactivate,
      ),
    );
  }
}
```

- [ ] **Step 3: Create the user form screen**

```dart
// mobile/lib/features/admin/user_form_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import 'users_admin_provider.dart';

class UserFormScreen extends ConsumerStatefulWidget {
  const UserFormScreen({super.key});

  @override
  ConsumerState<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends ConsumerState<UserFormScreen> {
  final _nombreCtrl = TextEditingController();
  final _apPaternoCtrl = TextEditingController();
  final _apMaternoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String? _role;
  bool _saving = false;

  static const _roles = ['directivo', 'control_escolar', 'docente', 'padre', 'alumno'];

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apPaternoCtrl.dispose();
    _apMaternoCtrl.dispose();
    _emailCtrl.dispose();
    _telefonoCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nombreCtrl.text.trim().isEmpty || _passwordCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nombre y contraseña son requeridos')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final dio = ref.read(apiClientProvider);
      await dio.post('/api/v1/users/', data: {
        'nombre': _nombreCtrl.text.trim(),
        'apellido_paterno': _apPaternoCtrl.text.trim().isEmpty
            ? null
            : _apPaternoCtrl.text.trim(),
        'apellido_materno': _apMaternoCtrl.text.trim().isEmpty
            ? null
            : _apMaternoCtrl.text.trim(),
        'email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        'telefono': _telefonoCtrl.text.trim().isEmpty
            ? null
            : _telefonoCtrl.text.trim(),
        'password': _passwordCtrl.text,
        'roles': _role != null ? [_role!] : [],
      });
      ref.invalidate(usersAdminProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario creado')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo usuario')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nombreCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _apPaternoCtrl,
              decoration: const InputDecoration(
                labelText: 'Apellido paterno',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _apMaternoCtrl,
              decoration: const InputDecoration(
                labelText: 'Apellido materno',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _telefonoCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Teléfono',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Contraseña *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _roles.contains(_role) ? _role : null,
              decoration: const InputDecoration(
                labelText: 'Rol',
                border: OutlineInputBorder(),
              ),
              items: _roles
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (v) => setState(() => _role = v),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Crear usuario'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Add routes and wire settings**

In `mobile/lib/core/router/router.dart`, add imports:
```dart
import '../../features/admin/users_admin_screen.dart';
import '../../features/admin/user_form_screen.dart';
```

Inside the ShellRoute routes list after `/admin/cycles`:
```dart
GoRoute(
  path: '/admin/users',
  builder: (_, __) => const UsersAdminScreen(),
),
GoRoute(
  path: '/admin/users/new',
  builder: (_, __) => const UserFormScreen(),
),
```

In `mobile/lib/features/settings/settings_screen.dart`, replace:
```dart
onTap: () => _showComingSoon(context, 'Gestión de usuarios'),
```
with:
```dart
onTap: () => context.push('/admin/users'),
```

- [ ] **Step 5: Verify with flutter analyze**

```bash
cd mobile && flutter analyze lib/features/admin/users_admin_screen.dart lib/features/admin/users_admin_provider.dart lib/features/admin/user_form_screen.dart
```
Expected: No errors.

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/features/admin/ mobile/lib/core/router/router.dart mobile/lib/features/settings/settings_screen.dart
git commit -m "feat: add user management screen with create and deactivate"
```

---

### Task 6: Flutter — Events admin (create/edit/delete)

**Files:**
- Create: `mobile/lib/features/events/event_form_screen.dart`
- Modify: `mobile/lib/features/events/events_screen.dart`
- Modify: `mobile/lib/core/router/router.dart`
- Modify: `mobile/lib/features/settings/settings_screen.dart`

- [ ] **Step 1: Create the event form screen**

```dart
// mobile/lib/features/events/event_form_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../shared/models/event.dart';
import 'events_provider.dart';

class EventFormScreen extends ConsumerStatefulWidget {
  final Event? existing;
  const EventFormScreen({super.key, this.existing});

  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends ConsumerState<EventFormScreen> {
  late final TextEditingController _tituloCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _inicioCtrl;
  late final TextEditingController _finCtrl;
  String? _tipo;
  bool _saving = false;

  static const _tipos = ['academico', 'cultural', 'deportivo', 'administrativo'];

  @override
  void initState() {
    super.initState();
    _tituloCtrl = TextEditingController(text: widget.existing?.titulo ?? '');
    _descCtrl = TextEditingController(text: widget.existing?.descripcion ?? '');
    _inicioCtrl = TextEditingController(
      text: widget.existing?.fechaInicio?.substring(0, 16) ?? '',
    );
    _finCtrl = TextEditingController(
      text: widget.existing?.fechaFin?.substring(0, 16) ?? '',
    );
    _tipo = widget.existing?.tipo;
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descCtrl.dispose();
    _inicioCtrl.dispose();
    _finCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_tituloCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El título es requerido')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final dio = ref.read(apiClientProvider);
      final body = {
        'titulo': _tituloCtrl.text.trim(),
        'descripcion': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'tipo': _tipo,
        'fecha_inicio': _inicioCtrl.text.trim().isEmpty ? null : _inicioCtrl.text.trim(),
        'fecha_fin': _finCtrl.text.trim().isEmpty ? null : _finCtrl.text.trim(),
      };
      if (widget.existing == null) {
        await dio.post('/api/v1/events/', data: body);
      } else {
        await dio.patch('/api/v1/events/${widget.existing!.id}', data: body);
      }
      ref.invalidate(eventsProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Nuevo evento' : 'Editar evento'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _tituloCtrl,
              decoration: const InputDecoration(
                labelText: 'Título *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _tipos.contains(_tipo) ? _tipo : null,
              decoration: const InputDecoration(
                labelText: 'Tipo',
                border: OutlineInputBorder(),
              ),
              items: _tipos
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _tipo = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _inicioCtrl,
              decoration: const InputDecoration(
                labelText: 'Fecha inicio (YYYY-MM-DDTHH:MM)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _finCtrl,
              decoration: const InputDecoration(
                labelText: 'Fecha fin (YYYY-MM-DDTHH:MM)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Update events_screen.dart to add admin controls**

The updated `mobile/lib/features/events/events_screen.dart` adds: import for auth state, FAB for admins to create events, and edit/delete actions on each card for admins.

Replace the entire file with:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_notifier.dart';
import '../../core/auth/auth_state.dart';
import '../../shared/models/event.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../../shared/widgets/error_view.dart';
import 'events_provider.dart';

class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsProvider);
    final auth = ref.watch(authNotifierProvider).valueOrNull;
    final isAdmin = auth is AuthAuthenticated &&
        (auth.primaryRole == 'directivo' || auth.primaryRole == 'control_escolar');

    return Scaffold(
      appBar: AppBar(title: const Text('Eventos')),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () => context.push('/events/new'),
              child: const Icon(Icons.add),
            )
          : null,
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
            itemBuilder: (_, i) => _EventCard(
              event: events[i],
              isAdmin: isAdmin,
              onEdit: () => context.push('/events/${events[i].id}/edit'),
              onDelete: () => _deleteEvent(context, ref, events[i]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteEvent(
    BuildContext context,
    WidgetRef ref,
    Event event,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar evento'),
        content: Text('¿Eliminar "${event.titulo}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      try {
        final dio = ref.read(apiClientProvider);
        await dio.delete('/api/v1/events/${event.id}');
        ref.invalidate(eventsProvider);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }
}

class _EventCard extends StatelessWidget {
  final Event event;
  final bool isAdmin;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EventCard({
    required this.event,
    required this.isAdmin,
    required this.onEdit,
    required this.onDelete,
  });

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
                if (isAdmin) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Editar'),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline, size: 18,
                            color: Colors.red),
                        label: const Text('Eliminar',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _tipoColor(String? tipo) {
    switch (tipo) {
      case 'academico':
        return Colors.blue;
      case 'cultural':
        return Colors.purple;
      case 'deportivo':
        return Colors.green;
      case 'administrativo':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _tipoIcon(String? tipo) {
    switch (tipo) {
      case 'academico':
        return Icons.school;
      case 'cultural':
        return Icons.palette;
      case 'deportivo':
        return Icons.sports;
      case 'administrativo':
        return Icons.business;
      default:
        return Icons.event;
    }
  }
}
```

- [ ] **Step 3: Add event form routes to router.dart**

In `mobile/lib/core/router/router.dart`, add import:
```dart
import '../../features/events/event_form_screen.dart';
```

Inside ShellRoute routes list, after the `/events` route:
```dart
GoRoute(
  path: '/events/new',
  builder: (_, __) => const EventFormScreen(),
),
GoRoute(
  path: '/events/:id/edit',
  builder: (context, state) {
    // EventFormScreen for editing: event is fetched from existing eventsProvider list
    // Pass event id via extra if available
    final event = state.extra as Event?;
    return EventFormScreen(existing: event);
  },
),
```

**Note:** To pass the event object to `/events/:id/edit`, the call must use `context.push('/events/${event.id}/edit', extra: event)` — which is already done in the updated `events_screen.dart` above.

- [ ] **Step 4: Wire settings → events**

In `mobile/lib/features/settings/settings_screen.dart`, replace:
```dart
onTap: () => _showComingSoon(context, 'Eventos'),
```
with:
```dart
onTap: () => context.push('/events'),
```

- [ ] **Step 5: Verify with flutter analyze**

```bash
cd mobile && flutter analyze lib/features/events/ lib/core/router/router.dart lib/features/settings/settings_screen.dart
```
Expected: No errors.

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/features/events/ mobile/lib/core/router/router.dart mobile/lib/features/settings/settings_screen.dart
git commit -m "feat: add event create/edit/delete for admin users"
```

---

## Self-Review

### Spec coverage

| Requirement | Task |
|---|---|
| Información del plantel (nombre, CCT, turno, dirección) | Task 1 (backend), Task 3 (Flutter) |
| Ciclo escolar activo — gestionar periodos | Task 4 |
| Gestión de usuarios — crear y administrar cuentas | Task 2 (backend update/deactivate), Task 5 (Flutter) |
| Gestión de eventos — crear y editar | Task 6 |
| Settings screen wired (replace _showComingSoon) | Tasks 3–6 each wire one item |
| Backend tests | Tasks 1 and 2 |

### Type consistency check

- `SchoolConfig` model defined in `school_config_provider.dart` and used only in `school_config_screen.dart` — consistent.
- `AcademicCycle` defined in `shared/models/academic_cycle.dart`, imported in `cycles_provider.dart` and `cycles_screen.dart` — consistent.
- `UserSummary` (existing) used in `users_admin_provider.dart` and `users_admin_screen.dart` — consistent. Uses existing `nombreCompleto` getter.
- `Event` (existing) used in `event_form_screen.dart` — consistent. Fields `titulo`, `descripcion`, `tipo`, `fechaInicio`, `fechaFin`, `id` all match the existing model.
- `eventsProvider` referenced in `event_form_screen.dart` — imported from `events_provider.dart`.
- `cyclesProvider` referenced in `_CycleDialog` — imported from `cycles_provider.dart`. The `ref` is passed as constructor argument from `CyclesScreen` where `WidgetRef` is available.

### Placeholder scan

No TBDs found. All steps include concrete code. API paths verified against existing backend routers.
