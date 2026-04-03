import uuid
from datetime import date
from typing import Optional

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession

from core.database import get_db
from core.security import get_current_user, require_roles
from modules.justifications import service
from modules.justifications.schemas import JustificationResponse, JustificationReview

router = APIRouter(prefix="/api/v1/justifications", tags=["justifications"])
_write = ["padre", "alumno", "control_escolar"]
_read = ["docente", "control_escolar", "directivo"]
_review = ["control_escolar", "directivo"]

MAX_FILE_SIZE = 5 * 1024 * 1024  # 5 MB


@router.post("/", status_code=status.HTTP_201_CREATED)
async def create_justification(
    student_id: uuid.UUID = Form(...),
    fecha_inicio: date = Form(...),
    fecha_fin: Optional[date] = Form(None),
    motivo: Optional[str] = Form(None),
    file: Optional[UploadFile] = File(None),
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_write)),
):
    file_data = None
    if file and file.filename:
        data = await file.read()
        if len(data) > MAX_FILE_SIZE:
            raise HTTPException(status_code=413, detail="Archivo demasiado grande (máx 5 MB)")
        file_data = (data, file.filename, file.content_type or "application/octet-stream")

    record = await service.create_justification(
        student_id=student_id,
        fecha_inicio=fecha_inicio,
        fecha_fin=fecha_fin,
        motivo=motivo,
        file_data=file_data,
        db=db,
    )
    return {"data": JustificationResponse.model_validate(record)}


@router.get("/my")
async def list_my_justifications(
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    records = await service.list_my_justifications(
        uuid.UUID(current_user["user_id"]), db
    )
    return {"data": [JustificationResponse.model_validate(r) for r in records]}


@router.get("/")
async def list_justifications(
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_read)),
):
    records = await service.list_justifications(db)
    return {"data": [JustificationResponse.model_validate(r) for r in records]}


@router.patch("/{justification_id}/review")
async def review_justification(
    justification_id: uuid.UUID,
    data: JustificationReview,
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(require_roles(_review)),
):
    record = await service.review_justification(
        justification_id=justification_id,
        data=data,
        reviewed_by=uuid.UUID(current_user["user_id"]),
        db=db,
    )
    return {"data": JustificationResponse.model_validate(record)}
