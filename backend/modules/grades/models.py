# backend/modules/grades/models.py
import enum
import uuid
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import Date, DateTime, Enum as SAEnum, ForeignKey, Numeric, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from core.database import Base


class EvaluationType(str, enum.Enum):
    examen = "examen"
    tarea = "tarea"
    proyecto = "proyecto"
    participacion = "participacion"
    otro = "otro"


class Evaluation(Base):
    __tablename__ = "evaluations"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    subject_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("subjects.id"), nullable=True
    )
    group_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("groups.id"), nullable=True
    )
    tipo: Mapped[EvaluationType | None] = mapped_column(
        SAEnum(EvaluationType, name="evaluation_type", create_type=False), nullable=True
    )
    titulo: Mapped[str | None] = mapped_column(String, nullable=True)
    descripcion: Mapped[str | None] = mapped_column(String, nullable=True)
    fecha: Mapped[date | None] = mapped_column(Date, nullable=True)
    porcentaje: Mapped[Decimal | None] = mapped_column(Numeric(5, 2), nullable=True)


class Grade(Base):
    __tablename__ = "grades"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    evaluation_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("evaluations.id"), nullable=True
    )
    student_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("students.id"), nullable=True
    )
    calificacion: Mapped[Decimal | None] = mapped_column(Numeric(5, 2), nullable=True)
    observaciones: Mapped[str | None] = mapped_column(String, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
