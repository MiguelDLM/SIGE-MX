import uuid
from datetime import date, datetime
from typing import Optional

from pydantic import BaseModel

from modules.justifications.models import JustificationStatus


class JustificationReview(BaseModel):
    status: JustificationStatus


class JustificationResponse(BaseModel):
    id: uuid.UUID
    student_id: Optional[uuid.UUID] = None
    fecha_inicio: Optional[date] = None
    fecha_fin: Optional[date] = None
    motivo: Optional[str] = None
    archivo_url: Optional[str] = None
    status: Optional[JustificationStatus] = None
    reviewed_by: Optional[uuid.UUID] = None
    created_at: datetime

    model_config = {"from_attributes": True}
