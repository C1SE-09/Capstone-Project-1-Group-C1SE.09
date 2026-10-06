"""
app/api/endpoints/schedule.py
==============================
FastAPI Routers cho quản lý Thời khóa biểu (TimeSlot, Subject, ClassSchedule).
"""

import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_user
from app.models.user import User
from app.schemas.schedule import (
    TimeSlotCreate,
    TimeSlotUpdate,
    TimeSlotResponse,
    SubjectCreate,
    SubjectUpdate,
    SubjectResponse,
    ClassScheduleCreate,
    ClassScheduleUpdate,
    ClassScheduleBulkCreateRequest,
    ClassScheduleResponse,
)
from app.services import schedule_service

router = APIRouter(prefix="/schedules", tags=["schedules"])
time_slot_router = APIRouter(prefix="/time-slots", tags=["time-slots"])
subject_router = APIRouter(prefix="/subjects", tags=["subjects"])


# ===========================================================================
# 1. TimeSlot APIs
# ===========================================================================
@time_slot_router.get("", response_model=list[TimeSlotResponse])
def get_time_slots(db: Session = Depends(get_db)):
    """Lấy danh sách tất cả các khung giờ (sắp xếp theo order_index)."""
    return schedule_service.get_all_time_slots(db)


@time_slot_router.post("", response_model=TimeSlotResponse, status_code=status.HTTP_201_CREATED)
def create_time_slot(
    data: TimeSlotCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Tạo mới một khung giờ (Cần đăng nhập)."""
    return schedule_service.create_time_slot(db, data)


@time_slot_router.put("/{slot_id}", response_model=TimeSlotResponse)
def update_time_slot(
    slot_id: uuid.UUID,
    data: TimeSlotUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Cập nhật khung giờ."""
    updated = schedule_service.update_time_slot(db, slot_id, data)
    if not updated:
        raise HTTPException(status_code=404, detail="Không tìm thấy khung giờ")
    return updated


@time_slot_router.delete("/{slot_id}")
def delete_time_slot(
    slot_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Xóa khung giờ."""
    success = schedule_service.delete_time_slot(db, slot_id)
    if not success:
        raise HTTPException(status_code=404, detail="Không tìm thấy khung giờ")
    return {"message": "Đã xóa khung giờ thành công"}


# ===========================================================================
# 2. Subject APIs
# ===========================================================================
@subject_router.get("", response_model=list[SubjectResponse])
def get_subjects(db: Session = Depends(get_db)):
    """Lấy danh sách tất cả môn học / hoạt động."""
    return schedule_service.get_all_subjects(db)


@subject_router.post("", response_model=SubjectResponse, status_code=status.HTTP_201_CREATED)
def create_subject(
    data: SubjectCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Tạo mới môn học / hoạt động (Cần đăng nhập)."""
    return schedule_service.create_subject(db, data)


@subject_router.put("/{subject_id}", response_model=SubjectResponse)
def update_subject(
    subject_id: uuid.UUID,
    data: SubjectUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Cập nhật môn học."""
    updated = schedule_service.update_subject(db, subject_id, data)
    if not updated:
        raise HTTPException(status_code=404, detail="Không tìm thấy môn học")
    return updated


@subject_router.delete("/{subject_id}")
def delete_subject(
    subject_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Xóa môn học."""
    success = schedule_service.delete_subject(db, subject_id)
    if not success:
        raise HTTPException(status_code=404, detail="Không tìm thấy môn học")
    return {"message": "Đã xóa môn học thành công"}


# ===========================================================================
# 3. ClassSchedule APIs (Option A - Flat Response)
# ===========================================================================
@router.get("/class/{class_id}", response_model=list[ClassScheduleResponse])
def get_class_schedule(
    class_id: uuid.UUID,
    day_of_week: int | None = None,
    db: Session = Depends(get_db),
):
    """
    Lấy thời khóa biểu của 1 lớp (dạng Flat List Option A).
    - `class_id`: UUID của lớp học
    - `day_of_week`: Tùy chọn lọc theo ngày (2=Thứ 2, 3=Thứ 3, ..., 7=Thứ 7)
    """
    return schedule_service.get_schedules_by_class(db, class_id, day_of_week=day_of_week)


@router.get("/teacher/{teacher_id}", response_model=list[ClassScheduleResponse])
def get_teacher_schedule(
    teacher_id: uuid.UUID,
    day_of_week: int | None = None,
    db: Session = Depends(get_db),
):
    """
    Lấy lịch giảng dạy của giáo viên.
    - `teacher_id`: UUID của giáo viên
    - `day_of_week`: Tùy chọn lọc theo ngày (2=Thứ 2, ..., 7=Thứ 7)
    """
    return schedule_service.get_schedules_by_teacher(db, teacher_id, day_of_week=day_of_week)


@router.post("", response_model=ClassScheduleResponse, status_code=status.HTTP_201_CREATED)
def create_class_schedule(
    data: ClassScheduleCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Tạo mới 1 tiết học trong thời khóa biểu (Có kiểm tra trùng lịch)."""
    try:
        return schedule_service.create_class_schedule(db, data)
    except ValueError as err:
        raise HTTPException(status_code=400, detail=str(err))


@router.post("/bulk-upsert", response_model=list[ClassScheduleResponse])
def bulk_upsert_class_schedule(
    data: ClassScheduleBulkCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Tạo/Thay thế toàn bộ thời khóa biểu tuần cho 1 lớp."""
    return schedule_service.bulk_upsert_class_schedule(db, data.class_id, data.schedules)


@router.put("/{schedule_id}", response_model=ClassScheduleResponse)
def update_class_schedule(
    schedule_id: uuid.UUID,
    data: ClassScheduleUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Cập nhật tiết học."""
    try:
        updated = schedule_service.update_class_schedule(db, schedule_id, data)
        if not updated:
            raise HTTPException(status_code=404, detail="Không tìm thấy tiết học")
        return updated
    except ValueError as err:
        raise HTTPException(status_code=400, detail=str(err))


@router.delete("/{schedule_id}")
def delete_class_schedule(
    schedule_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Xóa tiết học."""
    success = schedule_service.delete_class_schedule(db, schedule_id)
    if not success:
        raise HTTPException(status_code=404, detail="Không tìm thấy tiết học")
    return {"message": "Đã xóa tiết học thành công"}
