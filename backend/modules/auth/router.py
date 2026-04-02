import redis.asyncio as aioredis
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from core.config import settings
from core.database import get_db
from core.security import get_current_user
from modules.auth import service
from modules.auth.schemas import LoginRequest, RefreshRequest
from modules.users.schemas import UserResponse

router = APIRouter(prefix="/api/v1/auth", tags=["auth"])


async def get_redis() -> aioredis.Redis:
    client = aioredis.from_url(
        settings.redis_url, password=settings.redis_password or None, decode_responses=True
    )
    try:
        yield client
    finally:
        await client.aclose()


@router.post("/login")
async def login(data: LoginRequest, db: AsyncSession = Depends(get_db)):
    tokens = await service.login(data.email, data.password, db)
    return {"data": tokens}


@router.post("/refresh")
async def refresh(
    data: RefreshRequest,
    db: AsyncSession = Depends(get_db),
    redis_client: aioredis.Redis = Depends(get_redis),
):
    tokens = await service.refresh_access_token(data.refresh_token, db, redis_client)
    return {"data": tokens}


@router.post("/logout")
async def logout(
    data: RefreshRequest,
    current_user: dict = Depends(get_current_user),
    redis_client: aioredis.Redis = Depends(get_redis),
):
    result = await service.logout(data.refresh_token, redis_client)
    return {"data": result}


@router.get("/me")
async def get_me(
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    user = await service.get_me(current_user["user_id"], db)
    response = UserResponse(
        id=user.id,
        email=user.email,
        telefono=user.telefono,
        nombre=user.nombre,
        apellido_paterno=user.apellido_paterno,
        apellido_materno=user.apellido_materno,
        curp=user.curp,
        status=user.status,
        created_at=user.created_at,
        roles=current_user.get("roles", []),
    )
    return {"data": response}
