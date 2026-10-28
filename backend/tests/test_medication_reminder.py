"""
backend/tests/test_medication_reminder.py
=========================================
Unit tests cho Task #299: [Create][Service Medication Reminder]
- Kiểm thử logic xác định session (morning, noon, afternoon).
- Kiểm thử lọc đơn thuốc đã uống (is_given=True).
- Kiểm thử tự động bỏ qua trẻ vắng mặt (ABSENT, EXCUSED_ABSENT).
- Kiểm thử gom nhóm thông báo (grouped notification) gửi giáo viên.
- Kiểm thử Celery background task wrapper.
"""

from __future__ import annotations

import uuid
from datetime import date, datetime, timedelta, timezone
from unittest.mock import MagicMock, patch


from app.models.child import Child
from app.models.device_token import DeviceToken
from app.models.medication import (
    MedicationRequest,
    MedicationRequestStatus,
    MedicationSession,
)
from app.models.user import Class_, Teacher
from app.services.medication_reminder_service import (
    determine_current_session,
    get_unadministered_medications_by_class,
    send_grouped_medication_reminder,
)
from app.tasks.medication_notifications import remind_pending_medications


def test_determine_current_session():
    """Kiểm tra phân định session sáng / trưa / chiều theo giờ VN (UTC+7)."""
    vn_tz = timezone(timedelta(hours=7))

    # 09:00 sáng -> morning
    dt_morning = datetime(2026, 10, 28, 9, 0, tzinfo=vn_tz)
    assert determine_current_session(dt_morning) == MedicationSession.MORNING.value

    # 11:30 trưa -> noon
    dt_noon = datetime(2026, 10, 28, 11, 30, tzinfo=vn_tz)
    assert determine_current_session(dt_noon) == MedicationSession.NOON.value

    # 14:30 chiều -> afternoon
    dt_afternoon = datetime(2026, 10, 28, 14, 30, tzinfo=vn_tz)
    assert determine_current_session(dt_afternoon) == MedicationSession.AFTERNOON.value


def test_get_unadministered_medications_filters_given_and_absent():
    """
    Kiểm tra:
    - Bé 1: Chưa uống -> CẦN nhắc.
    - Bé 2: Đã có log is_given=True -> BỎ QUA.
    - Bé 3: Vắng mặt hôm nay (excused_absent) -> BỎ QUA.
    """
    mock_db = MagicMock()
    target_date = date(2026, 10, 28)
    class_id = uuid.uuid4()

    child1_id = uuid.uuid4()
    child2_id = uuid.uuid4()
    child3_id = uuid.uuid4()

    child1 = Child(child_id=child1_id, full_name="Nguyễn Văn Bé 1", class_id=class_id)
    child2 = Child(child_id=child2_id, full_name="Trần Thị Bé 2", class_id=class_id)
    child3 = Child(child_id=child3_id, full_name="Lê Văn Bé 3", class_id=class_id)

    req1 = MedicationRequest(
        request_id=uuid.uuid4(),
        child_id=child1_id,
        class_id=class_id,
        medication_name="Siro ho Prospan",
        dosage="5ml",
        sessions=["morning", "noon"],
        start_date=date(2026, 10, 27),
        end_date=date(2026, 10, 30),
        status=MedicationRequestStatus.ACTIVE,
        child=child1,
    )
    req2 = MedicationRequest(
        request_id=uuid.uuid4(),
        child_id=child2_id,
        class_id=class_id,
        medication_name="Kháng sinh Augmentin",
        dosage="1 gói",
        sessions=["noon"],
        start_date=date(2026, 10, 27),
        end_date=date(2026, 10, 30),
        status=MedicationRequestStatus.ACTIVE,
        child=child2,
    )
    req3 = MedicationRequest(
        request_id=uuid.uuid4(),
        child_id=child3_id,
        class_id=class_id,
        medication_name="Hạ sốt Hapacol",
        dosage="80mg",
        sessions=["noon"],
        start_date=date(2026, 10, 28),
        end_date=date(2026, 10, 29),
        status=MedicationRequestStatus.ACTIVE,
        child=child3,
    )

    # Giả lập query scalars:
    # Lần 1: toàn bộ request active -> [req1, req2, req3]
    # Lần 2: danh sách trẻ vắng mặt -> [child3_id]
    # Lần 3: request_id đã uống thành công -> [req2.request_id]
    mock_db.scalars.side_effect = [
        MagicMock(all=MagicMock(return_value=[req1, req2, req3])),
        MagicMock(all=MagicMock(return_value=[child3_id])),
        MagicMock(all=MagicMock(return_value=[req2.request_id])),
    ]

    result = get_unadministered_medications_by_class(
        db=mock_db,
        target_date=target_date,
        session_name="noon",
    )

    assert class_id in result
    unadministered = result[class_id]
    # Chỉ có Bé 1 (req1) là chưa uống và có đi học
    assert len(unadministered) == 1
    assert unadministered[0]["child_id"] == child1_id
    assert unadministered[0]["child_name"] == "Nguyễn Văn Bé 1"
    assert unadministered[0]["medication_name"] == "Siro ho Prospan"


@patch("app.services.medication_reminder_service.send_push_notification")
def test_send_grouped_medication_reminder_success(mock_send_push):
    """
    Kiểm tra gửi grouped notification tới giáo viên phụ trách lớp.
    """
    mock_db = MagicMock()
    target_date = date(2026, 10, 28)
    class_id = uuid.uuid4()
    teacher_id = uuid.uuid4()

    child1_id = uuid.uuid4()
    child2_id = uuid.uuid4()

    child1 = Child(child_id=child1_id, full_name="Bé An", class_id=class_id)
    child2 = Child(child_id=child2_id, full_name="Bé Bình", class_id=class_id)

    req1 = MedicationRequest(
        request_id=uuid.uuid4(),
        child_id=child1_id,
        class_id=class_id,
        medication_name="Siro ho",
        dosage="5ml",
        sessions=["noon"],
        start_date=target_date,
        end_date=target_date,
        status=MedicationRequestStatus.ACTIVE,
        child=child1,
    )
    req2 = MedicationRequest(
        request_id=uuid.uuid4(),
        child_id=child2_id,
        class_id=class_id,
        medication_name="Men vi sinh",
        dosage="1 gói",
        sessions=["noon"],
        start_date=target_date,
        end_date=target_date,
        status=MedicationRequestStatus.ACTIVE,
        child=child2,
    )

    cls_obj = Class_(class_id=class_id, name="Lớp Mầm 1")
    teacher = Teacher(teacher_id=teacher_id, class_id=class_id, full_name="Cô Hoa")
    token = DeviceToken(token="fcm_token_teacher_123", user_id=uuid.uuid4())

    mock_db.scalars.side_effect = [
        # get_unadministered_medications_by_class:
        MagicMock(all=MagicMock(return_value=[req1, req2])),  # requests
        MagicMock(all=MagicMock(return_value=[])),             # absent_child_ids
        MagicMock(all=MagicMock(return_value=[])),             # given_request_ids
        # send_grouped_medication_reminder:
        MagicMock(all=MagicMock(return_value=[teacher])),      # teachers of class
        MagicMock(all=MagicMock(return_value=[token])),        # device tokens of teacher
    ]
    mock_db.scalar.return_value = cls_obj

    result = send_grouped_medication_reminder(
        db=mock_db,
        target_date=target_date,
        session_name="noon",
    )

    assert result["notifications_sent"] == 1
    assert len(result["reminded_classes"]) == 1
    assert result["reminded_classes"][0]["class_name"] == "Lớp Mầm 1"
    assert result["reminded_classes"][0]["pending_children_count"] == 2

    # Xác thực nội dung gửi qua FCM
    mock_send_push.assert_called_once()
    call_kwargs = mock_send_push.call_args.kwargs
    assert call_kwargs["token"] == "fcm_token_teacher_123"
    assert "Nhắc nhở dặn thuốc buổi Trưa" in call_kwargs["title"]
    assert "Lớp Lớp Mầm 1 có 2 bé chưa uống thuốc" in call_kwargs["body"]
    assert "Bé An, Bé Bình" in call_kwargs["body"]
    assert call_kwargs["data"]["type"] == "medication_reminder"
    assert call_kwargs["data"]["session"] == "noon"
    assert call_kwargs["channel_id"] == "kinderlog_medication"


@patch("app.services.medication_reminder_service.send_push_notification")
def test_send_grouped_medication_reminder_no_pending(mock_send_push):
    """Khi không có đơn dặn thuốc nào chưa uống -> không gửi thông báo."""
    mock_db = MagicMock()
    mock_db.scalars.return_value.all.return_value = []

    result = send_grouped_medication_reminder(
        db=mock_db,
        target_date=date(2026, 10, 28),
        session_name="morning",
    )

    assert result["notifications_sent"] == 0
    assert result["reminded_classes"] == []
    mock_send_push.assert_not_called()


@patch("app.services.medication_reminder_service.send_grouped_medication_reminder")
def test_remind_pending_medications_celery_task(mock_send_grouped):
    """Kiểm tra Celery task remind_pending_medications gọi đúng service."""
    mock_send_grouped.return_value = {"status": "success", "notifications_sent": 2}

    res = remind_pending_medications.apply(args=["afternoon", "2026-10-28"]).get()

    assert res == {"status": "success", "notifications_sent": 2}
    mock_send_grouped.assert_called_once()
