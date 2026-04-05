# backend/modules/students/service.py
import uuid

from sqlalchemy import func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from core.exceptions import BusinessError
from modules.students.models import Student
from modules.students.schemas import StudentCreate, StudentUpdate


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
            # Default password is CURP or matricula
            pwd = data.curp or data.matricula
            user = User(
                email=data.email,
                password_hash=hash_password(pwd),
                nombre=data.nombre,
                apellido_paterno=data.apellido_paterno,
                apellido_materno=data.apellido_materno,
                curp=data.curp,
                fecha_nacimiento=data.fecha_nacimiento,
                status=UserStatus.activo,
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

    student_data = data.model_dump()
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
    db: AsyncSession, page: int = 1, size: int = 20, search: str | None = None
) -> tuple[list[Student], int]:
    q = select(Student)
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
