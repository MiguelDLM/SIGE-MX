import uuid

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from core.database import get_db
from core.security import get_current_user, require_roles
from modules.horarios import service
from modules.horarios.schemas import HorarioCreate, HorarioResponse, HorarioUpdate

router = APIRouter(prefix="/api/v1/horarios", tags=["horarios"])
_admin = ["directivo", "control_escolar"]
_read = ["directivo", "control_escolar", "docente", "alumno", "tutor"]


@router.get("/mi-horario")
async def mi_horario(
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    entries = await service.mi_horario(
        user_id=uuid.UUID(current_user["user_id"]),
        roles=current_user.get("roles", []),
        db=db,
    )
    return {"data": [e.model_dump(mode="json") for e in entries]}


@router.get("/grupo/{group_id}")
async def horario_grupo(
    group_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_read)),
):
    entries = await service.list_by_group(group_id, db)
    return {"data": [e.model_dump(mode="json") for e in entries]}


@router.get("/maestro/{teacher_id}")
async def horario_maestro(
    teacher_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin + ["docente"])),
):
    entries = await service.list_by_teacher(teacher_id, db)
    return {"data": [e.model_dump(mode="json") for e in entries]}


@router.post("/", status_code=status.HTTP_201_CREATED)
async def create_horario(
    data: HorarioCreate,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    h = await service.create_horario(data, db)
    enriched = await service._enrich(h, db)
    return {"data": enriched.model_dump(mode="json")}


@router.patch("/{horario_id}")
async def update_horario(
    horario_id: uuid.UUID,
    data: HorarioUpdate,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    h = await service.update_horario(horario_id, data, db)
    enriched = await service._enrich(h, db)
    return {"data": enriched.model_dump(mode="json")}


@router.delete("/{horario_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_horario(
    horario_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    await service.delete_horario(horario_id, db)
