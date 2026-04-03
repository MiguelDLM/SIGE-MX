# backend/modules/students/service.py
import uuid

from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from core.exceptions import BusinessError
from modules.students.models import Student
from modules.students.schemas import StudentCreate, StudentUpdate


async def create_student(data: StudentCreate, db: AsyncSession) -> Student:
    student = Student(**data.model_dump())
    db.add(student)
    try:
        await db.flush()
    except IntegrityError:
        await db.rollback()
        raise BusinessError(
            "DUPLICATE_MATRICULA", "La matrícula ya está registrada", status_code=409
        )
    await db.commit()
    await db.refresh(student)
    return student


async def get_student_by_id(student_id: uuid.UUID, db: AsyncSession) -> Student:
    result = await db.execute(select(Student).where(Student.id == student_id))
    student = result.scalar_one_or_none()
    if student is None:
        raise BusinessError("STUDENT_NOT_FOUND", "Alumno no encontrado", status_code=404)
    return student


async def list_students(
    db: AsyncSession, page: int = 1, size: int = 20
) -> tuple[list[Student], int]:
    total_result = await db.execute(select(func.count()).select_from(Student))
    total = total_result.scalar_one()
    result = await db.execute(
        select(Student)
        .order_by(Student.apellido_paterno, Student.nombre)
        .offset((page - 1) * size)
        .limit(size)
    )
    return list(result.scalars()), total


async def list_my_students(
    user_id: uuid.UUID, db: AsyncSession
) -> list[Student]:
    from modules.students.models import Parent, StudentParent
    results: list[Student] = []

    direct = await db.execute(
        select(Student).where(Student.user_id == user_id)
    )
    results.extend(direct.scalars().all())

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


async def update_student(
    student_id: uuid.UUID, data: StudentUpdate, db: AsyncSession
) -> Student:
    student = await get_student_by_id(student_id, db)
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(student, field, value)
    await db.commit()
    await db.refresh(student)
    return student
