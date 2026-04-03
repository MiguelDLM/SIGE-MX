# backend/modules/reports/schemas.py
import uuid
from datetime import datetime

from pydantic import BaseModel


class ReportMeta(BaseModel):
    id: uuid.UUID
    student_id: uuid.UUID | None
    tipo: str | None
    created_at: datetime

    model_config = {"from_attributes": True}
