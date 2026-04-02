# backend/modules/academic_cycles/service.py
import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from core.exceptions import BusinessError
from modules.academic_cycles.models import AcademicCycle
from modules.academic_cycles.schemas import AcademicCycleCreate, AcademicCycleUpdate


async def create_cycle(data: AcademicCycleCreate, db: AsyncSession) -> AcademicCycle:
    cycle = AcademicCycle(**data.model_dump())
    db.add(cycle)
    await db.commit()
    await db.refresh(cycle)
    return cycle


async def list_cycles(db: AsyncSession) -> list[AcademicCycle]:
    result = await db.execute(select(AcademicCycle).order_by(AcademicCycle.fecha_inicio.desc().nullslast()))
    return list(result.scalars())


async def get_active_cycle(db: AsyncSession) -> AcademicCycle:
    result = await db.execute(
        select(AcademicCycle).where(AcademicCycle.activo == True).limit(1)  # noqa: E712
    )
    cycle = result.scalar_one_or_none()
    if cycle is None:
        raise BusinessError("NO_ACTIVE_CYCLE", "No hay ciclo escolar activo", status_code=404)
    return cycle


async def get_cycle_by_id(cycle_id: uuid.UUID, db: AsyncSession) -> AcademicCycle:
    result = await db.execute(select(AcademicCycle).where(AcademicCycle.id == cycle_id))
    cycle = result.scalar_one_or_none()
    if cycle is None:
        raise BusinessError("CYCLE_NOT_FOUND", "Ciclo escolar no encontrado", status_code=404)
    return cycle


async def update_cycle(
    cycle_id: uuid.UUID, data: AcademicCycleUpdate, db: AsyncSession
) -> AcademicCycle:
    cycle = await get_cycle_by_id(cycle_id, db)
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(cycle, field, value)
    await db.commit()
    await db.refresh(cycle)
    return cycle
