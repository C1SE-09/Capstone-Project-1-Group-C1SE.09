"""HỒI QUY "PHẢN HỒI BÁO CÁO" — parent/teacher replies dưới báo cáo hằng ngày.

Nguyên tắc kiểm thử được chốt trong thiết kế:
1. Danh sách phản hồi **phẳng** (không cây reply lồng nhau) — không có cột
   ``reply_to_id`` trong schema.
2. Mọi tin nhắn (phụ huynh + giáo viên) nằm chung 1 bảng ``report_response``,
   phân biệt bằng ``author_role``.
3. Chỉ phản hồi được trên báo cáo đã **gửi** (SENT/READ/PUBLISHED).
4. Phân quyền: phụ huynh chỉ thấy bé mình; giáo viên chỉ thấy lớp mình.
5. Ảnh đính kèm dùng kho **private** → đường dẫn nội bộ, đọc qua endpoint
   có kiểm tra quyền.
6. ``is_read`` = giáo viên đã đọc phản hồi của phụ huynh; mở danh sách là
   tự đánh dấu đã đọc.
"""

import uuid
from datetime import date, datetime, timezone
from types import SimpleNamespace

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.api.endpoints import report_responses as routes
from app.core.database import get_db
from app.core.security import get_current_user
from app.models import (
    Base,
    Child,
    Class_,
    DailyReport,
    DailyReportStatus,
    Parent,
    ParentChild,
    ReportResponse,
    School,
    Teacher,
    User,
    UserRole,
)

TODAY = date(2030, 1, 5)


# ===========================================================================
# Fixture
# ===========================================================================


@pytest.fixture()
def env(monkeypatch):
    engine = create_engine(
        "sqlite://", poolclass=StaticPool, connect_args={"check_same_thread": False}
    )
    tables = [
        Base.metadata.tables[name]
        for name in (
            "school", "class", "teacher", "parent", "child", "parent_child",
            "users", "daily_report", "activity_entry", "report_response",
            "voice_record", "voice_recording_session",
        )
    ]
    Base.metadata.create_all(engine, tables=tables)
    factory = sessionmaker(bind=engine, expire_on_commit=False)
    db = factory()

    school = School(school_id=uuid.uuid4(), name="Trường A", code="A")
    class_ = Class_(class_id=uuid.uuid4(), school=school, name="Lớp A")
    other_class = Class_(class_id=uuid.uuid4(), school=school, name="Lớp B")
    parents = [
        Parent(parent_id=uuid.uuid4(), full_name=name, phone=f"090000000{i}")
        for i, name in enumerate(("Mẹ An", "Bố An", "Mẹ Bình"))
    ]
    child = Child(
        child_id=uuid.uuid4(), full_name="Bé An", parent=parents[0], class_=class_
    )
    other_child = Child(
        child_id=uuid.uuid4(), full_name="Bé Bình", parent=parents[2], class_=other_class
    )
    db.add_all([school, class_, other_class, *parents, child, other_child])
    db.flush()
    db.add(ParentChild(child_id=child.child_id, parent_id=parents[1].parent_id))

    teacher = Teacher(
        teacher_id=uuid.uuid4(), full_name="Cô Mai", school=school, class_=class_,
        email="mai@example.test",
    )
    other_teacher = Teacher(
        teacher_id=uuid.uuid4(), full_name="Cô Lan", school=school, class_=other_class,
        email="lan@example.test",
    )
    parent_users = [
        User(
            user_id=uuid.uuid4(), username=f"parent{i}", password_hash="x",
            role=UserRole.PARENT, parent_id=parent.parent_id,
        )
        for i, parent in enumerate(parents)
    ]
    teacher_user = User(
        user_id=uuid.uuid4(), username="teacher", password_hash="x",
        role=UserRole.TEACHER, teacher=teacher,
    )
    other_teacher_user = User(
        user_id=uuid.uuid4(), username="teacher2", password_hash="x",
        role=UserRole.TEACHER, teacher=other_teacher,
    )
    admin = User(
        user_id=uuid.uuid4(), username="admin", password_hash="x", role=UserRole.ADMIN
    )
    db.add_all([*parent_users, teacher_user, other_teacher_user, admin])
    db.commit()

    # Báo cáo đã gửi (phụ huynh được phản hồi) + báo cáo draft (chưa gửi)
    # Lưu ý: unique (child_id, report_date) → draft phải khác ngày.
    sent_report = DailyReport(
        daily_report_id=uuid.uuid4(),
        child_id=child.child_id,
        teacher_id=teacher.teacher_id,
        report_date=TODAY,
        status=DailyReportStatus.SENT,
        summary_text="Bé An ăn khá ngoan",
    )
    draft_report = DailyReport(
        daily_report_id=uuid.uuid4(),
        child_id=child.child_id,
        teacher_id=teacher.teacher_id,
        report_date=date(2030, 1, 6),
        status=DailyReportStatus.DRAFT,
        summary_text="Bản nháp",
    )
    other_report = DailyReport(
        daily_report_id=uuid.uuid4(),
        child_id=other_child.child_id,
        teacher_id=other_teacher.teacher_id,
        report_date=TODAY,
        status=DailyReportStatus.SENT,
        summary_text="Báo cáo của lớp khác",
    )
    db.add_all([sent_report, draft_report, other_report])
    db.commit()

    state = SimpleNamespace(
        db=db, factory=factory,
        child=child, other_child=other_child,
        class_=class_, other_class=other_class,
        parents=parent_users,
        teacher=teacher_user, other_teacher=other_teacher_user, admin=admin,
        report=sent_report, draft=draft_report, other_report=other_report,
        actor=parent_users[0],
    )

    app = FastAPI()
    app.include_router(routes.router)

    def request_db():
        with factory() as session:
            yield session

    app.dependency_overrides[get_db] = request_db
    app.dependency_overrides[get_current_user] = lambda: state.actor

    # Chặn dispatch Celery để test không phụ thuộc broker.
    monkeypatch.setattr(routes, "_safe_dispatch", lambda *a, **k: None)

    state.app = app
    with TestClient(app, raise_server_exceptions=False) as client:
        state.client = client
        yield state
    db.close()
    engine.dispose()


def as_user(env, user):
    env.actor = user


# ===========================================================================
# 1) Cấu trúc dữ liệu: phẳng, không reply lồng
# ===========================================================================


def test_schema_is_flat_no_reply_to_column():
    """Danh sách phẳng → bảng KHÔNG được có cột reply_to_id."""
    columns = {c.name for c in ReportResponse.__table__.columns}
    assert "reply_to_id" not in columns
    assert "parent_response_id" not in columns


def test_model_uses_single_table_for_both_roles():
    """Phụ huynh và giáo viên dùng chung 1 bảng, phân biệt bằng author_role."""
    columns = {c.name for c in ReportResponse.__table__.columns}
    assert "author_role" in columns
    assert "author_user_id" in columns
    assert "is_read" in columns
    assert "is_resolved" in columns


# ===========================================================================
# 2) Tạo phản hồi
# ===========================================================================


def test_parent_can_create_response(env):
    as_user(env, env.parents[0])
    resp = env.client.post(
        f"/api/report-responses/reports/{env.report.daily_report_id}",
        json={"content": "Bé An sốt nhẹ sáng nay, nhờ cô theo dõi thêm ạ."},
    )
    assert resp.status_code == 201
    body = resp.json()
    assert body["response"]["content"] == "Bé An sốt nhẹ sáng nay, nhờ cô theo dõi thêm ạ."
    assert body["response"]["author_role"] == "parent"
    assert body["response"]["author_name"] == "Mẹ An"
    assert body["response"]["is_read"] is False
    assert body["response"]["is_resolved"] is False
    assert body["total"] == 1


def test_response_content_is_stripped(env):
    as_user(env, env.parents[0])
    resp = env.client.post(
        f"/api/report-responses/reports/{env.report.daily_report_id}",
        json={"content": "  Bé ngủ tốt  "},
    )
    assert resp.status_code == 201
    assert resp.json()["response"]["content"] == "Bé ngủ tốt"


def test_empty_content_rejected(env):
    as_user(env, env.parents[0])
    resp = env.client.post(
        f"/api/report-responses/reports/{env.report.daily_report_id}",
        json={"content": "   "},
    )
    assert resp.status_code == 422


def test_too_long_content_rejected(env):
    as_user(env, env.parents[0])
    resp = env.client.post(
        f"/api/report-responses/reports/{env.report.daily_report_id}",
        json={"content": "a" * 2001},
    )
    assert resp.status_code == 422


def test_cannot_respond_to_draft_report(env):
    """Báo cáo chưa gửi → phụ huynh chưa thấy → không phản hồi được."""
    as_user(env, env.parents[0])
    resp = env.client.post(
        f"/api/report-responses/reports/{env.draft.daily_report_id}",
        json={"content": "Bé An sốt"},
    )
    assert resp.status_code == 409


def test_teacher_cannot_create_parent_response(env):
    """Chỉ phụ huynh được gửi phản hồi mới; giáo viên dùng endpoint reply."""
    as_user(env, env.teacher)
    resp = env.client.post(
        f"/api/report-responses/reports/{env.report.daily_report_id}",
        json={"content": "Xin mẹ kiểm tra lại"},
    )
    assert resp.status_code == 403


def test_other_parent_cannot_respond(env):
    """Phụ huynh của bé khác không được phản hồi báo cáo này."""
    as_user(env, env.parents[2])
    resp = env.client.post(
        f"/api/report-responses/reports/{env.report.daily_report_id}",
        json={"content": "Xin mẹ kiểm tra lại"},
    )
    assert resp.status_code == 403


def test_second_parent_of_same_child_can_respond(env):
    """Bố An (ParentChild N-N) cũng được phản hồi cho bé An."""
    as_user(env, env.parents[1])
    resp = env.client.post(
        f"/api/report-responses/reports/{env.report.daily_report_id}",
        json={"content": "Bố An xem báo cáo"},
    )
    assert resp.status_code == 201


# ===========================================================================
# 3) Danh sách phản hồi — phẳng, thời gian tăng dần
# ===========================================================================


def _insert_response(env, content, *, role="parent", author=None, offset_seconds=0):
    """Chèn phản hồi với created_at xác định (SQLite chỉ độ phân giải giây)."""
    from datetime import timedelta

    with env.factory() as db:
        row = ReportResponse(
            daily_report_id=env.report.daily_report_id,
            child_id=env.child.child_id,
            author_user_id=(author.user_id if author else env.parents[0].user_id),
            author_role=role,
            content=content,
            created_at=datetime(2030, 1, 5, 8, 0, 0, tzinfo=timezone.utc)
            + timedelta(seconds=offset_seconds),
        )
        db.add(row)
        db.commit()
        db.refresh(row)
        return row


def test_list_responses_is_flat_chronological(env):
    for i, content in enumerate(("Câu 1", "Câu 2", "Câu 3")):
        _insert_response(env, content, offset_seconds=i)

    as_user(env, env.teacher)
    resp = env.client.get(f"/api/report-responses/reports/{env.report.daily_report_id}")
    assert resp.status_code == 200
    body = resp.json()
    assert body["total"] == 3
    contents = [r["content"] for r in body["responses"]]
    assert contents == ["Câu 1", "Câu 2", "Câu 3"]
    # Phẳng: không có cấp con / reply_to nào trong payload
    for item in body["responses"]:
        assert "reply_to_id" not in item
        assert "children" not in item


def test_teacher_reply_appears_in_same_flat_list(env):
    _insert_response(env, "Bé An sốt nhẹ", role="parent", offset_seconds=0)
    _insert_response(
        env, "Cô đã cho uống thuốc hạ sốt rồi ạ", role="teacher",
        author=env.teacher, offset_seconds=10,
    )

    as_user(env, env.parents[0])
    body = env.client.get(
        f"/api/report-responses/reports/{env.report.daily_report_id}"
    ).json()
    assert [r["author_role"] for r in body["responses"]] == ["parent", "teacher"]
    assert body["responses"][1]["author_name"] == "Cô Mai"


def test_other_teacher_cannot_read_responses(env):
    """Giáo viên lớp khác không được xem phản hồi."""
    as_user(env, env.parents[0])
    env.client.post(
        f"/api/report-responses/reports/{env.report.daily_report_id}",
        json={"content": "Bé An sốt nhẹ"},
    )
    as_user(env, env.other_teacher)
    resp = env.client.get(f"/api/report-responses/reports/{env.report.daily_report_id}")
    assert resp.status_code == 403


def test_other_parent_cannot_read_responses(env):
    as_user(env, env.parents[0])
    env.client.post(
        f"/api/report-responses/reports/{env.report.daily_report_id}",
        json={"content": "Bé An sốt nhẹ"},
    )
    as_user(env, env.parents[2])
    resp = env.client.get(f"/api/report-responses/reports/{env.report.daily_report_id}")
    assert resp.status_code == 403


def test_admin_can_read_all_responses(env):
    as_user(env, env.parents[0])
    env.client.post(
        f"/api/report-responses/reports/{env.report.daily_report_id}",
        json={"content": "Bé An sốt nhẹ"},
    )
    as_user(env, env.admin)
    resp = env.client.get(f"/api/report-responses/reports/{env.report.daily_report_id}")
    assert resp.status_code == 200
    assert resp.json()["total"] == 1


# ===========================================================================
# 4) is_read — badge "phản hồi mới"
# ===========================================================================


def test_unread_count_starts_at_one_for_teacher(env):
    as_user(env, env.parents[0])
    env.client.post(
        f"/api/report-responses/reports/{env.report.daily_report_id}",
        json={"content": "Bé An sốt nhẹ"},
    )
    as_user(env, env.teacher)
    body = env.client.get(
        f"/api/report-responses/reports/{env.report.daily_report_id}",
        params={"mark_read": False},
    ).json()
    assert body["unread_count"] == 1


def test_teacher_opening_list_marks_read(env):
    as_user(env, env.parents[0])
    env.client.post(
        f"/api/report-responses/reports/{env.report.daily_report_id}",
        json={"content": "Bé An sốt nhẹ"},
    )
    as_user(env, env.teacher)
    env.client.get(f"/api/report-responses/reports/{env.report.daily_report_id}")
    body = env.client.get(
        f"/api/report-responses/reports/{env.report.daily_report_id}",
        params={"mark_read": False},
    ).json()
    assert body["unread_count"] == 0


def test_parent_reading_does_not_clear_unread(env):
    """Chỉ giáo viên mới 'đọc' phản hồi của phụ huynh."""
    as_user(env, env.parents[0])
    env.client.post(
        f"/api/report-responses/reports/{env.report.daily_report_id}",
        json={"content": "Bé An sốt nhẹ"},
    )
    env.client.get(f"/api/report-responses/reports/{env.report.daily_report_id}")
    with env.factory() as db:
        row = db.scalar(
            select(ReportResponse).where(
                ReportResponse.daily_report_id == env.report.daily_report_id
            )
        )
        assert row.is_read is False


# ===========================================================================
# 5) Đánh dấu đã xử lý
# ===========================================================================


def test_teacher_can_resolve_response(env):
    as_user(env, env.parents[0])
    created = env.client.post(
        f"/api/report-responses/reports/{env.report.daily_report_id}",
        json={"content": "Bé An sốt nhẹ"},
    ).json()
    response_id = created["response"]["response_id"]

    as_user(env, env.teacher)
    resp = env.client.post(
        f"/api/report-responses/{response_id}/resolve", json={"resolved": True}
    )
    assert resp.status_code == 200
    assert resp.json()["response"]["is_resolved"] is True
    assert resp.json()["response"]["resolved_at"] is not None


def test_parent_cannot_resolve_response(env):
    as_user(env, env.parents[0])
    created = env.client.post(
        f"/api/report-responses/reports/{env.report.daily_report_id}",
        json={"content": "Bé An sốt nhẹ"},
    ).json()
    response_id = created["response"]["response_id"]

    resp = env.client.post(
        f"/api/report-responses/{response_id}/resolve", json={"resolved": True}
    )
    assert resp.status_code == 403


def test_other_teacher_cannot_resolve_response(env):
    as_user(env, env.parents[0])
    created = env.client.post(
        f"/api/report-responses/reports/{env.report.daily_report_id}",
        json={"content": "Bé An sốt nhẹ"},
    ).json()
    response_id = created["response"]["response_id"]

    as_user(env, env.other_teacher)
    resp = env.client.post(
        f"/api/report-responses/{response_id}/resolve", json={"resolved": True}
    )
    assert resp.status_code == 403


def test_can_unresolve(env):
    as_user(env, env.parents[0])
    created = env.client.post(
        f"/api/report-responses/reports/{env.report.daily_report_id}",
        json={"content": "Bé An sốt nhẹ"},
    ).json()
    response_id = created["response"]["response_id"]

    as_user(env, env.teacher)
    env.client.post(f"/api/report-responses/{response_id}/resolve", json={"resolved": True})
    resp = env.client.post(
        f"/api/report-responses/{response_id}/resolve", json={"resolved": False}
    )
    assert resp.status_code == 200
    assert resp.json()["response"]["is_resolved"] is False
    assert resp.json()["response"]["resolved_at"] is None


# ===========================================================================
# 6) Cascade: xoá báo cáo → xoá phản hồi
# ===========================================================================


def test_responses_cascade_deleted_with_report(env):
    as_user(env, env.parents[0])
    env.client.post(
        f"/api/report-responses/reports/{env.report.daily_report_id}",
        json={"content": "Bé An sốt nhẹ"},
    )
    with env.factory() as db:
        report = db.scalar(
            select(DailyReport).where(
                DailyReport.daily_report_id == env.report.daily_report_id
            )
        )
        db.delete(report)
        db.commit()
        remaining = db.scalar(
            select(ReportResponse).where(
                ReportResponse.daily_report_id == env.report.daily_report_id
            )
        )
        assert remaining is None


# ===========================================================================
# 7) Ảnh đính kèm — kho private
# ===========================================================================


def test_attachment_path_is_internal_not_public_url(env, monkeypatch):
    """Đường dẫn ảnh phải là đường dẫn NỘI BỘ, không phải URL public."""
    captured = {}

    def fake_save(*, child_id, user_id, data, content_type):
        captured["child_id"] = child_id
        captured["user_id"] = user_id
        return f"/api/report-responses/attachments/{child_id}/{uuid.uuid4()}"

    monkeypatch.setattr(routes.attachments, "save_attachment", fake_save)

    as_user(env, env.parents[0])
    resp = env.client.post(
        f"/api/report-responses/reports/{env.report.daily_report_id}/with-image",
        data={"content": "Bé An sốt, đây là ảnh"},
        files={"file": ("photo.png", b"\x89PNG\r\n\x1a\n" + b"0" * 32, "image/png")},
    )
    assert resp.status_code == 201
    assert resp.json()["response"]["has_image"] is True
    assert captured["child_id"] == env.child.child_id


def test_teacher_reply_with_image(env, monkeypatch):
    """Giáo viên gửi phản hồi kèm ảnh qua /reply-with-image hoặc /with-image."""
    captured = {}

    def fake_save(*, child_id, user_id, data, content_type):
        captured["child_id"] = child_id
        captured["user_id"] = user_id
        return f"/api/report-responses/attachments/{child_id}/{uuid.uuid4()}"

    monkeypatch.setattr(routes.attachments, "save_attachment", fake_save)

    as_user(env, env.teacher)
    resp = env.client.post(
        f"/api/report-responses/reports/{env.report.daily_report_id}/reply-with-image",
        data={"content": "Cô gửi ảnh hoạt động hôm nay của bé"},
        files={"file": ("photo.png", b"\x89PNG\r\n\x1a\n" + b"0" * 32, "image/png")},
    )
    assert resp.status_code == 201
    body = resp.json()["response"]
    assert body["has_image"] is True
    assert body["author_role"] == "teacher"
    assert captured["child_id"] == env.child.child_id

    # Giáo viên cũng có thể gửi qua /with-image
    resp2 = env.client.post(
        f"/api/report-responses/reports/{env.report.daily_report_id}/with-image",
        data={"content": "Ảnh góc học tập"},
        files={"file": ("photo2.png", b"\x89PNG\r\n\x1a\n" + b"0" * 32, "image/png")},
    )
    assert resp2.status_code == 201
    body2 = resp2.json()["response"]
    assert body2["has_image"] is True
    assert body2["author_role"] == "teacher"


def test_attachment_read_requires_permission(env, monkeypatch):
    """Đọc ảnh của bé khác → 403."""
    monkeypatch.setattr(
        routes.attachments,
        "read_attachment",
        lambda **kwargs: (b"bytes", "image/png"),
    )
    as_user(env, env.parents[2])
    resp = env.client.get(
        f"/api/report-responses/attachments/{env.child.child_id}/{uuid.uuid4()}"
    )
    assert resp.status_code == 403


def test_attachment_read_returns_private_headers(env, monkeypatch):
    monkeypatch.setattr(
        routes.attachments,
        "read_attachment",
        lambda **kwargs: (b"bytes", "image/png"),
    )
    as_user(env, env.parents[0])
    resp = env.client.get(
        f"/api/report-responses/attachments/{env.child.child_id}/{uuid.uuid4()}"
    )
    assert resp.status_code == 200
    assert resp.headers["cache-control"] == "private, no-store"
    assert resp.headers["x-content-type-options"] == "nosniff"


# ===========================================================================
# 8) Tích hợp: dashboard trả kèm phản hồi
# ===========================================================================


def test_report_dict_includes_responses():
    """_report_dict của dashboard phải kèm luôn phản hồi để 1 request là đủ."""
    from app.api.dashboard import _report_dict

    engine = create_engine(
        "sqlite://", poolclass=StaticPool, connect_args={"check_same_thread": False}
    )
    tables = [
        Base.metadata.tables[name]
        for name in (
            "school", "class", "teacher", "parent", "child", "parent_child",
            "users", "daily_report", "activity_entry", "report_response",
            "voice_record", "voice_recording_session",
        )
    ]
    Base.metadata.create_all(engine, tables=tables)
    factory = sessionmaker(bind=engine, expire_on_commit=False)
    with factory() as db:
        school = School(school_id=uuid.uuid4(), name="Trường A", code="A")
        class_ = Class_(class_id=uuid.uuid4(), school=school, name="Lớp A")
        parent = Parent(parent_id=uuid.uuid4(), full_name="Mẹ An", phone="0900000000")
        child = Child(
            child_id=uuid.uuid4(), full_name="Bé An", parent=parent, class_=class_
        )
        teacher = Teacher(
            teacher_id=uuid.uuid4(), full_name="Cô Mai", school=school, class_=class_,
            email="mai@example.test",
        )
        db.add_all([school, class_, parent, child, teacher])
        db.flush()
        user = User(
            user_id=uuid.uuid4(), username="parent", password_hash="x",
            role=UserRole.PARENT, parent_id=parent.parent_id,
        )
        db.add(user)
        report = DailyReport(
            daily_report_id=uuid.uuid4(),
            child_id=child.child_id,
            teacher_id=teacher.teacher_id,
            report_date=TODAY,
            status=DailyReportStatus.SENT,
            summary_text="Bé An ăn khá ngoan",
        )
        db.add(report)
        db.flush()
        db.add(
            ReportResponse(
                daily_report_id=report.daily_report_id,
                child_id=child.child_id,
                author_user_id=user.user_id,
                author_role="parent",
                content="Bé An sốt nhẹ",
            )
        )
        db.commit()

        payload = _report_dict(report)
        assert payload["response_count"] == 1
        assert payload["unread_response_count"] == 1
        assert payload["responses"][0]["content"] == "Bé An sốt nhẹ"
        assert payload["responses"][0]["author_name"] == "Mẹ An"
    engine.dispose()
