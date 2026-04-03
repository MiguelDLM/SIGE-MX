# SIGE-MX — Plan 5 Design: Módulo Reports (Boleta y Constancia PDF)

**Date:** 2026-04-02
**Status:** Approved
**Fase:** 3

---

## Scope

Generación síncrona de dos tipos de documento PDF para alumnos:

1. **Boleta** — resumen de calificaciones por materia (evaluaciones + promedio)
2. **Constancia** — carta oficial de inscripción al ciclo escolar vigente

Los PDFs se generan en memoria con `fpdf2` y se devuelven como `StreamingResponse`. No se almacenan en MinIO ni en la base de datos — se generan bajo demanda.

---

## Architecture

El módulo sigue el patrón establecido: `models.py` (existe, stub — no se modifica) → `schemas.py` → `service.py` → `router.py` → registrado en `main.py`.

Nueva dependencia: `fpdf2==2.7.9` en `requirements.txt`.

La lógica de generación de PDF vive en `service.py`. El router simplemente llama al servicio y devuelve un `StreamingResponse`.

---

## Data Flow

### Boleta

Joins necesarios para construir la boleta:

```
Student
  └── GroupStudent → Group → AcademicCycle   (encabezado: grupo, ciclo)
  └── Grade → Evaluation → Subject            (tabla de calificaciones)
                └── filtro: Evaluation.group_id == group.id
```

Algoritmo:
1. Obtener alumno por `student_id` → 404 si no existe
2. Obtener el grupo activo del alumno (`GroupStudent → Group` donde `AcademicCycle.activo = true`). Si no tiene grupo activo, devolver boleta solo con datos del alumno y tabla vacía.
3. Obtener grades del alumno con join a evaluations+subjects filtrado por `group_id`
4. Agrupar en Python por materia; calcular promedio por materia como media de `calificacion` de las filas con valor
5. Generar PDF y devolver como `StreamingResponse`

### Constancia

```
Student
  └── GroupStudent → Group → AcademicCycle
```

1. Obtener alumno → 404 si no existe
2. Obtener grupo activo → si no tiene, la constancia indica "sin grupo asignado"
3. Generar PDF y devolver

---

## Endpoints

| Method | Path | Roles | Response |
|--------|------|-------|----------|
| GET | `/api/v1/reports/students/{student_id}/boleta` | control_escolar, directivo, padre, alumno | 200 StreamingResponse PDF |
| GET | `/api/v1/reports/students/{student_id}/constancia` | control_escolar, directivo, padre, alumno | 200 StreamingResponse PDF |

**Notas de autorización:**
- `control_escolar` y `directivo`: pueden generar reporte de cualquier alumno
- `padre` y `alumno`: se permite por ahora sin restricción de propiedad (ownership check diferido a Fase 4)
- Sin autenticación → 403

**Response headers:**
```
Content-Type: application/pdf
Content-Disposition: inline; filename="boleta_{matricula}.pdf"
Content-Disposition: inline; filename="constancia_{matricula}.pdf"
```

---

## PDF Content

### Boleta

```
┌─────────────────────────────────────────────────────┐
│  SISTEMA INTEGRAL DE GESTIÓN ESCOLAR                │
│  BOLETA DE CALIFICACIONES                           │
├─────────────────────────────────────────────────────┤
│  Alumno: [nombre completo]   Matrícula: [matrícula] │
│  Grupo:  [nombre del grupo]  Ciclo: [ciclo escolar] │
├────────────────┬────────────┬────────────┬──────────┤
│ Materia        │ Evaluación │ Tipo       │   Cal.   │
├────────────────┼────────────┼────────────┼──────────┤
│ Matemáticas    │ Examen 1   │ examen     │   8.5    │
│                │ Tarea 1    │ tarea      │   9.0    │
│                │            │ Promedio   │   8.75   │
├────────────────┼────────────┼────────────┼──────────┤
│ ...            │ ...        │ ...        │   ...    │
└────────────────┴────────────┴────────────┴──────────┘
  Fecha de expedición: [fecha actual]
```

- Si el alumno no tiene calificaciones registradas, la tabla aparece vacía (no es error)
- Promedio calculado como media aritmética de las calificaciones no nulas por materia

### Constancia

```
┌─────────────────────────────────────────────────────┐
│  SISTEMA INTEGRAL DE GESTIÓN ESCOLAR                │
│  CONSTANCIA DE INSCRIPCIÓN                         │
│                                                     │
│  [Lugar], a [fecha actual]                          │
│                                                     │
│  A quien corresponda:                               │
│                                                     │
│  Se hace constar que el/la alumno/a                 │
│  [NOMBRE COMPLETO], con matrícula [matrícula],      │
│  se encuentra debidamente inscrito/a en esta        │
│  institución en el grupo [grupo], turno [turno],    │
│  correspondiente al ciclo escolar [ciclo].          │
│                                                     │
│  Se expide la presente constancia a petición        │
│  del interesado para los fines que convenga.        │
│                                                     │
│  ________________________                           │
│  Control Escolar                                    │
└─────────────────────────────────────────────────────┘
```

---

## File Structure

```
backend/
├── modules/
│   └── reports/
│       ├── __init__.py     EXISTS (empty)
│       ├── models.py       EXISTS (stub — no modificar)
│       ├── schemas.py      NEW — ReportMeta (response mínima, no usada en PDF)
│       ├── service.py      NEW — generate_boleta(), generate_constancia()
│       └── router.py       NEW — 2 endpoints GET StreamingResponse
├── main.py                 MODIFY — registrar reports_router
└── requirements.txt        MODIFY — añadir fpdf2==2.7.9
tests/modules/
└── test_reports.py         NEW — 6 tests
```

---

## Tests (6)

| # | Test | Expected |
|---|------|----------|
| 1 | Boleta de alumno con calificaciones → GET `/boleta` | 200, `Content-Type: application/pdf`, body inicia con `%PDF` |
| 2 | Constancia de alumno con grupo activo → GET `/constancia` | 200, `Content-Type: application/pdf`, body inicia con `%PDF` |
| 3 | Boleta de alumno sin calificaciones → GET `/boleta` | 200, PDF generado (tabla vacía, sin crash) |
| 4 | Alumno inexistente → GET `/boleta` | 404 |
| 5 | Alumno inexistente → GET `/constancia` | 404 |
| 6 | Sin autenticación → GET `/boleta` | 403 |

---

## Implementation Notes

- `StreamingResponse(io.BytesIO(pdf_bytes), media_type="application/pdf")` — fpdf2 genera bytes con `pdf.output()`
- La clase PDF de fpdf2 se instancia dentro de cada función de servicio (no es un singleton)
- No se requiere fuente personalizada — usar la fuente built-in `Helvetica` de fpdf2
- El modelo `Report` (stub) no se usa en esta implementación; queda disponible para una futura feature de historial de reportes generados
- El modelo `Certificate` (stub) no es relevante para estos endpoints
- Tests: crear fixtures de Student, Group, AcademicCycle, Subject, Evaluation, Grade desde cero en conftest; mock no necesario (PDF generado en memoria)

---

## Deferred

- Ownership check para `padre`/`alumno` (verificar que el padre es tutor del alumno, o que el alumno es el mismo)
- Historial de reportes generados (usar tabla `reports`)
- Logo institucional en el encabezado
- Exportación de boleta grupal (todos los alumnos de un grupo)
