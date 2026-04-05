# backend/modules/teachers/service.py
import uuid

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from core.exceptions import BusinessError
from modules.teachers.models import Teacher
from modules.teachers.schemas import TeacherCreate, TeacherUpdate


from modules.users.models import Role, User, UserRole, UserStatus
from core.security import hash_password

async def create_teacher(data: TeacherCreate, db: AsyncSession) -> Teacher:
    user_id = data.user_id
    
    # Create user if email is provided and no user_id given
    if data.email and not user_id:
        # Check if user already exists
        user_stmt = select(User).where(User.email == data.email)
        user_res = await db.execute(user_stmt)
        user = user_res.scalar_one_or_none()
        
        if not user:
            # Standardized default password: CURP (uppercase) or employee number or fallback
            raw_pwd = (data.curp or data.numero_empleado or "SAS12345").strip().upper()
            user = User(
                email=data.email,
                password_hash=hash_password(raw_pwd),
                nombre=data.nombre,
                apellido_paterno=data.apellido_paterno,
                apellido_materno=data.apellido_materno,
                curp=data.curp.strip().upper() if data.curp else None,
                fecha_nacimiento=data.fecha_nacimiento,
                status=UserStatus.activo,
                must_change_password=True,
            )
            db.add(user)
            await db.flush()
            
            # Assign 'docente' role
            role_stmt = select(Role).where(Role.name == "docente")
            role_res = await db.execute(role_stmt)
            role = role_res.scalar_one_or_none()
            if not role:
                role = Role(name="docente")
                db.add(role)
                await db.flush()
            
            db.add(UserRole(user_id=user.id, role_id=role.id))
            user_id = user.id

    teacher_data = data.model_dump()
    teacher_data["user_id"] = user_id
    
    teacher = Teacher(**teacher_data)
    db.add(teacher)
    try:
        await db.flush()
    except IntegrityError:
        await db.rollback()
        raise BusinessError(
            "DUPLICATE_NUMERO_EMPLEADO",
            "El número de empleado ya existe",
            status_code=409,
        )
    await db.commit()
    await db.refresh(teacher)
    return teacher


async def get_teacher_by_id(teacher_id: uuid.UUID, db: AsyncSession) -> Teacher:
    result = await db.execute(select(Teacher).where(Teacher.id == teacher_id))
    teacher = result.scalar_one_or_none()
    if teacher is None:
        raise BusinessError("TEACHER_NOT_FOUND", "Docente no encontrado", status_code=404)
    return teacher


async def list_teachers(db: AsyncSession) -> list[Teacher]:
    result = await db.execute(
        select(Teacher).order_by(Teacher.apellido_paterno, Teacher.nombre)
    )
    return list(result.scalars())


async def update_teacher(
    teacher_id: uuid.UUID, data: TeacherUpdate, db: AsyncSession
) -> Teacher:
    teacher = await get_teacher_by_id(teacher_id, db)

    # If email is being set and no user_id yet, create/link a user account
    update_data = data.model_dump(exclude_unset=True)
    if "email" in update_data and update_data["email"] and not teacher.user_id and "user_id" not in update_data:
        email = update_data["email"]
        user_stmt = select(User).where(User.email == email)
        user_res = await db.execute(user_stmt)
        user = user_res.scalar_one_or_none()
        if not user:
            raw_pwd = (teacher.curp or teacher.numero_empleado or "SAS12345").strip().upper()
            user = User(
                email=email,
                password_hash=hash_password(raw_pwd),
                nombre=teacher.nombre,
                apellido_paterno=teacher.apellido_paterno,
                apellido_materno=teacher.apellido_materno,
                status=UserStatus.activo,
                must_change_password=True,
            )
            db.add(user)
            await db.flush()
            role_stmt = select(Role).where(Role.name == "docente")
            role_res = await db.execute(role_stmt)
            role = role_res.scalar_one_or_none()
            if not role:
                role = Role(name="docente")
                db.add(role)
                await db.flush()
            db.add(UserRole(user_id=user.id, role_id=role.id))
        update_data["user_id"] = user.id

    for field, value in update_data.items():
        setattr(teacher, field, value)
    await db.commit()
    await db.refresh(teacher)
    return teacher


async def delete_teacher(teacher_id: uuid.UUID, db: AsyncSession) -> None:
    teacher = await get_teacher_by_id(teacher_id, db)
    await db.delete(teacher)
    await db.commit()
