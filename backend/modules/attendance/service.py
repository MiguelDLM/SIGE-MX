# backend/modules/attendance/service.py
import uuid
from datetime import date

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from core.exceptions import BusinessError
from modules.attendance.models import Attendance
from modules.attendance.schemas import AttendanceCreate, AttendanceUpdate


async def register_attendance(data: AttendanceCreate, db: AsyncSession) -> Attendance:
    record = Attendance(**data.model_dump())
    db.add(record)
    try:
        await db.flush()
    except IntegrityError:
        await db.rollback()
        raise BusinessError(
            "DUPLICATE_ATTENDANCE",
            "Ya existe un registro de asistencia para este alumno en esta fecha",
            status_code=409,
        )
    await db.commit()
    await db.refresh(record)
    return record


async def update_attendance(
    attendance_id: uuid.UUID, data: AttendanceUpdate, db: AsyncSession
) -> Attendance:
    result = await db.execute(select(Attendance).where(Attendance.id == attendance_id))
    record = result.scalar_one_or_none()
    if record is None:
        raise BusinessError("ATTENDANCE_NOT_FOUND", "Registro de asistencia no encontrado", status_code=404)
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(record, field, value)
    await db.commit()
    await db.refresh(record)
    return record


async def list_attendance_by_group(
    group_id: uuid.UUID, fecha: date, db: AsyncSession
) -> list[Attendance]:
    result = await db.execute(
        select(Attendance)
        .where(Attendance.group_id == group_id, Attendance.fecha == fecha)
        .order_by(Attendance.student_id)
    )
    return list(result.scalars())


async def list_attendance_by_student(
    student_id: uuid.UUID, db: AsyncSession
) -> list[Attendance]:
    result = await db.execute(
        select(Attendance)
        .where(Attendance.student_id == student_id)
        .order_by(Attendance.fecha.desc())
    )
    return list(result.scalars())
