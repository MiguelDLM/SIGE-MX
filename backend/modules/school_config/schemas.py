from typing import Optional

from pydantic import BaseModel


class SchoolConfigUpdate(BaseModel):
    nombre: Optional[str] = None
    cct: Optional[str] = None
    turno: Optional[str] = None
    direccion: Optional[str] = None


class SchoolConfigResponse(BaseModel):
    nombre: Optional[str] = None
    cct: Optional[str] = None
    turno: Optional[str] = None
    direccion: Optional[str] = None

    model_config = {"from_attributes": True}
