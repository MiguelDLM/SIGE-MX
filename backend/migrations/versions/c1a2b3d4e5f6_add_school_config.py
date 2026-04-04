"""add_school_config

Revision ID: c1a2b3d4e5f6
Revises: bf731a076897
Create Date: 2026-04-03 12:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = 'c1a2b3d4e5f6'
down_revision: Union[str, None] = 'bf731a076897'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'school_config',
        sa.Column('id', sa.Integer(), primary_key=True),
        sa.Column('nombre', sa.String(), nullable=True),
        sa.Column('cct', sa.String(), nullable=True),
        sa.Column('turno', sa.String(), nullable=True),
        sa.Column('direccion', sa.String(), nullable=True),
    )


def downgrade() -> None:
    op.drop_table('school_config')
