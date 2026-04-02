from fastapi import HTTPException, Request
from fastapi.responses import JSONResponse


class BusinessError(HTTPException):
    def __init__(self, code: str, message: str, status_code: int = 400):
        self.error_code = code
        super().__init__(status_code=status_code, detail=message)


async def business_error_handler(request: Request, exc: BusinessError) -> JSONResponse:
    return JSONResponse(
        status_code=exc.status_code,
        content={"error": {"code": exc.error_code, "message": exc.detail}},
    )


async def http_exception_handler(request: Request, exc: HTTPException) -> JSONResponse:
    return JSONResponse(
        status_code=exc.status_code,
        content={"error": {"code": "HTTP_ERROR", "message": exc.detail}},
    )
