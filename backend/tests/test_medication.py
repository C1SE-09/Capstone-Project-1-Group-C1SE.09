"""
tests/test_medication.py
========================
Bộ kiểm thử tự động cho Module Dặn thuốc & Theo dõi sức khỏe (User Story 3.1).
Bao gồm 10 Test Cases đã được duyệt:
- TC-MED-01: Phụ huynh tạo đơn nhiều cữ trong ngày (08:30, 11:30)
- TC-MED-02: Đơn thuốc dài ngày (from_date đến to_date)
- TC-MED-03: Chặn tạo đơn khi thiếu ảnh đơn thuốc (422)
- TC-MED-04: Chống gửi trùng đơn cữ uống (409)
- TC-MED-05: Giáo viên tạo hộ tại cửa lớp (parent_id tự động gán không null)
- TC-MED-06: Giáo viên xem danh sách cữ thuốc của lớp hôm nay
- TC-MED-07: Cô giáo xác nhận cho uống thuốc thành công
- TC-MED-08: Chống uống trùng liều (409 Conflict khi cô B xác nhận sau cô A)
- TC-MED-09: Phụ huynh hủy đơn khi còn PENDING
- TC-MED-10: Khóa nút hủy nếu đơn đã GIVEN (400 Bad Request)
- TC-MED-11: Hủy toàn bộ cữ còn lại của đợt thuốc (batch cancel)
"""

from __future__ import annotations

import uuid
from datetime import date, timedelta
from typing import Generator

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.api.endpoints.medication import router as medication_router
from app.core.database import get_db
from app.core.security import get_current_user
from app.models.base import Base
from app.models.child import Child, ChildStatus, Parent
from app.models.medication import MedicationRequest, MedicationStatus, MedicineCategory
from app.models.user import Class_, School, Teacher, User, UserRole


# ---------------------------------------------------------------------------
# Test Database Engine (SQLite In-Memory with StaticPool)
# ---------------------------------------------------------------------------
@pytest.fixture(scope="session")
def engine():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    return engine


@pytest.fixture()
def db_session(engine) -> Generator[Session, None, None]:
    SessionLocal = sessionmaker(bind=engine)
    session = SessionLocal()

    yield session

    session.rollback()
    # Dọn dẹp dữ liệu các bảng sau mỗi test
    for table in reversed(Base.metadata.sorted_tables):
        session.execute(table.delete())
    session.commit()
    session.close()


# ---------------------------------------------------------------------------
# Seed Data Fixture (Trần Gia Bảo, Lớp Mầm A, Phụ huynh Nam, Cô Mai & Cô Hoa)
# ---------------------------------------------------------------------------
@pytest.fixture()
def seed_data(db_session: Session):
    school_id = uuid.uuid4()
    school = School(
        school_id=school_id,
        name="Trường Mầm Non Hoa Mai",
        code="MN-HM-01",
        address="123 Nguyễn Thị Minh Khai, Q.1",
        phone="02812345678",
    )
    db_session.add(school)

    class_id = uuid.uuid4()
    class_ = Class_(
        class_id=class_id,
        school_id=school_id,
        name="Lớp Mầm A",
        room_number="Phòng 101",
    )
    db_session.add(class_)

    teacher_mai_id = uuid.uuid4()
    teacher_mai = Teacher(
        teacher_id=teacher_mai_id,
        school_id=school_id,
        class_id=class_id,
        full_name="Nguyễn Thị Mai",
        email="mai.nguyen@kinderlog.vn",
    )
    db_session.add(teacher_mai)

    teacher_hoa_id = uuid.uuid4()
    teacher_hoa = Teacher(
        teacher_id=teacher_hoa_id,
        school_id=school_id,
        class_id=class_id,
        full_name="Trần Thị Hoa",
        email="hoa.tran@kinderlog.vn",
    )
    db_session.add(teacher_hoa)

    parent_id = uuid.uuid4()
    parent = Parent(
        parent_id=parent_id,
        full_name="Trần Văn Nam",
        phone="0912345678",
        email="nam.tran@gmail.com",
    )
    parent.relationship_ = "Bố"
    db_session.add(parent)

    child_id = uuid.uuid4()
    child = Child(
        child_id=child_id,
        parent_id=parent_id,
        class_id=class_id,
        full_name="Trần Gia Bảo",
        nickname="Bảo Bảo",
        date_of_birth=date(2021, 5, 20),
        gender="male",
        status=ChildStatus.ENROLLED,
    )
    db_session.add(child)

    # Users
    user_parent = User(
        user_id=uuid.uuid4(),
        username="parent_nam",
        password_hash="x",
        role=UserRole.PARENT,
        parent_id=parent_id,
    )
    db_session.add(user_parent)

    user_teacher_mai = User(
        user_id=uuid.uuid4(),
        username="teacher_mai",
        password_hash="x",
        role=UserRole.TEACHER,
        teacher_id=teacher_mai_id,
    )
    db_session.add(user_teacher_mai)

    user_teacher_hoa = User(
        user_id=uuid.uuid4(),
        username="teacher_hoa",
        password_hash="x",
        role=UserRole.TEACHER,
        teacher_id=teacher_hoa_id,
    )
    db_session.add(user_teacher_hoa)

    db_session.commit()

    return {
        "class": class_,
        "teacher_mai": teacher_mai,
        "teacher_hoa": teacher_hoa,
        "parent": parent,
        "child": child,
        "user_parent": user_parent,
        "user_teacher_mai": user_teacher_mai,
        "user_teacher_hoa": user_teacher_hoa,
    }


# ---------------------------------------------------------------------------
# Test App and Helpers
# ---------------------------------------------------------------------------
def get_test_client(db_session: Session, user: User) -> TestClient:
    app = FastAPI()
    app.include_router(medication_router, prefix="/api")
    app.dependency_overrides[get_db] = lambda: db_session
    app.dependency_overrides[get_current_user] = lambda: user
    return TestClient(app)


# ---------------------------------------------------------------------------
# 10 TEST CASES
# ---------------------------------------------------------------------------
def test_tc_med_01_parent_create_multi_slot_today(db_session, seed_data):
    """TC-MED-01: Phụ huynh tạo đơn dặn thuốc nhiều cữ trong ngày (08:30 và 11:30)."""
    client = get_test_client(db_session, seed_data["user_parent"])
    payload = {
        "child_id": str(seed_data["child"].child_id),
        "from_date": str(date.today()),
        "time_slots": ["08:30", "11:30"],
        "medicine_category": MedicineCategory.PRESCRIPTION.value,
        "medicine_name": "Thuốc hạ sốt & Kháng sinh",
        "dosage": "1 gói chia sẵn theo cữ",
        "notes": "Cho bé uống sau khi ăn no 15 phút",
        "prescription_image_url": "https://storage.kinderlog.vn/prescriptions/don1.jpg",
    }

    res = client.post("/api/medication-requests", json=payload)
    assert res.status_code == 201, res.text
    data = res.json()

    assert data["total_slots"] == 2
    assert len(data["items"]) == 2
    batch_id = data["batch_id"]

    for item in data["items"]:
        assert item["batch_id"] == batch_id
        assert item["child_id"] == str(seed_data["child"].child_id)
        assert item["parent_id"] == str(seed_data["parent"].parent_id)
        assert item["creator_name"] == seed_data["parent"].full_name
        assert item["created_by_role"] == "parent"
        assert item["status"] == MedicationStatus.PENDING.value
        assert item["prescription_image_url"] == "https://storage.kinderlog.vn/prescriptions/don1.jpg"

    assert {item["time_slot"] for item in data["items"]} == {"08:30", "11:30"}


def test_tc_med_02_multi_day_range(db_session, seed_data):
    """TC-MED-02: Đơn thuốc dài ngày (from_date đến to_date = 3 ngày liên tiếp)."""
    client = get_test_client(db_session, seed_data["user_parent"])
    today = date.today()
    to_date = today + timedelta(days=2)  # 3 ngày: today, today+1, today+2

    payload = {
        "child_id": str(seed_data["child"].child_id),
        "from_date": str(today),
        "to_date": str(to_date),
        "time_slots": ["11:30"],
        "medicine_category": MedicineCategory.FEVER_REDUCER.value,
        "dosage": "5ml siro Hapacol",
        "prescription_image_url": "https://storage.kinderlog.vn/prescriptions/siro.jpg",
    }

    res = client.post("/api/medication-requests", json=payload)
    assert res.status_code == 201, res.text
    data = res.json()

    assert data["total_slots"] == 3
    dates = [item["request_date"] for item in data["items"]]
    assert str(today) in dates
    assert str(today + timedelta(days=1)) in dates
    assert str(to_date) in dates


def test_tc_med_03_missing_prescription_image(db_session, seed_data):
    """TC-MED-03: Chặn tạo đơn khi thiếu ảnh đơn thuốc / giấy chỉ định (422 Validation Error)."""
    client = get_test_client(db_session, seed_data["user_parent"])
    payload = {
        "child_id": str(seed_data["child"].child_id),
        "from_date": str(date.today()),
        "time_slots": ["08:30"],
        "dosage": "1 gói",
        "prescription_image_url": "   ",  # Trống
    }

    res = client.post("/api/medication-requests", json=payload)
    assert res.status_code == 422


def test_tc_med_04_duplicate_prevention(db_session, seed_data):
    """TC-MED-04: Chống gửi trùng đơn cho cùng cữ uống của bé (409 Conflict)."""
    client = get_test_client(db_session, seed_data["user_parent"])
    payload = {
        "child_id": str(seed_data["child"].child_id),
        "from_date": str(date.today() + timedelta(days=10)),
        "time_slots": ["09:00"],
        "dosage": "1 gói chia sẵn",
        "prescription_image_url": "https://storage.kinderlog.vn/prescriptions/don2.jpg",
    }

    # Lần 1: Thành công
    res1 = client.post("/api/medication-requests", json=payload)
    assert res1.status_code == 201

    # Lần 2: Trùng cữ -> 409 Conflict
    res2 = client.post("/api/medication-requests", json=payload)
    assert res2.status_code == 409
    assert "đã có đơn thuốc lúc 09:00" in res2.json()["detail"]


def test_tc_med_05_teacher_intake_at_door(db_session, seed_data):
    """TC-MED-05: Giáo viên tạo hộ tại cửa lớp (parent_id tự động gán từ bé, không bị NULL)."""
    client = get_test_client(db_session, seed_data["user_teacher_mai"])
    payload = {
        "child_id": str(seed_data["child"].child_id),
        "from_date": str(date.today() + timedelta(days=15)),
        "time_slots": ["14:00"],
        "medicine_category": MedicineCategory.PRESCRIPTION.value,
        "dosage": "1 gói thuốc túi zip",
        "notes": "Phụ huynh gửi trực tiếp tại cửa lớp lúc 7:50",
        "prescription_image_url": "https://storage.kinderlog.vn/prescriptions/tui_zip.jpg",
    }

    res = client.post("/api/medication-requests", json=payload)
    assert res.status_code == 201, res.text
    data = res.json()
    item = data["items"][0]

    assert item["parent_id"] == str(seed_data["parent"].parent_id)
    assert item["created_by_role"] == "teacher"
    assert item["creator_name"] == seed_data["teacher_mai"].full_name


def test_tc_med_06_teacher_list_today_medications(db_session, seed_data):
    """TC-MED-06: Giáo viên xem danh sách cữ thuốc của lớp hôm nay."""
    # Tạo 1 cữ thuốc hôm nay
    req = MedicationRequest(
        id=uuid.uuid4(),
        batch_id=uuid.uuid4(),
        child_id=seed_data["child"].child_id,
        parent_id=seed_data["parent"].parent_id,
        class_id=seed_data["class"].class_id,
        request_date=date.today(),
        time_slot="10:00",
        medicine_category=MedicineCategory.PRESCRIPTION,
        dosage="1 gói chia sẵn",
        prescription_image_url="https://storage.kinderlog.vn/prescriptions/sample.jpg",
        status=MedicationStatus.PENDING,
        created_by_user_id=seed_data["user_parent"].user_id,
        created_by_role="parent",
    )
    db_session.add(req)
    db_session.commit()

    client = get_test_client(db_session, seed_data["user_teacher_mai"])
    res = client.get(f"/api/medication-requests?date={date.today()}")
    assert res.status_code == 200
    items = res.json()
    assert any(i["id"] == str(req.id) for i in items)


def test_tc_med_07_teacher_confirm_intake(db_session, seed_data):
    """TC-MED-07: Cô giáo xác nhận đã cho uống thuốc thành công."""
    req = MedicationRequest(
        id=uuid.uuid4(),
        batch_id=uuid.uuid4(),
        child_id=seed_data["child"].child_id,
        parent_id=seed_data["parent"].parent_id,
        class_id=seed_data["class"].class_id,
        request_date=date.today(),
        time_slot="11:30",
        medicine_category=MedicineCategory.PRESCRIPTION,
        dosage="1 gói chia sẵn",
        prescription_image_url="https://storage.kinderlog.vn/prescriptions/sample.jpg",
        status=MedicationStatus.PENDING,
        created_by_user_id=seed_data["user_parent"].user_id,
        created_by_role="parent",
    )
    db_session.add(req)
    db_session.commit()

    client_mai = get_test_client(db_session, seed_data["user_teacher_mai"])
    res = client_mai.post(f"/api/medication-requests/{req.id}/confirm", json={"notes": "Bé uống ngoan"})
    assert res.status_code == 200, res.text
    data = res.json()

    assert data["status"] == MedicationStatus.GIVEN.value
    assert data["given_by_id"] == str(seed_data["teacher_mai"].teacher_id)
    assert data["given_by_name"] == seed_data["teacher_mai"].full_name
    assert data["given_at"] is not None


def test_tc_med_08_atomic_concurrency_lock_second_teacher(db_session, seed_data):
    """TC-MED-08: Chống uống trùng liều (Cô B xác nhận sau cô A -> 409 Conflict)."""
    req = MedicationRequest(
        id=uuid.uuid4(),
        batch_id=uuid.uuid4(),
        child_id=seed_data["child"].child_id,
        parent_id=seed_data["parent"].parent_id,
        class_id=seed_data["class"].class_id,
        request_date=date.today(),
        time_slot="11:30",
        medicine_category=MedicineCategory.PRESCRIPTION,
        dosage="1 gói chia sẵn",
        prescription_image_url="https://storage.kinderlog.vn/prescriptions/sample.jpg",
        status=MedicationStatus.PENDING,
        created_by_user_id=seed_data["user_parent"].user_id,
        created_by_role="parent",
    )
    db_session.add(req)
    db_session.commit()

    # Cô Mai xác nhận trước
    client_mai = get_test_client(db_session, seed_data["user_teacher_mai"])
    res1 = client_mai.post(f"/api/medication-requests/{req.id}/confirm")
    assert res1.status_code == 200

    # Cô Hoa bấm xác nhận sau -> 409 Conflict
    client_hoa = get_test_client(db_session, seed_data["user_teacher_hoa"])
    res2 = client_hoa.post(f"/api/medication-requests/{req.id}/confirm")
    assert res2.status_code == 409
    assert "đã được cô Nguyễn Thị Mai cho bé uống" in res2.json()["detail"]


def test_tc_med_09_parent_cancel_pending(db_session, seed_data):
    """TC-MED-09: Phụ huynh hủy cữ thuốc khi còn PENDING -> thành công."""
    req = MedicationRequest(
        id=uuid.uuid4(),
        batch_id=uuid.uuid4(),
        child_id=seed_data["child"].child_id,
        parent_id=seed_data["parent"].parent_id,
        class_id=seed_data["class"].class_id,
        request_date=date.today() + timedelta(days=5),
        time_slot="15:00",
        medicine_category=MedicineCategory.LOZENGE,
        dosage="1 viên ngậm",
        prescription_image_url="https://storage.kinderlog.vn/prescriptions/sample.jpg",
        status=MedicationStatus.PENDING,
        created_by_user_id=seed_data["user_parent"].user_id,
        created_by_role="parent",
    )
    db_session.add(req)
    db_session.commit()

    client = get_test_client(db_session, seed_data["user_parent"])
    res = client.post(f"/api/medication-requests/{req.id}/cancel")
    assert res.status_code == 200
    assert res.json()["status"] == MedicationStatus.CANCELLED.value


def test_tc_med_10_parent_cannot_cancel_given(db_session, seed_data):
    """TC-MED-10: Khóa nút hủy nếu cô đã cho uống thuốc (GIVEN -> 400 Bad Request)."""
    req = MedicationRequest(
        id=uuid.uuid4(),
        batch_id=uuid.uuid4(),
        child_id=seed_data["child"].child_id,
        parent_id=seed_data["parent"].parent_id,
        class_id=seed_data["class"].class_id,
        request_date=date.today(),
        time_slot="08:30",
        medicine_category=MedicineCategory.PRESCRIPTION,
        dosage="1 gói",
        prescription_image_url="https://storage.kinderlog.vn/prescriptions/sample.jpg",
        status=MedicationStatus.GIVEN,
        created_by_user_id=seed_data["user_parent"].user_id,
        created_by_role="parent",
    )
    db_session.add(req)
    db_session.commit()

    client = get_test_client(db_session, seed_data["user_parent"])
    res = client.post(f"/api/medication-requests/{req.id}/cancel")
    assert res.status_code == 400
    assert "Không thể hủy đơn vì bé đã được cô giáo cho uống thuốc" in res.json()["detail"]


def test_tc_med_11_parent_cancel_batch(db_session, seed_data):
    """TC-MED-11: Phụ huynh hủy nhanh cả đợt (chỉ hủy các cữ PENDING, giữ nguyên cữ GIVEN)."""
    batch_id = uuid.uuid4()
    req_given = MedicationRequest(
        id=uuid.uuid4(),
        batch_id=batch_id,
        child_id=seed_data["child"].child_id,
        parent_id=seed_data["parent"].parent_id,
        class_id=seed_data["class"].class_id,
        request_date=date.today(),
        time_slot="08:30",
        medicine_category=MedicineCategory.PRESCRIPTION,
        dosage="1 gói",
        prescription_image_url="https://storage.kinderlog.vn/prescriptions/sample.jpg",
        status=MedicationStatus.GIVEN,
        created_by_user_id=seed_data["user_parent"].user_id,
        created_by_role="parent",
    )
    req_pending = MedicationRequest(
        id=uuid.uuid4(),
        batch_id=batch_id,
        child_id=seed_data["child"].child_id,
        parent_id=seed_data["parent"].parent_id,
        class_id=seed_data["class"].class_id,
        request_date=date.today() + timedelta(days=1),
        time_slot="08:30",
        medicine_category=MedicineCategory.PRESCRIPTION,
        dosage="1 gói",
        prescription_image_url="https://storage.kinderlog.vn/prescriptions/sample.jpg",
        status=MedicationStatus.PENDING,
        created_by_user_id=seed_data["user_parent"].user_id,
        created_by_role="parent",
    )
    db_session.add_all([req_given, req_pending])
    db_session.commit()

    client = get_test_client(db_session, seed_data["user_parent"])
    res = client.post(f"/api/medication-requests/batch/{batch_id}/cancel")
    assert res.status_code == 200
    data = res.json()
    assert data["cancelled_count"] == 1

    db_session.refresh(req_given)
    db_session.refresh(req_pending)
    assert req_given.status == MedicationStatus.GIVEN
    assert req_pending.status == MedicationStatus.CANCELLED
