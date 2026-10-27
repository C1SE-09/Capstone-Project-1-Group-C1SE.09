"""Đích mở từ push phải đúng bé/báo cáo và không vượt quyền phụ huynh."""

import uuid
from datetime import date
from types import SimpleNamespace
from unittest.mock import MagicMock

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.dashboard import router
from app.core.database import get_db
from app.core.security import get_current_user
from app.models.child import Child, ChildStatus, Parent, ParentChild
from app.models.report import DailyReport, DailyReportStatus
from app.models.user import User, UserRole


@pytest.fixture
def destination():
    parent_id = uuid.uuid4()
    children = [
        Child(
            child_id=uuid.uuid4(), parent_id=parent_id,
            full_name=name, status=ChildStatus.ENROLLED,
        )
        for name in ["Bé An", "Bé Bình"]
    ]
    report = DailyReport(
        daily_report_id=uuid.uuid4(), child_id=children[1].child_id,
        report_date=date(2026, 9, 1), status=DailyReportStatus.SENT,
        summary_text="Báo cáo cũ của bé Bình",
    )
    parent = SimpleNamespace(parent_id=parent_id, children=children)
    user = User(
        user_id=uuid.uuid4(), username="parent", password_hash="x",
        role=UserRole.PARENT, parent_id=parent_id,
    )
    db = MagicMock()

    def query(model):
        result = MagicMock()
        value = {Parent: parent, Child: children[1], DailyReport: report}.get(model)
        result.filter.return_value.first.return_value = value
        if model is Child:
            result.filter.return_value.order_by.return_value.all.return_value = [
                child for child in children if child.parent_id == parent_id
            ]
        return result

    db.query.side_effect = query
    app = FastAPI()
    app.include_router(router)
    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[get_current_user] = lambda: user
    with TestClient(app) as client:
        yield SimpleNamespace(
            client=client, children=children, report=report, user=user, db=db,
            app=app, parent_id=parent_id, parent=parent,
        )


def test_notification_selects_linked_child_instead_of_first_child(destination):
    child_id = str(destination.children[1].child_id)
    response = destination.client.get(
        f"/api/parent/{destination.parent_id}/child", params={"child_id": child_id},
    )
    assert response.status_code == 200
    assert response.json()["child"]["child_id"] == child_id


def test_unknown_notification_child_does_not_fall_back_to_another_child(destination):
    response = destination.client.get(
        f"/api/parent/{destination.parent_id}/child",
        params={"child_id": str(uuid.uuid4())},
    )
    assert response.status_code == 404


def test_parent_opens_exact_published_report_without_marking_it_read(destination):
    report_id = str(destination.report.daily_report_id)
    response = destination.client.get(f"/api/parent/reports/{report_id}")
    assert response.status_code == 200
    assert response.json()["daily_report_id"] == report_id
    assert response.json()["child_id"] == str(destination.children[1].child_id)
    assert response.json()["report_date"] == "2026-09-01"
    destination.db.commit.assert_not_called()


def test_notification_report_rejects_another_parent(destination):
    destination.user.parent_id = uuid.uuid4()
    response = destination.client.get(
        f"/api/parent/reports/{destination.report.daily_report_id}",
    )
    assert response.status_code == 403


def test_notification_report_does_not_expose_draft(destination):
    destination.report.status = DailyReportStatus.DRAFT
    response = destination.client.get(
        f"/api/parent/reports/{destination.report.daily_report_id}",
    )
    assert response.status_code == 404


def test_notification_report_requires_parent_role(destination):
    destination.user.role = UserRole.TEACHER
    response = destination.client.get(
        f"/api/parent/reports/{destination.report.daily_report_id}",
    )
    assert response.status_code == 403


def test_notification_report_supports_many_to_many_parent_link(destination):
    child = destination.children[1]
    child.parent_id = None
    child.parent_links = [ParentChild(parent_id=destination.parent_id)]
    response = destination.client.get(
        f"/api/parent/reports/{destination.report.daily_report_id}",
    )
    assert response.status_code == 200


def test_notification_report_requires_login(destination):
    destination.app.dependency_overrides.pop(get_current_user)
    response = destination.client.get(
        f"/api/parent/reports/{destination.report.daily_report_id}",
    )
    assert response.status_code == 401


def test_notification_selects_direct_child_when_parent_also_has_nn_child(destination):
    linked, direct = destination.children
    linked.parent_id = None
    linked.parent_links = [ParentChild(parent_id=destination.parent_id)]
    destination.parent.children = [linked]
    response = destination.client.get(
        f"/api/parent/{destination.parent_id}/child",
        params={"child_id": str(direct.child_id)},
    )
    assert response.status_code == 200
    assert response.json()["child"]["child_id"] == str(direct.child_id)
