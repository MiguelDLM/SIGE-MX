import enum
import uuid
from datetime import date, datetime

from sqlalchemy import Date, DateTime, Enum as SAEnum, ForeignKey, Integer, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from core.database import Base


class UserStatus(str, enum.Enum):
    activo = "activo"
    inactivo = "inactivo"
    suspendido = "suspendido"


class User(Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    email: Mapped[str | None] = mapped_column(String, unique=True, nullable=True)
    password_hash: Mapped[str] = mapped_column(String, nullable=False)
    telefono: Mapped[str | None] = mapped_column(String, nullable=True)
    nombre: Mapped[str] = mapped_column(String, nullable=False)
    apellido_paterno: Mapped[str | None] = mapped_column(String, nullable=True)
    apellido_materno: Mapped[str | None] = mapped_column(String, nullable=True)
    curp: Mapped[str | None] = mapped_column(String, unique=True, nullable=True)
    fecha_nacimiento: Mapped[date | None] = mapped_column(Date, nullable=True)
    status: Mapped[UserStatus] = mapped_column(
        SAEnum(UserStatus, name="user_status", create_type=False),
        default=UserStatus.activo,
        nullable=False,
    )
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, server_default=func.now(), onupdate=func.now()
    )

    roles: Mapped[list["UserRole"]] = relationship("UserRole", back_populates="user")


class Role(Base):
    __tablename__ = "roles"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String, unique=True, nullable=False)

    user_roles: Mapped[list["UserRole"]] = relationship("UserRole", back_populates="role")


class UserRole(Base):
    __tablename__ = "user_roles"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    role_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("roles.id"), primary_key=True
    )

    user: Mapped["User"] = relationship("User", back_populates="roles")
    role: Mapped["Role"] = relationship("Role", back_populates="user_roles")
