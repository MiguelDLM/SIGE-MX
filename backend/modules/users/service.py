import uuid

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from core.exceptions import BusinessError
from core.security import hash_password
from modules.users.models import Role, User, UserRole, UserStatus
from modules.users.schemas import UserCreate


async def create_user(data: UserCreate, db: AsyncSession) -> User:
    user = User(
        email=data.email,
        password_hash=hash_password(data.password),
        telefono=data.telefono,
        nombre=data.nombre,
        apellido_paterno=data.apellido_paterno,
        apellido_materno=data.apellido_materno,
        curp=data.curp,
        fecha_nacimiento=data.fecha_nacimiento,
        status=UserStatus.activo,
    )
    db.add(user)
    try:
        await db.flush()
    except IntegrityError:
        await db.rollback()
        raise BusinessError(
            "DUPLICATE_EMAIL", "El email ya está registrado", status_code=409
        )

    for role_name in data.roles:
        role_result = await db.execute(select(Role).where(Role.name == role_name))
        role = role_result.scalar_one_or_none()
        if role is None:
            role = Role(name=role_name)
            db.add(role)
            await db.flush()
        db.add(UserRole(user_id=user.id, role_id=role.id))

    await db.commit()
    await db.refresh(user)
    return user


async def get_user_by_id(user_id: uuid.UUID, db: AsyncSession) -> User:
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user is None:
        raise BusinessError("USER_NOT_FOUND", "Usuario no encontrado", status_code=404)
    return user


async def get_user_roles(user_id: uuid.UUID, db: AsyncSession) -> list[str]:
    result = await db.execute(
        select(Role.name)
        .join(UserRole, Role.id == UserRole.role_id)
        .where(UserRole.user_id == user_id)
    )
    return list(result.scalars())
