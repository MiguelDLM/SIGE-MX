import uuid
from datetime import datetime
from typing import Optional

from pydantic import BaseModel

from modules.events.models import EventType


class EventCreate(BaseModel):
    titulo: str
    tipo: Optional[EventType] = None
    descripcion: Optional[str] = None
    fecha_inicio: Optional[datetime] = None
    fecha_fin: Optional[datetime] = None


class EventUpdate(BaseModel):
    titulo: Optional[str] = None
    tipo: Optional[EventType] = None
    descripcion: Optional[str] = None
    fecha_inicio: Optional[datetime] = None
    fecha_fin: Optional[datetime] = None


class EventParticipantsAdd(BaseModel):
    user_ids: list[uuid.UUID]


class EventResponse(BaseModel):
    id: uuid.UUID
    titulo: Optional[str] = None
    descripcion: Optional[str] = None
    tipo: Optional[EventType] = None
    fecha_inicio: Optional[datetime] = None
    fecha_fin: Optional[datetime] = None
    creado_por: Optional[uuid.UUID] = None

    model_config = {"from_attributes": True}
