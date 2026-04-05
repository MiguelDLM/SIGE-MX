# backend/modules/subjects/models.py
import uuid

from sqlalchemy import Boolean, Integer, SmallInteger, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from core.database import Base


class Subject(Base):
    __tablename__ = "subjects"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    nombre: Mapped[str | None] = mapped_column(String, nullable=True)
    clave: Mapped[str | None] = mapped_column(String, nullable=True)
    horas_semana: Mapped[int | None] = mapped_column(Integer, nullable=True)
    grado: Mapped[int | None] = mapped_column(SmallInteger, nullable=True)
    activo: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
