from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from core.database import get_db
from core.security import require_roles
from modules.school_config import service
from modules.school_config.schemas import SchoolConfigResponse, SchoolConfigUpdate

router = APIRouter(prefix="/api/v1/config", tags=["config"])
_admin = ["directivo", "control_escolar"]


@router.get("/")
async def get_config(
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    config = await service.get_config(db)
    return {"data": SchoolConfigResponse.model_validate(config)}


@router.put("/")
async def update_config(
    data: SchoolConfigUpdate,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    config = await service.update_config(data, db)
    return {"data": SchoolConfigResponse.model_validate(config)}
