# backend/modules/reports/service.py
import io
import uuid
from datetime import date
from decimal import Decimal

from fpdf import FPDF
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from core.exceptions import BusinessError
from modules.academic_cycles.models import AcademicCycle
from modules.grades.models import Evaluation, Grade
from modules.groups.models import Group, GroupStudent
from modules.students.models import Student
from modules.subjects.models import Subject


async def _get_student_or_404(student_id: uuid.UUID, db: AsyncSession) -> Student:
    result = await db.execute(select(Student).where(Student.id == student_id))
    student = result.scalar_one_or_none()
    if student is None:
        raise BusinessError("STUDENT_NOT_FOUND", "Alumno no encontrado", status_code=404)
    return student


async def _get_active_group(student_id: uuid.UUID, db: AsyncSession) -> tuple[Group | None, AcademicCycle | None]:
    """Return (group, cycle) for the student's active group, or (None, None)."""
    stmt = (
        select(Group, AcademicCycle)
        .join(GroupStudent, GroupStudent.group_id == Group.id)
        .join(AcademicCycle, AcademicCycle.id == Group.ciclo_id)
        .where(GroupStudent.student_id == student_id)
        .where(AcademicCycle.activo == True)  # noqa: E712
    )
    result = await db.execute(stmt)
    row = result.first()
    if row is None:
        return None, None
    return row[0], row[1]


async def generate_boleta(student_id: uuid.UUID, db: AsyncSession) -> bytes:
    student = await _get_student_or_404(student_id, db)
    group, cycle = await _get_active_group(student_id, db)

    # Fetch grades with evaluation + subject info
    rows: list[tuple[Grade, Evaluation, Subject]] = []
    if group is not None:
        stmt = (
            select(Grade, Evaluation, Subject)
            .join(Evaluation, Evaluation.id == Grade.evaluation_id)
            .join(Subject, Subject.id == Evaluation.subject_id)
            .where(Grade.student_id == student_id)
            .where(Evaluation.group_id == group.id)
            .order_by(Subject.nombre, Evaluation.titulo)
        )
        result = await db.execute(stmt)
        rows = list(result.tuples())

    # Group by subject
    subjects_data: dict[str, list[tuple[str, str, Decimal | None]]] = {}
    for grade, evaluation, subject in rows:
        s_name = subject.nombre or "Sin nombre"
        if s_name not in subjects_data:
            subjects_data[s_name] = []
        subjects_data[s_name].append((
            evaluation.titulo or "",
            evaluation.tipo.value if evaluation.tipo else "",
            grade.calificacion,
        ))

    nombre_completo = " ".join(filter(None, [
        student.nombre,
        student.apellido_paterno,
        student.apellido_materno,
    ]))

    pdf = FPDF()
    pdf.add_page()
    pdf.set_auto_page_break(auto=True, margin=15)

    # Header
    pdf.set_font("Helvetica", "B", 14)
    pdf.cell(0, 8, "SISTEMA INTEGRAL DE GESTION ESCOLAR", ln=True, align="C")
    pdf.cell(0, 8, "BOLETA DE CALIFICACIONES", ln=True, align="C")
    pdf.ln(4)

    # Student info
    pdf.set_font("Helvetica", "", 10)
    pdf.cell(95, 6, f"Alumno: {nombre_completo}", border=0)
    pdf.cell(95, 6, f"Matricula: {student.matricula}", ln=True)
    pdf.cell(95, 6, f"Grupo: {group.nombre if group else 'Sin grupo'}", border=0)
    pdf.cell(95, 6, f"Ciclo: {cycle.nombre if cycle else '-'}", ln=True)
    pdf.ln(4)

    # Table header
    pdf.set_font("Helvetica", "B", 9)
    pdf.set_fill_color(220, 220, 220)
    pdf.cell(60, 7, "Materia", border=1, fill=True)
    pdf.cell(55, 7, "Evaluacion", border=1, fill=True)
    pdf.cell(45, 7, "Tipo", border=1, fill=True)
    pdf.cell(30, 7, "Cal.", border=1, fill=True, ln=True, align="C")

    pdf.set_font("Helvetica", "", 9)
    if not subjects_data:
        pdf.cell(190, 7, "(Sin calificaciones registradas)", border=1, align="C", ln=True)
    else:
        for subject_name, evaluations in subjects_data.items():
            valid_grades = [c for _, _, c in evaluations if c is not None]
            promedio = sum(valid_grades) / len(valid_grades) if valid_grades else None

            first = True
            for titulo, tipo, calificacion in evaluations:
                pdf.cell(60, 6, subject_name if first else "", border=1)
                pdf.cell(55, 6, titulo, border=1)
                pdf.cell(45, 6, tipo, border=1)
                cal_str = f"{calificacion:.2f}" if calificacion is not None else "-"
                pdf.cell(30, 6, cal_str, border=1, align="C", ln=True)
                first = False

            # Promedio row
            pdf.cell(60, 6, "", border=1)
            pdf.cell(55, 6, "", border=1)
            pdf.set_font("Helvetica", "B", 9)
            pdf.cell(45, 6, "Promedio", border=1)
            prom_str = f"{float(promedio):.2f}" if promedio is not None else "-"
            pdf.cell(30, 6, prom_str, border=1, align="C", ln=True)
            pdf.set_font("Helvetica", "", 9)

    pdf.ln(4)
    pdf.set_font("Helvetica", "I", 8)
    pdf.cell(0, 6, f"Fecha de expedicion: {date.today().strftime('%d/%m/%Y')}", ln=True)

    return bytes(pdf.output())


async def generate_constancia(student_id: uuid.UUID, db: AsyncSession) -> bytes:
    student = await _get_student_or_404(student_id, db)
    group, cycle = await _get_active_group(student_id, db)

    nombre_completo = " ".join(filter(None, [
        student.nombre,
        student.apellido_paterno,
        student.apellido_materno,
    ])).upper()

    today = date.today().strftime("%d/%m/%Y")

    pdf = FPDF()
    pdf.add_page()
    pdf.set_auto_page_break(auto=True, margin=15)

    # Header
    pdf.set_font("Helvetica", "B", 14)
    pdf.cell(0, 8, "SISTEMA INTEGRAL DE GESTION ESCOLAR", ln=True, align="C")
    pdf.cell(0, 8, "CONSTANCIA DE INSCRIPCION", ln=True, align="C")
    pdf.ln(10)

    pdf.set_font("Helvetica", "", 11)
    pdf.cell(0, 7, f"Lugar, a {today}", ln=True)
    pdf.ln(6)

    pdf.cell(0, 7, "A quien corresponda:", ln=True)
    pdf.ln(6)

    grupo_str = group.nombre if group else "sin grupo asignado"
    turno_str = group.turno if group else "-"
    ciclo_str = cycle.nombre if cycle else "-"

    body = (
        f"Se hace constar que el/la alumno/a {nombre_completo}, "
        f"con matricula {student.matricula}, se encuentra debidamente "
        f"inscrito/a en esta institucion en el grupo {grupo_str}, "
        f"turno {turno_str}, correspondiente al ciclo escolar {ciclo_str}."
    )
    pdf.set_font("Helvetica", "", 11)
    pdf.multi_cell(0, 7, body)
    pdf.ln(6)

    pdf.multi_cell(
        0, 7,
        "Se expide la presente constancia a peticion del interesado "
        "para los fines que convenga."
    )
    pdf.ln(16)

    pdf.cell(60, 0.5, "", border="T")
    pdf.ln(4)
    pdf.cell(0, 6, "Control Escolar", ln=True)

    return bytes(pdf.output())
