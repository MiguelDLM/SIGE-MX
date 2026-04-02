from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

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


@app.get("/health", tags=["health"])
async def health_check():
    return {"status": "ok"}


from modules.users.router import router as users_router
app.include_router(users_router)
