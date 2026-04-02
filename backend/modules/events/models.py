# backend/modules/events/models.py
import enum
import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum as SAEnum, ForeignKey, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from core.database import Base


class EventType(str, enum.Enum):
    academico = "academico"
    cultural = "cultural"
    deportivo = "deportivo"
    administrativo = "administrativo"


class Event(Base):
    __tablename__ = "events"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    titulo: Mapped[str | None] = mapped_column(String, nullable=True)
    descripcion: Mapped[str | None] = mapped_column(String, nullable=True)
    tipo: Mapped[EventType | None] = mapped_column(
        SAEnum(EventType, name="event_type", create_type=False), nullable=True
    )
    fecha_inicio: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    fecha_fin: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    creado_por: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=True
    )


class EventParticipant(Base):
    __tablename__ = "event_participants"

    event_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("events.id", ondelete="CASCADE"),
        primary_key=True,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), primary_key=True
    )
