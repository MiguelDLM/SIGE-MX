# backend/modules/attendance/schemas.py
import uuid
from datetime import date
from typing import Optional

from pydantic import BaseModel

from modules.attendance.models import AttendanceStatus


class AttendanceCreate(BaseModel):
    student_id: uuid.UUID
    group_id: uuid.UUID
    fecha: date
    status: AttendanceStatus
    observaciones: Optional[str] = None


class AttendanceUpdate(BaseModel):
    status: Optional[AttendanceStatus] = None
    observaciones: Optional[str] = None


class AttendanceResponse(BaseModel):
    id: uuid.UUID
    student_id: uuid.UUID
    group_id: uuid.UUID
    fecha: date
    status: AttendanceStatus
    observaciones: Optional[str] = None

    model_config = {"from_attributes": True}
