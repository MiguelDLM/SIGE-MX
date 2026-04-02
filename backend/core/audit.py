# backend/core/audit.py
import uuid
from datetime import datetime

from sqlalchemy import DateTime, String, func
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from core.database import Base


class AuditLog(Base):
    __tablename__ = "audit_log"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    action: Mapped[str | None] = mapped_column(String, nullable=True)
    table_name: Mapped[str | None] = mapped_column(String, nullable=True)
    record_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    old_data: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    new_data: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    timestamp: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())


async def log_audit(
    db,
    user_id: str | None,
    action: str,
    table_name: str,
    record_id: str | None = None,
    old_data: dict | None = None,
    new_data: dict | None = None,
) -> None:
    """Write one audit entry. Call from service layer after mutations."""
    entry = AuditLog(
        user_id=uuid.UUID(user_id) if user_id else None,
        action=action,
        table_name=table_name,
        record_id=uuid.UUID(record_id) if record_id else None,
        old_data=old_data,
        new_data=new_data,
    )
    db.add(entry)
    await db.flush()
