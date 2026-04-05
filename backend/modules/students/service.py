# backend/modules/students/service.py
import uuid

from sqlalchemy import func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from core.exceptions import BusinessError
from modules.students.models import Parent, Student, StudentParent
from modules.students.schemas import LinkParentRequest, StudentCreate, StudentUpdate

async def link_student_to_parent(
    student_id: uuid.UUID, data: LinkParentRequest, db: AsyncSession
) -> dict:
    # 1. Check if user exists
    user_stmt = select(User).where(User.id == data.user_id)
    user_res = await db.execute(user_stmt)
    user = user_res.scalar_one_or_none()
    if not user:
        raise BusinessError("USER_NOT_FOUND", "Usuario no encontrado", status_code=404)

    # 2. Ensure user has 'padre' role
    role_stmt = select(Role).where(Role.name == "padre")
    role_res = await db.execute(role_stmt)
    role = role_res.scalar_one_or_none()
    if not role:
        role = Role(name="padre")
        db.add(role)
        await db.flush()

    # Check if user already has this role
    existing_role_stmt = select(UserRole).where(
        UserRole.user_id == user.id, UserRole.role_id == role.id
    )
    existing_role_res = await db.execute(existing_role_stmt)
    if not existing_role_res.scalar_one_or_none():
        db.add(UserRole(user_id=user.id, role_id=role.id))

    # 3. Check/Create Parent profile
    parent_stmt = select(Parent).where(Parent.user_id == user.id)
    parent_res = await db.execute(parent_stmt)
    parent = parent_res.scalar_one_or_none()
    if not parent:
        parent = Parent(user_id=user.id)
        db.add(parent)
        await db.flush()

    # 4. Link Student and Parent
    link_stmt = select(StudentParent).where(
        StudentParent.student_id == student_id, StudentParent.parent_id == parent.id
    )
    link_res = await db.execute(link_stmt)
    if not link_res.scalar_one_or_none():
        db.add(
            StudentParent(
                student_id=student_id, parent_id=parent.id, parentesco=data.parentesco
            )
        )

    await db.commit()
    return {"linked": True}


async def get_student_parents(student_id: uuid.UUID, db: AsyncSession) -> list:
    stmt = (
        select(User, StudentParent.parentesco)
        .join(Parent, Parent.user_id == User.id)
        .join(StudentParent, StudentParent.parent_id == Parent.id)
        .where(StudentParent.student_id == student_id)
    )
    result = await db.execute(stmt)
    out = []
    for user, parentesco in result.all():
        out.append(
            {
                "id": user.id,
                "nombre": f"{user.nombre} {user.apellido_paterno or ''}".strip(),
                "email": user.email,
                "parentesco": parentesco,
            }
        )
    return out


from modules.users.models import Role, User, UserRole, UserStatus
from core.security import hash_password

async def create_student(data: StudentCreate, db: AsyncSession) -> Student:
    user_id = data.user_id
    
    # Create user if email is provided and no user_id given
    if data.email and not user_id:
        # Check if user already exists
        user_stmt = select(User).where(User.email == data.email)
        user_res = await db.execute(user_stmt)
        user = user_res.scalar_one_or_none()
        
        if not user:
            # Standardized default password: CURP (uppercase) or matricula
            raw_pwd = (data.curp or data.matricula).strip().upper()
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
            
            # Assign 'alumno' role
            role_stmt = select(Role).where(Role.name == "alumno")
            role_res = await db.execute(role_stmt)
            role = role_res.scalar_one_or_none()
            if not role:
                role = Role(name="alumno")
                db.add(role)
                await db.flush()
            
            db.add(UserRole(user_id=user.id, role_id=role.id))
            user_id = user.id

    student_data = data.model_dump(exclude={"email", "curp", "fecha_nacimiento"})
    student_data["user_id"] = user_id
    
    student = Student(**student_data)
    db.add(student)
    try:
        await db.flush()
    except IntegrityError:
        await db.rollback()
        raise BusinessError(
            "DUPLICATE_MATRICULA", "La matrícula ya está registrada", status_code=409
        )
    await db.commit()
    await db.refresh(student)
    return student


async def get_student_by_id(student_id: uuid.UUID, db: AsyncSession) -> Student:
    result = await db.execute(select(Student).where(Student.id == student_id))
    student = result.scalar_one_or_none()
    if student is None:
        raise BusinessError("STUDENT_NOT_FOUND", "Alumno no encontrado", status_code=404)
    return student


async def list_students(
    db: AsyncSession,
    page: int = 1,
    size: int = 20,
    search: str | None = None,
    include_inactive: bool = False,
) -> tuple[list[Student], int]:
    q = select(Student)
    if not include_inactive:
        q = q.where(Student.activo == True)  # noqa: E712

    if search:
        term = f"%{search.lower()}%"
        q = q.where(
            or_(
                func.lower(Student.nombre).like(term),
                func.lower(Student.apellido_paterno).like(term),
                func.lower(Student.matricula).like(term),
            )
        )
    total_result = await db.execute(select(func.count()).select_from(q.subquery()))
    total = total_result.scalar_one()
    result = await db.execute(
        q.order_by(Student.apellido_paterno, Student.nombre)
        .offset((page - 1) * size)
        .limit(size)
    )
    return list(result.scalars()), total


async def deactivate_student(student_id: uuid.UUID, db: AsyncSession) -> Student:
    student = await get_student_by_id(student_id, db)
    student.activo = False
    await db.commit()
    await db.refresh(student)
    return student


async def list_my_students(
    user_id: uuid.UUID, db: AsyncSession
) -> list[Student]:
    from modules.students.models import Parent, StudentParent
    results: list[Student] = []

    direct = await db.execute(
        select(Student).where(Student.user_id == user_id)
    )
    results.extend(direct.scalars().all())

    parent_result = await db.execute(
        select(Parent).where(Parent.user_id == user_id)
    )
    parent = parent_result.scalar_one_or_none()
    if parent:
        linked = await db.execute(
            select(Student)
            .join(StudentParent, StudentParent.student_id == Student.id)
            .where(StudentParent.parent_id == parent.id)
        )
        results.extend(linked.scalars().all())

    return results


async def update_student(
    student_id: uuid.UUID, data: StudentUpdate, db: AsyncSession
) -> Student:
    student = await get_student_by_id(student_id, db)
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(student, field, value)
    await db.commit()
    await db.refresh(student)
    return student
