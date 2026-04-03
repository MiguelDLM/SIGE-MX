import uuid
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, field_validator

from modules.messaging.models import MessageType


class MessageCreate(BaseModel):
    content: str
    type: MessageType
    recipient_ids: list[uuid.UUID]

    @field_validator("recipient_ids")
    @classmethod
    def at_least_one_recipient(cls, v: list) -> list:
        if not v:
            raise ValueError("At least one recipient is required")
        return v


class MessageResponse(BaseModel):
    id: uuid.UUID
    sender_id: Optional[uuid.UUID] = None
    content: Optional[str] = None
    type: Optional[MessageType] = None
    created_at: datetime

    model_config = {"from_attributes": True}


class InboxMessageResponse(BaseModel):
    id: uuid.UUID
    sender_id: Optional[uuid.UUID] = None
    content: Optional[str] = None
    type: Optional[MessageType] = None
    created_at: datetime
    read: bool

    model_config = {"from_attributes": True}
