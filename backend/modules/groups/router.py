# backend/modules/groups/router.py
import uuid

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from core.database import get_db
from core.security import require_roles
from modules.groups import service
from modules.groups.schemas import (
    AssignStudentRequest,
    AssignTeacherRequest,
    GroupCreate,
    GroupResponse,
    GroupUpdate,
)

router = APIRouter(prefix="/api/v1/groups", tags=["groups"])
_admin = ["directivo", "control_escolar"]


@router.post("/", status_code=status.HTTP_201_CREATED)
async def create_group(
    data: GroupCreate,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    group = await service.create_group(data, db)
    return {"data": GroupResponse.model_validate(group)}


@router.get("/")
async def list_groups(
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin + ["docente"])),
):
    groups = await service.list_groups(db)
    return {"data": [GroupResponse.model_validate(g) for g in groups]}


@router.get("/{group_id}")
async def get_group(
    group_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin + ["docente"])),
):
    group = await service.get_group_by_id(group_id, db)
    return {"data": GroupResponse.model_validate(group)}


@router.patch("/{group_id}")
async def update_group(
    group_id: uuid.UUID,
    data: GroupUpdate,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    group = await service.update_group(group_id, data, db)
    return {"data": GroupResponse.model_validate(group)}


@router.post("/{group_id}/students")
async def assign_student(
    group_id: uuid.UUID,
    data: AssignStudentRequest,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    result = await service.assign_student(group_id, data, db)
    return {"data": result}


@router.post("/{group_id}/teachers")
async def assign_teacher(
    group_id: uuid.UUID,
    data: AssignTeacherRequest,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    result = await service.assign_teacher(group_id, data, db)
    return {"data": result}
