# backend/modules/groups/schemas.py
import uuid
from typing import Optional

from pydantic import BaseModel


class GroupCreate(BaseModel):
    nombre: Optional[str] = None
    grado: Optional[int] = None
    seccion: Optional[str] = None
    nivel: Optional[str] = None
    turno: Optional[str] = None
    ciclo_id: Optional[uuid.UUID] = None


class GroupUpdate(BaseModel):
    nombre: Optional[str] = None
    grado: Optional[int] = None
    seccion: Optional[str] = None
    nivel: Optional[str] = None
    turno: Optional[str] = None
    ciclo_id: Optional[uuid.UUID] = None
    activo: Optional[bool] = None


class GroupResponse(BaseModel):
    id: uuid.UUID
    nombre: Optional[str] = None
    grado: Optional[int] = None
    seccion: Optional[str] = None
    nivel: Optional[str] = None
    turno: Optional[str] = None
    ciclo_id: Optional[uuid.UUID] = None
    activo: bool = True

    model_config = {"from_attributes": True}


class AssignStudentRequest(BaseModel):
    student_id: uuid.UUID


class AssignTeacherRequest(BaseModel):
    teacher_id: uuid.UUID
    subject_id: uuid.UUID
