# backend/modules/teachers/models.py
import uuid
from datetime import date

from sqlalchemy import Date, ForeignKey, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from core.database import Base


class Teacher(Base):
    __tablename__ = "teachers"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=True
    )
    numero_empleado: Mapped[str | None] = mapped_column(
        String, unique=True, nullable=True
    )
    especialidad: Mapped[str | None] = mapped_column(String, nullable=True)
    fecha_contratacion: Mapped[date | None] = mapped_column(Date, nullable=True)
    nombre: Mapped[str | None] = mapped_column(String, nullable=True)
    apellido_paterno: Mapped[str | None] = mapped_column(String, nullable=True)
    apellido_materno: Mapped[str | None] = mapped_column(String, nullable=True)
