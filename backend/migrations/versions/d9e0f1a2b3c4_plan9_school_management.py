"""plan9_school_management

Revision ID: d9e0f1a2b3c4
Revises: c1a2b3d4e5f6
Create Date: 2026-04-04 10:00:00.000000

Adds: horario_clases, constancias; extends groups/subjects/event_participants
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "d9e0f1a2b3c4"
down_revision: Union[str, None] = "c1a2b3d4e5f6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # --- Extend groups ---
    op.add_column("groups", sa.Column("seccion", sa.String(length=10), nullable=True))
    op.add_column("groups", sa.Column("nivel", sa.String(length=40), nullable=True))
    op.add_column(
        "groups",
        sa.Column("activo", sa.Boolean(), nullable=False, server_default=sa.true()),
    )

    # --- Extend subjects ---
    op.add_column(
        "subjects",
        sa.Column("activo", sa.Boolean(), nullable=False, server_default=sa.true()),
    )

    # --- Redesign event_participants ---
    # Drop the composite PK, add id + tipo + group/subject/rol columns
    op.drop_table("event_participants")
    op.create_table(
        "event_participants",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("event_id", sa.UUID(), nullable=False),
        sa.Column(
            "tipo",
            sa.String(length=20),
            nullable=False,
            server_default=sa.text("'individual'"),
        ),
        sa.Column("user_id", sa.UUID(), nullable=True),
        sa.Column("group_id", sa.UUID(), nullable=True),
        sa.Column("subject_id", sa.UUID(), nullable=True),
        sa.Column("rol", sa.String(length=40), nullable=True),
        sa.Column(
            "added_at",
            sa.DateTime(),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["event_id"], ["events.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["group_id"], ["groups.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["subject_id"], ["subjects.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )

    # --- Create horario_clases ---
    op.create_table(
        "horario_clases",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("group_id", sa.UUID(), nullable=False),
        sa.Column("subject_id", sa.UUID(), nullable=False),
        sa.Column("teacher_id", sa.UUID(), nullable=False),
        sa.Column("dia_semana", sa.SmallInteger(), nullable=False),
        sa.Column("hora_inicio", sa.Time(), nullable=False),
        sa.Column("hora_fin", sa.Time(), nullable=False),
        sa.Column("aula", sa.String(length=40), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["group_id"], ["groups.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["subject_id"], ["subjects.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["teacher_id"], ["teachers.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )

    # --- Create constancias ---
    op.create_table(
        "constancias",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("event_id", sa.UUID(), nullable=False),
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("authorized_by", sa.UUID(), nullable=False),
        sa.Column(
            "authorized_at",
            sa.DateTime(),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("revoked_at", sa.DateTime(), nullable=True),
        sa.Column("notas", sa.String(length=255), nullable=True),
        sa.ForeignKeyConstraint(["event_id"], ["events.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["authorized_by"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("event_id", "user_id", name="uq_constancia_event_user"),
    )


def downgrade() -> None:
    op.drop_table("constancias")
    op.drop_table("horario_clases")

    op.drop_table("event_participants")
    op.create_table(
        "event_participants",
        sa.Column("event_id", sa.UUID(), nullable=False),
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.ForeignKeyConstraint(["event_id"], ["events.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("event_id", "user_id"),
    )

    op.drop_column("subjects", "activo")
    op.drop_column("groups", "activo")
    op.drop_column("groups", "nivel")
    op.drop_column("groups", "seccion")
