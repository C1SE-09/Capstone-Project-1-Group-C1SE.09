"""Unit tests for Many-to-Many (N - N) Parent-Child relationship."""

import uuid
from datetime import date
from unittest.mock import MagicMock

from app.api.endpoints.admin import (
    ChildCreate,
    create_child,
    list_children,
)
from app.models.child import Child, ChildStatus, Parent, ParentChild
from app.models.device_token import DeviceToken
from app.models.user import Class_, User, UserRole
from app.services.notification_service import child_parents_device_tokens

ADMIN_USER = User(
    user_id=uuid.uuid4(), username="admin", password_hash="x", role=UserRole.ADMIN
)


class TestParentChildModelRelationships:
    """Test ORM models Parent, Child, ParentChild."""

    def test_parent_child_attributes(self):
        pid = uuid.uuid4()
        cid = uuid.uuid4()
        link = ParentChild(
            id=uuid.uuid4(),
            parent_id=pid,
            child_id=cid,
            relationship_="Bố",
            is_primary=True,
            can_pickup=True,
        )
        assert link.parent_id == pid
        assert link.child_id == cid
        assert link.relationship == "Bố"
        assert link.relationship_ == "Bố"
        assert link.is_primary is True
        assert link.can_pickup is True

        # Test relationship setter
        link.relationship = "Mẹ"
        assert link.relationship == "Mẹ"
        assert link.relationship_ == "Mẹ"

    def test_child_multiple_parent_links(self):
        c = Child(child_id=uuid.uuid4(), full_name="Bé Bảo")
        p1 = Parent(parent_id=uuid.uuid4(), full_name="Nguyễn Văn Bố")
        p2 = Parent(parent_id=uuid.uuid4(), full_name="Trần Thị Mẹ")

        link1 = ParentChild(
            id=uuid.uuid4(),
            parent=p1,
            child=c,
            relationship_="Bố",
            is_primary=True,
        )
        link2 = ParentChild(
            id=uuid.uuid4(),
            parent=p2,
            child=c,
            relationship_="Mẹ",
            is_primary=False,
        )

        c.parent_links = [link1, link2]
        assert len(c.parent_links) == 2
        assert c.parent_links[0].relationship == "Bố"
        assert c.parent_links[1].relationship == "Mẹ"


class TestAdminParentChildEndpoints:
    """Test Admin endpoints supporting multiple parents and children."""

    def test_create_child_with_multiple_parents(self):
        mock_db = MagicMock()
        mock_db.add = MagicMock()
        mock_db.commit = MagicMock()
        mock_db.flush = MagicMock()
        mock_db.refresh = MagicMock()

        p1_id = uuid.uuid4()
        p2_id = uuid.uuid4()

        p1 = Parent(parent_id=p1_id, full_name="Bố A")
        p1.relationship_ = "Bố"
        p2 = Parent(parent_id=p2_id, full_name="Mẹ B")
        p2.relationship_ = "Mẹ"

        # Mock db query
        def fake_query(model):
            mock_q = MagicMock()
            if model is Class_:
                mock_q.first.return_value = Class_(class_id=uuid.uuid4(), name="Lớp Mầm")
            elif model is Parent:
                def filter_fn(*args):
                    mock_filter = MagicMock()
                    # Return p1 or p2
                    mock_filter.first.return_value = p1
                    return mock_filter
                mock_q.filter = filter_fn
            return mock_q

        mock_db.query.side_effect = fake_query

        payload = ChildCreate(
            full_name="Nguyễn Văn Con",
            nickname="Bé Cún",
            parent_ids=[str(p1_id), str(p2_id)],
        )

        res = create_child(payload, mock_db, ADMIN_USER)
        assert res["message"] == "Tạo học sinh thành công"
        assert mock_db.commit.called

    def test_list_children_formats_multiple_parents(self):
        mock_db = MagicMock()
        c = Child(child_id=uuid.uuid4(), full_name="Trần Gia Bảo", nickname="Bảo")
        c.class_ = Class_(name="Mầm A")
        c.medical_allergies = None
        c.date_of_birth = date(2022, 5, 10)
        c.gender = "male"
        c.status = ChildStatus.ENROLLED

        p1 = Parent(parent_id=uuid.uuid4(), full_name="Trần Văn Bố", phone="0912000001", email="bo@gmail.com")
        p2 = Parent(parent_id=uuid.uuid4(), full_name="Lê Thị Mẹ", phone="0912000002", email="me@gmail.com")

        link1 = ParentChild(parent=p1, parent_id=p1.parent_id, relationship_="Bố", is_primary=True, can_pickup=True)
        link2 = ParentChild(parent=p2, parent_id=p2.parent_id, relationship_="Mẹ", is_primary=False, can_pickup=True)
        c.parent_links = [link1, link2]

        mock_db.query.return_value.all.return_value = [c]

        results = list_children(mock_db, ADMIN_USER)
        assert len(results) == 1
        item = results[0]
        assert len(item["parents"]) == 2
        assert item["parent_name"] == "Trần Văn Bố"
        assert item["parent_phone"] == "0912000001"
        assert "Trần Văn Bố (Bố)" in item["parents_summary"]
        assert "Lê Thị Mẹ (Mẹ)" in item["parents_summary"]


class TestNotificationsDeviceTokensNN:
    """Test device token collection across multiple parents."""

    def test_child_parents_device_tokens_queries_all_linked_parents(self):
        mock_db = MagicMock()
        cid = uuid.uuid4()
        pid1 = uuid.uuid4()
        pid2 = uuid.uuid4()

        # Mock db query for ParentChild and Child
        def fake_query(*models):
            mock_q = MagicMock()
            if models and models[0] is ParentChild.parent_id:
                mock_q.filter.return_value.all.return_value = [(pid1,), (pid2,)]
            elif models and models[0] is Child.parent_id:
                mock_q.filter.return_value.scalar.return_value = pid1
            elif models and models[0] is DeviceToken:
                token1 = DeviceToken(token="token_father", user_id=uuid.uuid4())
                token2 = DeviceToken(token="token_mother", user_id=uuid.uuid4())
                mock_q.join.return_value.filter.return_value.all.return_value = [token1, token2]
            return mock_q

        mock_db.query.side_effect = fake_query

        tokens = child_parents_device_tokens(mock_db, cid)
        assert len(tokens) == 2
        assert tokens[0].token == "token_father"
        assert tokens[1].token == "token_mother"
