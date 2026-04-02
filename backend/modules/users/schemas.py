import uuid
from datetime import date, datetime
from typing import Optional

from pydantic import BaseModel, EmailStr


class UserCreate(BaseModel):
    email: Optional[EmailStr] = None
    password: str
    telefono: Optional[str] = None
    nombre: str
    apellido_paterno: Optional[str] = None
    apellido_materno: Optional[str] = None
    curp: Optional[str] = None
    fecha_nacimiento: Optional[date] = None
    roles: list[str] = []


class UserUpdate(BaseModel):
    telefono: Optional[str] = None
    nombre: Optional[str] = None
    apellido_paterno: Optional[str] = None
    apellido_materno: Optional[str] = None
    status: Optional[str] = None


class UserResponse(BaseModel):
    id: uuid.UUID
    email: Optional[str] = None
    telefono: Optional[str] = None
    nombre: str
    apellido_paterno: Optional[str] = None
    apellido_materno: Optional[str] = None
    curp: Optional[str] = None
    status: str
    created_at: datetime
    roles: list[str] = []

    model_config = {"from_attributes": True}
