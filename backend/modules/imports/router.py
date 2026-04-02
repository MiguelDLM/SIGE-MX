# backend/modules/imports/router.py
from fastapi import APIRouter, Depends, UploadFile, File
from fastapi.responses import Response
from sqlalchemy.ext.asyncio import AsyncSession

from core.database import get_db
from core.security import require_roles
from modules.imports import service
from modules.imports.schemas import ImportResult

router = APIRouter(prefix="/api/v1/imports", tags=["imports"])
_admin = ["directivo", "control_escolar"]

MAX_FILE_SIZE = 5 * 1024 * 1024  # 5 MB


@router.post("/students")
async def import_students(
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    content = await file.read(MAX_FILE_SIZE + 1)
    result = await service.import_students(content, file.filename or "upload.csv", db)
    return {"data": result.model_dump()}


@router.post("/teachers")
async def import_teachers(
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    content = await file.read(MAX_FILE_SIZE + 1)
    result = await service.import_teachers(content, file.filename or "upload.csv", db)
    return {"data": result.model_dump()}


@router.get("/template/students")
async def student_template(
    _: dict = Depends(require_roles(_admin)),
):
    xlsx_bytes = service.get_student_template()
    return Response(
        content=xlsx_bytes,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": "attachment; filename=plantilla_alumnos.xlsx"},
    )


@router.get("/template/teachers")
async def teacher_template(
    _: dict = Depends(require_roles(_admin)),
):
    xlsx_bytes = service.get_teacher_template()
    return Response(
        content=xlsx_bytes,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": "attachment; filename=plantilla_docentes.xlsx"},
    )
