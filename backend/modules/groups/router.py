# backend/modules/groups/router.py
import uuid
from typing import Optional

from fastapi import APIRouter, Depends, Query, status  # noqa: F401
from sqlalchemy.ext.asyncio import AsyncSession

from core.database import get_db
from core.security import get_current_user, require_roles
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


@router.get("/mis-grupos")
async def mis_grupos(
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Returns all groups assigned to the currently authenticated teacher.
    Resolves user_id → Teacher → GroupTeacher, supporting multiple groups per teacher."""
    groups = await service.list_groups_by_user_id(
        uuid.UUID(current_user["user_id"]), db
    )
    return {"data": [GroupResponse.model_validate(g) for g in groups]}


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
    teacher_id: Optional[uuid.UUID] = Query(None),
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin + ["docente"])),
):
    if teacher_id:
        groups = await service.list_groups_by_teacher(teacher_id, db)
    else:
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


@router.get("/{group_id}/students")
async def list_group_students(
    group_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin + ["docente"])),
):
    from modules.students.schemas import StudentResponse
    students = await service.list_students_by_group(group_id, db)
    return {"data": [StudentResponse.model_validate(s) for s in students]}


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


@router.delete("/{group_id}/students/{student_id}", status_code=status.HTTP_200_OK)
async def remove_student(
    group_id: uuid.UUID,
    student_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    result = await service.remove_student(group_id, student_id, db)
    return {"data": result}


@router.delete("/{group_id}", status_code=status.HTTP_200_OK)
async def deactivate_group(
    group_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    group = await service.deactivate_group(group_id, db)
    return {"data": GroupResponse.model_validate(group).model_dump(mode="json")}
