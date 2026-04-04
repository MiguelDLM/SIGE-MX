import uuid
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from core.exceptions import BusinessError
from modules.constancias.models import Constancia
from modules.constancias.schemas import ConstanciaBatchCreate, ConstanciaCreate


async def authorize(
    data: ConstanciaCreate, authorized_by: uuid.UUID, db: AsyncSession
) -> Constancia:
    existing = await db.execute(
        select(Constancia).where(
            Constancia.event_id == data.event_id,
            Constancia.user_id == data.user_id,
        )
    )
    c = existing.scalar_one_or_none()
    if c:
        if c.revoked_at is None:
            raise BusinessError("ALREADY_EXISTS", "La constancia ya existe y está activa", status_code=409)
        # Re-authorize a previously revoked constancia
        c.revoked_at = None
        c.authorized_by = authorized_by
        c.notas = data.notas
        await db.commit()
        await db.refresh(c)
        return c

    c = Constancia(
        event_id=data.event_id,
        user_id=data.user_id,
        authorized_by=authorized_by,
        notas=data.notas,
    )
    db.add(c)
    await db.commit()
    await db.refresh(c)
    return c


async def authorize_batch(
    data: ConstanciaBatchCreate, authorized_by: uuid.UUID, db: AsyncSession
) -> list[Constancia]:
    results = []
    for user_id in data.user_ids:
        from modules.constancias.schemas import ConstanciaCreate
        single = ConstanciaCreate(event_id=data.event_id, user_id=user_id, notas=data.notas)
        try:
            c = await authorize(single, authorized_by, db)
            results.append(c)
        except BusinessError:
            pass  # skip already-active ones in batch
    return results


async def revoke(constancia_id: uuid.UUID, db: AsyncSession) -> Constancia:
    c = await db.get(Constancia, constancia_id)
    if not c:
        raise BusinessError("NOT_FOUND", "Constancia no encontrada", status_code=404)
    if c.revoked_at is not None:
        raise BusinessError("ALREADY_REVOKED", "La constancia ya fue revocada", status_code=409)
    c.revoked_at = datetime.now(tz=timezone.utc)
    await db.commit()
    await db.refresh(c)
    return c


async def list_by_event(event_id: uuid.UUID, db: AsyncSession) -> list[Constancia]:
    result = await db.execute(
        select(Constancia)
        .where(Constancia.event_id == event_id)
        .order_by(Constancia.authorized_at.desc())
    )
    return list(result.scalars())


async def list_my(user_id: uuid.UUID, db: AsyncSession) -> list[Constancia]:
    result = await db.execute(
        select(Constancia)
        .where(Constancia.user_id == user_id, Constancia.revoked_at.is_(None))
        .order_by(Constancia.authorized_at.desc())
    )
    return list(result.scalars())
