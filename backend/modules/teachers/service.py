# backend/modules/teachers/service.py
import uuid

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from core.exceptions import BusinessError
from modules.teachers.models import Teacher
from modules.teachers.schemas import TeacherCreate, TeacherUpdate


async def create_teacher(data: TeacherCreate, db: AsyncSession) -> Teacher:
    teacher = Teacher(**data.model_dump())
    db.add(teacher)
    try:
        await db.flush()
    except IntegrityError:
        await db.rollback()
        raise BusinessError(
            "DUPLICATE_NUMERO_EMPLEADO",
            "El número de empleado ya existe",
            status_code=409,
        )
    await db.commit()
    await db.refresh(teacher)
    return teacher


async def get_teacher_by_id(teacher_id: uuid.UUID, db: AsyncSession) -> Teacher:
    result = await db.execute(select(Teacher).where(Teacher.id == teacher_id))
    teacher = result.scalar_one_or_none()
    if teacher is None:
        raise BusinessError("TEACHER_NOT_FOUND", "Docente no encontrado", status_code=404)
    return teacher


async def list_teachers(db: AsyncSession) -> list[Teacher]:
    result = await db.execute(
        select(Teacher).order_by(Teacher.apellido_paterno, Teacher.nombre)
    )
    return list(result.scalars())


async def update_teacher(
    teacher_id: uuid.UUID, data: TeacherUpdate, db: AsyncSession
) -> Teacher:
    teacher = await get_teacher_by_id(teacher_id, db)
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(teacher, field, value)
    await db.commit()
    await db.refresh(teacher)
    return teacher
