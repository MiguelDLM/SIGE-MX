# backend/modules/grades/service.py
import uuid
from typing import Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from core.exceptions import BusinessError
from modules.grades.models import Evaluation, Grade
from modules.grades.schemas import EvaluationCreate, GradeCreate, GradeUpdate


async def create_evaluation(data: EvaluationCreate, db: AsyncSession) -> Evaluation:
    evaluation = Evaluation(**data.model_dump())
    db.add(evaluation)
    await db.commit()
    await db.refresh(evaluation)
    return evaluation


async def list_evaluations(
    db: AsyncSession,
    group_id: Optional[uuid.UUID] = None,
    subject_id: Optional[uuid.UUID] = None,
) -> list[Evaluation]:
    stmt = select(Evaluation).order_by(Evaluation.fecha.desc().nullslast())
    if group_id:
        stmt = stmt.where(Evaluation.group_id == group_id)
    if subject_id:
        stmt = stmt.where(Evaluation.subject_id == subject_id)
    result = await db.execute(stmt)
    return list(result.scalars())


async def create_grade(data: GradeCreate, db: AsyncSession) -> Grade:
    grade = Grade(**data.model_dump())
    db.add(grade)
    await db.commit()
    await db.refresh(grade)
    return grade


async def update_grade(
    grade_id: uuid.UUID, data: GradeUpdate, db: AsyncSession
) -> Grade:
    result = await db.execute(select(Grade).where(Grade.id == grade_id))
    grade = result.scalar_one_or_none()
    if grade is None:
        raise BusinessError("GRADE_NOT_FOUND", "Calificación no encontrada", status_code=404)
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(grade, field, value)
    await db.commit()
    await db.refresh(grade)
    return grade


async def list_grades_by_student(
    student_id: uuid.UUID, db: AsyncSession
) -> list[Grade]:
    result = await db.execute(
        select(Grade)
        .where(Grade.student_id == student_id)
        .order_by(Grade.created_at.desc())
    )
    return list(result.scalars())
