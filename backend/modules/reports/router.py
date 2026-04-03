# backend/modules/reports/router.py
import io
import uuid

from fastapi import APIRouter, Depends
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession

from core.database import get_db
from core.security import require_roles
from modules.reports import service

router = APIRouter(prefix="/api/v1/reports", tags=["reports"])
_allowed = ["control_escolar", "directivo", "padre", "alumno"]


@router.get("/students/{student_id}/boleta")
async def get_boleta(
    student_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_allowed)),
):
    pdf_bytes, matricula = await service.generate_boleta(student_id, db)
    filename = f"boleta_{matricula}.pdf"
    return StreamingResponse(
        io.BytesIO(pdf_bytes),
        media_type="application/pdf",
        headers={"Content-Disposition": f'inline; filename="{filename}"'},
    )


@router.get("/students/{student_id}/constancia")
async def get_constancia(
    student_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_allowed)),
):
    pdf_bytes, matricula = await service.generate_constancia(student_id, db)
    filename = f"constancia_{matricula}.pdf"
    return StreamingResponse(
        io.BytesIO(pdf_bytes),
        media_type="application/pdf",
        headers={"Content-Disposition": f'inline; filename="{filename}"'},
    )
