# backend/modules/attendance/router.py
import uuid
from datetime import date

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from core.database import get_db
from core.security import require_roles
from modules.attendance import service
from modules.attendance.schemas import AttendanceCreate, AttendanceResponse, AttendanceUpdate

router = APIRouter(prefix="/api/v1/attendance", tags=["attendance"])
_write = ["docente", "control_escolar", "directivo"]
_read = ["docente", "control_escolar", "directivo", "padre", "alumno"]
_admin_read = ["control_escolar", "directivo"]


@router.post("/", status_code=status.HTTP_201_CREATED)
async def register_attendance(
    data: AttendanceCreate,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_write)),
):
    record = await service.register_attendance(data, db)
    return {"data": AttendanceResponse.model_validate(record)}


@router.put("/{attendance_id}")
async def update_attendance(
    attendance_id: uuid.UUID,
    data: AttendanceUpdate,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_write)),
):
    record = await service.update_attendance(attendance_id, data, db)
    return {"data": AttendanceResponse.model_validate(record)}


@router.get("/group/{group_id}")
async def list_by_group(
    group_id: uuid.UUID,
    fecha: date = Query(..., description="Fecha en formato YYYY-MM-DD"),
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_read)),
):
    records = await service.list_attendance_by_group(group_id, fecha, db)
    return {"data": [AttendanceResponse.model_validate(r) for r in records]}


@router.get("/student/{student_id}")
async def list_by_student(
    student_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin_read)),
):
    records = await service.list_attendance_by_student(student_id, db)
    return {"data": [AttendanceResponse.model_validate(r) for r in records]}
