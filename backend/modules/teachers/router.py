# backend/modules/teachers/router.py
import uuid

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from core.database import get_db
from core.security import get_current_user, require_roles
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


@router.get("/mi-perfil")
async def mi_perfil(
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Returns the teacher profile linked to the currently authenticated user."""
    from sqlalchemy import select
    from modules.teachers.models import Teacher
    result = await db.execute(
        select(Teacher).where(Teacher.user_id == uuid.UUID(current_user["user_id"]))
    )
    teacher = result.scalar_one_or_none()
    if not teacher:
        from core.exceptions import BusinessError
        raise BusinessError(
            "NO_TEACHER_PROFILE",
            "No tienes un perfil de docente vinculado a tu cuenta",
            status_code=404,
        )
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


@router.delete("/{teacher_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_teacher(
    teacher_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    await service.delete_teacher(teacher_id, db)
