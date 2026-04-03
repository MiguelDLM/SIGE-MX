# SIGE-MX — Plan 6 Design: Flutter Phase 1 MVP

**Date:** 2026-04-03
**Status:** Approved
**Fase:** 4 (Flutter Phase 1)

---

## Scope

App Flutter Android para el MVP del sistema escolar. Cubre:

1. **Auth** — login con email/contraseña, refresh automático de token, logout
2. **Shell + navegación** — BottomNavigationBar filtrada por rol, GoRouter con guards
3. **Dashboard** — pantalla de inicio adaptada por rol con resumen de actividad
4. **Asistencia** — tomar lista (docente, con offline Hive), consultar (padre/alumno)
5. **Calificaciones** — capturar (docente), consultar (padre/alumno)

Fuera de scope en este plan: mensajería, justificantes, eventos, reportes PDF, constancias, notificaciones push.

---

## Stack

| Paquete | Versión | Uso |
|---------|---------|-----|
| flutter | 3.x | framework |
| flutter_riverpod | 2.x | estado global y por pantalla |
| go_router | 14.x | navegación declarativa con guards |
| dio | 5.x | cliente HTTP |
| flutter_secure_storage | 9.x | almacenamiento de tokens (Android Keystore) |
| hive_flutter | 1.x | caché offline de asistencia |
| connectivity_plus | 6.x | detección de red para sync |

---

## Estructura de archivos

```
mobile/
├── pubspec.yaml
├── android/
└── lib/
    ├── main.dart
    ├── core/
    │   ├── api/
    │   │   ├── api_client.dart          # Dio singleton + baseUrl
    │   │   └── auth_interceptor.dart    # inyecta Bearer, maneja 401 → refresh
    │   ├── auth/
    │   │   ├── auth_notifier.dart       # AsyncNotifier: login/logout/refresh
    │   │   └── auth_state.dart          # sealed class: loading/authenticated/unauthenticated
    │   ├── router/
    │   │   └── router.dart              # GoRouter + redirect guard
    │   ├── storage/
    │   │   └── secure_storage.dart      # wrapper flutter_secure_storage
    │   └── theme/
    │       └── app_theme.dart           # ThemeData azul #1976D2
    ├── features/
    │   ├── auth/
    │   │   └── login_screen.dart
    │   ├── dashboard/
    │   │   ├── app_shell.dart           # Scaffold + BottomNav por rol
    │   │   └── home_screen.dart         # resumen de actividad por rol
    │   ├── attendance/
    │   │   ├── attendance_provider.dart
    │   │   ├── attendance_sync_service.dart  # Hive → API sync
    │   │   ├── take_attendance_screen.dart   # docente
    │   │   └── view_attendance_screen.dart   # padre/alumno
    │   └── grades/
    │       ├── grades_provider.dart
    │       ├── capture_grades_screen.dart    # docente
    │       └── view_grades_screen.dart       # padre/alumno
    └── shared/
        ├── models/
        │   ├── student.dart
        │   ├── group.dart
        │   ├── evaluation.dart
        │   ├── grade.dart
        │   └── attendance_record.dart
        └── widgets/
            ├── loading_indicator.dart
            └── error_view.dart
```

---

## Architecture

### Capa de datos

**`ApiClient`** — singleton Dio instanciado como `Provider`. `baseUrl` leído de `String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8000')` (emulador Android apunta a localhost del host con `10.0.2.2`).

**`AuthInterceptor`** — `QueuedInterceptorsWrapper`:
- `onRequest`: lee access token de `SecureStorage`, agrega header `Authorization: Bearer <token>`
- `onError`: si status 401 → llama `POST /api/v1/auth/refresh` con refresh token → actualiza tokens → reintenta request original. Si refresh también falla → llama `authNotifier.logout()` → GoRouter redirige a `/login`

**`SecureStorage`** — wrapper sobre `flutter_secure_storage`. Métodos: `saveTokens(access, refresh)`, `getAccessToken()`, `getRefreshToken()`, `clearTokens()`.

### Autenticación

**`AuthState`** (sealed class):
```dart
sealed class AuthState {}
class AuthLoading extends AuthState {}
class AuthAuthenticated extends AuthState {
  final String userId;
  final List<String> roles;
  final String accessToken;
}
class AuthUnauthenticated extends AuthState {}
```

**`AuthNotifier`** (AsyncNotifier):
- `login(email, password)` → `POST /api/v1/auth/login` → guarda tokens → emite `AuthAuthenticated`
- `logout()` → `POST /api/v1/auth/logout` (best-effort) → limpia storage → emite `AuthUnauthenticated`
- `init()` → al arrancar, lee tokens de storage → si existen, intenta refresh → si ok emite `AuthAuthenticated`, si falla emite `AuthUnauthenticated`

### Navegación

**GoRouter** configurado con `refreshListenable` apuntando a un `ValueNotifier<AuthState>` que `AuthNotifier` actualiza en cada cambio de estado. (GoRouter requiere un `Listenable`; `AsyncNotifier` de Riverpod no lo es directamente — se usa un `ValueNotifier` como puente.) Redirect:
- Si `AuthUnauthenticated` y ruta ≠ `/login` → redirige a `/login`
- Si `AuthAuthenticated` y ruta == `/login` → redirige a `/`

Rutas:
```
/login
/                          → AppShell (ShellRoute)
  /home
  /attendance              → lista de grupos (docente) o resumen (padre/alumno)
  /attendance/take/:groupId
  /grades                  → lista de evaluaciones (docente) o materias (padre/alumno)
  /grades/capture/:evaluationId
  /grades/view/:studentId
  /students                → directivo / control_escolar
  /groups                  → directivo
  /reports                 → directivo
  /imports                 → control_escolar
```

### AppShell y tabs por rol

`AppShell` lee el rol desde `authNotifier`. Construye la lista de `BottomNavigationBarItem` filtrando por rol:

| Rol | Items |
|-----|-------|
| `docente` | Inicio · Asistencia · Calificaciones |
| `padre` | Inicio · Asistencia · Calificaciones |
| `alumno` | Inicio · Mi Asistencia · Mis Calificaciones |
| `directivo` | Inicio · Alumnos · Grupos · Reportes |
| `control_escolar` | Inicio · Alumnos · Importar · Constancias |

### Offline — Asistencia

**Hive Box** `attendance_pending` almacena registros de tipo `AttendanceRecord` con campos: `studentId`, `groupId`, `fecha`, `status` (`presente`/`ausente`/`justificado`), `syncState` (`pending`/`synced`).

**`AttendanceSyncService`**:
- Observa `connectivity_plus` stream
- Al detectar conexión: lee todos los registros con `syncState == pending`
- Los envía en batch a `POST /api/v1/attendance/` uno por uno (o en lote si el API lo soporta)
- Si éxito: marca `synced`
- Si falla: deja `pending` para el próximo intento

**Badge visual**: `AppShell` muestra un punto naranja en el tab Asistencia cuando `Box.values.any((r) => r.syncState == 'pending')`.

---

## Endpoints consumidos

### Existentes (sin cambios)

| Feature | Method | Path |
|---------|--------|------|
| Login | POST | `/api/v1/auth/login` |
| Refresh | POST | `/api/v1/auth/refresh` |
| Logout | POST | `/api/v1/auth/logout` |
| Lista todos los grupos | GET | `/api/v1/groups/` |
| Asistencia del grupo por fecha | GET | `/api/v1/attendance/group/{group_id}?fecha=YYYY-MM-DD` |
| Registrar asistencia | POST | `/api/v1/attendance/` |
| Evaluaciones del grupo | GET | `/api/v1/grades/evaluations/?group_id=` |
| Calificaciones alumno | GET | `/api/v1/grades/student/{id}` |
| Capturar calificación | POST | `/api/v1/grades/` |
| Actualizar calificación | PUT | `/api/v1/grades/{id}` |
| Lista alumnos | GET | `/api/v1/students/` |

### Extensiones de backend requeridas (incluidas en Plan 6)

Estos endpoints deben agregarse al backend antes o en paralelo con la app Flutter:

| Feature | Method | Path | Cambio |
|---------|--------|------|--------|
| Grupos del docente | GET | `/api/v1/groups/?teacher_id={uuid}` | Agregar query param `teacher_id` al endpoint existente |
| Alumnos de un grupo | GET | `/api/v1/groups/{id}/students` | Nuevo endpoint GET (el POST ya existe para asignar) |
| Asistencia del alumno (padre/alumno) | GET | `/api/v1/attendance/student/{id}` | Agregar roles `padre` y `alumno` a `_read` |

---

## Visual Theme

- **Primary**: `#1976D2` (Material Blue 700)
- **Surface**: `#FFFFFF`
- **Background**: `#F5F5F5`
- **Error**: `#D32F2F`
- **Typography**: Roboto (default Material)
- **Modo oscuro**: no en Phase 1

---

## Tests (widget tests)

| # | Test | Descripción |
|---|------|-------------|
| 1 | Login exitoso | Mock API devuelve tokens → navega a `/home` |
| 2 | Login fallido | API devuelve 401 → muestra mensaje de error |
| 3 | Tomar asistencia online | Lista de alumnos cargada, tap guardar → POST al API |
| 4 | Asistencia offline | Sin conectividad → guarda en Hive, badge visible |
| 5 | Ver calificaciones | Padre ve lista de materias con promedios correctos |

---

## Deferred

- Mensajería, justificantes, eventos (Phase 2 Flutter)
- Reportes PDF descargables (Phase 3 Flutter)
- Notificaciones push FCM
- iOS build
- Modo oscuro
- Ownership check padre→alumno (verificar que el padre es tutor del alumno que consulta)
