import uuid

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from core.exceptions import BusinessError
from modules.messaging.models import Message, MessageRecipient
from modules.messaging.schemas import InboxMessageResponse, MessageCreate


async def send_message(
    sender_id: uuid.UUID, data: MessageCreate, db: AsyncSession
) -> Message:
    message = Message(
        sender_id=sender_id,
        content=data.content,
        type=data.type,
    )
    db.add(message)
    await db.flush()

    for recipient_id in data.recipient_ids:
        try:
            async with db.begin_nested():
                db.add(MessageRecipient(message_id=message.id, user_id=recipient_id, read=False))
                await db.flush()
        except IntegrityError:
            raise BusinessError("INVALID_RECIPIENT", f"Usuario {recipient_id} no existe", status_code=422)

    await db.commit()
    await db.refresh(message)
    return message


async def get_inbox(
    user_id: uuid.UUID, db: AsyncSession
) -> list[InboxMessageResponse]:
    result = await db.execute(
        select(Message, MessageRecipient.read)
        .join(MessageRecipient, MessageRecipient.message_id == Message.id)
        .where(MessageRecipient.user_id == user_id)
        .order_by(Message.created_at.desc())
    )
    return [
        InboxMessageResponse(
            id=msg.id,
            sender_id=msg.sender_id,
            content=msg.content,
            type=msg.type,
            created_at=msg.created_at,
            read=read,
        )
        for msg, read in result.all()
    ]


async def get_sent(
    user_id: uuid.UUID, db: AsyncSession
) -> list[Message]:
    result = await db.execute(
        select(Message)
        .where(Message.sender_id == user_id)
        .order_by(Message.created_at.desc())
    )
    return list(result.scalars())


async def mark_as_read(
    message_id: uuid.UUID, user_id: uuid.UUID, db: AsyncSession
) -> InboxMessageResponse:
    result = await db.execute(
        select(MessageRecipient).where(
            MessageRecipient.message_id == message_id,
            MessageRecipient.user_id == user_id,
        )
    )
    receipt = result.scalar_one_or_none()
    if receipt is None:
        raise BusinessError("MESSAGE_NOT_FOUND", "Mensaje no encontrado o no eres destinatario", status_code=404)
    receipt.read = True
    await db.commit()

    msg_result = await db.execute(select(Message).where(Message.id == message_id))
    message = msg_result.scalar_one_or_none()
    if message is None:
        raise BusinessError("MESSAGE_NOT_FOUND", "Mensaje no encontrado", status_code=404)
    return InboxMessageResponse(
        id=message.id,
        sender_id=message.sender_id,
        content=message.content,
        type=message.type,
        created_at=message.created_at,
        read=True,
    )
