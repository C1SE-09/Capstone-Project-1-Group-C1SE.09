from contextlib import asynccontextmanager

from app.api.class_data import router as class_data_router
from app.api.teacher import router as teacher_router
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware


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
app.include_router(teacher_router)
app.include_router(class_data_router)


@app.get("/")
async def root():
    return {"status": "ok", "message": "FastAPI is running successfully!"}


@app.get("/api/health")
async def health_check():
    return {"status": "ok", "message": "Server is healthy and running successfully"}
