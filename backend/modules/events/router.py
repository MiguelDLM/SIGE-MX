import uuid

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from core.database import get_db
from core.security import get_current_user, require_roles
from modules.events import service
from modules.events.schemas import (
    EventCreate,
    EventParticipantRuleAdd,
    EventParticipantsAdd,
    EventParticipantResponse,
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
    return {"data": EventResponse.model_validate(event).model_dump(mode="json")}


@router.get("/")
async def list_events(
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(get_current_user),
):
    events = await service.list_events(db)
    return {"data": [EventResponse.model_validate(e).model_dump(mode="json") for e in events]}


@router.patch("/{event_id}")
async def update_event(
    event_id: uuid.UUID,
    data: EventUpdate,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    event = await service.update_event(event_id, data, db)
    return {"data": EventResponse.model_validate(event).model_dump(mode="json")}


@router.delete("/{event_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_event(
    event_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_delete)),
):
    await service.delete_event(event_id, db)


# --- Participants ---

@router.get("/{event_id}/participants")
async def list_participants(
    event_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(get_current_user),
):
    rules = await service.list_participants(event_id, db)
    return {"data": [r.model_dump(mode="json") for r in rules]}


@router.get("/{event_id}/participants/resolved")
async def resolve_participants(
    event_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    users = await service.resolve_participants(event_id, db)
    return {"data": users, "total": len(users)}


@router.post("/{event_id}/participants", status_code=status.HTTP_201_CREATED)
async def add_participant_rule(
    event_id: uuid.UUID,
    data: EventParticipantRuleAdd,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    ep = await service.add_participant_rule(event_id, data, db)
    return {"data": EventParticipantResponse.model_validate(ep).model_dump(mode="json")}


@router.post("/{event_id}/participants/bulk", status_code=status.HTTP_201_CREATED)
async def add_participants_bulk(
    event_id: uuid.UUID,
    data: EventParticipantsAdd,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    await service.add_participants(event_id, data, db)
    return {"data": {"event_id": str(event_id), "added": len(data.user_ids)}}


@router.delete("/{event_id}/participants/{participant_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_participant(
    event_id: uuid.UUID,
    participant_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin)),
):
    await service.remove_participant(participant_id, db)
