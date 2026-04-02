# backend/modules/imports/service.py
from typing import Any

from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from modules.imports.parsers import (
    build_student_template_xlsx,
    build_teacher_template_xlsx,
    parse_file,
    validate_student_row,
    validate_teacher_row,
)
from modules.imports.schemas import ImportResult, RowError
from modules.students.models import Student
from modules.teachers.models import Teacher

MAX_ROWS = 2000


async def import_students(
    content: bytes, filename: str, db: AsyncSession
) -> ImportResult:
    rows = parse_file(content, filename)[:MAX_ROWS]
    total = len(rows)
    error_details: list[RowError] = []
    valid_students: list[Student] = []
    preview: list[dict[str, Any]] = []

    for i, row in enumerate(rows, start=2):  # row 1 = header
        errs = validate_student_row(row, i)
        if errs:
            error_details.extend([RowError(**e) for e in errs])
            continue
        valid_students.append(
            Student(
                matricula=row["matricula"].strip(),
                nombre=row.get("nombre", "").strip() or None,
                apellido_paterno=row.get("apellido_paterno", "").strip() or None,
                apellido_materno=row.get("apellido_materno", "").strip() or None,
                municipio=row.get("municipio", "").strip() or None,
                estado=row.get("estado", "").strip() or None,
                codigo_postal=row.get("codigo_postal", "").strip() or None,
                tipo_sangre=row.get("tipo_sangre", "").strip() or None,
            )
        )
        if len(preview) < 5:
            preview.append({"row": i, "matricula": row["matricula"], "nombre": row.get("nombre")})

    importados = 0
    for student in valid_students:
        try:
            db.add(student)
            await db.flush()
            importados += 1
        except IntegrityError:
            await db.rollback()
            error_details.append(
                RowError(row=0, field="matricula", message=f"Matrícula '{student.matricula}' ya existe")
            )

    await db.commit()
    return ImportResult(
        total=total,
        importados=importados,
        errores=len(error_details),
        error_details=error_details,
        preview=preview,
    )


async def import_teachers(
    content: bytes, filename: str, db: AsyncSession
) -> ImportResult:
    rows = parse_file(content, filename)[:MAX_ROWS]
    total = len(rows)
    error_details: list[RowError] = []
    valid_teachers: list[Teacher] = []
    preview: list[dict[str, Any]] = []

    for i, row in enumerate(rows, start=2):
        errs = validate_teacher_row(row, i)
        if errs:
            error_details.extend([RowError(**e) for e in errs])
            continue
        valid_teachers.append(
            Teacher(
                numero_empleado=row["numero_empleado"].strip(),
                nombre=row.get("nombre", "").strip() or None,
                apellido_paterno=row.get("apellido_paterno", "").strip() or None,
                apellido_materno=row.get("apellido_materno", "").strip() or None,
                especialidad=row.get("especialidad", "").strip() or None,
            )
        )
        if len(preview) < 5:
            preview.append({"row": i, "numero_empleado": row["numero_empleado"], "nombre": row.get("nombre")})

    importados = 0
    for teacher in valid_teachers:
        try:
            db.add(teacher)
            await db.flush()
            importados += 1
        except IntegrityError:
            await db.rollback()
            error_details.append(
                RowError(row=0, field="numero_empleado", message=f"Número de empleado '{teacher.numero_empleado}' ya existe")
            )

    await db.commit()
    return ImportResult(
        total=total,
        importados=importados,
        errores=len(error_details),
        error_details=error_details,
        preview=preview,
    )


def get_student_template() -> bytes:
    return build_student_template_xlsx()


def get_teacher_template() -> bytes:
    return build_teacher_template_xlsx()
