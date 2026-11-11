"""Authorization checks for the Teacher Review report flow."""

import uuid
from unittest.mock import MagicMock

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.teacher import router
from app.core.database import get_db
from app.core.security import get_current_user
from app.models.report import DailyReport, DailyReportStatus
from app.models.child import Child
from app.models.report import VoiceRecord
from app.models.user import Teacher, User, UserRole


@pytest.fixture
def report_client():
    app = FastAPI()
    app.include_router(router)
    db = MagicMock()
    teacher_id = uuid.uuid4()
    class_id = uuid.uuid4()
    teacher = Teacher(teacher_id=teacher_id, class_id=class_id, full_name="Cô Mai")
    user = User(
        user_id=uuid.uuid4(), username="teacher", password_hash="x",
        role=UserRole.TEACHER, teacher_id=teacher_id,
    )
    user.teacher = teacher
    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[get_current_user] = lambda: user
    with TestClient(app) as client:
        yield client, db, user, class_id
    app.dependency_overrides.clear()


def test_approve_item_requires_authentication(report_client):
    client, _, _, _ = report_client
    app = client.app
    app.dependency_overrides.pop(get_current_user)

    response = client.post(
        "/api/teacher/reports/approve-item",
        json={
            "voice_record_id": str(uuid.uuid4()),
            "teacher_id": str(uuid.uuid4()),
            "kind": "child",
            "child_id": str(uuid.uuid4()),
        },
    )

    assert response.status_code == 401


def test_approve_item_rejects_payload_teacher_spoof(report_client):
    client, db, _, class_id = report_client
    response = client.post(
        "/api/teacher/reports/approve-item",
        json={
            "voice_record_id": str(uuid.uuid4()),
            "teacher_id": str(uuid.uuid4()),
            "kind": "classwide",
            "class_id": str(class_id),
        },
    )

    assert response.status_code == 403
    db.query.assert_not_called()


def test_approve_item_rejects_a_class_not_assigned_to_teacher(report_client):
    client, db, user, _ = report_client
    db.query.return_value.filter.return_value.first.return_value = user.teacher

    response = client.post(
        "/api/teacher/reports/approve-item",
        json={
            "voice_record_id": str(uuid.uuid4()),
            "teacher_id": str(user.teacher_id),
            "kind": "classwide",
            "class_id": str(uuid.uuid4()),
        },
    )

    assert response.status_code == 403
    db.add.assert_not_called()
    db.commit.assert_not_called()


def test_approve_item_rejects_another_teachers_voice_record(report_client):
    client, db, user, class_id = report_client
    child = Child(child_id=uuid.uuid4(), class_id=class_id, full_name="Bé An")
    foreign_voice = VoiceRecord(
        voice_record_id=uuid.uuid4(), teacher_id=uuid.uuid4(),
        extraction_result={},
    )
    db.query.return_value.filter.return_value.first.side_effect = [
        child,
        user.teacher,
        foreign_voice,
    ]

    response = client.post(
        "/api/teacher/reports/approve-item",
        json={
            "voice_record_id": str(foreign_voice.voice_record_id),
            "teacher_id": str(user.teacher_id),
            "kind": "child",
            "child_id": str(child.child_id),
        },
    )

    assert response.status_code == 403
    db.add.assert_not_called()
    db.commit.assert_not_called()


def test_delete_draft_rejects_another_teachers_report(report_client):
    client, db, user, _ = report_client
    foreign_report = DailyReport(
        daily_report_id=uuid.uuid4(),
        teacher_id=uuid.uuid4(),
        status=DailyReportStatus.DRAFT,
    )
    db.query.return_value.filter.return_value.first.return_value = foreign_report

    response = client.delete(
        f"/api/teacher/reports/{foreign_report.daily_report_id}"
    )

    assert response.status_code == 403
    db.delete.assert_not_called()
    assert foreign_report.teacher_id != user.teacher_id


def test_teacher_can_delete_own_draft(report_client):
    client, db, user, _ = report_client
    own_report = DailyReport(
        daily_report_id=uuid.uuid4(),
        teacher_id=user.teacher_id,
        status=DailyReportStatus.DRAFT,
    )
    db.query.return_value.filter.return_value.first.return_value = own_report

    response = client.delete(f"/api/teacher/reports/{own_report.daily_report_id}")

    assert response.status_code == 200
    db.delete.assert_called_once_with(own_report)
    db.commit.assert_called_once()


def test_delete_drafts_batch_rejects_foreign_report_before_deleting(report_client):
    client, db, user, _ = report_client
    report_id = uuid.uuid4()
    foreign_report = DailyReport(
        daily_report_id=report_id,
        teacher_id=uuid.uuid4(),
        status=DailyReportStatus.DRAFT,
    )
    db.query.return_value.filter.return_value.all.return_value = [foreign_report]

    response = client.post(
        "/api/teacher/reports/delete-drafts",
        json={"report_ids": [str(report_id)]},
    )

    assert response.status_code == 403
    db.delete.assert_not_called()
    assert foreign_report.teacher_id != user.teacher_id


def test_send_batch_rejects_another_teachers_report(report_client):
    client, db, user, _ = report_client
    report_id = uuid.uuid4()
    foreign_report = DailyReport(
        daily_report_id=report_id,
        teacher_id=uuid.uuid4(),
        status=DailyReportStatus.DRAFT,
    )
    db.query.return_value.filter.return_value.all.return_value = [foreign_report]

    response = client.post(
        "/api/teacher/reports/send-batch",
        json={"report_ids": [str(report_id)]},
    )

    assert response.status_code == 403
    assert foreign_report.teacher_id != user.teacher_id
