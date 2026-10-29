"""
backend/app/api/endpoints/attendance.py
=======================================
API Điểm danh:
- GET  /api/attendance: Lấy danh sách điểm danh lớp trong ngày (phản hồi < 200ms)
- POST /api/attendance/batch: Lưu điểm danh hàng loạt (PostgreSQL Upsert siêu tốc)
"""

from __future__ import annotations

import logging
import uuid
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_user
from app.models.attendance import AttendanceStatus, AttendanceRecord
from app.models.child import Child, ChildStatus
from app.models.user import Teacher, User, UserRole
from app.schemas.attendance_schema import (
    AttendanceBatchSaveRequest,
    AttendanceBatchSaveResponse,
    ChildAttendanceResponse,
    ClassAttendanceSummaryResponse,
    AttendanceNotifyAbsentRequest,
    AttendanceNotifyAbsentResponse
)
from app.tasks.attendance_notifications import (
    remind_unmarked_attendance,
    send_absence_notifications,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/attendance", tags=["attendance"])

def verify_class_access(class_id: uuid.UUID, current_user, db: Session)->None:
    """
    Kiểm tra phân quyền nghiêm ngặt (Class Isolation / Security):
    - Admin: Toàn quyền truy cập mọi lớp.
    - Giáo viên: Chỉ được truy cập lớp mà mình đang trực tiếp phụ trách.
    """
    # 1. Admin được phép truy cập tất cả
    role_val = current_user.role.value if hasattr(current_user.role, "value") else str(current_user.role)
    if role_val == UserRole.ADMIN.value:
        return

    # 2. Nếu là Teacher: kiểm tra class_id được gán trong bảng teacher
    if role_val == UserRole.TEACHER.value:
        if not current_user.teacher_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Tài khoản giáo viên chưa được liên kết với thông tin nhân sự",
            )
        teacher = db.scalar(select(Teacher).where(Teacher.teacher_id == current_user.teacher_id))
        if not teacher or teacher.class_id != class_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Bảo mật: Bạn không có quyền truy cập dữ liệu điểm danh của lớp này!",
            )
        return

    # 3. Phụ huynh hoặc role khác không được truy cập endpoint này
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Chức năng này chỉ dành cho Giáo viên phụ trách lớp và quản trị viên",
    )

# ===========================================================================
# 1. GET /api/attendance
# ===========================================================================
@router.get("", response_model=ClassAttendanceSummaryResponse)
def get_class_attendance(
    class_id: uuid.UUID = Query(..., description="ID của lớp cần xem điểm danh"),
    attendance_date: date = Query(default_factory=date.today, description="Ngày điểm danh (mặc định ngày hôm nay)"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Lấy danh sách điểm danh của cả lớp.
    - Nếu trẻ đã được lưu trong ngày -> Trả về trạng thái thực tế.
    - Nếu trẻ chưa được lưu -> Mặc định là PRESENT (đúng tinh thần 1 chạm cho cô).
    """
    verify_class_access(class_id=class_id, current_user=current_user, db=db)

    # 1. Lấy tất cả học sinh đang học trong lớp
    children = db.scalars(
        select(Child)
        .where(Child.class_id == class_id, Child.status == ChildStatus.ENROLLED)
        .order_by(Child.full_name.asc())
    ).all()

    # 2. Lấy các bản ghi điểm danh đã lưu hôm đó của lớp
    saved_records = db.scalars(
        select(AttendanceRecord).where(
            AttendanceRecord.class_id == class_id,
            AttendanceRecord.date == attendance_date,
        )
    ).all()

    # Mapping nhanh qua dictionary child_id -> record
    record_map: dict[uuid.UUID, AttendanceRecord] = {rec.child_id: rec for rec in saved_records}

    # 3. Hợp nhất danh sách & tính toán sĩ số
    result_items: list[ChildAttendanceResponse] = []
    present_cnt = 0
    absent_cnt = 0
    excused_absent_cnt = 0
    late_cnt = 0

    for child in children:
        rec = record_map.get(child.child_id)
        if rec:
            st = rec.status
            in_time = rec.check_in_time
            eta = rec.expected_arrival_time
            note = rec.note
        else:
            # Mặc định chưa lưu thì là Có mặt
            st = AttendanceStatus.PRESENT
            in_time = None
            eta = None
            note = None

        if st == AttendanceStatus.PRESENT:
            present_cnt += 1
        elif st == AttendanceStatus.ABSENT:
            absent_cnt += 1
        elif st == AttendanceStatus.EXCUSED_ABSENT:
            excused_absent_cnt += 1
        elif st == AttendanceStatus.LATE:
            late_cnt += 1

        result_items.append(
            ChildAttendanceResponse(
                child_id=child.child_id,
                full_name=child.full_name,
                nickname=child.nickname,
                avatar_url=getattr(child, "avatar_url", None),
                status=st,
                check_in_time=in_time,
                expected_arrival_time=eta,
                note=note,
            )
        )

    return ClassAttendanceSummaryResponse(
        class_id=class_id,
        date=attendance_date,
        total_children=len(children),
        present_count=present_cnt,
        absent_count=absent_cnt,
        excused_absent_count=excused_absent_cnt,
        late_count=late_cnt,
        children=result_items,
    )

# ===========================================================================
# 2. POST /api/attendance/batch
# ===========================================================================
@router.post("/batch", response_model=AttendanceBatchSaveResponse)
def save_class_attendance_batch(
    payload: AttendanceBatchSaveRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Lưu hoặc Cập nhật điểm danh cả lớp cùng lúc (Bulk Upsert).
    Sử dụng PostgreSQL ON CONFLICT DO UPDATE -> Tốc độ cực nhanh (< 50ms)
    và chống hoàn toàn race condition nếu cô giáo bấm liên tục.
    """
    verify_class_access(class_id=payload.class_id, current_user=current_user, db=db)

    if not payload.records:
        return AttendanceBatchSaveResponse(
            success=True,
            message="Không có dữ liệu điểm danh cần lưu.",
            saved_count=0,
        )

    teacher_id = current_user.teacher_id

    # Chuẩn bị dữ liệu cho câu lệnh insert/update
    values = [
        {
            "record_id": uuid.uuid4(),
            "child_id": r.child_id,
            "class_id": payload.class_id,
            "date": payload.date,
            "status": r.status,
            "check_in_time": r.check_in_time,
            "expected_arrival_time": r.expected_arrival_time,
            "source_leave_id": None,
            "note": r.note,
            "teacher_id": teacher_id,
        }
        for r in payload.records
    ]

    # Cú pháp Native PostgreSQL Upsert trên UniqueConstraint (child_id, date)
    stmt = insert(AttendanceRecord).values(values)
    upsert_stmt = stmt.on_conflict_do_update(
        constraint="uq_attendance_child_date",
        set_={
            "status": stmt.excluded.status,
            "check_in_time": stmt.excluded.check_in_time,
            "expected_arrival_time": stmt.excluded.expected_arrival_time,
            "source_leave_id": None,
            "note": stmt.excluded.note,
            "teacher_id": stmt.excluded.teacher_id,
            "updated_at": stmt.excluded.updated_at,
        },
    )

    db.execute(upsert_stmt)
    db.commit()

    return AttendanceBatchSaveResponse(
        success=True,
        message=f"Đã lưu điểm danh thành công cho {len(payload.records)} trẻ",
        saved_count=len(payload.records),
    )

# ===========================================================================
# 3. POST /api/attendance/notify-absent
# ===========================================================================
@router.post("/notify-absent", response_model = AttendanceNotifyAbsentResponse)
def notify_absent_parents(
    payload: AttendanceNotifyAbsentRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Kích hoạt gửi Push Notification cho phụ huynh của các bé vắng mặt.
    - Chạy ngầm qua Celery worker (đáp ứng SLA < 60s, không treo app của cô).
    """
    verify_class_access(class_id=payload.class_id, current_user=current_user, db=db)

    # Kiểm tra xem có học sinh vắng trong lớp không
    query = select(AttendanceRecord).where(
        AttendanceRecord.class_id == payload.class_id,
        AttendanceRecord.date == payload.date,
        AttendanceRecord.status == AttendanceStatus.ABSENT,
    )
    if payload.child_ids:
        query = query.where(AttendanceRecord.child_id.in_(payload.child_ids))
    absent_records = db.scalars(query).all()
    if not absent_records:
        return AttendanceNotifyAbsentResponse(
            success=True,
            message="Không có học sinh vắng mặt nào cần thông báo.",
            target_count=0,
        )
    target_ids = [str(r.child_id) for r in absent_records]
    # Đẩy job vào hàng đợi Celery
    send_absence_notifications.delay(
        str(payload.class_id),
        payload.date.isoformat(),
        target_ids,
    )
    return AttendanceNotifyAbsentResponse(
        success=True,
        message=f"Đã kích hoạt gửi thông báo đến phụ huynh của {len(target_ids)} bé vắng mặt.",
        target_count=len(target_ids),
    )

# ===========================================================================
# 4. POST /api/attendance/trigger-reminder (Dành cho Quản trị viên / Test)
# ===========================================================================
@router.post("/trigger-reminder")
def trigger_attendance_reminder(
    target_date: date = Query(default_factory=date.today, description="Ngày cần nhắc nhở"),
    current_user: User = Depends(get_current_user)
):
    """
    Kích hoạt thủ công luồng quét nhắc nhở điểm danh 07:40.
    Hữu ích để demo hoặc kiểm thử chức năng nhắc nhở.
    """
    # Kích hoạt task chạy ngầm
    task = remind_unmarked_attendance.delay(target_date.isoformat())
    return{
        "success": True,
        "message": f"Đã kích hoạt quét nhắc nhở điểm danh cho ngày {target_date}",
        "task_id": task.id,
    }
