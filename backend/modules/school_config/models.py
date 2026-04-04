from sqlalchemy import Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from core.database import Base


class SchoolConfig(Base):
    __tablename__ = "school_config"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, default=1)
    nombre: Mapped[str | None] = mapped_column(String, nullable=True)
    cct: Mapped[str | None] = mapped_column(String, nullable=True)
    turno: Mapped[str | None] = mapped_column(String, nullable=True)
    direccion: Mapped[str | None] = mapped_column(String, nullable=True)
