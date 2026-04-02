# backend/modules/students/models.py
import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from core.database import Base


class Student(Base):
    __tablename__ = "students"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=True
    )
    matricula: Mapped[str] = mapped_column(String, unique=True, nullable=False)
    numero_seguro_social: Mapped[str | None] = mapped_column(String, nullable=True)
    tipo_sangre: Mapped[str | None] = mapped_column(String, nullable=True)
    direccion: Mapped[str | None] = mapped_column(String, nullable=True)
    municipio: Mapped[str | None] = mapped_column(String, nullable=True)
    estado: Mapped[str | None] = mapped_column(String, nullable=True)
    codigo_postal: Mapped[str | None] = mapped_column(String, nullable=True)
    nombre: Mapped[str | None] = mapped_column(String, nullable=True)
    apellido_paterno: Mapped[str | None] = mapped_column(String, nullable=True)
    apellido_materno: Mapped[str | None] = mapped_column(String, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())


class Parent(Base):
    __tablename__ = "parents"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=True
    )
    ocupacion: Mapped[str | None] = mapped_column(String, nullable=True)


class StudentParent(Base):
    __tablename__ = "student_parent"

    student_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("students.id", ondelete="CASCADE"),
        primary_key=True,
    )
    parent_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("parents.id", ondelete="CASCADE"),
        primary_key=True,
    )
    parentesco: Mapped[str | None] = mapped_column(String, nullable=True)
