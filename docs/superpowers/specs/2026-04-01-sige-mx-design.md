# SIGE-MX — Sistema Integral de Gestión Escolar

**Fecha:** 2026-04-01  
**Estado:** Aprobado  
**Alcance:** Educación media superior pública, instancia única por escuela

---

## 1. Objetivo

Plataforma integral para administrar una institución de educación media superior del sistema público mexicano. Cubre gestión de alumnos y docentes, control académico (grupos, materias, evaluaciones), registro de asistencia y calificaciones, comunicación institucional, eventos escolares, generación de reportes y constancias, justificantes, y auditoría completa.

---

## 2. Decisiones de arquitectura

| Decisión | Elección | Razón |
|---|---|---|
| Topología | Instancia única (una escuela) | Sin multi-tenant; sin overhead de aislamiento |
| Patrón backend | Monolito modular | Una escuela no justifica microservicios; módulos bien delimitados permiten extracción futura |
| Frontend | Flutter mobile-first | Docentes toman asistencia desde celular; padres consultan desde móvil |
| Roles activos desde MVP | Todos (5 roles) | Requerimiento del cliente desde el día uno |
| Carga de datos inicial | Importación CSV/Excel + captura manual | Datos existentes en hojas de cálculo; manual como fallback |
| Despliegue | Docker Compose (agnóstico) | No definido aún; puede correr en servidor local o nube |

---

## 3. Stack tecnológico

### Backend
- **FastAPI** (Python 3.12) — API REST
- **SQLAlchemy 2.0** — ORM, queries async
- **Alembic** — migraciones versionadas
- **PostgreSQL 16** — base de datos principal
- **Redis** — caché de sesiones, blacklist de tokens, colas de tareas
- **Dramatiq + Redis** — tareas asíncronas (generación de PDFs, notificaciones)
- **MinIO** — almacenamiento de archivos (justificantes, constancias, boletas)
- **Argon2** — hash de contraseñas

### Frontend
- **Flutter 3.x** — Android + iOS + Web
- **Riverpod** — gestión de estado
- **GoRouter** — navegación con guards por rol
- **Dio** — cliente HTTP con interceptor JWT
- **flutter_secure_storage** — almacenamiento seguro de tokens
- **Hive** — caché offline ligero (asistencia pendiente de sync)

### Infraestructura
- **Docker Compose** — 4 contenedores: `backend`, `postgres`, `redis`, `minio`
- **Nginx** — reverse proxy

---

## 4. Estructura del backend

```
backend/
├── main.py                  # app FastAPI, registro de routers
├── core/
│   ├── config.py            # settings (pydantic-settings, env vars)
│   ├── database.py          # engine SQLAlchemy, get_db()
│   ├── security.py          # JWT, Argon2, dependencias RBAC
│   └── audit.py             # middleware auditoría automática
├── modules/
│   ├── auth/                # login, refresh token, logout
│   ├── users/               # CRUD usuarios + asignación de roles
│   ├── students/            # alumnos, tutores, relaciones
│   ├── teachers/            # docentes, especialidades
│   ├── groups/              # grupos, ciclos escolares, asignaciones
│   ├── subjects/            # materias, catálogo
│   ├── attendance/          # registro de asistencia diaria
│   ├── grades/              # evaluaciones y calificaciones
│   ├── justifications/      # justificantes + subida de archivos
│   ├── messaging/           # mensajes directos y grupales
│   ├── events/              # eventos escolares
│   ├── reports/             # boletas y constancias PDF
│   └── imports/             # carga masiva CSV/Excel
├── migrations/              # Alembic versions/
└── tests/                   # pytest por módulo
```

### Anatomía de cada módulo

Cada módulo contiene exactamente cuatro archivos:

- `router.py` — endpoints FastAPI (rutas, guards, serialización)
- `service.py` — lógica de negocio; recibe sesión de BD como dependencia inyectada
- `models.py` — modelos SQLAlchemy (tablas)
- `schemas.py` — esquemas Pydantic (request/response)

Los **routers** no importan otros módulos directamente. Los **services** sí pueden llamar a services de otros módulos cuando la lógica lo requiere (por ejemplo, `attendance.service` llama a `students.service` para validar que el alumno existe).

---

## 5. Convenciones de la API REST

- **Prefijo:** `/api/v1/<módulo>/`
- **Paginación:** `?page=1&size=20` → `{data, total, page, size, pages}`
- **Respuesta exitosa:** `{"data": {...}}` con status 200/201
- **Error de validación (422):** formato Pydantic estándar con `loc` mapeado al campo
- **Error de negocio (400/409):** `{"error": {"code": "DUPLICATE_MATRICULA", "message": "..."}}`
- **Error inesperado (500):** respuesta genérica al cliente; detalle completo solo en logs

---

## 6. Autenticación y seguridad

### Flujo JWT
1. `POST /api/v1/auth/login` → retorna `access_token` (15 min) + `refresh_token` (7 días)
2. Requests: `Authorization: Bearer {access_token}`
3. Interceptor Dio detecta 401 → `POST /auth/refresh` automáticamente (sin interrumpir al usuario)
4. Logout: refresh token agregado a blacklist en Redis (TTL 7 días)

### RBAC
Los roles son: `directivo`, `docente`, `control_escolar`, `padre`, `alumno`.

Los permisos se implementan como dependencias FastAPI reutilizables:
- `require_roles(["directivo", "control_escolar"])` — acceso total al recurso
- `require_own_student(student_id, current_user)` — acceso restringido al propio alumno/hijo

**Reglas clave:**
- Docente: ve y modifica solo su grupo y materia asignada
- Padre: ve solo datos de su hijo/a
- Alumno: ve solo su propio historial
- Control escolar: gestión de alumnos y constancias, sin acceso a auditoría
- Directivo: acceso completo incluyendo auditoría

---

## 7. Estructura Flutter

```
lib/
├── main.dart
├── core/
│   ├── api/             # cliente Dio, interceptores JWT, manejo de errores
│   ├── auth/            # estado de sesión global (Riverpod)
│   ├── router/          # GoRouter, guards por rol
│   └── theme/           # colores, tipografía, modo oscuro
├── features/
│   ├── auth/            # login, recuperar contraseña
│   ├── dashboard/       # pantalla de inicio adaptada por rol
│   ├── attendance/      # tomar lista (docente), consultar (padre/alumno)
│   ├── grades/          # capturar (docente), consultar (padre/alumno)
│   ├── students/        # perfil de alumno, historial académico
│   ├── messaging/       # mensajes directos y grupales
│   ├── events/          # calendario de eventos escolares
│   ├── justifications/  # subir (padre), revisar (docente/control)
│   └── reports/         # ver y descargar boletas y constancias
└── shared/              # widgets reutilizables, utils, constantes
```

### Navegación por rol (bottom navigation bar)

| Rol | Tabs |
|---|---|
| Docente | Inicio · Asistencia · Calificaciones · Mensajes |
| Padre/Tutor | Inicio · Asistencia · Calificaciones · Mensajes |
| Directivo | Inicio · Alumnos · Grupos · Reportes |
| Alumno | Inicio · Mi Asistencia · Mis Calificaciones · Mensajes |
| Control Escolar | Inicio · Alumnos · Importar · Constancias |

### Gestión de estado
- **Riverpod** — `AsyncNotifier` para datos remotos, `StateNotifier` para UI local
- **Offline:** asistencia se guarda en Hive si no hay red; sync automático al recuperar conexión con indicador visual de "pendiente"

---

## 8. Importación CSV/Excel

### Flujo en 5 pasos
1. Upload (`POST /api/v1/imports/students`, multipart) — límite 5 MB / 2000 filas
2. Validación fila por fila: CURP, matrícula única, campos requeridos, formato de fecha
3. Preview: API retorna `{total, validas, errores, advertencias, preview[0..5]}`
4. Confirmación selectiva: "importar solo filas válidas" o "cancelar y corregir"
5. Inserción atómica de filas válidas en una sola transacción; rollback completo si falla

### Plantilla esperada
Columnas requeridas: `nombre`, `apellido_paterno`, `curp`, `matricula`, `fecha_nacimiento`  
Columnas opcionales: `apellido_materno`, `email`, `grupo`

La app ofrece descarga de plantilla `.xlsx` con encabezados correctos y fila de ejemplo.

### Entidades importables (Fase 1)
- Alumnos
- Docentes

---

## 9. Schema de base de datos

El schema sigue el diseño provisto, con estas precisiones:

- Todos los IDs son UUID v4 (`uuid_generate_v4()`)
- `audit_log` registra toda escritura: `user_id`, `action`, `table_name`, `record_id`, `old_data` (JSONB), `new_data` (JSONB), `timestamp`
- La restricción `UNIQUE(student_id, fecha)` en `attendance` previene duplicados por día
- `group_teachers` incluye `subject_id` para modelar docente→grupo→materia
- Índices clave: `students(matricula)`, `attendance(fecha)`, `grades(student_id)`, `messages(sender_id)`

---

## 10. Fases de desarrollo

### Fase 1 — MVP (prioridad máxima)
- Infraestructura Docker Compose
- Migraciones Alembic (schema completo)
- Módulos backend: `auth`, `users`, `students`, `teachers`, `groups`, `subjects`, `attendance`, `grades`
- Importación CSV/Excel (alumnos y docentes)
- App Flutter: login, dashboard por rol, tomar asistencia, capturar/consultar calificaciones
- RBAC completo desde el inicio

### Fase 2
- Módulos backend: `justifications`, `messaging`, `events`
- Flutter: mensajería, justificantes con carga de archivos, calendario de eventos
- Notificaciones push (FCM)

### Fase 3
- Módulos backend: `reports`, auditoría visible en UI
- Generación de PDFs (boletas, constancias) con Dramatiq
- Dashboard directivo con métricas
- Constancias oficiales descargables

---

## 11. Pruebas

- **Backend:** pytest con base de datos de prueba en PostgreSQL (sin mocks de BD)
- **Por módulo:** tests de integración que cubren happy path + casos de error principales
- **Flutter:** widget tests para flujos críticos (login, tomar asistencia, ver calificaciones)

---

## 12. Lo que este diseño NO incluye

- Multi-tenant (múltiples escuelas en una instancia)
- Integración con SIASE u otros sistemas SEP (puede agregarse en Fase 3+)
- WebSockets para mensajería en tiempo real (la mensajería es asíncrona en Fase 2)
- Biometría o QR para asistencia (puede agregarse como feature de Fase 2+)
