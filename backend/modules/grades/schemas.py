# backend/modules/grades/schemas.py
import uuid
from datetime import date, datetime
from decimal import Decimal
from typing import Optional

from pydantic import BaseModel

from modules.grades.models import EvaluationType


class EvaluationCreate(BaseModel):
    titulo: str
    tipo: Optional[EvaluationType] = None
    subject_id: Optional[uuid.UUID] = None
    group_id: Optional[uuid.UUID] = None
    descripcion: Optional[str] = None
    fecha: Optional[date] = None
    porcentaje: Optional[Decimal] = None


class EvaluationResponse(BaseModel):
    id: uuid.UUID
    titulo: Optional[str] = None
    tipo: Optional[EvaluationType] = None
    subject_id: Optional[uuid.UUID] = None
    group_id: Optional[uuid.UUID] = None
    fecha: Optional[date] = None
    porcentaje: Optional[Decimal] = None

    model_config = {"from_attributes": True}


class GradeCreate(BaseModel):
    evaluation_id: uuid.UUID
    student_id: uuid.UUID
    calificacion: Optional[Decimal] = None
    observaciones: Optional[str] = None


class GradeUpdate(BaseModel):
    calificacion: Optional[Decimal] = None
    observaciones: Optional[str] = None


class GradeResponse(BaseModel):
    id: uuid.UUID
    evaluation_id: Optional[uuid.UUID] = None
    student_id: Optional[uuid.UUID] = None
    calificacion: Optional[Decimal] = None
    observaciones: Optional[str] = None
    created_at: datetime

    model_config = {"from_attributes": True}
