import logging
import time
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import text

from app.api.class_data import router as class_router
from app.api.child_health import router as child_health_router
from app.api.dashboard import router as dashboard_router
from app.api.endpoints import admin, admin_auth, auth, bug_reports, notifications
from app.api.endpoints.school_admin_auth import router as school_admin_router
from app.api.endpoints.attendance import router as attendance_router
from app.api.endpoints.leave_request import router as leave_requests_router
from app.api.endpoints.health_exam import router as health_exam_router
from app.api.endpoints.health_incident import router as health_incident_router
from app.api.endpoints.admin_dashboard import (
    router as admin_dashboard_router,
)
from app.api.endpoints.bug_report_stats import stats_router
from app.api.endpoints.schedule import (
    router as schedule_router,
)
from app.api.endpoints.schedule import (
    subject_router,
    time_slot_router,
)
from app.api.endpoints.stt import router as stt_router
from app.api.endpoints.report_responses import router as report_responses_router
from app.api.parent import router as parent_router
from app.api.teacher import reports_router
from app.api.teacher import router as teacher_router


from app.config import settings
from app.core.database import SessionLocal
from app.core.error_handlers import register_error_handlers
from app.core.security import get_redis_client

_WEAK_JWT_SECRETS = {
    "",
    "change-me",
    "change-me-to-a-random-32-byte-string",
    "kinderlog-secret",
}


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Kiểm tra cấu hình bảo mật khi khởi động
    if settings.jwt_secret_key in _WEAK_JWT_SECRETS:
        if settings.environment.lower() == "production":
            raise RuntimeError(
                "JWT_SECRET_KEY không được phép dùng giá trị mặc định yếu ở môi trường production."
            )
        logger.warning(
            "CẢNH BÁO BẢO MẬT: JWT_SECRET_KEY đang dùng giá trị mặc định yếu. Hãy cấu hình biến môi trường trước khi deploy production."
        )
    yield
    # Các logic dọn dẹp khi tắt server (ví dụ: đóng kết nối DB)


_is_prod = settings.environment.lower() == "production" and not settings.debug

app = FastAPI(
    title="Capstone Project API",
    description="Backend API services",
    version="1.0.0",
    lifespan=lifespan,
    docs_url=None if _is_prod else "/docs",
    redoc_url=None if _is_prod else "/redoc",
    openapi_url=None if _is_prod else "/openapi.json",
)

register_error_handlers(app)


logger = logging.getLogger(__name__)


@app.middleware("http")
async def timing_middleware(request: Request, call_next):
    start = time.perf_counter()

    response = await call_next(request)

    elapsed = (time.perf_counter() - start) * 1000

    logger.info("[API] %s %s - %.2f ms", request.method, request.url.path, elapsed)
    response.headers.setdefault("X-Content-Type-Options", "nosniff")
    response.headers.setdefault("X-Frame-Options", "DENY")
    response.headers.setdefault("Referrer-Policy", "strict-origin-when-cross-origin")

    return response


_allowed_origins = [
    origin.strip() for origin in settings.cors_origins.split(",") if origin.strip()
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=_allowed_origins,
    allow_origin_regex=r"^https://admin-web-kinderlog(-[a-zA-Z0-9-]+)?\.vercel\.app$",
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "Accept", "Origin", "X-Requested-With"],
)

# ---------------------------------------------------------------------------
# Routers
# ---------------------------------------------------------------------------
app.include_router(auth.router, prefix="/api")
app.include_router(admin.router, prefix="/api")
app.include_router(teacher_router)
app.include_router(parent_router)
app.include_router(reports_router)
app.include_router(class_router)
app.include_router(dashboard_router)
app.include_router(child_health_router)
app.include_router(stt_router, prefix="/api/stt", tags=["stt"])
app.include_router(time_slot_router, prefix="/api")
app.include_router(subject_router, prefix="/api")
app.include_router(schedule_router, prefix="/api")
app.include_router(admin_auth.router)
app.include_router(school_admin_router)
app.include_router(notifications.router)
app.include_router(stats_router)
app.include_router(bug_reports.router)
app.include_router(admin_dashboard_router, prefix="/api")
app.include_router(attendance_router, prefix="/api")
app.include_router(leave_requests_router, prefix="/api")
app.include_router(health_exam_router, prefix="/api")
app.include_router(health_incident_router, prefix="/api")
app.include_router(report_responses_router)


@app.get("/")
async def root():
    return {"status": "ok", "message": "FastAPI is running successfully!"}


@app.get("/api/health")
def health_check():
    checks: dict[str, str] = {"database": "ok", "redis": "ok"}

    db = SessionLocal()
    try:
        db.execute(text("SELECT 1"))
    except Exception as exc:  # noqa: BLE001
        logger.error("[Health] Kiểm tra PostgreSQL thất bại: %s", exc)
        checks["database"] = "error"
    finally:
        db.close()

    try:
        if not get_redis_client().ping():
            checks["redis"] = "error"
    except Exception as exc:  # noqa: BLE001
        logger.error("[Health] Kiểm tra Redis thất bại: %s", exc)
        checks["redis"] = "error"

    is_healthy = all(value == "ok" for value in checks.values())
    payload = {
        "status": "ok" if is_healthy else "degraded",
        "message": (
            "Server is healthy and running successfully"
            if is_healthy
            else "Một số dịch vụ nền đang gặp sự cố"
        ),
        "checks": checks,
    }
    if not is_healthy:
        return JSONResponse(status_code=503, content=payload)
    return payload
