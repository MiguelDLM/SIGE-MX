# backend/modules/groups/service.py
import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from core.exceptions import BusinessError
from modules.groups.models import Group, GroupStudent, GroupTeacher
from modules.groups.schemas import AssignStudentRequest, AssignTeacherRequest, GroupCreate, GroupUpdate


async def create_group(data: GroupCreate, db: AsyncSession) -> Group:
    group = Group(**data.model_dump())
    db.add(group)
    await db.commit()
    await db.refresh(group)
    return group


async def get_group_by_id(group_id: uuid.UUID, db: AsyncSession) -> Group:
    result = await db.execute(select(Group).where(Group.id == group_id))
    group = result.scalar_one_or_none()
    if group is None:
        raise BusinessError("GROUP_NOT_FOUND", "Grupo no encontrado", status_code=404)
    return group


async def list_groups(db: AsyncSession, include_inactive: bool = False) -> list[Group]:
    stmt = select(Group)
    if not include_inactive:
        stmt = stmt.where(Group.activo == True)  # noqa: E712
    stmt = stmt.order_by(Group.grado, Group.nombre)
    result = await db.execute(stmt)
    return list(result.scalars())


async def list_groups_by_teacher(
    teacher_id: uuid.UUID, db: AsyncSession, include_inactive: bool = False
) -> list[Group]:
    stmt = (
        select(Group)
        .join(GroupTeacher, GroupTeacher.group_id == Group.id)
        .where(GroupTeacher.teacher_id == teacher_id)
    )
    if not include_inactive:
        stmt = stmt.where(Group.activo == True)  # noqa: E712
    stmt = stmt.order_by(Group.grado, Group.nombre)
    result = await db.execute(stmt)
    return list(result.scalars())


async def list_students_by_group(
    group_id: uuid.UUID, db: AsyncSession
) -> list:
    from modules.students.models import Student
    await get_group_by_id(group_id, db)
    result = await db.execute(
        select(Student)
        .join(GroupStudent, GroupStudent.student_id == Student.id)
        .where(GroupStudent.group_id == group_id)
        .order_by(Student.apellido_paterno, Student.nombre)
    )
    return list(result.scalars())


async def update_group(
    group_id: uuid.UUID, data: GroupUpdate, db: AsyncSession
) -> Group:
    group = await get_group_by_id(group_id, db)
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(group, field, value)
    await db.commit()
    await db.refresh(group)
    return group


async def assign_student(
    group_id: uuid.UUID, data: AssignStudentRequest, db: AsyncSession
) -> dict:
    await get_group_by_id(group_id, db)
    existing = await db.execute(
        select(GroupStudent).where(
            GroupStudent.group_id == group_id,
            GroupStudent.student_id == data.student_id,
        )
    )
    if existing.scalar_one_or_none():
        raise BusinessError("ALREADY_ASSIGNED", "Alumno ya asignado al grupo", status_code=409)
    db.add(GroupStudent(group_id=group_id, student_id=data.student_id))
    await db.commit()
    return {"assigned": True}


async def assign_teacher(
    group_id: uuid.UUID, data: AssignTeacherRequest, db: AsyncSession
) -> dict:
    await get_group_by_id(group_id, db)
    db.add(
        GroupTeacher(
            group_id=group_id,
            teacher_id=data.teacher_id,
            subject_id=data.subject_id,
        )
    )
    await db.commit()
    return {"assigned": True}


async def remove_student(
    group_id: uuid.UUID, student_id: uuid.UUID, db: AsyncSession
) -> dict:
    result = await db.execute(
        select(GroupStudent).where(
            GroupStudent.group_id == group_id,
            GroupStudent.student_id == student_id,
        )
    )
    gs = result.scalar_one_or_none()
    if not gs:
        raise BusinessError("NOT_FOUND", "Alumno no encontrado en este grupo", status_code=404)
    await db.delete(gs)
    await db.commit()
    return {"removed": True}


async def deactivate_group(group_id: uuid.UUID, db: AsyncSession) -> Group:
    group = await get_group_by_id(group_id, db)
    group.activo = False
    await db.commit()
    await db.refresh(group)
    return group
