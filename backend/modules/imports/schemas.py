# backend/modules/imports/schemas.py
from typing import Any
from pydantic import BaseModel


class RowError(BaseModel):
    row: int
    field: str
    message: str


class ImportResult(BaseModel):
    total: int
    importados: int
    errores: int
    error_details: list[RowError]
    preview: list[dict[str, Any]]
