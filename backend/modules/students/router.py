# backend/modules/students/router.py
import uuid
from typing import Optional

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from core.database import get_db
from core.security import get_current_user, require_roles
from modules.students import service
from modules.students.schemas import StudentCreate, StudentResponse, StudentUpdate

router = APIRouter(prefix="/api/v1/students", tags=["students"])
_admin = ["directivo", "control_escolar"]
_read = ["directivo", "control_escolar", "docente"]


@router.post("/", status_code=status.HTTP_201_CREATED)
async def create_student(
    data: StudentCreate,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    student = await service.create_student(data, db)
    return {"data": StudentResponse.model_validate(student)}


@router.get("/")
async def list_students(
    page: int = Query(1, ge=1),
    size: int = Query(20, ge=1, le=100),
    search: Optional[str] = Query(None),
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_read)),
):
    students, total = await service.list_students(db, page, size, search)
    pages = (total + size - 1) // size
    return {
        "data": [StudentResponse.model_validate(s) for s in students],
        "total": total,
        "page": page,
        "size": size,
        "pages": pages,
    }


@router.get("/my")
async def list_my_students(
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    students = await service.list_my_students(uuid.UUID(current_user["user_id"]), db)
    return {"data": [StudentResponse.model_validate(s) for s in students]}


@router.get("/{student_id}")
async def get_student(
    student_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_read)),
):
    student = await service.get_student_by_id(student_id, db)
    return {"data": StudentResponse.model_validate(student)}


@router.patch("/{student_id}")
async def update_student(
    student_id: uuid.UUID,
    data: StudentUpdate,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    student = await service.update_student(student_id, data, db)
    return {"data": StudentResponse.model_validate(student)}
