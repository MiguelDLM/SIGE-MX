import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from core.exceptions import BusinessError
from modules.events.models import Event, EventParticipant
from modules.events.schemas import (
    EventCreate,
    EventParticipantRuleAdd,
    EventParticipantsAdd,
    EventParticipantResponse,
    EventUpdate,
)
from modules.groups.models import Group, GroupStudent
from modules.students.models import Student
from modules.subjects.models import Subject
from modules.teachers.models import Teacher
from modules.users.models import User


async def create_event(
    data: EventCreate, creado_por: uuid.UUID, db: AsyncSession
) -> Event:
    event = Event(**data.model_dump(), creado_por=creado_por)
    db.add(event)
    await db.commit()
    await db.refresh(event)
    return event


async def list_events(db: AsyncSession) -> list[Event]:
    result = await db.execute(
        select(Event).order_by(Event.fecha_inicio.asc().nullslast())
    )
    return list(result.scalars())


async def update_event(
    event_id: uuid.UUID, data: EventUpdate, db: AsyncSession
) -> Event:
    result = await db.execute(select(Event).where(Event.id == event_id))
    event = result.scalar_one_or_none()
    if event is None:
        raise BusinessError("EVENT_NOT_FOUND", "Evento no encontrado", status_code=404)
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(event, field, value)
    await db.commit()
    await db.refresh(event)
    return event


async def delete_event(event_id: uuid.UUID, db: AsyncSession) -> None:
    result = await db.execute(select(Event).where(Event.id == event_id))
    event = result.scalar_one_or_none()
    if event is None:
        raise BusinessError("EVENT_NOT_FOUND", "Evento no encontrado", status_code=404)
    await db.delete(event)
    await db.commit()


async def add_participants(
    event_id: uuid.UUID, data: EventParticipantsAdd, db: AsyncSession
) -> None:
    """Legacy: add individual user_ids directly."""
    result = await db.execute(select(Event).where(Event.id == event_id))
    if result.scalar_one_or_none() is None:
        raise BusinessError("EVENT_NOT_FOUND", "Evento no encontrado", status_code=404)

    for user_id in data.user_ids:
        existing = await db.execute(
            select(EventParticipant).where(
                EventParticipant.event_id == event_id,
                EventParticipant.tipo == "individual",
                EventParticipant.user_id == user_id,
            )
        )
        if existing.scalar_one_or_none() is None:
            db.add(EventParticipant(event_id=event_id, tipo="individual", user_id=user_id))

    await db.commit()


async def add_participant_rule(
    event_id: uuid.UUID, data: EventParticipantRuleAdd, db: AsyncSession
) -> EventParticipant:
    """Add a flexible participant rule (individual/grupo/materia/rol)."""
    result = await db.execute(select(Event).where(Event.id == event_id))
    if result.scalar_one_or_none() is None:
        raise BusinessError("EVENT_NOT_FOUND", "Evento no encontrado", status_code=404)

    ep = EventParticipant(
        event_id=event_id,
        tipo=data.tipo,
        user_id=data.user_id,
        group_id=data.group_id,
        subject_id=data.subject_id,
        rol=data.rol,
    )
    db.add(ep)
    await db.commit()
    await db.refresh(ep)
    return ep


async def remove_participant(participant_id: uuid.UUID, db: AsyncSession) -> None:
    ep = await db.get(EventParticipant, participant_id)
    if not ep:
        raise BusinessError("NOT_FOUND", "Participante no encontrado", status_code=404)
    await db.delete(ep)
    await db.commit()


async def list_participants(
    event_id: uuid.UUID, db: AsyncSession
) -> list[EventParticipantResponse]:
    """List all event participant rules (not expanded)."""
    result = await db.execute(
        select(EventParticipant)
        .where(EventParticipant.event_id == event_id)
        .order_by(EventParticipant.added_at)
    )
    rows = list(result.scalars())
    responses = []
    for ep in rows:
        label = None
        if ep.tipo == "individual" and ep.user_id:
            user = await db.get(User, ep.user_id)
            label = user.nombre if user else str(ep.user_id)
        elif ep.tipo == "grupo" and ep.group_id:
            group = await db.get(Group, ep.group_id)
            label = group.nombre if group else str(ep.group_id)
        elif ep.tipo == "materia" and ep.subject_id:
            subj = await db.get(Subject, ep.subject_id)
            label = f"Maestros de {subj.nombre}" if subj else str(ep.subject_id)
        elif ep.tipo == "rol":
            label = f"Todos: {ep.rol}"

        responses.append(
            EventParticipantResponse(
                id=ep.id,
                event_id=ep.event_id,
                tipo=ep.tipo,
                user_id=ep.user_id,
                group_id=ep.group_id,
                subject_id=ep.subject_id,
                rol=ep.rol,
                label=label,
            )
        )
    return responses


async def resolve_participants(
    event_id: uuid.UUID, db: AsyncSession
) -> list[dict]:
    """Expand all participant rules to individual users."""
    result = await db.execute(
        select(EventParticipant).where(EventParticipant.event_id == event_id)
    )
    rules = list(result.scalars())
    user_set: set[uuid.UUID] = set()

    for ep in rules:
        if ep.tipo == "individual" and ep.user_id:
            user_set.add(ep.user_id)

        elif ep.tipo == "grupo" and ep.group_id:
            gs_result = await db.execute(
                select(GroupStudent).where(GroupStudent.group_id == ep.group_id)
            )
            for gs in gs_result.scalars():
                student = await db.get(Student, gs.student_id)
                if student and student.user_id:
                    user_set.add(student.user_id)

        elif ep.tipo == "materia" and ep.subject_id:
            teachers_result = await db.execute(
                select(Teacher).where(Teacher.id.in_(
                    select(Teacher.id)
                ))
            )
            # Find teachers assigned to this subject via group_teachers
            from modules.groups.models import GroupTeacher
            gt_result = await db.execute(
                select(GroupTeacher).where(GroupTeacher.subject_id == ep.subject_id)
            )
            teacher_ids = {gt.teacher_id for gt in gt_result.scalars()}
            for tid in teacher_ids:
                teacher = await db.get(Teacher, tid)
                if teacher and teacher.user_id:
                    user_set.add(teacher.user_id)

        elif ep.tipo == "rol" and ep.rol:
            from modules.users.models import Role, UserRole
            role_result = await db.execute(
                select(Role).where(Role.nombre == ep.rol)
            )
            role = role_result.scalar_one_or_none()
            if role:
                ur_result = await db.execute(
                    select(UserRole).where(UserRole.role_id == role.id)
                )
                for ur in ur_result.scalars():
                    user_set.add(ur.user_id)

    users = []
    for uid in user_set:
        user = await db.get(User, uid)
        if user:
            users.append({"user_id": str(uid), "nombre": user.nombre, "email": user.email})
    return users
