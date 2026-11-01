"""
backend/tests/test_attendance_auto_sync.py
==========================================
Unit & Integration tests cho Task 1: [Service Attendance Auto-Sync]:
- Đồng bộ EXCUSED_ABSENT cho ngày trống; ETA đi trễ không phải check-in thực.
- Hoàn tác điểm danh (Rollback) khi phụ huynh huỷ đơn trước 07:30 AM.
- Chặn huỷ đơn tự động sau 07:30 AM.
- API GET /api/attendance trả về đầy đủ sĩ số excused_absent_count và ETA.
"""

import uuid
from datetime import date, datetime, time
from unittest.mock import MagicMock, patch
from zoneinfo import ZoneInfo

import pytest
from fastapi import FastAPI, HTTPException, status
from fastapi.testclient import TestClient

from app.api.endpoints.attendance import router as attendance_router
from app.api.endpoints.leave_request import router as leave_request_router
from app.core.database import get_db
from app.core.security import get_current_user
from app.models.attendance import AttendanceRecord, AttendanceStatus
from app.models.child import Child, ChildStatus
from app.models.leave_request import LeaveRequest, LeaveStatus, LeaveType
from app.models.user import Teacher, User, UserRole
from app.services.attendance_sync_service import (
    cancel_leave_request,
    rollback_leave_request_attendance,
    sync_leave_request_to_attendance,
)

VN_TZ = ZoneInfo("Asia/Ho_Chi_Minh")

app = FastAPI()
app.include_router(leave_request_router, prefix="/api")
app.include_router(attendance_router, prefix="/api")


@pytest.fixture()
def mock_db():
    return MagicMock()


@pytest.fixture()
def sample_ids():
    return {
        "class_id": uuid.uuid4(),
        "child_id": uuid.uuid4(),
        "parent_id": uuid.uuid4(),
        "teacher_id": uuid.uuid4(),
        "user_teacher_id": uuid.uuid4(),
        "user_parent_id": uuid.uuid4(),
    }


def test_sync_single_day_approved_creates_new(sample_ids):
    """Duyệt đơn nghỉ 1 ngày khi chưa có bản ghi -> Tự động tạo bản ghi điểm danh EXCUSED_ABSENT."""
    db = MagicMock()
    req = LeaveRequest(
        leave_id=uuid.uuid4(),
        child_id=sample_ids["child_id"],
        class_id=sample_ids["class_id"],
        parent_id=sample_ids["parent_id"],
        type=LeaveType.SINGLE_DAY,
        from_date=date(2026, 11, 2),
        to_date=date(2026, 11, 2),
        reason="Bé bị sốt",
        status=LeaveStatus.APPROVED,
    )
    db.scalar.return_value = None

    synced = sync_leave_request_to_attendance(db, req, teacher_id=sample_ids["teacher_id"])
    assert len(synced) == 1
    assert db.add.called
    assert synced[0].status == AttendanceStatus.EXCUSED_ABSENT
    assert synced[0].source_leave_id == req.leave_id


def test_sync_single_day_approved_updates_existing(sample_ids):
    """Duyệt đơn nghỉ 1 ngày khi đã có bản ghi -> Cập nhật trạng thái thành EXCUSED_ABSENT."""
    db = MagicMock()
    req = LeaveRequest(
        leave_id=uuid.uuid4(),
        child_id=sample_ids["child_id"],
        class_id=sample_ids["class_id"],
        parent_id=sample_ids["parent_id"],
        type=LeaveType.SINGLE_DAY,
        from_date=date(2026, 11, 2),
        to_date=date(2026, 11, 2),
        reason="Bé bị sốt",
        status=LeaveStatus.APPROVED,
    )
    existing_record = AttendanceRecord(
        record_id=uuid.uuid4(),
        child_id=req.child_id,
        class_id=req.class_id,
        date=req.from_date,
        status=AttendanceStatus.PRESENT,
        source_leave_id=None,
    )
    db.scalar.return_value = existing_record

    synced = sync_leave_request_to_attendance(db, req, teacher_id=sample_ids["teacher_id"])
    assert len(synced) == 1
    assert synced[0].status == AttendanceStatus.EXCUSED_ABSENT
    assert synced[0].source_leave_id == req.leave_id


def test_sync_late_approved_with_eta(sample_ids):
    """Duyệt báo trễ giữ ETA trong đơn, không tự đánh dấu bé đã đến lớp."""
    db = MagicMock()
    req = LeaveRequest(
        leave_id=uuid.uuid4(),
        child_id=sample_ids["child_id"],
        class_id=sample_ids["class_id"],
        parent_id=sample_ids["parent_id"],
        type=LeaveType.LATE,
        from_date=date(2026, 11, 2),
        to_date=date(2026, 11, 2),
        expected_arrival_time=time(8, 30),
        reason="Kẹt xe",
        status=LeaveStatus.APPROVED,
    )
    db.scalar.return_value = None

    synced = sync_leave_request_to_attendance(db, req, teacher_id=sample_ids["teacher_id"])
    assert len(synced) == 1
    assert db.add.called
    assert synced[0].status == AttendanceStatus.LATE
    assert synced[0].expected_arrival_time == time(8, 30)
    assert synced[0].source_leave_id == req.leave_id


def test_sync_pending_does_not_execute(sample_ids):
    """Đơn chưa duyệt (PENDING) -> Không đồng bộ vào bảng điểm danh."""
    db = MagicMock()
    req = LeaveRequest(
        leave_id=uuid.uuid4(),
        child_id=sample_ids["child_id"],
        class_id=sample_ids["class_id"],
        parent_id=sample_ids["parent_id"],
        type=LeaveType.SINGLE_DAY,
        from_date=date(2026, 11, 2),
        to_date=date(2026, 11, 2),
        status=LeaveStatus.PENDING,
    )

    synced = sync_leave_request_to_attendance(db, req)
    assert synced == []
    db.add.assert_not_called()
    db.scalar.assert_not_called()


def test_rollback_leave_request_attendance(sample_ids):
    """Rollback điểm danh gọi delete bản ghi điểm danh trong khoảng ngày."""
    db = MagicMock()
    result_mock = MagicMock()
    result_mock.rowcount = 2
    db.execute.return_value = result_mock

    req = LeaveRequest(
        leave_id=uuid.uuid4(),
        child_id=sample_ids["child_id"],
        class_id=sample_ids["class_id"],
        parent_id=sample_ids["parent_id"],
        from_date=date(2026, 11, 2),
        to_date=date(2026, 11, 3),
    )

    deleted = rollback_leave_request_attendance(db, req)
    assert deleted == 2
    assert db.execute.called


def test_cancel_leave_request_before_cutoff(sample_ids):
    """Phụ huynh huỷ đơn trước 07:30 AM cùng ngày -> Thành công và hoàn tác điểm danh."""
    db = MagicMock()
    today = date(2026, 11, 2)
    req = LeaveRequest(
        leave_id=uuid.uuid4(),
        child_id=sample_ids["child_id"],
        class_id=sample_ids["class_id"],
        parent_id=sample_ids["parent_id"],
        from_date=today,
        to_date=today,
        status=LeaveStatus.APPROVED,
    )
    db.scalar.return_value = req
    result_mock = MagicMock()
    result_mock.rowcount = 1
    db.execute.return_value = result_mock

    mock_now = datetime(2026, 11, 2, 7, 0, 0, tzinfo=VN_TZ)
    with patch("app.services.attendance_sync_service.datetime") as mock_dt:
        mock_dt.now.return_value = mock_now
        cancelled_req, rollbacked = cancel_leave_request(db, req.leave_id, sample_ids["parent_id"])

        assert cancelled_req.status == LeaveStatus.CANCELLED
        assert rollbacked is True
        assert db.commit.called


def test_cancel_leave_request_after_cutoff_blocked(sample_ids):
    """Phụ huynh huỷ đơn sau 07:30 AM cùng ngày -> Bị chặn với HTTP 400."""
    db = MagicMock()
    today = date(2026, 11, 2)
    req = LeaveRequest(
        leave_id=uuid.uuid4(),
        child_id=sample_ids["child_id"],
        class_id=sample_ids["class_id"],
        parent_id=sample_ids["parent_id"],
        from_date=today,
        to_date=today,
        status=LeaveStatus.APPROVED,
    )
    db.scalar.return_value = req

    mock_now = datetime(2026, 11, 2, 8, 15, 0, tzinfo=VN_TZ)
    with patch("app.services.attendance_sync_service.datetime") as mock_dt:
        mock_dt.now.return_value = mock_now
        with pytest.raises(HTTPException) as exc_info:
            cancel_leave_request(db, req.leave_id, sample_ids["parent_id"])
        assert exc_info.value.status_code == status.HTTP_400_BAD_REQUEST
        assert "07:30 AM" in exc_info.value.detail


def test_cancel_leave_request_unauthorized(sample_ids):
    """Phụ huynh khác cố tình huỷ đơn -> Bị chặn 403 Forbidden."""
    db = MagicMock()
    req = LeaveRequest(
        leave_id=uuid.uuid4(),
        child_id=sample_ids["child_id"],
        parent_id=sample_ids["parent_id"],
        from_date=date(2026, 11, 2),
        to_date=date(2026, 11, 2),
        status=LeaveStatus.PENDING,
    )
    db.scalar.return_value = req

    other_parent_id = uuid.uuid4()
    with pytest.raises(HTTPException) as exc_info:
        cancel_leave_request(db, req.leave_id, other_parent_id)
    assert exc_info.value.status_code == status.HTTP_403_FORBIDDEN


def test_api_approve_endpoint(sample_ids):
    """Test API endpoint POST /api/leave-requests/{id}/approve."""
    teacher_user = User(
        user_id=sample_ids["user_teacher_id"],
        username="teacher1",
        role=UserRole.TEACHER,
        teacher_id=sample_ids["teacher_id"],
    )
    teacher = Teacher(
        teacher_id=sample_ids["teacher_id"],
        class_id=sample_ids["class_id"],
        full_name="Cô Hoa",
    )
    req = LeaveRequest(
        leave_id=uuid.uuid4(),
        child_id=sample_ids["child_id"],
        class_id=sample_ids["class_id"],
        parent_id=sample_ids["parent_id"],
        type=LeaveType.SINGLE_DAY,
        from_date=date.today(),
        to_date=date.today(),
        reason="Nghỉ ốm",
        status=LeaveStatus.PENDING,
        meal_warning_acknowledged=False,
        submitted_after_cutoff=False,
        created_at=datetime(2026, 11, 2, 6, 0, tzinfo=VN_TZ),
        updated_at=datetime(2026, 11, 2, 6, 0, tzinfo=VN_TZ),
        child=Child(child_id=sample_ids["child_id"], class_id=sample_ids["class_id"], status=ChildStatus.ENROLLED),
    )

    mock_db = MagicMock()
    # Mock queries: 1. find req, 2. find teacher in verify, 3. find saved_rec in sync
    def mock_scalar_fn(stmt):
        stmt_str = str(stmt).lower()
        if "from leave_request" in stmt_str:
            return req
        if "from teacher" in stmt_str:
            return teacher
        if "from attendance_record" in stmt_str:
            return AttendanceRecord(
                record_id=uuid.uuid4(),
                child_id=req.child_id,
                class_id=req.class_id,
                date=req.from_date,
                status=AttendanceStatus.EXCUSED_ABSENT,
                source_leave_id=req.leave_id,
            )
        return None

    mock_db.scalar.side_effect = mock_scalar_fn

    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: teacher_user

    client = TestClient(app)
    response = client.post(f"/api/leave-requests/{req.leave_id}/approve")
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert data["status"] == "approved"
    assert data["synced_attendance_count"] == 1

    app.dependency_overrides.clear()
