# Plan 9 — Gestión Escolar Completa: Materias, Grupos, Horarios, Vinculos, Eventos y Constancias

**Fecha:** 2026-04-04  
**Estado:** Pendiente

---

## Contexto y requerimientos

1. **Multi-rol familiar**: Un padre puede tener varios hijos en la misma escuela. Un maestro o administrativo puede también estar vinculado como tutor de un alumno del plantel. Un usuario puede tener múltiples roles simultáneos.

2. **Gestión de la escuela** (solo directivo/control_escolar):
   - Crear/editar/eliminar materias (`materias`)
   - Crear/editar/eliminar grupos con nivel y grado (`grupos`)
   - Asignar alumnos a grupos (`grupo_alumnos`)
   - Asignar maestros a materias (`materia_maestros`)
   - Crear horario de clases: grupo + materia + maestro + día + hora + aula

3. **Ver horario** (alumnos, maestros, tutores):
   - Alumno: ve el horario de su grupo
   - Maestro: ve las clases que imparte (en qué grupos)
   - Tutor: ve el horario del grupo de su(s) hijo(s)
   - **Debe funcionar offline** (cache en Hive)

4. **Vinculación familiar**:
   - Un usuario puede tener rol `tutor`
   - La tabla `student_guardians` vincula `guardian_user_id -> student_user_id`
   - Un admin crea/gestiona los vínculos
   - Un tutor también puede tener rol `maestro` o `administrativo` simultáneamente

5. **Participantes en eventos**:
   - Al crear/editar un evento se pueden añadir participantes:
     - Usuarios individuales (alumno, maestro, admin)
     - Grupo completo (todos los alumnos de un grupo)
     - Todos los maestros de una materia
     - Todos los usuarios con un rol específico
   - Backend resuelve los participantes al momento de guardar/listar

6. **Constancias de participación**:
   - Después de un evento, los administrativos pueden autorizar constancias
   - Autorización individual o por lote (todos los participantes del evento)
   - Una constancia puede retractarse y eliminarse (soft-delete con `revoked_at`)
   - El alumno/maestro puede ver sus constancias

---

## Esquema de base de datos nuevo

### Tablas nuevas

```sql
-- Materias del plantel
materias (
  id UUID PK,
  nombre VARCHAR(120) NOT NULL,
  clave VARCHAR(30),
  activo BOOLEAN DEFAULT true,
  created_at TIMESTAMP
)

-- Grupos (e.g. "1°A", "2°B")
grupos (
  id UUID PK,
  nombre VARCHAR(60) NOT NULL,     -- "1°A"
  nivel VARCHAR(40),               -- "primaria", "secundaria"
  grado INTEGER,                   -- 1, 2, 3
  seccion VARCHAR(10),             -- "A", "B"
  ciclo_id UUID FK -> academic_cycles.id,
  activo BOOLEAN DEFAULT true,
  created_at TIMESTAMP
)

-- Alumnos en grupos (un alumno -> un grupo por ciclo)
grupo_alumnos (
  grupo_id UUID FK -> grupos.id,
  alumno_id UUID FK -> users.id,
  PRIMARY KEY (grupo_id, alumno_id)
)

-- Maestros asignados a materias (un maestro puede dar varias materias)
materia_maestros (
  materia_id UUID FK -> materias.id,
  maestro_id UUID FK -> users.id,
  PRIMARY KEY (materia_id, maestro_id)
)

-- Horario de clases
horario_clases (
  id UUID PK,
  grupo_id UUID FK -> grupos.id,
  materia_id UUID FK -> materias.id,
  maestro_id UUID FK -> users.id,
  dia_semana SMALLINT NOT NULL,    -- 0=lunes ... 4=viernes
  hora_inicio TIME NOT NULL,
  hora_fin TIME NOT NULL,
  aula VARCHAR(40),
  created_at TIMESTAMP
)

-- Vínculos familiares (tutor -> alumno)
student_guardians (
  guardian_id UUID FK -> users.id,
  student_id UUID FK -> users.id,
  relacion VARCHAR(40),            -- "padre", "madre", "tutor"
  PRIMARY KEY (guardian_id, student_id)
)

-- Participantes de eventos
event_participants (
  id UUID PK,
  event_id UUID FK -> events.id ON DELETE CASCADE,
  -- Puede ser individual o grupo:
  user_id UUID FK -> users.id NULLABLE,
  grupo_id UUID FK -> grupos.id NULLABLE,
  materia_id UUID FK -> materias.id NULLABLE,  -- todos los maestros de esa materia
  rol VARCHAR(40) NULLABLE,        -- todos los usuarios de ese rol
  tipo VARCHAR(20) NOT NULL,       -- "individual"|"grupo"|"materia"|"rol"
  added_at TIMESTAMP DEFAULT now()
)

-- Constancias de participación en eventos
constancias (
  id UUID PK,
  event_id UUID FK -> events.id,
  user_id UUID FK -> users.id,     -- beneficiario
  authorized_by UUID FK -> users.id,
  authorized_at TIMESTAMP DEFAULT now(),
  revoked_at TIMESTAMP NULLABLE,
  notas VARCHAR(255),
  UNIQUE (event_id, user_id)
)
```

---

## Módulos Backend (FastAPI)

### Módulo: `materias`
- `GET /api/v1/materias/` — lista (con paginación)
- `POST /api/v1/materias/` — crear (directivo/control_escolar)
- `PUT /api/v1/materias/{id}` — editar
- `DELETE /api/v1/materias/{id}` — soft-delete (activo=false)

### Módulo: `grupos`
- `GET /api/v1/grupos/` — lista (filtrable por ciclo)
- `POST /api/v1/grupos/` — crear
- `PUT /api/v1/grupos/{id}` — editar
- `DELETE /api/v1/grupos/{id}` — soft-delete
- `POST /api/v1/grupos/{id}/alumnos` — agregar alumnos (array de user_ids)
- `DELETE /api/v1/grupos/{id}/alumnos/{alumno_id}` — remover alumno
- `GET /api/v1/grupos/{id}/alumnos` — lista de alumnos del grupo

### Módulo: `horarios`
- `GET /api/v1/horarios/grupo/{grupo_id}` — horario de un grupo (offline-friendly)
- `GET /api/v1/horarios/maestro/{maestro_id}` — horario del maestro
- `GET /api/v1/horarios/mi-horario` — horario del usuario actual (auto-detecta si es alumno/maestro)
- `POST /api/v1/horarios/` — crear entrada (directivo)
- `PUT /api/v1/horarios/{id}` — editar
- `DELETE /api/v1/horarios/{id}` — eliminar

### Módulo: `student_guardians`
- `GET /api/v1/mis-tutelados` — alumnos que tiene bajo tutela el usuario actual
- `POST /api/v1/student-guardians/` — vincular (admin only)
- `DELETE /api/v1/student-guardians/{guardian_id}/{student_id}` — desvincular

### Módulo: `event_participants` (extender módulo events)
- `GET /api/v1/events/{id}/participants` — lista expandida de participantes (resuelve grupos/roles a usuarios individuales)
- `POST /api/v1/events/{id}/participants` — agregar participante(s) (individual/grupo/materia/rol)
- `DELETE /api/v1/events/{id}/participants/{participant_id}` — remover

### Módulo: `constancias`
- `GET /api/v1/constancias/` — las mías (alumno/maestro) o filtrar por evento (admin)
- `POST /api/v1/constancias/batch` — autorizar por lote (array de user_ids + event_id)
- `POST /api/v1/constancias/` — autorizar individual
- `DELETE /api/v1/constancias/{id}` — revocar (soft-delete: revoked_at=now())

---

## Módulos Flutter

### Offline para horarios
- Guardar horario en Hive: `Box<String>` con key `schedule_<userId>`, value = JSON serializado
- En `HorarioProvider`: si hay datos en Hive y no hay red → mostrar cached; actualizar en background cuando haya red
- `connectivity_plus` ya está incluido en pubspec

### Pantallas nuevas

#### Gestión escolar (admin)
- `AdminMateriaScreen` — CRUD materias
- `AdminGruposScreen` — CRUD grupos
- `AdminGrupoDetailScreen` — ver/agregar/remover alumnos del grupo
- `AdminHorarioScreen` — grilla semanal editable para un grupo
- `AdminGuardiansScreen` — vincular tutor ↔ alumno

#### Mi horario (todos los roles)
- `MiHorarioScreen` — grilla semanal de solo lectura; badge "sin conexión" si está en cache

#### Mis hijos / tutelados (tutores)
- `MisTuteladosScreen` — lista de alumnos vinculados; tap → ver horario/notas de ese alumno

#### Participantes de eventos
- `EventParticipantsScreen` — lista de participantes resueltos con búsqueda
- `AddParticipantsSheet` — bottom sheet con pestañas: Individual / Grupo / Materia / Rol

#### Constancias
- `ConstanciasEventScreen` — lista de participantes del evento con checkbox; botón "Autorizar seleccionados" y "Autorizar todos"
- `MisConstanciasScreen` — constancias propias (visible para todos)
- Cada constancia tiene botón "Revocar" (solo admin)

---

## Migraciones Alembic

Una sola migración que crea todas las tablas nuevas en orden correcto (respetar FKs).

---

## Orden de implementación

1. Migración Alembic (una sola)
2. Backend: módulos `materias`, `grupos` (con alumnos)
3. Backend: módulo `horarios`
4. Backend: módulo `student_guardians`
5. Backend: extender eventos con `event_participants`
6. Backend: módulo `constancias`
7. Flutter: pantallas admin (materias, grupos, horarios, guardians)
8. Flutter: `MiHorarioScreen` con offline cache
9. Flutter: `MisTuteladosScreen`
10. Flutter: participantes de eventos + constancias
11. Pruebas backend (pytest)
12. Compilar APK final
