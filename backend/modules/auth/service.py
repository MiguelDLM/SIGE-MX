from datetime import timedelta

import redis.asyncio as aioredis
from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from core.config import settings
from core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    verify_password,
)
from modules.users.models import Role, User, UserRole, UserStatus


async def login(email: str, password: str, db: AsyncSession) -> dict:
    result = await db.execute(select(User).where(User.email == email))
    user = result.scalar_one_or_none()

    if user is None or not verify_password(password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Credenciales inválidas",
        )
    if user.status != UserStatus.activo:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Usuario inactivo o suspendido",
        )

    roles_result = await db.execute(
        select(Role.name)
        .join(UserRole, Role.id == UserRole.role_id)
        .where(UserRole.user_id == user.id)
    )
    roles = list(roles_result.scalars())

    return {
        "access_token": create_access_token(str(user.id), roles),
        "refresh_token": create_refresh_token(str(user.id)),
        "token_type": "bearer",
    }


async def refresh_access_token(
    refresh_token: str, db: AsyncSession, redis_client: aioredis.Redis
) -> dict:
    if await redis_client.get(f"blacklist:{refresh_token}"):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Token revocado"
        )

    payload = decode_token(refresh_token)
    if payload.get("type") != "refresh":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Tipo de token inválido"
        )

    user_id = payload["sub"]
    roles_result = await db.execute(
        select(Role.name)
        .join(UserRole, Role.id == UserRole.role_id)
        .where(UserRole.user_id == user_id)
    )
    roles = list(roles_result.scalars())

    return {
        "access_token": create_access_token(user_id, roles),
        "token_type": "bearer",
    }


async def logout(refresh_token: str, redis_client: aioredis.Redis) -> dict:
    try:
        decode_token(refresh_token)
    except HTTPException:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Token inválido"
        )

    ttl = int(timedelta(days=settings.refresh_token_expire_days).total_seconds())
    await redis_client.setex(f"blacklist:{refresh_token}", ttl, "1")
    return {"message": "Sesión cerrada correctamente"}


async def get_me(user_id: str, db: AsyncSession) -> User:
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Usuario no encontrado"
        )
    return user
