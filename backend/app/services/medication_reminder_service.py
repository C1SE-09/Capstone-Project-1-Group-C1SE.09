"""
backend/app/services/medication_reminder_service.py
===================================================
Service quản lý việc quét và gửi thông báo nhắc nhở dặn thuốc theo từng lớp:
- Quét các đơn dặn thuốc đang ACTIVE và trong thời hạn hiệu lực.
- Bỏ qua các bé hôm nay vắng mặt (ABSENT / EXCUSED_ABSENT).
- Lọc ra những bé chưa được giáo viên cho uống thuốc (chưa có log is_given=True).
- Gửi grouped push notification tới toàn bộ giáo viên phụ trách của lớp.
"""

from __future__ import annotations

import logging
import uuid
from datetime import date, datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.attendance import AttendanceRecord, AttendanceStatus
from app.models.device_token import DeviceToken
from app.models.medication import (
    MedicationLog,
    MedicationRequest,
    MedicationRequestStatus,
    MedicationSession,
)
from app.models.user import Class_, Teacher, User
from app.services.notification_service import (
    is_invalid_token,
    send_push_notification,
)

logger = logging.getLogger(__name__)

SESSION_LABELS = {
    "morning": "Sáng",
    "noon": "Trưa",
    "afternoon": "Chiều",
}


def determine_current_session(now_dt: datetime | None = None) -> str:
    """Xác định buổi uống thuốc tương ứng theo giờ hiện tại tại Việt Nam (UTC+7)."""
    vn_tz = timezone(timedelta(hours=7))
    current_time = now_dt.astimezone(vn_tz) if now_dt else datetime.now(vn_tz)
    hour = current_time.hour
    minute = current_time.minute
    total_minutes = hour * 60 + minute

    # Trước 10:30 (630 phút) -> Sáng
    if total_minutes < 630:
        return MedicationSession.MORNING.value
    # Từ 10:30 đến 13:30 (810 phút) -> Trưa
    if total_minutes < 810:
        return MedicationSession.NOON.value
    # Sau 13:30 -> Chiều
    return MedicationSession.AFTERNOON.value


def get_unadministered_medications_by_class(
    db: Session,
    target_date: date,
    session_name: str,
) -> dict[uuid.UUID, list[dict]]:
    """
    Tìm danh sách các đơn dặn thuốc chưa được cho uống theo từng lớp.

    Returns:
        dict: {class_id: [
            {
                "request_id": UUID,
                "child_id": UUID,
                "child_name": str,
                "medication_name": str,
                "dosage": str,
            }, ...
        ]}
    """
    # 1. Truy vấn toàn bộ đơn thuốc đang có hiệu lực trong ngày target_date
    requests = db.scalars(
        select(MedicationRequest)
        .where(
            MedicationRequest.status == MedicationRequestStatus.ACTIVE,
            MedicationRequest.start_date <= target_date,
            MedicationRequest.end_date >= target_date,
        )
    ).all()

    if not requests:
        return {}

    # 2. Lấy danh sách trẻ vắng mặt hôm nay để tự động loại trừ (tránh làm phiền giáo viên)
    absent_child_ids = set(
        db.scalars(
            select(AttendanceRecord.child_id).where(
                AttendanceRecord.date == target_date,
                AttendanceRecord.status.in_([
                    AttendanceStatus.ABSENT,
                    AttendanceStatus.EXCUSED_ABSENT,
                ]),
            )
        ).all()
    )

    # 3. Lấy tập hợp các request_id đã uống thành công trong buổi này
    given_request_ids = set(
        db.scalars(
            select(MedicationLog.request_id).where(
                MedicationLog.log_date == target_date,
                MedicationLog.session == session_name,
                MedicationLog.is_given.is_(True),
            )
        ).all()
    )

    result: dict[uuid.UUID, list[dict]] = {}

    for req in requests:
        # Bỏ qua nếu đơn thuốc không dặn buổi này
        req_sessions = req.sessions or []
        if session_name.lower() not in [s.lower() for s in req_sessions]:
            continue

        # Bỏ qua nếu bé hôm nay vắng mặt
        if req.child_id in absent_child_ids:
            continue

        # Bỏ qua nếu đã uống thành công
        if req.request_id in given_request_ids:
            continue

        child = req.child
        child_name = (
            child.full_name.strip()
            if (child and child.full_name)
            else (child.nickname if child else "Bé")
        )

        item = {
            "request_id": req.request_id,
            "child_id": req.child_id,
            "child_name": child_name,
            "medication_name": req.medication_name,
            "dosage": req.dosage,
        }

        result.setdefault(req.class_id, []).append(item)

    return result


def send_grouped_medication_reminder(
    db: Session,
    target_date: date | None = None,
    session_name: str | None = None,
) -> dict:
    """
    Quét và gửi push notification nhắc uống thuốc cho toàn bộ giáo viên phụ trách các lớp:
    - target_date: Ngày cần quét (mặc định hôm nay).
    - session_name: morning, noon, afternoon (mặc định tự xác định theo giờ VN).
    """
    actual_date = target_date or date.today()
    actual_session = session_name.lower() if session_name else determine_current_session()
    session_label = SESSION_LABELS.get(actual_session, actual_session)

    unadministered_by_class = get_unadministered_medications_by_class(
        db=db,
        target_date=actual_date,
        session_name=actual_session,
    )

    if not unadministered_by_class:
        logger.info(
            "[MedicationReminder] Không có liều thuốc nào chưa uống cần nhắc nhở (ngày %s, buổi %s)",
            actual_date,
            actual_session,
        )
        return {
            "reminded_classes": [],
            "notifications_sent": 0,
            "session": actual_session,
            "target_date": actual_date.isoformat(),
        }

    reminded_classes: list[dict] = []
    total_sent = 0

    for class_id, pending_items in unadministered_by_class.items():
        class_obj = db.scalar(select(Class_).where(Class_.class_id == class_id))
        class_name = class_obj.name if class_obj else "Lớp học"

        # Tìm toàn bộ giáo viên được phân công phụ trách lớp này
        teachers = db.scalars(
            select(Teacher).where(Teacher.class_id == class_id)
        ).all()

        if not teachers:
            logger.info("[MedicationReminder] Lớp %s chưa có giáo viên phụ trách.", class_name)
            continue

        # Gom danh sách tên học sinh (loại bỏ trùng lặp nếu 1 bé có 2 loại thuốc)
        unique_children: list[str] = list(
            dict.fromkeys(item["child_name"] for item in pending_items)
        )
        names_str = ", ".join(unique_children[:3])
        if len(unique_children) > 3:
            names_str += f" và {len(unique_children) - 3} bé khác"

        title = f"KinderLog: Nhắc nhở dặn thuốc buổi {session_label}"
        body = (
            f"Lớp {class_name} có {len(unique_children)} bé chưa uống thuốc buổi {session_label} "
            f"({names_str}). Cô vui lòng kiểm tra và cho bé uống thuốc nhé!"
        )

        data = {
            "type": "medication_reminder",
            "class_id": str(class_id),
            "session": actual_session,
            "date": actual_date.isoformat(),
            "unadministered_count": str(len(pending_items)),
        }

        class_sent = 0
        for teacher in teachers:
            # Lấy toàn bộ device token của giáo viên
            tokens = db.scalars(
                select(DeviceToken)
                .join(User, DeviceToken.user_id == User.user_id)
                .where(User.teacher_id == teacher.teacher_id)
            ).all()

            for dt in tokens:
                try:
                    send_push_notification(
                        token=dt.token,
                        title=title,
                        body=body,
                        data=data,
                        channel_id="kinderlog_medication",
                    )
                    class_sent += 1
                    total_sent += 1
                except Exception as ex:
                    logger.warning(
                        "[MedicationReminder] Lỗi gửi push tới giáo viên %s (token=%s): %s",
                        teacher.full_name,
                        dt.token,
                        ex,
                    )
                    if is_invalid_token(ex):
                        db.delete(dt)
                        db.commit()

        reminded_classes.append({
            "class_id": str(class_id),
            "class_name": class_name,
            "pending_children_count": len(unique_children),
            "pending_doses_count": len(pending_items),
            "sent_notifications": class_sent,
        })

    logger.info(
        "[MedicationReminder] Hoàn tất quét dặn thuốc buổi %s: %d lớp có liều chưa uống, đã gửi %d thông báo.",
        actual_session,
        len(reminded_classes),
        total_sent,
    )

    return {
        "reminded_classes": reminded_classes,
        "notifications_sent": total_sent,
        "session": actual_session,
        "target_date": actual_date.isoformat(),
    }
