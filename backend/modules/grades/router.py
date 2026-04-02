# backend/modules/grades/router.py
import uuid
from typing import Optional

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from core.database import get_db
from core.security import require_roles
from modules.grades import service
from modules.grades.schemas import (
    EvaluationCreate,
    EvaluationResponse,
    GradeCreate,
    GradeResponse,
    GradeUpdate,
)

router = APIRouter(prefix="/api/v1/grades", tags=["grades"])
_write = ["docente", "control_escolar", "directivo"]
_read = ["docente", "control_escolar", "directivo"]


@router.post("/evaluations/", status_code=status.HTTP_201_CREATED)
async def create_evaluation(
    data: EvaluationCreate,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_write)),
):
    evaluation = await service.create_evaluation(data, db)
    return {"data": EvaluationResponse.model_validate(evaluation)}


@router.get("/evaluations/")
async def list_evaluations(
    group_id: Optional[uuid.UUID] = Query(None),
    subject_id: Optional[uuid.UUID] = Query(None),
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_read)),
):
    evaluations = await service.list_evaluations(db, group_id, subject_id)
    return {"data": [EvaluationResponse.model_validate(e) for e in evaluations]}


@router.post("/", status_code=status.HTTP_201_CREATED)
async def create_grade(
    data: GradeCreate,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_write)),
):
    grade = await service.create_grade(data, db)
    return {"data": GradeResponse.model_validate(grade)}


@router.put("/{grade_id}")
async def update_grade(
    grade_id: uuid.UUID,
    data: GradeUpdate,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_write)),
):
    grade = await service.update_grade(grade_id, data, db)
    return {"data": GradeResponse.model_validate(grade)}


@router.get("/student/{student_id}")
async def get_student_grades(
    student_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_roles(_read)),
):
    grades = await service.list_grades_by_student(student_id, db)
    return {"data": [GradeResponse.model_validate(g) for g in grades]}
