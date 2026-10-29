"""
backend/app/services/attendance_sync_service.py
===============================================
Service tự động đồng bộ điểm danh khi đơn xin nghỉ học / đi trễ được duyệt (Task 1: Attendance Auto-Sync Hook),
và rollback bản ghi điểm danh khi phụ huynh huỷ đơn trước 07:30 AM.
"""

from __future__ import annotations

import logging
import uuid
from datetime import datetime, time, timedelta
from zoneinfo import ZoneInfo

from fastapi import HTTPException, status
from sqlalchemy import delete, func, select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

from app.models.attendance import AttendanceRecord, AttendanceStatus
from app.models.leave_request import LeaveRequest, LeaveStatus, LeaveType

logger = logging.getLogger(__name__)

VN_TZ = ZoneInfo("Asia/Ho_Chi_Minh")
CUTOFF_TIME = time(7, 30)


def sync_leave_request_to_attendance(
    db: Session,
    leave_request: LeaveRequest,
    teacher_id: uuid.UUID | None = None,
) -> list[AttendanceRecord]:
    """
    Tự động đồng bộ đơn xin nghỉ / đi trễ đã duyệt sang bảng attendance_record:
    - Nếu đơn là LATE: status = AttendanceStatus.LATE, expected_arrival_time = ETA, note = 'Đi trễ...'
    - Nếu đơn là SINGLE_DAY / MULTI_DAY: status = AttendanceStatus.EXCUSED_ABSENT, note = 'Nghỉ có phép...'
    - Duyệt qua toàn bộ các ngày từ from_date đến to_date.
    - Áp dụng PostgreSQL Upsert (ON CONFLICT DO UPDATE) an toàn, tránh race condition.
    """
    if leave_request.status != LeaveStatus.APPROVED:
        logger.warning(
            "Bỏ qua đồng bộ điểm danh: Đơn %s chưa ở trạng thái APPROVED (status=%s)",
            leave_request.leave_id,
            leave_request.status,
        )
        return []

    synced_records: list[AttendanceRecord] = []
    curr_date = leave_request.from_date

    while curr_date <= leave_request.to_date:
        if leave_request.type == LeaveType.LATE:
            target_status = AttendanceStatus.LATE
            eta = leave_request.expected_arrival_time
            eta_str = eta.strftime("%H:%M") if eta else ""
            note_content = f"Đi trễ{f' (ETA: {eta_str})' if eta_str else ''}: {leave_request.reason[:120]}"
        else:
            target_status = AttendanceStatus.EXCUSED_ABSENT
            eta = None
            note_content = f"Nghỉ có phép: {leave_request.reason[:150]}"

        record_id = uuid.uuid4()
        insert_stmt = insert(AttendanceRecord).values(
            record_id=record_id,
            child_id=leave_request.child_id,
            class_id=leave_request.class_id,
            date=curr_date,
            status=target_status,
            expected_arrival_time=eta,
            note=note_content,
            teacher_id=teacher_id,
        )

        upsert_stmt = insert_stmt.on_conflict_do_update(
            constraint="uq_attendance_child_date",
            set_={
                "status": target_status,
                "expected_arrival_time": eta,
                "note": note_content,
                "teacher_id": teacher_id,
                "updated_at": func.now(),
            },
        )
        db.execute(upsert_stmt)

        # Lấy lại bản ghi sau upsert
        saved_rec = db.scalar(
            select(AttendanceRecord).where(
                AttendanceRecord.child_id == leave_request.child_id,
                AttendanceRecord.date == curr_date,
            )
        )
        if saved_rec:
            synced_records.append(saved_rec)

        curr_date += timedelta(days=1)

    logger.info(
        "Auto-Sync Attendance: Đã đồng bộ %d ngày cho học sinh %s (Đơn: %s)",
        len(synced_records),
        leave_request.child_id,
        leave_request.leave_id,
    )
    return synced_records


def rollback_leave_request_attendance(
    db: Session,
    leave_request: LeaveRequest,
) -> int:
    """
    Rollback điểm danh khi phụ huynh huỷ đơn trước 07:30 AM:
    - Xoá hẳn bản ghi điểm danh (DELETE) của trẻ trong các ngày thuộc phạm vi đơn
    - Cho phép cô giáo điểm danh lại bình thường khi trẻ đến lớp.
    """
    stmt = delete(AttendanceRecord).where(
        AttendanceRecord.child_id == leave_request.child_id,
        AttendanceRecord.date >= leave_request.from_date,
        AttendanceRecord.date <= leave_request.to_date,
    )
    result = db.execute(stmt)
    deleted_count = result.rowcount
    logger.info(
        "Rollback Attendance: Đã xoá %d bản ghi điểm danh của học sinh %s (Đơn: %s)",
        deleted_count,
        leave_request.child_id,
        leave_request.leave_id,
    )
    return deleted_count


def cancel_leave_request(
    db: Session,
    request_id: uuid.UUID,
    parent_id: uuid.UUID,
) -> tuple[LeaveRequest, bool]:
    """
    Phụ huynh huỷ đơn xin nghỉ / đi trễ:
    - Kiểm tra bảo mật: Chỉ phụ huynh tạo đơn mới được quyền huỷ.
    - Điều kiện thời gian:
        + Nếu ngày nghỉ là hôm nay (from_date == today): Chỉ được huỷ trước 07:30 AM.
        + Nếu từ 07:30 AM trở đi: Chặn huỷ tự động (HTTP 400).
        + Nếu ngày nghỉ trong tương lai (from_date > today): Được phép huỷ bình thường.
    - Chuyển status = CANCELLED.
    - Rollback bản ghi điểm danh tương ứng.
    """
    req = db.scalar(select(LeaveRequest).where(LeaveRequest.request_id == request_id))
    if not req:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Không tìm thấy đơn xin nghỉ học.",
        )

    if req.parent_id != parent_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Bảo mật: Bạn không có quyền huỷ đơn của học sinh khác!",
        )

    if req.status == LeaveStatus.CANCELLED:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Đơn này đã được huỷ trước đó.",
        )

    now_vn = datetime.now(VN_TZ)
    today = now_vn.date()

    if req.from_date < today:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Không thể huỷ đơn xin nghỉ cho ngày trong quá khứ.",
        )

    if req.from_date == today and now_vn.time() >= CUTOFF_TIME:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Đã quá 07:30 AM ngày xin nghỉ, hệ thống không thể tự động huỷ đơn. Vui lòng liên hệ trực tiếp cô giáo phụ trách lớp.",
        )

    # 1. Chuyển trạng thái đơn sang CANCELLED
    req.status = LeaveStatus.CANCELLED
    req.action_at = datetime.now(VN_TZ)

    # 2. Rollback điểm danh (Xoá bản ghi để cô điểm danh lại bình thường)
    deleted_count = rollback_leave_request_attendance(db, req)

    db.commit()
    db.refresh(req)

    logger.info(
        "Phụ huynh %s huỷ thành công đơn %s (deleted_attendance=%d)",
        parent_id,
        req.leave_id,
        deleted_count,
    )
    return req, bool(deleted_count > 0)
