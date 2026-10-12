"""
tests/test_bug_reports.py
=========================
Comprehensive test suite cho Bug Report feature (B-05).

Pattern giống test_teacher.py / test_notifications.py:
    - Dùng full main app
    - ``app.dependency_overrides`` để mock ``get_db`` + ``get_current_user``
    - ``patch()`` cho external services (MinIO, FCM, email, Celery)

Test classes:
    TestServiceLayer       - Unit tests cho service.py
    TestEndpointsAuth      - JWT auth + role permission
    TestEndpointCreate     - POST /api/bug-reports
    TestEndpointList       - GET /me + / (admin)
    TestEndpointDetail     - GET /{id} + /me/{id}
    TestEndpointUpdate     - PATCH /{id}
    TestEndpointAttachments - POST /{id}/attachments
    TestRateLimit          - 10 reports / user / hour
    TestOpenAPIDocs        - OpenAPI schema integrity
"""

from __future__ import annotations

import io
import uuid
from datetime import datetime, timezone
from unittest.mock import MagicMock, patch

import pytest
from app.core.database import get_db
from app.core.security import get_current_user
from app.main import app
from app.models.bug_report import (
    BugCategory,
    BugReport,
    BugReportAttachment,
    BugReportHistory,
    BugSeverity,
    BugStatus,
)
from app.models.user import User, UserRole
from fastapi.testclient import TestClient

# ===========================================================================
# Constants
# ===========================================================================

REPORT_ID = uuid.UUID("11111111-1111-1111-1111-111111111111")
TEACHER_ID = uuid.UUID("22222222-2222-2222-2222-222222222222")
ADMIN_ID = uuid.UUID("33333333-3333-3333-3333-333333333333")
OTHER_TEACHER_ID = uuid.UUID("44444444-4444-4444-4444-444444444444")
TEACHER_RECORD_ID = uuid.UUID("55555555-5555-5555-5555-555555555555")


# ===========================================================================
# Helpers - tạo report/attachment/history dạng dict (cho serialization)
# ===========================================================================


def _make_report_obj(
    report_id=REPORT_ID,
    user_id=TEACHER_ID,
    status=BugStatus.OPEN,
    severity=BugSeverity.HIGH,
    category=BugCategory.CRASH,
    title="App crash on save",
    description="Mo ta chi tiet",
    attachments=None,
    history=None,
) -> MagicMock:
    """Tạo MagicMock(spec=BugReport) với enum values đúng + relationships=None.

    Hỗ trợ cả attribute access (endpoint code) lẫn serialization (Pydantic).
    String status/severity/category sẽ tự convert sang enum.
    """
    # Coerce strings to enums (để bug_report_to_out dùng .value được)
    if isinstance(status, str):
        status = BugStatus(status)
    if isinstance(severity, str):
        severity = BugSeverity(severity)
    if isinstance(category, str):
        category = BugCategory(category)

    obj = MagicMock(spec=BugReport)
    obj.bug_report_id = report_id
    obj.user_id = user_id
    obj.user = None
    obj.teacher = None
    obj.title = title
    obj.description = description
    obj.category = category
    obj.severity = severity
    obj.status = status
    obj.app_version = "1.2.3"
    obj.build_number = "42"
    obj.os_version = "Android 14"
    obj.device_model = "Pixel 7"
    obj.network_type = "wifi"
    obj.teacher_id = None
    obj.created_at = datetime(2026, 10, 12, tzinfo=timezone.utc)
    obj.updated_at = datetime(2026, 10, 12, tzinfo=timezone.utc)
    obj.resolved_at = None
    obj.closed_at = None
    obj.attachments = attachments or []
    obj.history = history or []
    return obj


def _make_attachment_obj(
    file_name="screenshot.png",
    file_url="http://minio/file.png",
    mime_type="image/png",
    file_size=1024,
) -> MagicMock:
    obj = MagicMock(spec=BugReportAttachment)
    obj.attachment_id = uuid.uuid4()
    obj.bug_report_id = REPORT_ID
    obj.file_url = file_url
    obj.file_name = file_name
    obj.file_size = file_size
    obj.mime_type = mime_type
    obj.description = None  # tránh MagicMock cascade
    obj.uploaded_at = datetime(2026, 10, 12, tzinfo=timezone.utc)
    return obj


def _make_history_obj(
    old_status=None,
    new_status=BugStatus.OPEN,
    note="Report created",
    changed_by=TEACHER_ID,
) -> MagicMock:
    """Tạo BugReportHistory mock. Strings sẽ convert sang enum."""
    if isinstance(old_status, str):
        old_status = BugStatus(old_status)
    if isinstance(new_status, str):
        new_status = BugStatus(new_status)

    obj = MagicMock(spec=BugReportHistory)
    obj.history_id = uuid.uuid4()
    obj.bug_report_id = REPORT_ID
    obj.changed_by = None
    obj.old_status = old_status
    obj.new_status = new_status
    obj.old_teacher_id = None
    obj.new_teacher_id = None
    obj.comment = note
    obj.created_at = datetime(2026, 10, 12, tzinfo=timezone.utc)
    return obj


def _fake_png_bytes() -> bytes:
    return bytes.fromhex(
        "89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4"
        "890000000d4944415478da6300010000050001c4d4c40000000049454e44ae426082"
    )


def _make_user(user_id, role, username=None):
    """MagicMock user với role enum thật (so sánh == hoạt động)."""
    user = MagicMock(spec=User)
    user.user_id = user_id
    user.role = role
    user.username = username or f"user_{user_id.hex[:8]}"
    return user


# ===========================================================================
# Fixtures
# ===========================================================================


@pytest.fixture()
def mock_db():
    """Mock SQLAlchemy Session với safe defaults."""
    db = MagicMock()
    db.add = MagicMock()
    db.commit = MagicMock()
    db.rollback = MagicMock()
    db.refresh = MagicMock()
    db.delete = MagicMock()
    db.flush = MagicMock()

    # Default: empty results
    query_chain = MagicMock()
    query_chain.filter.return_value.first.return_value = None
    query_chain.filter.return_value.all.return_value = []
    query_chain.filter.return_value.scalar.return_value = 0
    query_chain.filter.return_value.count.return_value = 0
    query_chain.options.return_value.filter.return_value.first.return_value = None
    query_chain.options.return_value.filter.return_value.all.return_value = []
    db.query.return_value = query_chain

    return db


@pytest.fixture()
def teacher_user():
    return _make_user(TEACHER_ID, UserRole.TEACHER)


@pytest.fixture()
def admin_user():
    return _make_user(ADMIN_ID, UserRole.ADMIN)


@pytest.fixture()
def teacher_client(mock_db, teacher_user):
    """TestClient authenticated as teacher."""
    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: teacher_user
    yield TestClient(app)
    app.dependency_overrides.clear()


@pytest.fixture()
def admin_client(mock_db, admin_user):
    """TestClient authenticated as admin."""
    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: admin_user
    yield TestClient(app)
    app.dependency_overrides.clear()


@pytest.fixture()
def anon_client(mock_db):
    """TestClient without auth (gây 401)."""
    app.dependency_overrides[get_db] = lambda: mock_db
    yield TestClient(app)
    app.dependency_overrides.clear()


# ===========================================================================
# TestServiceLayer
# ===========================================================================


class TestServiceLayer:
    """Unit tests cho service functions."""

    @patch("app.services.bug_report_service._upload_to_minio")
    def test_create_report_returns_report_and_count(self, mock_upload, mock_db, teacher_user):
        """create_report returns (report, count, reset_at)."""
        from app.schemas.bug_report import BugReportCreate
        from app.services.bug_report_service import create_report

        mock_upload.return_value = "http://minio/file.png"
        data = BugReportCreate(
            title="Test", description="Desc"
        ).model_dump()

        _report, used, reset_at = create_report(
            db=mock_db, user=teacher_user, data=data, attachments=[]
        )
        assert mock_db.add.called
        assert mock_db.commit.called
        assert used == 1  # count + 1
        assert reset_at is not None

    @patch("app.services.bug_report_service._upload_to_minio")
    def test_create_report_uploads_attachments(self, mock_upload, mock_db, teacher_user):
        """create_report upload từng attachment."""
        from app.schemas.bug_report import BugReportCreate
        from app.services.bug_report_service import create_report

        mock_upload.return_value = "http://minio/f.png"
        data = BugReportCreate(title="X", description="Y").model_dump()
        atts = [
            {"file_data": b"a", "file_name": "a.png", "mime_type": "image/png"},
            {"file_data": b"b", "file_name": "b.png", "mime_type": "image/png"},
        ]
        create_report(
            db=mock_db, user=teacher_user, data=data, attachments=atts
        )
        assert mock_upload.call_count == 2

    def test_create_report_too_many_attachments_raises(self, mock_db, teacher_user):
        """6 attachments → ValidationError 400."""
        from app.schemas.bug_report import BugReportCreate
        from app.services.bug_report_service import (
            BugReportValidationError,
            create_report,
        )

        data = BugReportCreate(title="X", description="Y").model_dump()
        atts = [
            {"file_data": b"x", "file_name": f"{i}.png", "mime_type": "image/png"}
            for i in range(6)
        ]
        with pytest.raises(BugReportValidationError) as exc_info:
            create_report(
                db=mock_db, user=teacher_user, data=data, attachments=atts
            )
        assert exc_info.value.status_code == 400
        assert "5" in exc_info.value.message

    def test_create_report_oversized_file_raises(self, mock_db, teacher_user):
        """File > 5MB → ValidationError 400."""
        from app.schemas.bug_report import BugReportCreate
        from app.services.bug_report_service import (
            BugReportValidationError,
            create_report,
        )

        data = BugReportCreate(title="X", description="Y").model_dump()
        big = b"x" * (6 * 1024 * 1024)  # 6 MB
        with pytest.raises(BugReportValidationError) as exc_info:
            create_report(
                db=mock_db,
                user=teacher_user,
                data=data,
                attachments=[
                    {
                        "file_data": big,
                        "file_name": "big.png",
                        "mime_type": "image/png",
                    }
                ],
            )
        # Message format: "File 'big.png' quá lớn (6.00 MB). Tối đa 5 MB."
        assert "5" in exc_info.value.message
        assert "MB" in exc_info.value.message

    def test_create_report_invalid_mime_raises(self, mock_db, teacher_user):
        """MIME không phải image/* hoặc text/plain → ValidationError."""
        from app.schemas.bug_report import BugReportCreate
        from app.services.bug_report_service import (
            BugReportValidationError,
            create_report,
        )

        data = BugReportCreate(title="X", description="Y").model_dump()
        with pytest.raises(BugReportValidationError) as exc_info:
            create_report(
                db=mock_db,
                user=teacher_user,
                data=data,
                attachments=[
                    {
                        "file_data": b"x",
                        "file_name": "f.exe",
                        "mime_type": "application/x-msdownload",  # not in allowed list
                    }
                ],
            )
        assert "image" in exc_info.value.message.lower() or "MIME" in exc_info.value.message or "khong" in exc_info.value.message.lower()

    def test_update_status_invalid_status_raises_validation(self, mock_db, admin_user):
        """update_status với status rác → ValidationError 400."""
        from app.services.bug_report_service import (
            BugReportValidationError,
            update_status,
        )

        # Set up: report tồn tại, owned by TEACHER_ID
        # update_status uses .filter().first() (NOT .options().filter().first())
        report = MagicMock(spec=BugReport)
        report.bug_report_id = REPORT_ID
        report.user_id = TEACHER_ID
        report.user = None
        report.teacher = None
        report.attachments = []
        report.history = []
        report.status = BugStatus.OPEN
        report.resolved_at = None
        report.closed_at = None
        report.teacher_id = None
        mock_db.query.return_value.filter.return_value.first.return_value = report

        with pytest.raises(BugReportValidationError) as exc_info:
            update_status(
                db=mock_db,
                report_id=REPORT_ID,
                changed_by=admin_user,
                new_status="garbage_status",
            )
        assert "status" in exc_info.value.message.lower() or "hợp lệ" in exc_info.value.message

    def test_get_report_permission_error_for_other_user(self, mock_db):
        """User khác xem report → PermissionError 403."""
        from app.services.bug_report_service import (
            BugReportPermissionError,
            get_report,
        )

        # Setup: report exists, owned by TEACHER_ID
        report = MagicMock(spec=BugReport)
        report.bug_report_id = REPORT_ID
        report.user_id = TEACHER_ID
        report.user = None
        report.teacher = None
        report.attachments = []
        report.history = []
        mock_db.query.return_value.options.return_value.filter.return_value.first.return_value = report

        other_teacher = _make_user(OTHER_TEACHER_ID, UserRole.TEACHER)
        with pytest.raises(BugReportPermissionError) as exc_info:
            get_report(mock_db, REPORT_ID, other_teacher)
        assert exc_info.value.status_code == 403

    def test_get_report_not_found_raises(self, mock_db, admin_user):
        """Report không tồn tại → NotFoundError 404."""
        from app.services.bug_report_service import (
            BugReportNotFoundError,
            get_report,
        )

        mock_db.query.return_value.options.return_value.filter.return_value.first.return_value = None
        with pytest.raises(BugReportNotFoundError) as exc_info:
            get_report(mock_db, REPORT_ID, admin_user)
        assert exc_info.value.status_code == 404


# ===========================================================================
# TestEndpointsAuth
# ===========================================================================


class TestEndpointsAuth:
    """JWT auth + role permission cho cả 7 endpoints."""

    @pytest.mark.parametrize(
        "method,path",
        [
            ("POST", "/api/bug-reports"),
            ("GET", "/api/bug-reports/me"),
            ("GET", f"/api/bug-reports/me/{REPORT_ID}"),
            ("GET", "/api/bug-reports"),
            ("GET", f"/api/bug-reports/{REPORT_ID}"),
            ("PATCH", f"/api/bug-reports/{REPORT_ID}"),
            ("POST", f"/api/bug-reports/{REPORT_ID}/attachments"),
        ],
    )
    def test_endpoint_requires_auth(self, anon_client, method, path):
        """Tất cả 7 endpoints đều yêu cầu JWT hợp lệ."""
        if method == "POST" and "attachments" in path:
            resp = anon_client.post(
                path,
                files=[("attachments", ("f.png", io.BytesIO(b"x"), "image/png"))],
            )
        elif method == "POST":
            resp = anon_client.post(
                path,
                data={
                    "title": "x",
                    "description": "y",
                    "category": "ui",
                    "severity": "low",
                },
            )
        elif method == "PATCH":
            resp = anon_client.patch(path, json={"status": "open"})
        else:
            resp = anon_client.get(path)
        assert resp.status_code in (401, 403), (
            f"{method} {path}: expected 401/403, got {resp.status_code} - {resp.text}"
        )

    def test_list_all_requires_admin_role(self, teacher_client):
        """GET /api/bug-reports (admin only) — teacher bị 403."""
        resp = teacher_client.get("/api/bug-reports")
        assert resp.status_code == 403
        assert "quyền" in resp.json()["detail"].lower()

    def test_update_requires_admin_role(self, teacher_client):
        """PATCH (admin only) — teacher bị 403."""
        resp = teacher_client.patch(
            f"/api/bug-reports/{REPORT_ID}", json={"status": "in_progress"}
        )
        assert resp.status_code == 403

    def test_teacher_can_create(self, teacher_client, mock_db):
        """Teacher ĐƯỢC phép POST /api/bug-reports."""
        from app.api.endpoints import bug_reports as br_module

        with patch.object(
            br_module, "create_report", return_value=(_make_report_obj(), 0, datetime.now(tz=timezone.utc))
        ), patch.object(
            br_module, "get_report", return_value=_make_report_obj()
        ), patch.object(
            br_module, "_safe_dispatch_celery"
        ):
            resp = teacher_client.post(
                "/api/bug-reports",
                data={
                    "title": "Test",
                    "description": "Desc",
                    "category": "ui",
                    "severity": "low",
                },
            )
            assert resp.status_code == 201


# ===========================================================================
# TestEndpointCreate
# ===========================================================================


class TestEndpointCreate:
    """POST /api/bug-reports"""

    def test_create_with_minimal_fields(self, teacher_client, mock_db):
        """Tạo report tối thiểu (title + description)."""
        from app.api.endpoints import bug_reports as br_module

        with patch.object(
            br_module, "create_report", return_value=(_make_report_obj(), 0, datetime.now(tz=timezone.utc))
        ), patch.object(
            br_module, "get_report", return_value=_make_report_obj()
        ), patch.object(
            br_module, "_safe_dispatch_celery"
        ) as mock_dispatch:
            resp = teacher_client.post(
                "/api/bug-reports",
                data={
                    "title": "Minimal",
                    "description": "Desc",
                    "category": "ui",
                    "severity": "low",
                },
            )
            assert resp.status_code == 201
            data = resp.json()
            assert data["title"] == "App crash on save"
            assert data["status"] == "open"
            assert mock_dispatch.called

    def test_create_with_attachments(self, teacher_client, mock_db):
        """Tạo report kèm 1 ảnh PNG."""
        from app.api.endpoints import bug_reports as br_module

        report_with_att = _make_report_obj()
        report_with_att.attachments = [_make_attachment_obj()]

        with patch.object(
            br_module, "create_report", return_value=(report_with_att, 1, datetime.now(tz=timezone.utc))
        ), patch.object(
            br_module, "get_report", return_value=report_with_att
        ), patch.object(
            br_module, "_safe_dispatch_celery"
        ):
            resp = teacher_client.post(
                "/api/bug-reports",
                data={
                    "title": "With img",
                    "description": "Desc",
                    "category": "ui",
                    "severity": "low",
                },
                files=[
                    ("attachments", ("s.png", io.BytesIO(_fake_png_bytes()), "image/png"))
                ],
            )
            assert resp.status_code == 201
            assert len(resp.json()["attachments"]) == 1
            assert resp.json()["attachments"][0]["file_name"] == "screenshot.png"

    def test_create_empty_title_returns_422(self, teacher_client):
        """Empty title bị 422 (Pydantic validation)."""
        resp = teacher_client.post(
            "/api/bug-reports",
            data={
                "title": "",
                "description": "Desc",
                "category": "ui",
                "severity": "low",
            },
        )
        assert resp.status_code == 422

    def test_create_too_long_description_returns_422(self, teacher_client):
        """Description > 4000 chars bị 422."""
        resp = teacher_client.post(
            "/api/bug-reports",
            data={
                "title": "OK",
                "description": "x" * 4001,
                "category": "ui",
                "severity": "low",
            },
        )
        assert resp.status_code == 422

    def test_create_invalid_category_returns_422(self, teacher_client):
        """Category không hợp lệ bị 422."""
        resp = teacher_client.post(
            "/api/bug-reports",
            data={
                "title": "OK",
                "description": "Desc",
                "category": "invalid_category",
                "severity": "low",
            },
        )
        assert resp.status_code == 422

    def test_create_dispatches_celery_task(self, teacher_client, mock_db):
        """Verify notify_admin dispatched với đúng report_id."""
        from app.api.endpoints import bug_reports as br_module

        with patch.object(
            br_module, "create_report", return_value=(_make_report_obj(), 0, datetime.now(tz=timezone.utc))
        ), patch.object(
            br_module, "get_report", return_value=_make_report_obj()
        ), patch.object(
            br_module, "_safe_dispatch_celery"
        ) as mock_dispatch:
            teacher_client.post(
                "/api/bug-reports",
                data={
                    "title": "T",
                    "description": "D",
                    "category": "ui",
                    "severity": "low",
                },
            )
            assert mock_dispatch.called
            # First arg là .delay method, second arg là report_id
            assert str(REPORT_ID) in str(mock_dispatch.call_args.args[1])


# ===========================================================================
# TestEndpointList
# ===========================================================================


class TestEndpointList:
    """GET /me + GET / (admin)."""

    def test_list_my_reports_teacher(self, teacher_client):
        """GET /me trả về danh sách report của user."""
        from app.api.endpoints import bug_reports as br_module

        with patch.object(
            br_module, "get_user_reports", return_value=([_make_report_obj()], 1)
        ):
            resp = teacher_client.get("/api/bug-reports/me")
            assert resp.status_code == 200
            data = resp.json()
            assert data["total"] == 1
            assert len(data["items"]) == 1
            assert data["page"] == 1
            assert data["page_size"] == 20
            assert data["total_pages"] == 1

    def test_list_my_reports_with_pagination(self, teacher_client):
        """Pagination params pass tới service."""
        from app.api.endpoints import bug_reports as br_module

        with patch.object(
            br_module, "get_user_reports", return_value=([], 0)
        ) as mock_svc:
            resp = teacher_client.get(
                "/api/bug-reports/me?page=2&page_size=5"
            )
            assert resp.status_code == 200
            assert mock_svc.call_args.kwargs["page"] == 2
            assert mock_svc.call_args.kwargs["page_size"] == 5

    def test_list_all_reports_admin(self, admin_client):
        """GET /api/bug-reports (admin)."""
        from app.api.endpoints import bug_reports as br_module

        items = [
            _make_report_obj(),
            _make_report_obj(report_id=uuid.uuid4(), title="Bug 2"),
        ]
        with patch.object(br_module, "list_reports", return_value=(items, 2)):
            resp = admin_client.get("/api/bug-reports")
            assert resp.status_code == 200
            data = resp.json()
            assert data["total"] == 2

    def test_list_all_reports_with_filters(self, admin_client):
        """Filter params parsed thành dict."""
        from app.api.endpoints import bug_reports as br_module

        with patch.object(
            br_module, "list_reports", return_value=([], 0)
        ) as mock_svc:
            resp = admin_client.get(
                "/api/bug-reports?status=open&severity=high&category=crash"
            )
            assert resp.status_code == 200
            filters = mock_svc.call_args.kwargs["filters"]
            assert filters["status"] == "open"
            assert filters["severity"] == "high"
            assert filters["category"] == "crash"

    def test_list_all_reports_invalid_date(self, admin_client):
        """Invalid date_from → 400."""
        resp = admin_client.get("/api/bug-reports?date_from=not-a-date")
        assert resp.status_code == 400
        assert "date_from" in resp.json()["detail"]


# ===========================================================================
# TestEndpointDetail
# ===========================================================================


class TestEndpointDetail:
    """GET /me/{id} + GET /{id}."""

    def test_get_my_report(self, teacher_client):
        """GET /me/{id} - teacher thấy report của mình."""
        from app.api.endpoints import bug_reports as br_module

        report = _make_report_obj(user_id=TEACHER_ID)
        report.attachments = [_make_attachment_obj()]
        report.history = [_make_history_obj()]

        with patch.object(br_module, "get_report", return_value=report):
            resp = teacher_client.get(f"/api/bug-reports/me/{REPORT_ID}")
            assert resp.status_code == 200
            data = resp.json()
            assert data["bug_report_id"] == str(REPORT_ID)
            assert len(data["attachments"]) == 1
            assert len(data["history"]) == 1

    def test_get_other_user_report_forbidden(self, teacher_client):
        """GET /me/{id} của user khác → 403."""
        from app.api.endpoints import bug_reports as br_module
        from app.services.bug_report_service import BugReportPermissionError

        with patch.object(
            br_module, "get_report",
            side_effect=BugReportPermissionError("Khong co quyen"),
        ):
            resp = teacher_client.get(f"/api/bug-reports/me/{REPORT_ID}")
            assert resp.status_code == 403

    def test_get_admin_any_report(self, admin_client):
        """GET /{id} với admin."""
        from app.api.endpoints import bug_reports as br_module

        report = _make_report_obj(user_id=TEACHER_ID)
        with patch.object(br_module, "get_report", return_value=report):
            resp = admin_client.get(f"/api/bug-reports/{REPORT_ID}")
            assert resp.status_code == 200
            # user_id is nested in user dict (since user=None -> {})
            # Just verify the response structure is correct
            assert resp.json()["bug_report_id"] == str(REPORT_ID)

    def test_get_not_found(self, admin_client):
        """GET /{id} với UUID không tồn tại → 404."""
        from app.api.endpoints import bug_reports as br_module
        from app.services.bug_report_service import BugReportNotFoundError

        with patch.object(
            br_module, "get_report",
            side_effect=BugReportNotFoundError(),
        ):
            resp = admin_client.get(f"/api/bug-reports/{REPORT_ID}")
            assert resp.status_code == 404


# ===========================================================================
# TestEndpointUpdate
# ===========================================================================


class TestEndpointUpdate:
    """PATCH /api/bug-reports/{id} (admin only)."""

    def test_update_status_success(self, admin_client):
        """Admin cập nhật status thành công."""
        from app.api.endpoints import bug_reports as br_module

        report = _make_report_obj(status="in_progress")
        report.history = [
            _make_history_obj(new_status="open"),
            _make_history_obj(new_status="in_progress", note="Dang xu ly"),
        ]
        with patch.object(br_module, "update_status", return_value=report), patch.object(
            br_module, "get_report", return_value=report
        ), patch.object(
            br_module, "_safe_dispatch_celery"
        ) as mock_dispatch:
            resp = admin_client.patch(
                f"/api/bug-reports/{REPORT_ID}",
                json={"status": "in_progress", "comment": "Dang xu ly"},
            )
            assert resp.status_code == 200
            assert resp.json()["status"] == "in_progress"
            assert mock_dispatch.called

    def test_update_resolved_sets_resolved_at(self, admin_client):
        """PATCH status=resolved auto-set resolved_at."""
        from app.api.endpoints import bug_reports as br_module

        report = _make_report_obj(status="resolved")
        report.resolved_at = datetime(2026, 10, 13, tzinfo=timezone.utc)
        with patch.object(br_module, "update_status", return_value=report), patch.object(
            br_module, "get_report", return_value=report
        ), patch.object(br_module, "_safe_dispatch_celery"):
            resp = admin_client.patch(
                f"/api/bug-reports/{REPORT_ID}",
                json={"status": "resolved", "comment": "Fixed"},
            )
            assert resp.status_code == 200
            assert resp.json()["status"] == "resolved"
            assert resp.json()["resolved_at"] is not None

    def test_update_invalid_status_returns_400(self, admin_client):
        """Service raises validation → 400."""
        from app.api.endpoints import bug_reports as br_module
        from app.services.bug_report_service import BugReportValidationError

        with patch.object(
            br_module, "update_status",
            side_effect=BugReportValidationError("Invalid status"),
        ):
            # Status 'open' hợp lệ với Pydantic; service sẽ raise ValidationError
            resp = admin_client.patch(
                f"/api/bug-reports/{REPORT_ID}",
                json={"status": "open"},
            )
            assert resp.status_code == 400

    def test_update_dispatches_user_notification(self, admin_client):
        """Verify notify_user dispatched với đúng args."""
        from app.api.endpoints import bug_reports as br_module

        report = _make_report_obj(status="resolved")
        with patch.object(br_module, "update_status", return_value=report), patch.object(
            br_module, "get_report", return_value=report
        ), patch.object(br_module, "_safe_dispatch_celery") as mock_dispatch:
            admin_client.patch(
                f"/api/bug-reports/{REPORT_ID}",
                json={"status": "resolved", "comment": "Fixed in abc"},
            )
            assert mock_dispatch.called
            args = mock_dispatch.call_args.args
            # args: dispatch_fn, report_id, old_status, new_status, comment, admin_id
            assert str(REPORT_ID) == args[1]
            assert "resolved" == args[3]
            assert "Fixed in abc" == args[4]

    def test_update_no_status_no_notification(self, admin_client):
        """PATCH chỉ comment, không status → không dispatch."""
        from app.api.endpoints import bug_reports as br_module

        report = _make_report_obj()
        with patch.object(br_module, "update_status", return_value=report), patch.object(
            br_module, "get_report", return_value=report
        ), patch.object(br_module, "_safe_dispatch_celery") as mock_dispatch:
            resp = admin_client.patch(
                f"/api/bug-reports/{REPORT_ID}",
                json={"comment": "chi ghi chu"},
            )
            assert resp.status_code == 200
            assert not mock_dispatch.called


# ===========================================================================
# TestEndpointAttachments
# ===========================================================================


class TestEndpointAttachments:
    """POST /api/bug-reports/{id}/attachments"""

    def test_add_attachments_success(self, teacher_client):
        """Author thêm 1 attachment vào report của mình."""
        from app.api.endpoints import bug_reports as br_module

        report = _make_report_obj(user_id=TEACHER_ID)
        new_att = _make_attachment_obj(file_name="extra.png")
        report.attachments = [new_att]

        with patch.object(
            br_module, "add_attachments", return_value=(report, [new_att])
        ):
            resp = teacher_client.post(
                f"/api/bug-reports/{REPORT_ID}/attachments",
                files=[
                    ("attachments", ("extra.png", io.BytesIO(_fake_png_bytes()), "image/png"))
                ],
            )
            assert resp.status_code == 201
            data = resp.json()
            assert data["total_attachments"] == 1
            assert data["attachments"][0]["file_name"] == "extra.png"

    def test_add_attachments_empty_files(self, teacher_client):
        """Upload 0-byte file → endpoint raise 400 (no valid file)."""
        from app.api.endpoints import bug_reports as br_module

        with patch.object(br_module, "add_attachments") as mock_add:
            resp = teacher_client.post(
                f"/api/bug-reports/{REPORT_ID}/attachments",
                files=[
                    ("attachments", ("empty.png", io.BytesIO(b""), "image/png"))
                ],
            )
            assert resp.status_code == 400
            # Service should NOT be called since no valid file
            assert not mock_add.called

    def test_add_attachments_not_owner(self, teacher_client):
        """Teacher khác upload vào report không phải của mình → 403."""
        from app.api.endpoints import bug_reports as br_module
        from app.services.bug_report_service import BugReportPermissionError

        with patch.object(
            br_module, "add_attachments",
            side_effect=BugReportPermissionError("Khong phai author"),
        ):
            resp = teacher_client.post(
                f"/api/bug-reports/{REPORT_ID}/attachments",
                files=[
                    ("attachments", ("f.png", io.BytesIO(_fake_png_bytes()), "image/png"))
                ],
            )
            assert resp.status_code == 403

    def test_add_attachments_report_not_found(self, teacher_client):
        """Report không tồn tại → 404."""
        from app.api.endpoints import bug_reports as br_module
        from app.services.bug_report_service import BugReportNotFoundError

        with patch.object(
            br_module, "add_attachments",
            side_effect=BugReportNotFoundError(),
        ):
            resp = teacher_client.post(
                f"/api/bug-reports/{REPORT_ID}/attachments",
                files=[
                    ("attachments", ("f.png", io.BytesIO(_fake_png_bytes()), "image/png"))
                ],
            )
            assert resp.status_code == 404


# ===========================================================================
# TestRateLimit
# ===========================================================================


class TestRateLimit:
    """Rate limit 10 reports / user / hour."""

    def test_rate_limit_exceeded_returns_429(self, teacher_client):
        """Service raises rate limit → 429."""
        from app.api.endpoints import bug_reports as br_module
        from app.services.bug_report_service import BugReportRateLimitError

        with patch.object(
            br_module, "create_report",
            side_effect=BugReportRateLimitError(),  # default message
        ):
            resp = teacher_client.post(
                "/api/bug-reports",
                data={
                    "title": "X",
                    "description": "Y",
                    "category": "ui",
                    "severity": "low",
                },
            )
            assert resp.status_code == 429
            # Default message: "Bạn đã gửi quá nhiều báo cáo. Vui lòng thử lại sau."
            assert "nhiều" in resp.json()["detail"] or "thử lại" in resp.json()["detail"]

    def test_rate_limit_allows_under_limit(self, teacher_client):
        """Dưới limit → OK."""
        from app.api.endpoints import bug_reports as br_module

        with patch.object(
            br_module, "create_report", return_value=(_make_report_obj(), 0, datetime.now(tz=timezone.utc))
        ), patch.object(
            br_module, "get_report", return_value=_make_report_obj()
        ), patch.object(br_module, "_safe_dispatch_celery"):
            resp = teacher_client.post(
                "/api/bug-reports",
                data={
                    "title": "X",
                    "description": "Y",
                    "category": "ui",
                    "severity": "low",
                },
            )
            assert resp.status_code == 201


# ===========================================================================
# TestAttachmentValidation (service layer)
# ===========================================================================


class TestAttachmentValidation:
    """Validation file uploads ở service layer."""

    def test_non_image_mime_rejected(self, mock_db, teacher_user):
        """MIME không hợp lệ bị reject."""
        from app.schemas.bug_report import BugReportCreate
        from app.services.bug_report_service import (
            BugReportValidationError,
            create_report,
        )

        data = BugReportCreate(title="X", description="Y").model_dump()
        with pytest.raises(BugReportValidationError):
            create_report(
                db=mock_db,
                user=teacher_user,
                data=data,
                attachments=[
                    {
                        "file_data": b"x",
                        "file_name": "f.exe",
                        "mime_type": "application/x-msdownload",
                    }
                ],
            )

    def test_oversized_file_rejected(self, mock_db, teacher_user):
        """File > 5MB bị reject."""
        from app.schemas.bug_report import BugReportCreate
        from app.services.bug_report_service import (
            BugReportValidationError,
            create_report,
        )

        data = BugReportCreate(title="X", description="Y").model_dump()
        with pytest.raises(BugReportValidationError):
            create_report(
                db=mock_db,
                user=teacher_user,
                data=data,
                attachments=[
                    {
                        "file_data": b"x" * (10 * 1024 * 1024),
                        "file_name": "big.png",
                        "mime_type": "image/png",
                    }
                ],
            )


# ===========================================================================
# TestHistoryAudit (audit trail cho status changes)
# ===========================================================================


class TestHistoryAudit:
    """Mọi status change đều phải ghi 1 entry vào bug_report_history."""

    def _make_report(self, status=BugStatus.OPEN):
        """Tạo report mock với .filter().first() chain (cho update_status)."""
        report = MagicMock(spec=BugReport)
        report.bug_report_id = REPORT_ID
        report.user_id = TEACHER_ID
        report.user = None
        report.teacher = None
        report.attachments = []
        report.history = []
        report.status = status
        report.resolved_at = None
        report.closed_at = None
        report.teacher_id = None
        return report

    @patch("app.services.bug_report_service._upload_to_minio")
    def test_create_records_initial_history_entry(
        self, mock_upload, mock_db, teacher_user
    ):
        """create_report phải ghi 1 history entry initial (status=open)."""
        from app.schemas.bug_report import BugReportCreate
        from app.services.bug_report_service import create_report

        mock_upload.return_value = "http://minio/file.png"
        data = BugReportCreate(title="X", description="Y").model_dump()

        # Capture all objects added to db
        added_objects = []
        mock_db.add.side_effect = lambda obj: added_objects.append(obj)

        create_report(db=mock_db, user=teacher_user, data=data, attachments=[])

        # Phải có ít nhất 2 add: 1 cho BugReport, 1 cho BugReportHistory
        history_entries = [
            obj for obj in added_objects
            if isinstance(obj, BugReportHistory)
            or (hasattr(obj, "__class__") and obj.__class__.__name__ == "BugReportHistory")
        ]
        assert len(history_entries) >= 1, (
            f"Expected at least 1 BugReportHistory entry on create, "
            f"got {len(history_entries)} (added: {added_objects})"
        )

    def test_check_rate_limit_raises_when_exceeded(self, mock_db, teacher_user):
        """check_rate_limit raise BugReportRateLimitError khi used >= limit."""
        from app.services.bug_report_service import (
            BugReportRateLimitError,
            check_rate_limit,
        )

        # count query returns 10 (== limit)
        mock_db.query.return_value.filter.return_value.scalar.return_value = 10
        # oldest query returns a tuple (created_at,)
        from datetime import datetime as _dt
        from datetime import timezone as _tz
        mock_db.query.return_value.filter.return_value.first.return_value = (
            _dt.now(_tz.utc),
        )

        with pytest.raises(BugReportRateLimitError) as exc_info:
            check_rate_limit(db=mock_db, user_id=TEACHER_ID, limit=10)
        assert exc_info.value.status_code == 429
        assert "10" in exc_info.value.message

    def test_check_rate_limit_returns_count_under_limit(
        self, mock_db, teacher_user
    ):
        """check_rate_limit returns (used, reset_at) khi dưới limit."""
        from app.services.bug_report_service import check_rate_limit

        mock_db.query.return_value.filter.return_value.scalar.return_value = 3
        used, reset_at = check_rate_limit(db=mock_db, user_id=TEACHER_ID, limit=10)
        assert used == 3
        assert reset_at is not None

    def test_list_reports_service_layer(self, mock_db):
        """list_reports trả về items + total khi gọi service trực tiếp."""
        from app.services.bug_report_service import list_reports

        report_obj = MagicMock(spec=BugReport)
        report_obj.bug_report_id = REPORT_ID
        report_obj.user = None
        report_obj.teacher = None

        # Khi filters=None: _build_filter_query returns []; query chain
        # là: .query().join().order_by().options().offset().limit().all()
        items_query = MagicMock()
        items_query.join.return_value.order_by.return_value.options.return_value.offset.return_value.limit.return_value.all.return_value = [
            report_obj
        ]
        # Count: .query().join().scalar()
        count_query = MagicMock()
        count_query.join.return_value.scalar.return_value = 1

        mock_db.query.side_effect = [items_query, count_query]
        items, total = list_reports(db=mock_db, filters=None)
        assert total == 1
        assert items == [report_obj]

    def test_get_user_reports_service_layer(self, mock_db):
        """get_user_reports trả về items + total cho 1 user."""
        import uuid as uuid_mod

        from app.services.bug_report_service import get_user_reports

        user_id = uuid_mod.uuid4()
        report_obj = MagicMock(spec=BugReport)
        report_obj.bug_report_id = REPORT_ID
        report_obj.user = None
        report_obj.teacher = None

        # Items query: .query().options().filter().order_by().offset().limit().all()
        items_query = MagicMock()
        items_query.options.return_value.filter.return_value.order_by.return_value.offset.return_value.limit.return_value.all.return_value = [
            report_obj
        ]
        # Count query: .query().filter().scalar()
        count_query = MagicMock()
        count_query.filter.return_value.scalar.return_value = 1
        mock_db.query.side_effect = [items_query, count_query]

        items, total = get_user_reports(db=mock_db, user_id=user_id)
        assert total == 1
        assert items == [report_obj]

    def test_add_attachments_service_layer(self, mock_db, teacher_user):
        """add_attachments upload + gắn attachments vào report."""
        from app.services.bug_report_service import add_attachments

        report = MagicMock(spec=BugReport)
        report.bug_report_id = REPORT_ID
        report.user_id = teacher_user.user_id
        report.attachments = []  # empty
        mock_db.query.return_value.options.return_value.filter.return_value.first.return_value = report

        with patch(
            "app.services.bug_report_service._upload_to_minio",
            return_value="http://minio/f.png",
        ) as mock_upload:
            atts = [
                {"file_data": b"abc", "file_name": "f.png", "mime_type": "image/png"},
            ]
            _returned_report, new_atts = add_attachments(
                db=mock_db, user=teacher_user,
                report_id=REPORT_ID, attachments=atts,
            )
            assert mock_upload.call_count == 1
            assert len(new_atts) == 1
            assert mock_db.add.called
            assert mock_db.commit.called

    def test_get_stats_service_layer(self, mock_db):
        """get_stats trả về total + by_status/severity/category."""
        from app.services.bug_report_service import get_stats

        # group_by(...).all() returns list of (enum, count)
        mock_db.query.return_value.group_by.return_value.all.side_effect = [
            [(BugStatus.OPEN, 5), (BugStatus.RESOLVED, 2)],
            [(BugSeverity.HIGH, 3), (BugSeverity.LOW, 4)],
            [(BugCategory.UI, 6), (BugCategory.CRASH, 1)],
        ]
        # final count query
        mock_db.query.return_value.scalar.return_value = 7

        stats = get_stats(db=mock_db)
        assert stats["total"] == 7
        assert stats["by_status"]["open"] == 5
        assert stats["by_severity"]["high"] == 3
        assert stats["by_category"]["ui"] == 6

    def test_build_filter_query_with_all_filters(self):
        """_build_filter_query tạo conditions cho tất cả filter keys."""
        import uuid as uuid_mod

        from app.services.bug_report_service import _build_filter_query

        filters = {
            "status": "open",
            "severity": "high",
            "category": "ui",
            "user_id": uuid_mod.uuid4(),
            "teacher_id": uuid_mod.uuid4(),
            "user_role": "teacher",
            "search": "crash",
            "date_from": None,  # None values must be skipped
            "date_to": None,
        }
        conditions = _build_filter_query(filters)
        # status + severity + category + user_id + teacher_id + user_role + search = 7
        assert len(conditions) == 7

    def test_update_status_records_history_with_old_and_new(
        self, mock_db, admin_user
    ):
        """update_status ghi history với old_status và new_status đúng."""
        from app.services.bug_report_service import update_status

        report = self._make_report(status=BugStatus.OPEN)
        mock_db.query.return_value.filter.return_value.first.return_value = report

        # Capture history entries added
        history_entries = []

        def capture_add(obj):
            history_entries.append(obj)

        mock_db.add.side_effect = capture_add

        update_status(
            db=mock_db,
            report_id=REPORT_ID,
            changed_by=admin_user,
            new_status=BugStatus.IN_PROGRESS,
            comment="Bat dau xu ly",
        )

        # Tìm entry history được add
        assert len(history_entries) >= 1
        entry = history_entries[-1]
        assert entry.old_status == BugStatus.OPEN
        assert entry.new_status == BugStatus.IN_PROGRESS
        assert entry.comment == "Bat dau xu ly"
        assert entry.changed_by_id == admin_user.user_id
        assert entry.bug_report_id == REPORT_ID

    def test_update_status_no_change_no_history(
        self, mock_db, admin_user
    ):
        """update_status với status giống cũ → không ghi history."""
        from app.services.bug_report_service import update_status

        report = self._make_report(status=BugStatus.IN_PROGRESS)
        mock_db.query.return_value.filter.return_value.first.return_value = report

        history_entries = []
        mock_db.add.side_effect = lambda obj: history_entries.append(obj)

        update_status(
            db=mock_db,
            report_id=REPORT_ID,
            changed_by=admin_user,
            new_status=BugStatus.IN_PROGRESS,  # same as current
        )

        history_entries = [
            obj for obj in history_entries
            if obj.__class__.__name__ == "BugReportHistory"
        ]
        assert len(history_entries) == 0, (
            f"No history should be recorded on no-op, got {len(history_entries)}"
        )

    def test_update_assignee_change_records_history(
        self, mock_db, admin_user
    ):
        """Khi đổi assignee, history ghi lại old/new teacher_id."""
        import uuid as uuid_mod

        from app.models.user import Teacher
        from app.services.bug_report_service import update_status

        old_teacher_id = uuid_mod.uuid4()
        new_teacher_id = uuid_mod.uuid4()

        report = self._make_report(status=BugStatus.OPEN)
        report.teacher_id = old_teacher_id

        # update_status gọi 2 queries tuần tự:
        #   1) db.query(BugReport).filter().first() → report
        #   2) db.query(Teacher).filter().first()   → Teacher tồn tại
        teacher_obj = MagicMock(spec=Teacher)
        mock_db.query.return_value.filter.return_value.first.side_effect = [
            report,
            teacher_obj,
        ]

        history_entries = []
        mock_db.add.side_effect = lambda obj: history_entries.append(obj)

        update_status(
            db=mock_db,
            report_id=REPORT_ID,
            changed_by=admin_user,
            new_teacher_id=new_teacher_id,
        )

        assert len(history_entries) >= 1
        entry = history_entries[-1]
        assert entry.old_teacher_id == old_teacher_id
        assert entry.new_teacher_id == new_teacher_id

    def test_history_endpoint_returns_audit_trail(self, admin_client):
        """GET /api/bug-reports/{id} trả về history list (audit trail)."""
        from app.api.endpoints import bug_reports as br_module

        report = _make_report_obj(status="in_progress")
        report.history = [
            _make_history_obj(new_status="open", note="Tao report"),
            _make_history_obj(
                old_status="open", new_status="in_progress", note="Dang xu ly"
            ),
        ]
        with patch.object(br_module, "get_report", return_value=report):
            resp = admin_client.get(f"/api/bug-reports/{REPORT_ID}")
            assert resp.status_code == 200
            data = resp.json()
            assert "history" in data
            assert len(data["history"]) == 2
            # Verify thứ tự audit trail: created → updated
            assert data["history"][0]["new_status"] == "open"
            assert data["history"][1]["new_status"] == "in_progress"
            assert data["history"][1]["comment"] == "Dang xu ly"


# ===========================================================================
# TestOpenAPIDocs
# ===========================================================================


class TestOpenAPIDocs:
    """Verify OpenAPI schema integrity."""

    def test_all_endpoints_in_openapi(self):
        """OpenAPI có 5 unique bug-report paths (= 7 endpoints)."""
        schema = app.openapi()
        bug_paths = [p for p in schema["paths"] if "bug-reports" in p]
        assert len(bug_paths) == 5, (
            f"Expected 5 unique paths, got {len(bug_paths)}: {bug_paths}"
        )

    def test_endpoint_summaries_present(self):
        """Mỗi endpoint có summary mô tả bằng tiếng Anh."""
        schema = app.openapi()
        expected = {
            "Create a new bug report",
            "List MY bug reports",
            "Get MY bug report detail",
            "[Admin] List all bug reports",
            "[Admin] Get bug report detail",
            "[Admin] Update bug report",
            "Add attachments to existing bug report",
        }
        found = set()
        for path, methods in schema["paths"].items():
            if "bug-reports" in path:
                for method, op in methods.items():
                    if method in ("get", "post", "patch"):
                        found.add(op.get("summary", ""))
        missing = expected - found
        assert not missing, f"Missing summaries: {missing}"

    def test_response_models_defined(self):
        """Mỗi endpoint có response schema với success + error codes."""
        schema = app.openapi()
        for path, methods in schema["paths"].items():
            if "bug-reports" in path:
                for method, op in methods.items():
                    if method in ("get", "post", "patch"):
                        assert "responses" in op
                        status_codes = list(op["responses"].keys())
                        assert any(
                            code in ("200", "201") for code in status_codes
                        ), f"{method.upper()} {path} missing success response"
