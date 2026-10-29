"""Đồng bộ nghỉ có phép và đi trễ, hoàn tác đúng bản ghi do đơn tạo, giữ điểm danh thực."""

import logging
import uuid
from datetime import datetime, time, timedelta

from fastapi import HTTPException
from sqlalchemy import delete, select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

from app.config import vn_tz
from app.models.attendance import AttendanceRecord, AttendanceStatus
from app.models.leave_request import LeaveRequest, LeaveStatus, LeaveType

logger = logging.getLogger(__name__)


def sync_leave_request_to_attendance(
    db: Session, leave_request: LeaveRequest, teacher_id: uuid.UUID | None = None,
) -> list[AttendanceRecord]:
    if leave_request.status != LeaveStatus.APPROVED:
        return []
    days = (leave_request.to_date - leave_request.from_date).days
    if not 0 <= days < 366:
        raise HTTPException(status_code=422, detail="Khoảng ngày không hợp lệ hoặc vượt quá 366 ngày")

    is_late = leave_request.type == LeaveType.LATE
    target_status = AttendanceStatus.LATE if is_late else AttendanceStatus.EXCUSED_ABSENT
    eta = leave_request.expected_arrival_time if is_late else None
    if is_late:
        eta_str = eta.strftime("%H:%M") if eta else ""
        if eta_str and leave_request.reason:
            note = f"Đi trễ (ETA: {eta_str}): {leave_request.reason}"[:255]
        elif eta_str:
            note = f"Đi trễ (ETA: {eta_str})"[:255]
        elif leave_request.reason:
            note = f"Đi trễ: {leave_request.reason}"[:255]
        else:
            note = "Đi trễ"
    else:
        note = "Nghỉ có phép"

    records = []
    for day in range(days + 1):
        date = leave_request.from_date + timedelta(days=day)
        stmt = insert(AttendanceRecord).values(
            record_id=uuid.uuid4(), child_id=leave_request.child_id, class_id=leave_request.class_id,
            date=date, status=target_status, expected_arrival_time=eta, note=note,
            source_leave_id=leave_request.leave_id, teacher_id=teacher_id,
        ).on_conflict_do_nothing(index_elements=["child_id", "date"])
        # Không ghi đè kể cả bản ghi vắng do giáo viên đã lưu; hủy đơn không được xóa nó.
        db.execute(stmt)
        record = db.scalar(select(AttendanceRecord).where(
            AttendanceRecord.child_id == leave_request.child_id, AttendanceRecord.date == date,
        ))
        if record and record.source_leave_id == leave_request.leave_id:
            records.append(record)
    return records


def rollback_leave_request_attendance(db: Session, leave_request: LeaveRequest) -> int:
    result = db.execute(delete(AttendanceRecord).where(
        AttendanceRecord.source_leave_id == leave_request.leave_id,
        AttendanceRecord.child_id == leave_request.child_id,
        AttendanceRecord.class_id == leave_request.class_id,
        AttendanceRecord.date >= leave_request.from_date, AttendanceRecord.date <= leave_request.to_date,
        AttendanceRecord.status.in_([AttendanceStatus.EXCUSED_ABSENT, AttendanceStatus.LATE]),
        AttendanceRecord.check_in_time.is_(None),
    ))
    return result.rowcount


def cancellation_eligibility(req: LeaveRequest, now: datetime) -> tuple[bool, str | None]:
    now = now.astimezone(vn_tz)
    if req.status not in (LeaveStatus.PENDING, LeaveStatus.APPROVED):
        return False, "Đơn đã được xử lý, không thể hủy"
    if req.from_date < now.date():
        return False, "Không thể hủy đơn cho ngày đã qua"
    if req.from_date == now.date() and now.time() >= time(7, 30):
        return False, "Đã quá 07:30 AM, vui lòng liên hệ giáo viên để hủy"
    return True, None


def cancellation_metadata(req: LeaveRequest, parent_id: uuid.UUID | None) -> dict:
    if parent_id is None or parent_id != req.parent_id:
        return {"can_cancel": False, "cancel_before": None,
                "cancel_block_reason": "Chỉ phụ huynh gửi đơn mới có thể hủy"}
    allowed, reason = cancellation_eligibility(req, datetime.now(vn_tz))
    return {"can_cancel": allowed, "cancel_before": datetime.combine(req.from_date, time(7, 30), tzinfo=vn_tz),
            "cancel_block_reason": reason}


def cancel_leave_request(db: Session, request_id: uuid.UUID, parent_id: uuid.UUID) -> tuple[LeaveRequest, bool]:
    req = db.scalar(select(LeaveRequest).where(LeaveRequest.leave_id == request_id)
        .with_for_update(of=LeaveRequest).execution_options(populate_existing=True))
    if req is None:
        raise HTTPException(status_code=404, detail="Không tìm thấy đơn xin nghỉ học")
    if req.parent_id != parent_id:
        raise HTTPException(status_code=403, detail="Bạn không có quyền hủy đơn này")
    now = datetime.now(vn_tz)
    allowed, reason = cancellation_eligibility(req, now)
    if not allowed:
        raise HTTPException(status_code=400, detail=reason)
    deleted = rollback_leave_request_attendance(db, req) if req.status == LeaveStatus.APPROVED else 0
    req.status = LeaveStatus.CANCELLED
    req.action_at = now
    db.commit()
    db.refresh(req)
    logger.info("Hủy đơn: id=%s, số bản ghi tự tạo đã hoàn tác=%s", req.leave_id, deleted)
    return req, bool(deleted)
