import uuid
from datetime import date
from typing import Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from core import storage
from core.exceptions import BusinessError
from modules.justifications.models import Justification, JustificationStatus
from modules.justifications.schemas import JustificationReview


async def create_justification(
    student_id: uuid.UUID,
    fecha_inicio: date,
    fecha_fin: Optional[date],
    motivo: Optional[str],
    file_data: Optional[tuple[bytes, str, str]],
    db: AsyncSession,
) -> Justification:
    archivo_url = None
    if file_data:
        data, filename, content_type = file_data
        ext = filename.rsplit(".", 1)[-1].lower() if "." in filename else "bin"
        key = f"{student_id}/{uuid.uuid4()}.{ext}"
        archivo_url = await storage.upload_file("justifications", key, data, content_type)

    record = Justification(
        student_id=student_id,
        fecha_inicio=fecha_inicio,
        fecha_fin=fecha_fin,
        motivo=motivo,
        archivo_url=archivo_url,
        status=JustificationStatus.pendiente,
    )
    db.add(record)
    await db.commit()
    await db.refresh(record)
    return record


async def list_justifications(db: AsyncSession) -> list[Justification]:
    result = await db.execute(
        select(Justification).order_by(Justification.created_at.desc())
    )
    return list(result.scalars())


async def review_justification(
    justification_id: uuid.UUID,
    data: JustificationReview,
    reviewed_by: uuid.UUID,
    db: AsyncSession,
) -> Justification:
    result = await db.execute(
        select(Justification).where(Justification.id == justification_id)
    )
    record = result.scalar_one_or_none()
    if record is None:
        raise BusinessError("JUSTIFICATION_NOT_FOUND", "Justificante no encontrado", status_code=404)
    record.status = data.status
    record.reviewed_by = reviewed_by
    await db.commit()
    await db.refresh(record)
    return record
