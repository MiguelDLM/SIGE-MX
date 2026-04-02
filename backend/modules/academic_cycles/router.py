# backend/modules/academic_cycles/router.py
import uuid

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from core.database import get_db
from core.security import require_roles
from modules.academic_cycles import service
from modules.academic_cycles.schemas import (
    AcademicCycleCreate,
    AcademicCycleResponse,
    AcademicCycleUpdate,
)

router = APIRouter(prefix="/api/v1/academic-cycles", tags=["academic-cycles"])
_admin = ["directivo", "control_escolar"]


@router.post("/", status_code=status.HTTP_201_CREATED)
async def create_cycle(
    data: AcademicCycleCreate,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    cycle = await service.create_cycle(data, db)
    return {"data": AcademicCycleResponse.model_validate(cycle)}


@router.get("/active")
async def get_active_cycle(
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin + ["docente"])),
):
    cycle = await service.get_active_cycle(db)
    return {"data": AcademicCycleResponse.model_validate(cycle)}


@router.get("/")
async def list_cycles(
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    cycles = await service.list_cycles(db)
    return {"data": [AcademicCycleResponse.model_validate(c) for c in cycles]}


@router.get("/{cycle_id}")
async def get_cycle(
    cycle_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    cycle = await service.get_cycle_by_id(cycle_id, db)
    return {"data": AcademicCycleResponse.model_validate(cycle)}


@router.patch("/{cycle_id}")
async def update_cycle(
    cycle_id: uuid.UUID,
    data: AcademicCycleUpdate,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    cycle = await service.update_cycle(cycle_id, data, db)
    return {"data": AcademicCycleResponse.model_validate(cycle)}
