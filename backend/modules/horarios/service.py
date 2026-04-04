import uuid
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from core.exceptions import BusinessError
from modules.groups.models import Group, GroupStudent
from modules.horarios.models import HorarioClase
from modules.horarios.schemas import HorarioCreate, HorarioResponse, HorarioUpdate
from modules.students.models import Student
from modules.subjects.models import Subject
from modules.teachers.models import Teacher
from modules.users.models import User


async def _enrich(h: HorarioClase, db: AsyncSession) -> HorarioResponse:
    """Build HorarioResponse with enriched names."""
    subj = await db.get(Subject, h.subject_id)
    teacher = await db.get(Teacher, h.teacher_id)
    group = await db.get(Group, h.group_id)

    teacher_nombre = None
    if teacher:
        parts = filter(
            None,
            [teacher.nombre, teacher.apellido_paterno, teacher.apellido_materno],
        )
        teacher_nombre = " ".join(parts) or None

    return HorarioResponse(
        id=h.id,
        group_id=h.group_id,
        subject_id=h.subject_id,
        teacher_id=h.teacher_id,
        dia_semana=h.dia_semana,
        hora_inicio=h.hora_inicio,
        hora_fin=h.hora_fin,
        aula=h.aula,
        subject_nombre=subj.nombre if subj else None,
        teacher_nombre=teacher_nombre,
        group_nombre=group.nombre if group else None,
    )


async def create_horario(data: HorarioCreate, db: AsyncSession) -> HorarioClase:
    h = HorarioClase(**data.model_dump())
    db.add(h)
    await db.commit()
    await db.refresh(h)
    return h


async def list_by_group(group_id: uuid.UUID, db: AsyncSession) -> list[HorarioResponse]:
    result = await db.execute(
        select(HorarioClase)
        .where(HorarioClase.group_id == group_id)
        .order_by(HorarioClase.dia_semana, HorarioClase.hora_inicio)
    )
    rows = list(result.scalars())
    return [await _enrich(h, db) for h in rows]


async def list_by_teacher(teacher_id: uuid.UUID, db: AsyncSession) -> list[HorarioResponse]:
    result = await db.execute(
        select(HorarioClase)
        .where(HorarioClase.teacher_id == teacher_id)
        .order_by(HorarioClase.dia_semana, HorarioClase.hora_inicio)
    )
    rows = list(result.scalars())
    return [await _enrich(h, db) for h in rows]


async def mi_horario(user_id: uuid.UUID, roles: list[str], db: AsyncSession) -> list[HorarioResponse]:
    """Return schedule based on user role: student → group schedule; teacher → their classes."""
    if "docente" in roles:
        teacher_result = await db.execute(
            select(Teacher).where(Teacher.user_id == user_id)
        )
        teacher = teacher_result.scalar_one_or_none()
        if teacher:
            return await list_by_teacher(teacher.id, db)

    if "alumno" in roles:
        student_result = await db.execute(
            select(Student).where(Student.user_id == user_id)
        )
        student = student_result.scalar_one_or_none()
        if student:
            gs_result = await db.execute(
                select(GroupStudent).where(GroupStudent.student_id == student.id)
            )
            gs = gs_result.scalar_one_or_none()
            if gs:
                return await list_by_group(gs.group_id, db)

    return []


async def update_horario(horario_id: uuid.UUID, data: HorarioUpdate, db: AsyncSession) -> HorarioClase:
    h = await db.get(HorarioClase, horario_id)
    if not h:
        raise BusinessError("NOT_FOUND", "Entrada de horario no encontrada", status_code=404)
    for field, value in data.model_dump(exclude_none=True).items():
        setattr(h, field, value)
    await db.commit()
    await db.refresh(h)
    return h


async def delete_horario(horario_id: uuid.UUID, db: AsyncSession) -> None:
    h = await db.get(HorarioClase, horario_id)
    if not h:
        raise BusinessError("NOT_FOUND", "Entrada de horario no encontrada", status_code=404)
    await db.delete(h)
    await db.commit()
