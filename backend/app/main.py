import logging
import time
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware

from app.api.class_data import router as class_router
from app.api.child_health import router as child_health_router
from app.api.dashboard import router as dashboard_router
from app.api.endpoints import admin, admin_auth, auth, bug_reports, notifications
from app.api.endpoints.school_admin_auth import router as school_admin_router
from app.api.endpoints.attendance import router as attendance_router
from app.api.endpoints.leave_requests import router as leave_requests_router
from app.api.endpoints.health_exam import router as health_exam_router
from app.api.endpoints.medication import router as teacher_medication_router
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
from app.api.parent import router as parent_router
from app.api.teacher import reports_router
from app.api.teacher import router as teacher_router


from app.core.error_handlers import register_error_handlers


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Các logic chạy trước khi server nhận request (ví dụ: mở kết nối DB)
    yield
    # Các logic dọn dẹp khi tắt server (ví dụ: đóng kết nối DB)


app = FastAPI(
    title="Capstone Project API",
    description="Backend API services",
    version="1.0.0",
    lifespan=lifespan,
)

register_error_handlers(app)


logger = logging.getLogger(__name__)


@app.middleware("http")
async def timing_middleware(request: Request, call_next):
    start = time.perf_counter()

    response = await call_next(request)

    elapsed = (time.perf_counter() - start) * 1000

    logger.info("[API] %s %s - %.2f ms", request.method, request.url.path, elapsed)

    return response


app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"^https?://.*",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
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
app.include_router(teacher_medication_router, prefix="/api")
app.include_router(health_incident_router, prefix="/api")


@app.get("/")
async def root():
    return {"status": "ok", "message": "FastAPI is running successfully!"}


@app.get("/api/health")
async def health_check():
    return {"status": "ok", "message": "Server is healthy and running successfully"}
