"""
tests/test_health_exam.py
=========================
Unit tests cho API GET /api/health-exam/template (Chỉ dành cho Admin):
- Quản trị viên (Admin) xuất file mẫu -> 200 OK, trả file .xlsx.
- Kiểm tra file Excel có cấu trúc đúng:
  * Sheet KHÔNG bị khóa bảo vệ (ws.protection.sheet == False) — người dùng sửa tự do.
  * Các cột định danh (Mã HS, Họ tên, Ngày sinh, Giới tính) vẫn có dữ liệu điền sẵn.
  * Các cột nhập kết quả đo (Ngày ghi nhận, Chiều cao, Cân nặng, Thể trạng, Ghi chú) trống để điền.
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
from app.models.health_examination import HealthCategory, HealthExamination
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
        nickname="Nhỏ",
        date_of_birth=date(2021, 5, 10),
        gender="male",
        status=ChildStatus.ENROLLED,
    )
    c2 = Child(
        child_id=uuid.uuid4(),
        class_id=OWN_CLASS_ID,
        full_name="Trần Thị Bình",
        nickname="Lớn",
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
        text = str(statement)
        if "health_examination" in text:
            result.all.return_value = []  # Chưa có bản ghi sức khoẻ nào
        else:
            result.all.return_value = sample_children
        return result

    mock_db.scalar.side_effect = mock_scalar
    mock_db.scalars.side_effect = mock_scalars

    client = TestClient(app)
    resp = client.get(f"/api/health-exam/template?class_id={OWN_CLASS_ID}")

    assert resp.status_code == 200
    assert "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" in resp.headers["content-type"]
    assert "Mau_So_Suc_Khoe" in resp.headers["content-disposition"]

    # Đọc và kiểm tra file Excel
    wb = openpyxl.load_workbook(BytesIO(resp.content))
    ws = wb.active

    # 1. Sheet KHÔNG bị khóa bảo vệ (người dùng sửa tự do)
    assert ws.protection.sheet is False

    # 2. Tiêu đề các cột — KHÔNG có cột mã học sinh
    expected_headers = [
        "Họ và tên",
        "Ngày sinh",
        "Giới tính",
        "Ngày ghi nhận",
        "Chiều cao (cm)",
        "Cân nặng (kg)",
        "Kết luận chung",
    ]
    for col_idx, expected in enumerate(expected_headers, start=1):
        assert ws.cell(row=1, column=col_idx).value == expected
    assert ws.max_column == 7

    # 3. Dòng dữ liệu học sinh 1 — họ tên kèm biệt danh
    c1 = sample_children[0]
    assert ws.cell(row=2, column=1).value == f"{c1.full_name} ({c1.nickname})"
    assert ws.cell(row=2, column=2).value == "10/05/2021"
    assert ws.cell(row=2, column=3).value == "Nam"

    # Các cột nhập liệu để trống cho người dùng điền
    assert ws.cell(row=2, column=5).value is None  # Chiều cao
    assert ws.cell(row=2, column=6).value is None  # Cân nặng
    assert ws.cell(row=2, column=7).value is None  # Kết luận

    app.dependency_overrides.clear()


def test_export_template_prefills_existing_data(
    mock_db, admin_user, sample_classroom, sample_children
):
    """Bé đã có bản ghi sức khoẻ -> file mẫu điền sẵn chiều cao/cân nặng/kết luận."""
    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: admin_user

    c1 = sample_children[0]
    existing = HealthExamination(
        examination_id=uuid.uuid4(),
        child_id=c1.child_id,
        examination_date=date(2026, 9, 1),
        height=94.0,
        weight=13.5,
        bmi=15.26,
        health_category=HealthCategory.NORMAL,
        general_conclusion="Bé khỏe",
    )

    def mock_scalar(statement):
        if "FROM class" in str(statement):
            return sample_classroom
        return None

    def mock_scalars(statement):
        result = MagicMock()
        text = str(statement)
        if "health_examination" in text:
            result.all.return_value = [existing]
        else:
            result.all.return_value = sample_children
        return result

    mock_db.scalar.side_effect = mock_scalar
    mock_db.scalars.side_effect = mock_scalars

    client = TestClient(app)
    resp = client.get(f"/api/health-exam/template?class_id={OWN_CLASS_ID}")

    assert resp.status_code == 200
    wb = openpyxl.load_workbook(BytesIO(resp.content))
    ws = wb.active

    # Dòng của bé đã có số liệu -> điền sẵn 3 cột + ngày ghi nhận cũ
    assert ws.cell(row=2, column=4).value == "01/09/2026"
    assert ws.cell(row=2, column=5).value == 94.0
    assert ws.cell(row=2, column=6).value == 13.5
    assert ws.cell(row=2, column=7).value == "Bé khỏe"

    # Bé chưa có số liệu -> vẫn để trống
    assert ws.cell(row=3, column=5).value is None

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


# ===========================================================================
# POST /api/health-exam/import — nhập file Excel kết quả vào sổ sức khoẻ
# ===========================================================================

def _build_exam_workbook(rows: list[list]) -> bytes:
    """Dựng file .xlsx mẫu trong bộ nhớ (dòng 1 là tiêu đề)."""
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.append([
        "Họ và tên", "Ngày sinh", "Giới tính", "Ngày ghi nhận",
        "Chiều cao (cm)", "Cân nặng (kg)", "Kết luận chung",
    ])
    for row in rows:
        ws.append(row)
    buf = BytesIO()
    wb.save(buf)
    return buf.getvalue()


def _display_name(child) -> str:
    """Tên hiển thị trong file mẫu: "Nguyễn Văn An (Nhỏ)"."""
    if child.nickname:
        return f"{child.full_name} ({child.nickname})"
    return child.full_name


def _mock_import_db(mock_db, classroom, children):
    """Giả lập DB cho import: tìm thấy lớp, học sinh thuộc lớp, chưa có bản ghi khám."""

    def mock_scalar(statement):
        text = str(statement)
        if "FROM class" in text:
            return classroom
        return None

    def mock_scalars(statement):
        result = MagicMock()
        text = str(statement)
        if "health_examination" in text:
            result.all.return_value = []  # Chưa có bản ghi khám nào
        else:
            result.all.return_value = children
        return result

    mock_db.scalar.side_effect = mock_scalar
    mock_db.scalars.side_effect = mock_scalars


def test_import_exam_mixed_rows(mock_db, admin_user, sample_classroom, sample_children):
    """File có 1 dòng đúng + 1 dòng thiếu cân nặng + 1 dòng cân nặng vô lý (150kg):
    dòng đúng được lưu (tự tính BMI + xếp loại), 2 dòng lỗi báo rõ số dòng."""
    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: admin_user
    _mock_import_db(mock_db, sample_classroom, sample_children)

    c1, c2 = sample_children
    content = _build_exam_workbook([
        # Dòng 2: hợp lệ (BMI + phân loại do hệ thống tự tính)
        [_display_name(c1), "10/05/2021", "Nam", "20/10/2026", 95, 14, "Bé khỏe"],
        # Dòng 3: thiếu cân nặng
        [_display_name(c2), "20/08/2021", "Nữ", "20/10/2026", 90, "", ""],
        # Dòng 4: cân nặng vô lý 150kg
        [_display_name(c2), "20/08/2021", "Nữ", "21/10/2026", 90, 150, ""],
    ])

    client = TestClient(app)
    resp = client.post(
        "/api/health-exam/import",
        data={"class_id": str(OWN_CLASS_ID)},
        files={"file": ("ket_qua.xlsx", content, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")},
    )

    assert resp.status_code == 200
    body = resp.json()
    assert body["total_rows"] == 3
    assert body["success_count"] == 1
    assert body["failed_count"] == 2
    assert body["created_count"] == 1
    assert body["updated_count"] == 0

    # Báo lỗi ghi rõ số dòng Excel
    by_row = {e["row_number"]: e for e in body["errors"]}
    assert 3 in by_row and any("cân nặng" in m.lower() for m in by_row[3]["errors"])
    assert 4 in by_row and any("150" in m for m in by_row[4]["errors"])

    # Bản ghi được lưu có BMI tự tính (14kg / 0.95m^2 ≈ 15.51) và xếp loại Bình thường
    saved = mock_db.add.call_args_list[0].args[0]
    assert abs(saved.bmi - 15.51) < 0.01
    assert saved.health_category == HealthCategory.NORMAL
    assert saved.general_conclusion == "Bé khỏe"
    mock_db.commit.assert_called_once()

    app.dependency_overrides.clear()


def test_import_exam_forbidden_teacher(mock_db, teacher_user):
    """Giáo viên (không phải admin trường) bị chặn với 403."""
    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: teacher_user

    client = TestClient(app)
    resp = client.post(
        "/api/health-exam/import",
        data={"class_id": str(OWN_CLASS_ID)},
        files={"file": ("ket_qua.xlsx", b"fake", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")},
    )

    assert resp.status_code == 403

    app.dependency_overrides.clear()


def test_import_exam_wrong_extension(mock_db, admin_user):
    """Từ chối file không phải .xlsx."""
    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: admin_user
    mock_db.scalar.return_value = MagicMock()

    client = TestClient(app)
    resp = client.post(
        "/api/health-exam/import",
        data={"class_id": str(OWN_CLASS_ID)},
        files={"file": ("ket_qua.pdf", b"%PDF-fake", "application/pdf")},
    )

    assert resp.status_code == 400
    assert ".xlsx" in resp.json()["detail"]

    app.dependency_overrides.clear()


def test_import_exam_corrupt_file(mock_db, admin_user, sample_classroom):
    """File .xlsx hỏng nội dung -> 400 với thông báo rõ ràng."""
    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: admin_user
    mock_db.scalar.return_value = sample_classroom

    client = TestClient(app)
    resp = client.post(
        "/api/health-exam/import",
        data={"class_id": str(OWN_CLASS_ID)},
        files={"file": ("ket_qua.xlsx", b"not-a-real-excel", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")},
    )

    assert resp.status_code == 400
    assert "Excel" in resp.json()["detail"]

    app.dependency_overrides.clear()


# ===========================================================================
# GET /api/health-exam/records — danh sách bản ghi sổ sức khoẻ
# ===========================================================================

def _build_exam_record(child, classroom, *, height=95.0, weight=14.0, bmi=15.51,
                       category=HealthCategory.NORMAL, exam_date=date(2026, 10, 20)):
    """Dựng một bản ghi HealthExamination gắn với học sinh + lớp để mock kết quả query."""
    rec = HealthExamination(
        examination_id=uuid.uuid4(),
        child_id=child.child_id,
        examination_date=exam_date,
        height=height,
        weight=weight,
        bmi=bmi,
        health_category=category,
        general_conclusion="Bé khỏe",
        created_by_user_id=None,
    )
    rec.child = child
    rec.created_by_user = None
    return rec


def test_list_records_success_admin(mock_db, admin_user, sample_classroom, sample_children):
    """Admin xem danh sách: trả về toàn bộ học sinh kèm số liệu + thống kê."""
    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: admin_user

    c1, c2 = sample_children
    rec1 = _build_exam_record(c1, sample_classroom)
    rec2 = _build_exam_record(
        c2, sample_classroom, height=90.0, weight=12.0, bmi=14.81,
        category=HealthCategory.UNDERWEIGHT,
    )

    def mock_execute(statement):
        result = MagicMock()
        result.all.return_value = [
            (c1, sample_classroom),
            (c2, sample_classroom),
        ]
        return result

    def mock_scalars(statement):
        result = MagicMock()
        result.all.return_value = [rec1, rec2]
        return result

    mock_db.execute.side_effect = mock_execute
    mock_db.scalars.side_effect = mock_scalars

    client = TestClient(app)
    resp = client.get("/api/health-exam/records")

    assert resp.status_code == 200
    body = resp.json()
    assert body["total"] == 2
    assert len(body["records"]) == 2

    first = body["records"][0]
    assert first["full_name"] == c1.full_name
    assert first["nickname"] == c1.nickname
    assert first["class_name"] == sample_classroom.name
    assert first["height"] == 95.0
    assert first["weight"] == 14.0
    assert first["bmi"] == 15.51
    assert first["health_category"] == "NORMAL"
    assert first["health_category_label"] == "Bình thường"
    assert first["examination_date"] == "20/10/2026"
    assert first["date_of_birth"] == "10/05/2021"
    assert first["has_record"] is True

    # Thống kê theo phân loại thể trạng
    assert body["stats"]["normal"] == 1
    assert body["stats"]["underweight"] == 1
    assert body["stats"]["overweight"] == 0

    app.dependency_overrides.clear()


def test_list_records_includes_children_without_data(
    mock_db, admin_user, sample_classroom, sample_children
):
    """Bé chưa có số liệu vẫn xuất hiện trong danh sách (has_record = false)."""
    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: admin_user

    c1, c2 = sample_children
    rec1 = _build_exam_record(c1, sample_classroom)

    def mock_execute(statement):
        result = MagicMock()
        result.all.return_value = [(c1, sample_classroom), (c2, sample_classroom)]
        return result

    def mock_scalars(statement):
        result = MagicMock()
        result.all.return_value = [rec1]
        return result

    mock_db.execute.side_effect = mock_execute
    mock_db.scalars.side_effect = mock_scalars

    client = TestClient(app)
    resp = client.get("/api/health-exam/records")

    assert resp.status_code == 200
    body = resp.json()
    assert body["total"] == 2

    second = body["records"][1]
    assert second["child_id"] == str(c2.child_id)
    assert second["id"] is None
    assert second["has_record"] is False
    assert second["height"] is None
    assert second["weight"] is None
    assert second["bmi"] is None
    assert second["health_category"] is None
    assert second["general_conclusion"] is None

    app.dependency_overrides.clear()


def test_list_records_filter_by_date_only_returns_children_with_record(
    mock_db, admin_user, sample_classroom, sample_children
):
    """Lọc theo ngày ghi nhận: chỉ trả về bé CÓ bản ghi đúng ngày đó.

    Bé không có bản ghi trong ngày được lọc thì KHÔNG xuất hiện
    (khác với trường hợp không lọc ngày — lúc đó mọi bé đều hiện).
    """
    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: admin_user

    c1, c2 = sample_children
    rec1 = _build_exam_record(c1, sample_classroom, exam_date=date(2026, 10, 20))
    rec2 = _build_exam_record(
        c2, sample_classroom, height=90.0, weight=12.0, bmi=14.81,
        category=HealthCategory.UNDERWEIGHT, exam_date=date(2026, 9, 1),
    )

    def mock_execute(statement):
        result = MagicMock()
        result.all.return_value = [(c1, sample_classroom), (c2, sample_classroom)]
        return result

    def mock_scalars(statement):
        result = MagicMock()
        # Backend đã lọc sẵn theo ngày trong query → chỉ trả về rec1.
        result.all.return_value = [rec1]
        return result

    mock_db.execute.side_effect = mock_execute
    mock_db.scalars.side_effect = mock_scalars

    client = TestClient(app)
    resp = client.get("/api/health-exam/records?examination_date=2026-10-20")

    assert resp.status_code == 200
    body = resp.json()
    assert body["total"] == 1
    assert len(body["records"]) == 1
    assert body["records"][0]["child_id"] == str(c1.child_id)
    assert body["records"][0]["examination_date"] == "20/10/2026"
    assert body["records"][0]["has_record"] is True

    # Thống kê cũng chỉ tính trong nhóm đã lọc.
    assert body["stats"]["normal"] == 1
    assert body["stats"]["underweight"] == 0

    app.dependency_overrides.clear()


def test_list_records_filter_by_date_excludes_children_without_record_that_day(
    mock_db, admin_user, sample_classroom, sample_children
):
    """Lọc theo ngày mà bé không có bản ghi → bị loại khỏi danh sách."""
    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: admin_user

    c1, c2 = sample_children
    rec1 = _build_exam_record(c1, sample_classroom, exam_date=date(2026, 10, 20))

    def mock_execute(statement):
        result = MagicMock()
        result.all.return_value = [(c1, sample_classroom), (c2, sample_classroom)]
        return result

    def mock_scalars(statement):
        result = MagicMock()
        result.all.return_value = [rec1]
        return result

    mock_db.execute.side_effect = mock_execute
    mock_db.scalars.side_effect = mock_scalars

    client = TestClient(app)
    resp = client.get("/api/health-exam/records?examination_date=2026-10-20")

    assert resp.status_code == 200
    body = resp.json()
    # c2 không có bản ghi ngày 20/10/2026 → không xuất hiện.
    assert body["total"] == 1
    assert all(r["child_id"] == str(c1.child_id) for r in body["records"])
    assert all(r["has_record"] is True for r in body["records"])

    app.dependency_overrides.clear()


def test_list_records_forbidden_teacher(mock_db, teacher_user):
    """Giáo viên không được xem sổ sức khoẻ -> 403."""
    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: teacher_user

    client = TestClient(app)
    resp = client.get("/api/health-exam/records")

    assert resp.status_code == 403
    assert "chỉ dành cho Quản trị viên" in resp.json()["detail"]

    app.dependency_overrides.clear()


def test_list_records_empty(mock_db, admin_user):
    """Không có học sinh nào -> trả về danh sách rỗng, total = 0."""
    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: admin_user

    def mock_execute(statement):
        result = MagicMock()
        result.all.return_value = []
        return result

    def mock_scalars(statement):
        result = MagicMock()
        result.all.return_value = []
        return result

    mock_db.execute.side_effect = mock_execute
    mock_db.scalars.side_effect = mock_scalars

    client = TestClient(app)
    resp = client.get("/api/health-exam/records")

    assert resp.status_code == 200
    body = resp.json()
    assert body["total"] == 0
    assert body["records"] == []

    app.dependency_overrides.clear()


# ===========================================================================
# Validation moi — Chaque loi chan / canh bao
# ===========================================================================

def _post_import(client, rows: list[list]):
    content = _build_exam_workbook(rows)
    return client.post(
        "/api/health-exam/import",
        data={"class_id": str(OWN_CLASS_ID)},
        files={"file": ("ket_qua.xlsx", content, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")},
    )


def test_import_exam_date_before_birth(mock_db, admin_user, sample_classroom, sample_children):
    """Ngay ghi nhan truoc ngay sinh -> LOI CHAN (khong luu)."""
    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: admin_user
    _mock_import_db(mock_db, sample_classroom, sample_children)

    c1 = sample_children[0]  # Sinh 10/05/2021
    client = TestClient(app)
    resp = _post_import(client, [
        [_display_name(c1), "10/05/2021", "Nam", "01/01/2020", 95, 14, ""],
    ])

    assert resp.status_code == 200
    body = resp.json()
    assert body["success_count"] == 0
    assert body["failed_count"] == 1
    assert any("trước ngày sinh" in m for m in body["errors"][0]["errors"])

    app.dependency_overrides.clear()


def test_import_duplicate_child_in_file(mock_db, admin_user, sample_classroom, sample_children):
    """Cung HS xuat hien 2 dong cung ngay -> CA 2 DONG DEU LOI (tranh ghi de im lang)."""
    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: admin_user
    _mock_import_db(mock_db, sample_classroom, sample_children)

    c1 = sample_children[0]
    client = TestClient(app)
    resp = _post_import(client, [
        [_display_name(c1), "10/05/2021", "Nam", "20/10/2026", 95, 14, ""],
        [_display_name(c1), "10/05/2021", "Nam", "20/10/2026", 96, 15, ""],
    ])

    assert resp.status_code == 200
    body = resp.json()
    assert body["success_count"] == 0
    assert body["failed_count"] == 2
    assert all(any("trùng" in m for m in e["errors"]) for e in body["errors"])

    app.dependency_overrides.clear()


def test_import_who_classification(mock_db, admin_user, sample_classroom, sample_children):
    """Xep loai theo nguong WHO theo tuoi, khong dung nguong flat 14/18.

    Be trai ~65 thang (48-71 thang): nguong thua can 16.5.
    - BMI 16.0 -> BINH THUONG
    - BMI 19.0 -> THUA CAN
    """
    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: admin_user
    _mock_import_db(mock_db, sample_classroom, sample_children)

    c1, c2 = sample_children
    client = TestClient(app)
    resp = _post_import(client, [
        [_display_name(c1), "10/05/2021", "Nam", "20/10/2026", 100, 16, ""],
        [_display_name(c2), "20/08/2021", "Nữ", "21/10/2026", 100, 19, ""],
    ])

    assert resp.status_code == 200
    body = resp.json()
    assert body["success_count"] == 2

    saved1 = mock_db.add.call_args_list[0].args[0]
    assert abs(saved1.bmi - 16.0) < 0.01
    assert saved1.health_category == HealthCategory.NORMAL

    saved2 = mock_db.add.call_args_list[1].args[0]
    assert abs(saved2.bmi - 19.0) < 0.01
    assert saved2.health_category == HealthCategory.OVERWEIGHT

    app.dependency_overrides.clear()


def test_import_who_underweight(mock_db, admin_user, sample_classroom, sample_children):
    """Be gai ~62 thang, BMI 12.0 -> SUY DINH DUONG (nguong 12.5 cho 48-71 thang)."""
    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: admin_user
    _mock_import_db(mock_db, sample_classroom, sample_children)

    c2 = sample_children[1]  # Nu, sinh 20/08/2021
    client = TestClient(app)
    resp = _post_import(client, [
        [_display_name(c2), "20/08/2021", "Nữ", "20/10/2026", 100, 12, ""],
    ])

    assert resp.status_code == 200
    body = resp.json()
    assert body["success_count"] == 1

    saved = mock_db.add.call_args_list[0].args[0]
    assert saved.health_category == HealthCategory.UNDERWEIGHT

    app.dependency_overrides.clear()


def test_import_unknown_child_name_rejected(mock_db, admin_user, sample_classroom, sample_children):
    """Ten + biet danh khong khop ho so -> LOI CHAN (khong luu)."""
    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: admin_user
    _mock_import_db(mock_db, sample_classroom, sample_children)

    client = TestClient(app)
    resp = _post_import(client, [
        ["Nguyen Van X (Nho)", "01/01/2020", "Nữ", "20/10/2026", 95, 14, ""],
    ])

    assert resp.status_code == 200
    body = resp.json()
    assert body["success_count"] == 0
    assert body["failed_count"] == 1
    assert any("Không tìm thấy học sinh" in m for m in body["errors"][0]["errors"])

    app.dependency_overrides.clear()


def test_import_profile_mismatch_warns_but_saves(mock_db, admin_user, sample_classroom, sample_children):
    """Ngay sinh/gioi tinh lech ho so -> CANH BAO nhung VAN LUU theo ten + biet danh."""
    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: admin_user
    _mock_import_db(mock_db, sample_classroom, sample_children)

    c1 = sample_children[0]  # Nam, sinh 10/05/2021
    client = TestClient(app)
    resp = _post_import(client, [
        [_display_name(c1), "01/01/2020", "Nữ", "20/10/2026", 95, 14, ""],
    ])

    assert resp.status_code == 200
    body = resp.json()
    assert body["success_count"] == 1
    # Co canh bao cho ca ngay sinh, gioi tinh
    warns = " ".join(body["errors"][0]["warnings"])
    assert "Ngày sinh" in warns
    assert "Giới tính" in warns

    app.dependency_overrides.clear()


def test_import_height_outlier_warns(mock_db, admin_user, sample_classroom, sample_children):
    """Chieu cao 60cm o 5 tuoi -> CANH BAO nhung VAN LUU."""
    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: admin_user
    _mock_import_db(mock_db, sample_classroom, sample_children)

    c1 = sample_children[0]
    client = TestClient(app)
    resp = _post_import(client, [
        [_display_name(c1), "10/05/2021", "Nam", "20/10/2026", 60, 14, ""],
    ])

    assert resp.status_code == 200
    body = resp.json()
    assert body["success_count"] == 1
    warns = " ".join(body["errors"][0]["warnings"])
    assert "Chiều cao" in warns and "thấp" in warns

    app.dependency_overrides.clear()


def test_import_wrong_structure_rejected(mock_db, admin_user):
    """File sai cau truc (thieu cot Ma HS/Chieu cao/Can nang) -> 400."""
    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: admin_user
    mock_db.scalar.return_value = MagicMock()

    wb = openpyxl.Workbook()
    ws = wb.active
    ws.append(["Ten", "Tuoi", "Ghi chu"])
    ws.append(["An", 5, "khoe"])
    buf = BytesIO()
    wb.save(buf)

    client = TestClient(app)
    resp = client.post(
        "/api/health-exam/import",
        data={"class_id": str(OWN_CLASS_ID)},
        files={"file": ("sai.xlsx", buf.getvalue(), "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")},
    )

    assert resp.status_code == 400
    assert "cấu trúc" in resp.json()["detail"]

    app.dependency_overrides.clear()


def test_import_duplicate_different_date_formats(mock_db, admin_user, sample_classroom, sample_children):
    """Trung ma HS voi 2 dinh dang ngay khac nhau -> van bat trung."""
    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: admin_user
    _mock_import_db(mock_db, sample_classroom, sample_children)

    c1 = sample_children[0]
    client = TestClient(app)
    resp = _post_import(client, [
        [_display_name(c1), "10/05/2021", "Nam", "20/10/2026", 95, 14, ""],
        [_display_name(c1), "10/05/2021", "Nam", "2026-10-20", 96, 15, ""],
    ])

    assert resp.status_code == 200
    body = resp.json()
    assert body["success_count"] == 0
    assert body["failed_count"] == 2

    app.dependency_overrides.clear()


def test_import_zero_height_rejected(mock_db, admin_user, sample_classroom, sample_children):
    """Chieu cao = 0 -> LOI ro rang (khong phai 'ngoai khoang')."""
    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: admin_user
    _mock_import_db(mock_db, sample_classroom, sample_children)

    c1 = sample_children[0]
    client = TestClient(app)
    resp = _post_import(client, [
        [_display_name(c1), "10/05/2021", "Nam", "20/10/2026", 0, 14, ""],
    ])

    assert resp.status_code == 200
    body = resp.json()
    assert body["failed_count"] == 1
    assert any("lớn hơn 0" in m for m in body["errors"][0]["errors"])

    app.dependency_overrides.clear()


# ===========================================================================
# PUT/POST /api/health-exam/records — sua & tao so lieu suc khoe
# ===========================================================================

def test_update_record_recalculates_bmi(mock_db, admin_user, sample_children):
    """Sua chieu cao/can nang -> server tu tinh lai BMI va xep loai theo WHO."""
    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: admin_user

    c1 = sample_children[0]
    rec = _build_exam_record(c1, None)

    def mock_scalar(statement):
        text = str(statement)
        if "FROM health_examinations" in text:
            return rec
        if "FROM child" in text:
            return c1
        return None

    mock_db.scalar.side_effect = mock_scalar

    client = TestClient(app)
    resp = client.put(
        f"/api/health-exam/records/{rec.examination_id}",
        json={"height": 100, "weight": 16, "general_conclusion": "Bé khỏe"},
    )

    assert resp.status_code == 200
    body = resp.json()
    # BMI = 16 / 1.0^2 = 16.0
    assert abs(body["bmi"] - 16.0) < 0.01
    assert body["height"] == 100.0
    assert body["weight"] == 16.0
    assert body["general_conclusion"] == "Bé khỏe"
    assert body["has_record"] is True
    mock_db.commit.assert_called_once()

    app.dependency_overrides.clear()


def test_update_record_not_found(mock_db, admin_user):
    """Sua ban ghi khong ton tai -> 404."""
    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: admin_user
    mock_db.scalar.return_value = None

    client = TestClient(app)
    resp = client.put(
        f"/api/health-exam/records/{uuid.uuid4()}",
        json={"height": 100, "weight": 16},
    )

    assert resp.status_code == 404
    app.dependency_overrides.clear()


def test_update_record_invalid_height(mock_db, admin_user):
    """Chieu cao <= 0 -> 422 (validate schema)."""
    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: admin_user

    client = TestClient(app)
    resp = client.put(
        f"/api/health-exam/records/{uuid.uuid4()}",
        json={"height": 0, "weight": 16},
    )

    assert resp.status_code == 422
    app.dependency_overrides.clear()


def test_create_record_for_child_without_data(mock_db, admin_user, sample_children):
    """Tao moi ban ghi cho be chua co so lieu -> tao record va tu tinh BMI."""
    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: admin_user

    c1 = sample_children[0]

    def mock_scalar(statement):
        text = str(statement)
        if "FROM child" in text:
            return c1
        return None

    mock_db.scalar.side_effect = mock_scalar

    client = TestClient(app)
    resp = client.post(
        "/api/health-exam/records",
        json={
            "child_id": str(c1.child_id),
            "height": 95,
            "weight": 14,
            "general_conclusion": "Bé khỏe",
        },
    )

    assert resp.status_code == 201
    body = resp.json()
    assert abs(body["bmi"] - 15.51) < 0.01
    assert body["full_name"] == c1.full_name
    assert body["has_record"] is True
    assert mock_db.add.called

    app.dependency_overrides.clear()


def test_create_record_child_not_found(mock_db, admin_user):
    """Hoc sinh khong ton tai -> 404."""
    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_current_user] = lambda: admin_user
    mock_db.scalar.return_value = None

    client = TestClient(app)
    resp = client.post(
        "/api/health-exam/records",
        json={"child_id": str(uuid.uuid4()), "height": 95, "weight": 14},
    )

    assert resp.status_code == 404
    app.dependency_overrides.clear()
