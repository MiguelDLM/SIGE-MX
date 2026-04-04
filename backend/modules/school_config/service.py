from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from modules.school_config.models import SchoolConfig
from modules.school_config.schemas import SchoolConfigUpdate


async def get_config(db: AsyncSession) -> SchoolConfig:
    result = await db.execute(select(SchoolConfig).where(SchoolConfig.id == 1))
    config = result.scalar_one_or_none()
    if config is None:
        config = SchoolConfig(id=1)
        db.add(config)
        await db.commit()
        await db.refresh(config)
    return config


async def update_config(data: SchoolConfigUpdate, db: AsyncSession) -> SchoolConfig:
    config = await get_config(db)
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(config, field, value)
    await db.commit()
    await db.refresh(config)
    return config
