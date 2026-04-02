# backend/core/audit.py
import json
import uuid
from datetime import datetime

from sqlalchemy import DateTime, String, func
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request as StarletteRequest
from starlette.responses import Response

from core.database import AsyncSessionLocal, Base


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


class AuditMiddleware(BaseHTTPMiddleware):
    """Log all write operations (POST/PUT/PATCH/DELETE) to audit_log."""

    WRITE_METHODS = {"POST", "PUT", "PATCH", "DELETE"}

    async def dispatch(self, request: StarletteRequest, call_next) -> Response:
        response = await call_next(request)

        if request.method not in self.WRITE_METHODS:
            return response

        # Extract user from request state (set by get_current_user dependency)
        user_id: str | None = getattr(request.state, "user_id", None)

        # Derive table name from path: /api/v1/students/... → "students"
        parts = request.url.path.strip("/").split("/")
        table_name = parts[2] if len(parts) >= 3 else request.url.path

        try:
            async with AsyncSessionLocal() as db:
                entry = AuditLog(
                    user_id=uuid.UUID(user_id) if user_id else None,
                    action=f"{request.method} {request.url.path}",
                    table_name=table_name,
                )
                db.add(entry)
                await db.commit()
        except Exception:
            pass  # Audit failures must never break the request

        return response
