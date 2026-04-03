import uuid

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from core.database import get_db
from core.security import get_current_user, require_roles
from modules.events import service
from modules.events.schemas import (
    EventCreate,
    EventParticipantsAdd,
    EventResponse,
    EventUpdate,
)

router = APIRouter(prefix="/api/v1/events", tags=["events"])
_admin = ["directivo", "control_escolar"]
_delete = ["directivo"]


@router.post("/", status_code=status.HTTP_201_CREATED)
async def create_event(
    data: EventCreate,
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(require_roles(_admin)),
):
    event = await service.create_event(
        data=data,
        creado_por=uuid.UUID(current_user["user_id"]),
        db=db,
    )
    return {"data": EventResponse.model_validate(event)}


@router.get("/")
async def list_events(
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(get_current_user),
):
    events = await service.list_events(db)
    return {"data": [EventResponse.model_validate(e) for e in events]}


@router.patch("/{event_id}")
async def update_event(
    event_id: uuid.UUID,
    data: EventUpdate,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    event = await service.update_event(event_id, data, db)
    return {"data": EventResponse.model_validate(event)}


@router.delete("/{event_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_event(
    event_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_delete)),
):
    await service.delete_event(event_id, db)


@router.post("/{event_id}/participants", status_code=status.HTTP_201_CREATED)
async def add_participants(
    event_id: uuid.UUID,
    data: EventParticipantsAdd,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    await service.add_participants(event_id, data, db)
    return {"data": {"event_id": str(event_id), "added": len(data.user_ids)}}
