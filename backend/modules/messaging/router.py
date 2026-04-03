import uuid

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from core.database import get_db
from core.security import get_current_user
from modules.messaging import service
from modules.messaging.schemas import InboxMessageResponse, MessageCreate, MessageResponse

router = APIRouter(prefix="/api/v1/messages", tags=["messaging"])


@router.post("/", status_code=status.HTTP_201_CREATED)
async def send_message(
    data: MessageCreate,
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    message = await service.send_message(
        sender_id=uuid.UUID(current_user["user_id"]),
        data=data,
        db=db,
    )
    return {"data": MessageResponse.model_validate(message)}


@router.get("/inbox")
async def get_inbox(
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    messages = await service.get_inbox(uuid.UUID(current_user["user_id"]), db)
    return {"data": messages}


@router.get("/sent")
async def get_sent(
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    messages = await service.get_sent(uuid.UUID(current_user["user_id"]), db)
    return {"data": [MessageResponse.model_validate(m) for m in messages]}


@router.post("/{message_id}/read")
async def mark_as_read(
    message_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    receipt = await service.mark_as_read(
        message_id=message_id,
        user_id=uuid.UUID(current_user["user_id"]),
        db=db,
    )
    return {"data": receipt}
