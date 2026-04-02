import uuid

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from core.database import get_db
from core.security import require_roles
from modules.users import service
from modules.users.schemas import UserCreate, UserResponse

router = APIRouter(prefix="/api/v1/users", tags=["users"])

_admin_roles = ["directivo", "control_escolar"]


def _user_to_response(user, roles: list[str]) -> UserResponse:
    return UserResponse(
        id=user.id,
        email=user.email,
        telefono=user.telefono,
        nombre=user.nombre,
        apellido_paterno=user.apellido_paterno,
        apellido_materno=user.apellido_materno,
        curp=user.curp,
        status=user.status,
        created_at=user.created_at,
        roles=roles,
    )


@router.post("/", status_code=status.HTTP_201_CREATED)
async def create_user(
    data: UserCreate,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin_roles)),
):
    user = await service.create_user(data, db)
    roles = await service.get_user_roles(user.id, db)
    return {"data": _user_to_response(user, roles)}


@router.get("/{user_id}")
async def get_user(
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_admin_roles)),
):
    user = await service.get_user_by_id(user_id, db)
    roles = await service.get_user_roles(user.id, db)
    return {"data": _user_to_response(user, roles)}
