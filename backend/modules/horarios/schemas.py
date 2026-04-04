import uuid
from datetime import time
from typing import Optional

from pydantic import BaseModel


class HorarioCreate(BaseModel):
    group_id: uuid.UUID
    subject_id: uuid.UUID
    teacher_id: uuid.UUID
    dia_semana: int  # 0-4
    hora_inicio: time
    hora_fin: time
    aula: Optional[str] = None


class HorarioUpdate(BaseModel):
    dia_semana: Optional[int] = None
    hora_inicio: Optional[time] = None
    hora_fin: Optional[time] = None
    aula: Optional[str] = None


class HorarioResponse(BaseModel):
    id: uuid.UUID
    group_id: uuid.UUID
    subject_id: uuid.UUID
    teacher_id: uuid.UUID
    dia_semana: int
    hora_inicio: time
    hora_fin: time
    aula: Optional[str] = None
    # Enriched fields (optional, populated by service)
    subject_nombre: Optional[str] = None
    teacher_nombre: Optional[str] = None
    group_nombre: Optional[str] = None

    model_config = {"from_attributes": True}
