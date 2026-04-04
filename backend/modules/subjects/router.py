# backend/modules/subjects/router.py
import uuid

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from core.database import get_db
from core.security import require_roles
from modules.subjects import service
from modules.subjects.schemas import SubjectCreate, SubjectResponse, SubjectUpdate

router = APIRouter(prefix="/api/v1/subjects", tags=["subjects"])
_admin = ["directivo", "control_escolar"]
_read = ["directivo", "control_escolar", "docente", "alumno"]


@router.post("/", status_code=status.HTTP_201_CREATED)
async def create_subject(
    data: SubjectCreate,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    subject = await service.create_subject(data, db)
    return {"data": SubjectResponse.model_validate(subject).model_dump(mode="json")}


@router.get("/")
async def list_subjects(
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_read)),
):
    subjects = await service.list_subjects(db)
    return {"data": [SubjectResponse.model_validate(s).model_dump(mode="json") for s in subjects]}


@router.get("/{subject_id}")
async def get_subject(
    subject_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_read)),
):
    subject = await service.get_subject_by_id(subject_id, db)
    return {"data": SubjectResponse.model_validate(subject).model_dump(mode="json")}


@router.patch("/{subject_id}")
async def update_subject(
    subject_id: uuid.UUID,
    data: SubjectUpdate,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    subject = await service.update_subject(subject_id, data, db)
    return {"data": SubjectResponse.model_validate(subject).model_dump(mode="json")}


@router.delete("/{subject_id}", status_code=status.HTTP_200_OK)
async def deactivate_subject(
    subject_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    subject = await service.deactivate_subject(subject_id, db)
    return {"data": SubjectResponse.model_validate(subject).model_dump(mode="json")}
