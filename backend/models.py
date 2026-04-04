"""Central import of all SQLAlchemy models.

Import this module wherever Base.metadata needs to reflect the full schema:
  - migrations/env.py
  - tests/conftest.py

Order matters: tables with FK dependencies must be imported after their targets.
"""
# Core
import core.audit  # noqa: F401 — audit_log table

# Plan 1
import modules.users.models  # noqa: F401 — users, roles, user_roles

# Plan 2
import modules.academic_cycles.models  # noqa: F401 — academic_cycles
import modules.students.models  # noqa: F401 — students, parents, student_parent
import modules.teachers.models  # noqa: F401 — teachers
import modules.subjects.models  # noqa: F401 — subjects
import modules.groups.models  # noqa: F401 — groups, group_students, group_teachers

# Plan 3 (stub models — schema defined, routers not yet implemented)
import modules.attendance.models  # noqa: F401 — attendance
import modules.grades.models  # noqa: F401 — evaluations, grades
import modules.justifications.models  # noqa: F401 — justifications
import modules.messaging.models  # noqa: F401 — messages, message_recipients
import modules.events.models  # noqa: F401 — events, event_participants
import modules.reports.models  # noqa: F401 — certificates, reports

# Plan 8
import modules.school_config.models  # noqa: F401 — school_config

# Plan 9
import modules.horarios.models  # noqa: F401 — horario_clases
import modules.constancias.models  # noqa: F401 — constancias
