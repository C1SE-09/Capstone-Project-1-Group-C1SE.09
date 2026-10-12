import time
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware

from app.api.class_data import router as class_router
from app.api.dashboard import router as dashboard_router
from app.api.endpoints import admin, auth, bug_reports, notifications
from app.api.endpoints.schedule import (
    router as schedule_router,
)
from app.api.endpoints.schedule import (
    subject_router,
    time_slot_router,
)
from app.api.endpoints.stt import router as stt_router
from app.api.model import router as model_router
from app.api.parent import router as parent_router
from app.api.teacher import reports_router
from app.api.teacher import router as teacher_router


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


@app.middleware("http")
async def timing_middleware(request: Request, call_next):
    start = time.perf_counter()

    response = await call_next(request)

    elapsed = (time.perf_counter() - start) * 1000

    print(f"[API] {request.method} {request.url.path} - {elapsed:.2f} ms")

    return response


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
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
app.include_router(model_router, prefix="/api/model", tags=["model"])
app.include_router(stt_router, prefix="/api/stt", tags=["stt"])
app.include_router(time_slot_router, prefix="/api")
app.include_router(subject_router, prefix="/api")
app.include_router(schedule_router, prefix="/api")
app.include_router(notifications.router)
app.include_router(bug_reports.router)


@app.get("/")
async def root():
    return {"status": "ok", "message": "FastAPI is running successfully!"}


@app.get("/api/health")
async def health_check():
    return {"status": "ok", "message": "Server is healthy and running successfully"}
