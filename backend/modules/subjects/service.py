# backend/modules/subjects/service.py
import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from core.exceptions import BusinessError
from modules.subjects.models import Subject
from modules.subjects.schemas import SubjectCreate, SubjectUpdate


async def create_subject(data: SubjectCreate, db: AsyncSession) -> Subject:
    subject = Subject(**data.model_dump())
    db.add(subject)
    await db.commit()
    await db.refresh(subject)
    return subject


async def list_subjects(db: AsyncSession) -> list[Subject]:
    result = await db.execute(select(Subject).order_by(Subject.nombre))
    return list(result.scalars())


async def get_subject_by_id(subject_id: uuid.UUID, db: AsyncSession) -> Subject:
    result = await db.execute(select(Subject).where(Subject.id == subject_id))
    subject = result.scalar_one_or_none()
    if subject is None:
        raise BusinessError("SUBJECT_NOT_FOUND", "Materia no encontrada", status_code=404)
    return subject


async def update_subject(
    subject_id: uuid.UUID, data: SubjectUpdate, db: AsyncSession
) -> Subject:
    subject = await get_subject_by_id(subject_id, db)
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(subject, field, value)
    await db.commit()
    await db.refresh(subject)
    return subject
