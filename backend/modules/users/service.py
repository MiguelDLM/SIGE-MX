import uuid
from typing import Optional

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from core.exceptions import BusinessError
from core.security import hash_password
from modules.users.models import Role, User, UserRole, UserStatus
from modules.users.schemas import UserCreate, UserUpdate


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
            try:
                role = Role(name=role_name)
                db.add(role)
                await db.flush()
            except IntegrityError:
                await db.rollback()
                role_result = await db.execute(select(Role).where(Role.name == role_name))
                role = role_result.scalar_one()
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


async def update_user(user_id: uuid.UUID, data: UserUpdate, db: AsyncSession) -> User:
    user = await get_user_by_id(user_id, db)
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(user, field, value)
    await db.commit()
    await db.refresh(user)
    return user


async def deactivate_user(user_id: uuid.UUID, db: AsyncSession) -> None:
    user = await get_user_by_id(user_id, db)
    user.status = UserStatus.inactivo
    await db.commit()


async def reset_password(user_id: uuid.UUID, db: AsyncSession) -> str:
    user = await get_user_by_id(user_id, db)
    
    # Determinar nueva contraseña default
    new_pwd = "SAS12345"
    if user.curp:
        new_pwd = user.curp.strip().upper()
    else:
        # Intentar buscar matricula si es alumno
        from modules.students.models import Student
        from modules.teachers.models import Teacher
        
        s_res = await db.execute(select(Student).where(Student.user_id == user.id))
        student = s_res.scalar_one_or_none()
        if student:
            new_pwd = student.matricula.strip().upper()
        else:
            t_res = await db.execute(select(Teacher).where(Teacher.user_id == user.id))
            teacher = t_res.scalar_one_or_none()
            if teacher and teacher.numero_empleado:
                new_pwd = teacher.numero_empleado.strip().upper()

    user.password_hash = hash_password(new_pwd)
    user.must_change_password = True
    await db.commit()
    return new_pwd


async def list_users(
    db: AsyncSession,
    role: Optional[str] = None,
    include_inactive: bool = False,
) -> list[tuple[User, list[str]]]:
    if role:
        stmt = (
            select(User)
            .join(UserRole, UserRole.user_id == User.id)
            .join(Role, Role.id == UserRole.role_id)
            .where(Role.name == role)
        )
    else:
        stmt = select(User)

    if not include_inactive:
        stmt = stmt.where(User.status == UserStatus.activo)

    stmt = stmt.order_by(User.apellido_paterno, User.nombre)

    result = await db.execute(stmt)
    users = list(result.scalars().unique())
    out = []
    for u in users:
        roles = await get_user_roles(u.id, db)
        out.append((u, roles))
    return out
