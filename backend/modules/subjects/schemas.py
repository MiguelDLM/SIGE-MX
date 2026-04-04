# backend/modules/subjects/schemas.py
import uuid
from typing import Optional

from pydantic import BaseModel


class SubjectCreate(BaseModel):
    nombre: Optional[str] = None
    clave: Optional[str] = None
    horas_semana: Optional[int] = None


class SubjectUpdate(BaseModel):
    nombre: Optional[str] = None
    clave: Optional[str] = None
    horas_semana: Optional[int] = None


class SubjectResponse(BaseModel):
    id: uuid.UUID
    nombre: Optional[str] = None
    clave: Optional[str] = None
    horas_semana: Optional[int] = None
    activo: bool = True

    model_config = {"from_attributes": True}
