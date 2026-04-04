import uuid
from datetime import datetime
from typing import Literal, Optional

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
    """Legacy: add individual users by id list."""
    user_ids: list[uuid.UUID]


class EventParticipantRuleAdd(BaseModel):
    """Flexible: add a rule-based participant entry."""
    tipo: Literal["individual", "grupo", "materia", "rol"]
    user_id: Optional[uuid.UUID] = None
    group_id: Optional[uuid.UUID] = None
    subject_id: Optional[uuid.UUID] = None
    rol: Optional[str] = None


class EventParticipantResponse(BaseModel):
    id: uuid.UUID
    event_id: uuid.UUID
    tipo: str
    user_id: Optional[uuid.UUID] = None
    group_id: Optional[uuid.UUID] = None
    subject_id: Optional[uuid.UUID] = None
    rol: Optional[str] = None
    label: Optional[str] = None

    model_config = {"from_attributes": True}


class EventResponse(BaseModel):
    id: uuid.UUID
    titulo: Optional[str] = None
    descripcion: Optional[str] = None
    tipo: Optional[EventType] = None
    fecha_inicio: Optional[datetime] = None
    fecha_fin: Optional[datetime] = None
    creado_por: Optional[uuid.UUID] = None

    model_config = {"from_attributes": True}
