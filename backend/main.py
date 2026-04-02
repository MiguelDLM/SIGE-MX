from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from core.audit import AuditMiddleware
from core.exceptions import BusinessError, business_error_handler, http_exception_handler

app = FastAPI(
    title="SIGE-MX API",
    description="Sistema Integral de Gestión Escolar",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.add_exception_handler(BusinessError, business_error_handler)
app.add_exception_handler(HTTPException, http_exception_handler)

app.add_middleware(AuditMiddleware)


@app.get("/health", tags=["health"])
async def health_check():
    return {"status": "ok"}


from modules.users.router import router as users_router
app.include_router(users_router)

from modules.auth.router import router as auth_router
app.include_router(auth_router)

from modules.academic_cycles.router import router as cycles_router
app.include_router(cycles_router)

from modules.students.router import router as students_router
app.include_router(students_router)

from modules.teachers.router import router as teachers_router
app.include_router(teachers_router)

from modules.subjects.router import router as subjects_router
app.include_router(subjects_router)

from modules.groups.router import router as groups_router
app.include_router(groups_router)

from modules.attendance.router import router as attendance_router
app.include_router(attendance_router)

from modules.grades.router import router as grades_router
app.include_router(grades_router)
