import uuid

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from core.exceptions import BusinessError
from modules.events.models import Event, EventParticipant
from modules.events.schemas import EventCreate, EventParticipantsAdd, EventUpdate


async def create_event(
    data: EventCreate, creado_por: uuid.UUID, db: AsyncSession
) -> Event:
    event = Event(**data.model_dump(), creado_por=creado_por)
    db.add(event)
    await db.commit()
    await db.refresh(event)
    return event


async def list_events(db: AsyncSession) -> list[Event]:
    result = await db.execute(
        select(Event).order_by(Event.fecha_inicio.asc().nullslast())
    )
    return list(result.scalars())


async def update_event(
    event_id: uuid.UUID, data: EventUpdate, db: AsyncSession
) -> Event:
    result = await db.execute(select(Event).where(Event.id == event_id))
    event = result.scalar_one_or_none()
    if event is None:
        raise BusinessError("EVENT_NOT_FOUND", "Evento no encontrado", status_code=404)
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(event, field, value)
    await db.commit()
    await db.refresh(event)
    return event


async def delete_event(event_id: uuid.UUID, db: AsyncSession) -> None:
    result = await db.execute(select(Event).where(Event.id == event_id))
    event = result.scalar_one_or_none()
    if event is None:
        raise BusinessError("EVENT_NOT_FOUND", "Evento no encontrado", status_code=404)
    await db.delete(event)
    await db.commit()


async def add_participants(
    event_id: uuid.UUID, data: EventParticipantsAdd, db: AsyncSession
) -> None:
    result = await db.execute(select(Event).where(Event.id == event_id))
    if result.scalar_one_or_none() is None:
        raise BusinessError("EVENT_NOT_FOUND", "Evento no encontrado", status_code=404)

    for user_id in data.user_ids:
        try:
            async with db.begin_nested():
                db.add(EventParticipant(event_id=event_id, user_id=user_id))
                await db.flush()
        except IntegrityError:
            pass  # duplicate participant — silently ignore

    await db.commit()
