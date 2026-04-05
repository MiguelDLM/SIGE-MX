# backend/modules/teachers/schemas.py
import uuid
from datetime import date, datetime
from typing import Optional

from pydantic import BaseModel


class TeacherCreate(BaseModel):
    numero_empleado: Optional[str] = None
    especialidad: Optional[str] = None
    nombre: str
    apellido_paterno: Optional[str] = None
    apellido_materno: Optional[str] = None
    email: Optional[str] = None
    curp: Optional[str] = None
    fecha_nacimiento: Optional[date] = None
    fecha_contratacion: Optional[date] = None
    user_id: Optional[uuid.UUID] = None


class TeacherUpdate(BaseModel):
    nombre: Optional[str] = None
    apellido_paterno: Optional[str] = None
    apellido_materno: Optional[str] = None
    especialidad: Optional[str] = None
    numero_empleado: Optional[str] = None
    email: Optional[str] = None
    curp: Optional[str] = None
    fecha_nacimiento: Optional[date] = None
    fecha_contratacion: Optional[date] = None
    # Allows admin to link an existing user account to this teacher profile
    user_id: Optional[uuid.UUID] = None


class TeacherResponse(BaseModel):
    id: uuid.UUID
    numero_empleado: Optional[str] = None
    especialidad: Optional[str] = None
    nombre: str
    apellido_paterno: Optional[str] = None
    email: Optional[str] = None
    curp: Optional[str] = None
    fecha_nacimiento: Optional[date] = None
    user_id: Optional[uuid.UUID] = None

    model_config = {"from_attributes": True}
