# backend/modules/academic_cycles/schemas.py
import uuid
from datetime import date
from typing import Optional

from pydantic import BaseModel


class AcademicCycleCreate(BaseModel):
    nombre: Optional[str] = None
    fecha_inicio: Optional[date] = None
    fecha_fin: Optional[date] = None
    activo: bool = True


class AcademicCycleUpdate(BaseModel):
    nombre: Optional[str] = None
    fecha_inicio: Optional[date] = None
    fecha_fin: Optional[date] = None
    activo: Optional[bool] = None


class AcademicCycleResponse(BaseModel):
    id: uuid.UUID
    nombre: Optional[str] = None
    fecha_inicio: Optional[date] = None
    fecha_fin: Optional[date] = None
    activo: bool

    model_config = {"from_attributes": True}
