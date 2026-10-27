"""
tests/test_health_exam.py
=========================
Unit tests cho API GET /api/health-exam/template (Chỉ dành cho Admin):
- Quản trị viên (Admin) xuất file mẫu -> 200 OK, trả file .xlsx.
- Kiểm tra file Excel có cấu trúc đúng:
  * Sheet protection bật (ws.protection.sheet == True).
  * Các cột định danh (Mã HS, Họ tên, Ngày sinh, Giới tính) bị khóa (locked=True).
  * Các cột nhập kết quả khám (Ngày khám, Chiều cao, Cân nặng, Thể trạng, Ghi chú) mở khóa (locked=False).
- Giáo viên truy cập -> 403 Forbidden (chỉ Admin mới được quyền).
- Phụ huynh truy cập -> 403 Forbidden.
- Lớp không tồn tại -> 404 Not Found.
"""

import uuid
from datetime import date
from io import BytesIO
from unittest.mock import MagicMock

import openpyxl
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.endpoints.health_exam import router as health_exam_router
from app.core.database import get_db
from app.core.security import get_current_user
from app.models.child import Child, ChildStatus
from app.models.user import Class_, Teacher, User, UserRole

app = FastAPI()
app.include_router(health_exam_router, prefix="/api")

OWN_CLASS_ID = uuid.uuid4()
TEACHER_ID = uuid.uuid4()


@pytest.fixture()
def mock_db():
    return MagicMock()


@pytest.fixture()
def admin_user():
    return User(
        user_id=uuid.uuid4(),
        username="admin",
        password_hash="hashed",
        role=UserRole.ADMIN,
    )


@pytest.fixture()
def teacher_user():
    teacher = Teacher(
        teacher_id=TEACHER_ID,
        class_id=OWN_CLASS_ID,
        full_name="Cô Lan",
    )
    user = User(
        user_id=uuid.uuid4(),
        username="teacher.lan",
        password_hash="hashed",
        role=UserRole.TEACHER,
        teacher_id=TEACHER_ID,
    )
    user.teacher = teacher
    return user


@pytest.fixture()
def parent_user():
    return User(
        user_id=uuid.uuid4(),
        username="parent.tuan",
        password_hash="hashed",
        role=UserRole.PARENT,
        parent_id=uuid.uuid4(),
    )


@pytest.fixture()
def sample_classroom():
    return Class_(
        class_id=OWN_CLASS_ID,
        name="Lớp Mầm 1",
        school_id=uuid.uuid4(),
    )


@pytest.fixture()
def sample_children():
    c1 = Child(
        child_id=uuid.uuid4(),
        class_id=OWN_CLASS_ID,
        full_name="Nguyễn Văn An",
        date_of_birth=date(2021, 5, 10),
        gender="male",
        status=ChildStatus.ENROLLED,
    )
    c2 = Child(
        child_id=uuid.uuid4(),
        class_id=OWN_CLASS_ID,
        full_name="Trần Thị Bình",
        date_of_birth=date(2021, 8, 20),
        gender="female",
        status=ChildStatus.ENROLLED,
    )
    return [c1, c2]


def test_export_template_success_admin(mock_db, admin_user, sample_classroom, sample_children):
    """Admin tải file mẫu: nhận file .xlsx với các cột định danh bị khóa."""
    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: admin_user

    def mock_scalar(statement):
        if "FROM class" in str(statement):
            return sample_classroom
        return None

    def mock_scalars(statement):
        result = MagicMock()
        result.all.return_value = sample_children
        return result

    mock_db.scalar.side_effect = mock_scalar
    mock_db.scalars.side_effect = mock_scalars

    client = TestClient(app)
    resp = client.get(f"/api/health-exam/template?class_id={OWN_CLASS_ID}")

    assert resp.status_code == 200
    assert "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" in resp.headers["content-type"]
    assert "Mau_Kham_Suc_Khoe" in resp.headers["content-disposition"]

    # Đọc và kiểm tra file Excel
    wb = openpyxl.load_workbook(BytesIO(resp.content))
    ws = wb.active

    # 1. Sheet protection được kích hoạt
    assert ws.protection.sheet is True

    # 2. Tiêu đề các cột
    expected_headers = [
        "Mã học sinh",
        "Họ và tên",
        "Ngày sinh",
        "Giới tính",
        "Ngày khám",
        "Chiều cao (cm)",
        "Cân nặng (kg)",
        "BMI",
        "Phân loại thể trạng",
        "Kết luận chung",
    ]
    for col_idx, expected in enumerate(expected_headers, start=1):
        assert ws.cell(row=1, column=col_idx).value == expected
        assert ws.cell(row=1, column=col_idx).protection.locked is True

    # 3. Dòng dữ liệu học sinh 1
    c1 = sample_children[0]
    assert ws.cell(row=2, column=1).value == str(c1.child_id)
    assert ws.cell(row=2, column=2).value == c1.full_name
    assert ws.cell(row=2, column=3).value == "10/05/2021"
    assert ws.cell(row=2, column=4).value == "Nam"

    # Kiểm tra các cột định danh bị KHÓA (locked=True)
    assert ws.cell(row=2, column=1).protection.locked is True
    assert ws.cell(row=2, column=2).protection.locked is True
    assert ws.cell(row=2, column=3).protection.locked is True
    assert ws.cell(row=2, column=4).protection.locked is True

    # Kiểm tra các cột nhập liệu được MỞ KHÓA (locked=False)
    assert ws.cell(row=2, column=5).protection.locked is False  # Ngày khám
    assert ws.cell(row=2, column=6).protection.locked is False  # Chiều cao
    assert ws.cell(row=2, column=7).protection.locked is False  # Cân nặng
    assert ws.cell(row=2, column=9).protection.locked is False  # Thể trạng
    assert ws.cell(row=2, column=10).protection.locked is False  # Kết luận

    app.dependency_overrides.clear()


def test_export_template_forbidden_teacher(mock_db, teacher_user):
    """Giáo viên không có quyền truy cập endpoint này (chỉ Admin)."""
    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: teacher_user

    client = TestClient(app)
    resp = client.get(f"/api/health-exam/template?class_id={OWN_CLASS_ID}")

    assert resp.status_code == 403
    assert "chỉ dành cho Quản trị viên" in resp.json()["detail"]

    app.dependency_overrides.clear()


def test_export_template_forbidden_parent(mock_db, parent_user):
    """Phụ huynh không có quyền truy cập endpoint này."""
    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: parent_user

    client = TestClient(app)
    resp = client.get(f"/api/health-exam/template?class_id={OWN_CLASS_ID}")

    assert resp.status_code == 403
    assert "chỉ dành cho Quản trị viên" in resp.json()["detail"]

    app.dependency_overrides.clear()


def test_export_template_not_found_class(mock_db, admin_user):
    """Báo 404 khi class_id không tồn tại trong hệ thống."""
    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: admin_user

    mock_db.scalar.return_value = None  # Không tìm thấy Class_

    client = TestClient(app)
    resp = client.get(f"/api/health-exam/template?class_id={OWN_CLASS_ID}")

    assert resp.status_code == 404
    assert "Không tìm thấy" in resp.json()["detail"]

    app.dependency_overrides.clear()
