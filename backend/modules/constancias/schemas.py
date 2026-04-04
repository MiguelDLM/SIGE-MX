import uuid
from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class ConstanciaCreate(BaseModel):
    event_id: uuid.UUID
    user_id: uuid.UUID
    notas: Optional[str] = None


class ConstanciaBatchCreate(BaseModel):
    event_id: uuid.UUID
    user_ids: list[uuid.UUID]
    notas: Optional[str] = None


class ConstanciaResponse(BaseModel):
    id: uuid.UUID
    event_id: uuid.UUID
    user_id: uuid.UUID
    authorized_by: uuid.UUID
    authorized_at: datetime
    revoked_at: Optional[datetime] = None
    notas: Optional[str] = None
    active: bool = True

    model_config = {"from_attributes": True}

    @classmethod
    def from_orm_with_active(cls, obj: object) -> "ConstanciaResponse":
        data = cls.model_validate(obj)
        data.active = obj.revoked_at is None  # type: ignore[attr-defined]
        return data
