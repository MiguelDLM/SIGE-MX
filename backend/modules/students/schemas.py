# backend/modules/students/schemas.py
import uuid
from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class StudentCreate(BaseModel):
    matricula: str
    nombre: str
    apellido_paterno: Optional[str] = None
    apellido_materno: Optional[str] = None
    numero_seguro_social: Optional[str] = None
    tipo_sangre: Optional[str] = None
    direccion: Optional[str] = None
    municipio: Optional[str] = None
    estado: Optional[str] = None
    codigo_postal: Optional[str] = None
    user_id: Optional[uuid.UUID] = None


class StudentUpdate(BaseModel):
    nombre: Optional[str] = None
    apellido_paterno: Optional[str] = None
    apellido_materno: Optional[str] = None
    direccion: Optional[str] = None
    municipio: Optional[str] = None
    estado: Optional[str] = None
    codigo_postal: Optional[str] = None


class StudentResponse(BaseModel):
    id: uuid.UUID
    matricula: str
    nombre: Optional[str] = None
    apellido_paterno: Optional[str] = None
    apellido_materno: Optional[str] = None
    municipio: Optional[str] = None
    estado: Optional[str] = None
    created_at: datetime

    model_config = {"from_attributes": True}
