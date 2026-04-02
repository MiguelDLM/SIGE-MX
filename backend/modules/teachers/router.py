# backend/modules/teachers/router.py
import uuid

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from core.database import get_db
from core.security import require_roles
from modules.teachers import service
from modules.teachers.schemas import TeacherCreate, TeacherResponse, TeacherUpdate

router = APIRouter(prefix="/api/v1/teachers", tags=["teachers"])
_admin = ["directivo", "control_escolar"]


@router.post("/", status_code=status.HTTP_201_CREATED)
async def create_teacher(
    data: TeacherCreate,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    teacher = await service.create_teacher(data, db)
    return {"data": TeacherResponse.model_validate(teacher)}


@router.get("/")
async def list_teachers(
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin + ["docente"])),
):
    teachers = await service.list_teachers(db)
    return {"data": [TeacherResponse.model_validate(t) for t in teachers]}


@router.get("/{teacher_id}")
async def get_teacher(
    teacher_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    teacher = await service.get_teacher_by_id(teacher_id, db)
    return {"data": TeacherResponse.model_validate(teacher)}


@router.patch("/{teacher_id}")
async def update_teacher(
    teacher_id: uuid.UUID,
    data: TeacherUpdate,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    teacher = await service.update_teacher(teacher_id, data, db)
    return {"data": TeacherResponse.model_validate(teacher)}
