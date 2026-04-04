import uuid
from typing import Optional

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from core.database import get_db
from core.security import get_current_user, require_roles
from modules.constancias import service
from modules.constancias.schemas import (
    ConstanciaBatchCreate,
    ConstanciaCreate,
    ConstanciaResponse,
)

router = APIRouter(prefix="/api/v1/constancias", tags=["constancias"])
_admin = ["directivo", "control_escolar"]


@router.get("/mis-constancias")
async def mis_constancias(
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    items = await service.list_my(uuid.UUID(current_user["user_id"]), db)
    return {"data": [ConstanciaResponse.from_orm_with_active(c).model_dump(mode="json") for c in items]}


@router.get("/")
async def list_constancias(
    event_id: Optional[uuid.UUID] = Query(None),
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    if event_id:
        items = await service.list_by_event(event_id, db)
    else:
        items = []
    return {"data": [ConstanciaResponse.from_orm_with_active(c).model_dump(mode="json") for c in items]}


@router.post("/", status_code=status.HTTP_201_CREATED)
async def authorize_constancia(
    data: ConstanciaCreate,
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(require_roles(_admin)),
):
    c = await service.authorize(data, uuid.UUID(current_user["user_id"]), db)
    return {"data": ConstanciaResponse.from_orm_with_active(c).model_dump(mode="json")}


@router.post("/batch", status_code=status.HTTP_201_CREATED)
async def authorize_batch(
    data: ConstanciaBatchCreate,
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(require_roles(_admin)),
):
    items = await service.authorize_batch(data, uuid.UUID(current_user["user_id"]), db)
    return {
        "data": [ConstanciaResponse.from_orm_with_active(c).model_dump(mode="json") for c in items],
        "total": len(items),
    }


@router.delete("/{constancia_id}", status_code=status.HTTP_200_OK)
async def revoke_constancia(
    constancia_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    c = await service.revoke(constancia_id, db)
    return {"data": ConstanciaResponse.from_orm_with_active(c).model_dump(mode="json")}
