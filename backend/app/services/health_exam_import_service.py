"""
app/services/health_exam_import_service.py
===========================================
Nhập kết quả vào sổ sức khoẻ từ file Excel (.xlsx) do school admin tải lên:
- Đọc đúng cấu trúc 7 cột của file mẫu do GET /api/health-exam/template sinh ra
  (A: Họ và tên — dạng "Nguyễn Văn Ánh (Nhỏ)", B: Ngày sinh, C: Giới tính,
   D: Ngày ghi nhận, E: Chiều cao, F: Cân nặng, G: Kết luận chung).
- KHÔNG dùng mã học sinh trong file: học sinh được đối chiếu bằng Họ tên + Biệt danh.
- Validate từng dòng theo 2 mức:
  + LỖI CHẶN (không lưu dòng): không tìm thấy học sinh theo tên/biệt danh,
    HS không thuộc lớp/đã nghỉ, ngày ghi nhận sai/tương lai/trước ngày sinh,
    trùng HS trong file, thiếu/sai số liệu chiều cao-cân nặng,
    file sai cấu trúc/quá nhiều dòng.
  + CẢNH BÁO (vẫn lưu): ngày sinh/giới tính trong file lệch hồ sơ
    (tên + biệt danh là khoá đối chiếu), chiều cao bất thường so với tuổi,
    hồ sơ thiếu ngày sinh/giới tính.
- Tự tính BMI và xếp loại thể trạng theo ngưỡng WHO BMI-for-age theo nhóm tuổi
  (xem who_growth.py; fallback ngưỡng chung khi thiếu ngày sinh/giới tính).
- Upsert theo cặp (child_id, examination_date): tạo mới hoặc cập nhật bản ghi đã có,
  để nhập lại cùng một file không sinh bản ghi trùng.
- Trả báo cáo lỗi từng dòng (số dòng Excel + lý do) để người dùng sửa lại trong file.
"""

from __future__ import annotations

import logging
import re
import unicodedata
from dataclasses import dataclass, field
from datetime import date, datetime
from io import BytesIO

import openpyxl
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.child import Child, ChildStatus
from app.models.health_examination import HealthExamination, HealthCategory
from app.models.user import Class_, User
from app.services.who_growth import age_in_months, classify_bmi_who

logger = logging.getLogger(__name__)

ALLOWED_EXAM_EXTENSIONS = {".xlsx", ".xlsm"}
MAX_EXAM_FILE_SIZE_BYTES = 10 * 1024 * 1024  # 10 MB

# Gioi han so dong du lieu trong 1 file de tranh file qua lon gay cham.
MAX_EXAM_ROWS = 2000

# Ngay ghi nhan khong duoc xa qua trong qua khu (tranh nham nam).
MAX_EXAM_DATE_AGE_DAYS = 730  # ~2 nam

# Ngưỡng hợp lệ cho số liệu trẻ mầm non (bắt "số vô lý" như cân nặng 150kg).
HEIGHT_MIN_CM = 30.0
HEIGHT_MAX_CM = 200.0
WEIGHT_MIN_KG = 2.0
WEIGHT_MAX_KG = 100.0

# Nhãn tiếng Việt của phân loại thể trạng (dùng cho endpoint /records).
CATEGORY_VI_LABEL: dict[HealthCategory, str] = {
    HealthCategory.NORMAL: "Bình thường",
    HealthCategory.UNDERWEIGHT: "Suy dinh dưỡng",
    HealthCategory.OVERWEIGHT: "Thừa cân",
}


class HealthExamFileError(ValueError):
    """File tải lên không đọc được (hỏng, sai định dạng, rỗng)."""


@dataclass
class HealthExamRowIssue:
    """Lỗi/cảnh báo của một dòng trong file Excel."""

    row_number: int
    child_id: str | None = None
    full_name: str | None = None
    sheet_name: str | None = None
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)


@dataclass
class HealthExamImportResult:
    """Kết quả tổng hợp sau khi nhập file."""

    total_rows: int = 0
    success_count: int = 0
    failed_count: int = 0
    created_count: int = 0
    updated_count: int = 0
    issues: list[HealthExamRowIssue] = field(default_factory=list)


def parse_float_cell(value: object) -> float | None:
    """Đọc số từ ô Excel, chịu được chuỗi kiểu Việt Nam ('15,5', ' 72 ')."""
    if value is None:
        return None
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    text = str(value).strip().replace(" ", "").replace(",", ".")
    if not text:
        return None
    try:
        return float(text)
    except ValueError:
        return None


def parse_date_cell(value: object) -> date | None:
    """Đọc ngày từ ô Excel (datetime có sẵn, 'DD/MM/YYYY', 'YYYY-MM-DD')."""
    if value is None:
        return None
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, date):
        return value
    text = str(value).strip()
    if not text:
        return None
    for fmt in ("%d/%m/%Y", "%d-%m-%Y", "%d.%m.%Y", "%Y-%m-%d", "%Y/%m/%d"):
        try:
            return datetime.strptime(text, fmt).date()
        except ValueError:
            continue
    return None


def calc_bmi(height_cm: float, weight_kg: float) -> float:
    """Tính BMI = cân nặng (kg) / (chiều cao (m))^2, làm tròn 2 chữ số."""
    height_m = height_cm / 100.0
    return round(weight_kg / (height_m * height_m), 2)


def _duplicate_key(values: list[object]) -> tuple[str, str] | None:
    """Khoa nhoan trung dong trong file: (ten HS chuan hoa, ngay ISO).

    Ngay rong -> dung chuoi rong de moi dong co ngay khac nhau van la duy nhat.
    """
    cols = list(values) + [None] * (7 - len(values))
    name_key = normalize_name_key(cols[0])
    if not name_key:
        return None
    exam_date = parse_date_cell(cols[3])
    date_key = exam_date.isoformat() if exam_date is not None else ""
    return (name_key, date_key)


def normalize_name_key(value: object) -> str:
    """Chuan hoa chuoi ten de so sanh: bo dau, lowercase, gom khoang trang."""
    if value is None:
        return ""
    text = unicodedata.normalize("NFD", str(value).strip().lower())
    text = "".join(ch for ch in text if unicodedata.category(ch) != "Mn")
    text = text.replace("đ", "d").replace("Đ", "d")
    text = re.sub(r"[^a-z0-9]+", " ", text)
    return " ".join(text.split())


def split_display_name(value: object) -> tuple[str, str | None]:
    """Tach chuoi 'Nguyen Van Anh (Nho)' thanh (ho ten, biet danh).

    Neu khong co phan trong ngoac -> biet danh = None.
    """
    text = str(value or "").strip()
    if not text:
        return "", None
    match = re.match(r"^(.*?)\s*\(([^()]*)\)\s*$", text)
    if not match:
        return text, None
    full_name = match.group(1).strip()
    nickname = match.group(2).strip()
    if not full_name or not nickname:
        return text, None
    return full_name, nickname


def normalize_gender_cell(value: object) -> str | None:
    """Chuan hoa o gioi tinh trong file ve 'male' | 'female' | 'other' | None."""
    if value is None:
        return None
    text = " ".join(str(value).strip().lower().split())
    if not text:
        return None
    if text in ("nam", "male", "m", "boy", "trai", "be trai", "bé trai"):
        return "male"
    if text in ("nu", "nữ", "female", "f", "girl", "gai", "gái", "be gai", "bé gái"):
        return "female"
    if text in ("other", "khac", "khác"):
        return "other"
    return None


def read_exam_workbook(file_bytes: bytes) -> list[tuple[str | None, int, list[object]]]:
    """Đọc toàn bộ sheet của file Excel, trả về [(tên sheet, số dòng, [giá trị 7 cột])].

    Mỗi sheet xử lý giống nhau: dòng 1 là tiêu đề (bỏ qua). Các dòng trống
    được bỏ qua. File mẫu tải tất cả lớp có mỗi lớp 1 sheet nên cần đọc hết,
    không chỉ sheet đầu.
    """
    try:
        wb = openpyxl.load_workbook(BytesIO(file_bytes), data_only=True, read_only=True)
    except Exception as exc:
        raise HealthExamFileError("Không đọc được file Excel. Vui lòng tải lên đúng file .xlsx.") from exc

    if not wb.sheetnames:
        raise HealthExamFileError("File Excel không có sheet dữ liệu.")

    data_rows: list[tuple[str | None, int, list[object]]] = []
    skipped_blank = 0
    for ws in wb.worksheets:
        sheet_name = ws.title if len(wb.sheetnames) > 1 else None
        all_rows = list(ws.iter_rows(min_row=1, max_col=7, values_only=True))
        if not all_rows:
            continue

        _validate_header_row(all_rows[0])
        start_idx = 1

        for idx in range(start_idx, len(all_rows)):
            values = list(all_rows[idx])
            if all(v is None or str(v).strip() == "" for v in values):
                skipped_blank += 1
                continue
            data_rows.append((sheet_name, idx + 1, values))

    if not data_rows:
        raise HealthExamFileError(
            "File Excel không có dòng dữ liệu nào (ngoài tiêu đề). "
            "Vui lòng điền số liệu vào file mẫu rồi tải lên lại."
        )
    if len(data_rows) > MAX_EXAM_ROWS:
        raise HealthExamFileError(
            f"File có {len(data_rows)} dòng dữ liệu, vượt quá giới hạn "
            f"{MAX_EXAM_ROWS} dòng/file. Vui lòng chia nhỏ file rồi nhập từng phần."
        )
    if skipped_blank > 0:
        logger.info("Bo qua %s dong trong trong file Excel.", skipped_blank)
    return data_rows


def _validate_header_row(header: tuple[object, ...]) -> None:
    """Kiem tra dong tieu de co dung cau truc file mau khong.

    File mau co 7 cot: Ho va ten / Ngay sinh / Gioi tinh / Ngay ghi nhan /
    Chieu cao / Can nang / Ket luan chung.

    Neu dong 1 khong giong mot tieu de (vi du nguoi dung xoa tieu de roi
    nhung chua nhap du lieu) thi bao loi de tai lai file mau.
    """
    cells = [(str(c).strip().lower() if c is not None else "") for c in list(header)]
    if not any(cells):
        return

    # Neu co it nhat mot cot dinh danh/doi luong thi co the la tieu de that.
    has_name = any("họ và tên" in c or "ho va ten" in c or "họ tên" in c for c in cells)
    has_height = any("chiều cao" in c or "chieu cao" in c for c in cells)
    has_weight = any("cân nặng" in c or "can nang" in c for c in cells)
    if has_name or has_height or has_weight:
        # Co tieu de nhung thieu cot bat buoc -> bao loi.
        missing = []
        if not has_name:
            missing.append("Họ và tên")
        if not has_height:
            missing.append("Chiều cao")
        if not has_weight:
            missing.append("Cân nặng")
        if missing:
            raise HealthExamFileError(
                "File không đúng cấu trúc file mẫu (thiếu cột "
                + ", ".join(missing)
                + "). Vui lòng tải file mẫu mới nhất rồi nhập lại."
            )
        return

    # Khong co cot nao giong tieu duoc biet -> dong 1 co the la du lieu.
    raise HealthExamFileError(
        "File không đúng cấu trúc file mẫu. Vui lòng giữ nguyên dòng tiêu đề "
        "(Họ và tên, Ngày sinh, Giới tính, Ngày ghi nhận, "
        "Chiều cao, Cân nặng, Kết luận chung) "
        "hoặc tải file mẫu mới nhất rồi nhập lại."
    )


def import_health_exam_file(
    db: Session,
    classroom: Class_ | None,
    file_bytes: bytes,
    actor: User,
) -> HealthExamImportResult:
    """Validate + lưu toàn bộ dòng hợp lệ, gom báo cáo lỗi từng dòng.

    Đọc toàn bộ sheet trong file (mỗi sheet là một lớp trong file mẫu tải tất cả).
    Học sinh được tra theo Họ tên + Biệt danh nên file nhiều sheet vẫn nhập
    đúng lớp của từng bé. `classroom=None` nghĩa là nhập toàn trường.
    Các dòng hợp lệ được lưu trong một commit duy nhất; dòng lỗi không chặn dòng đúng.
    """
    rows = read_exam_workbook(file_bytes)
    result = HealthExamImportResult(total_rows=len(rows))
    if not rows:
        return result

    children = db.scalars(select(Child)).all()
    if classroom is not None:
        children = [c for c in children if c.class_id == classroom.class_id]
    class_name = classroom.name if classroom is not None else "toàn trường"

    # Index tra cứu học sinh theo (họ tên, biệt danh) và theo họ tên đơn thuần.
    children_by_name: dict[tuple[str, str], list[Child]] = {}
    children_by_full_name: dict[str, list[Child]] = {}
    for c in children:
        full_key = normalize_name_key(c.full_name)
        nick_key = normalize_name_key(c.nickname) if c.nickname else ""
        children_by_full_name.setdefault(full_key, []).append(c)
        children_by_name.setdefault((full_key, nick_key), []).append(c)

    child_ids = [str(c.child_id) for c in children]
    existing: dict[tuple[str, date], HealthExamination] = {}
    if child_ids:
        records = db.scalars(
            select(HealthExamination).where(HealthExamination.child_id.in_(child_ids))
        ).all()
        for rec in records:
            existing[(str(rec.child_id), rec.examination_date)] = rec

    pending: dict[tuple[str, date], HealthExamination] = {}

    # Phat hien trung HS + cung ngay trong 1 file TRUOC khi luu:
    # gom nhom theo (ten HS chuan hoa, ngay da chuan hoa) de bao loi ca 2 dong.
    # Ngay duoc chuan hoa ve ISO de "20/10/2026" va "2026-10-20" la trung nhau.
    seen_in_file: dict[tuple[str, str], list[tuple[str | None, int]]] = {}
    for sheet_name, row_number, values in rows:
        key = _duplicate_key(values)
        if key is not None:
            seen_in_file.setdefault(key, []).append((sheet_name, row_number))
    dup_keys = {k: v for k, v in seen_in_file.items() if len(v) > 1}

    try:
        for sheet_name, row_number, values in rows:
            issue = HealthExamRowIssue(row_number=row_number, sheet_name=sheet_name)
            record = _build_record(
                db=db,
                scope_name=class_name,
                children_by_name=children_by_name,
                children_by_full_name=children_by_full_name,
                existing=existing,
                pending=pending,
                dup_keys=dup_keys,
                values=values,
                actor=actor,
                issue=issue,
            )
            if issue.errors:
                result.failed_count += 1
                result.issues.append(issue)
                if issue.warnings:
                    logger.info("Dòng %s có cảnh báo: %s", row_number, issue.warnings)
                continue
            key = (str(record.child_id), record.examination_date)
            if key in existing or key in pending:
                target = pending.get(key, existing.get(key))
                assert target is not None
                target.height = record.height
                target.weight = record.weight
                target.bmi = record.bmi
                target.health_category = record.health_category
                target.general_conclusion = record.general_conclusion
                target.created_by_user_id = record.created_by_user_id
                pending[key] = target
                result.updated_count += 1
            else:
                db.add(record)
                pending[key] = record
                result.created_count += 1
            result.success_count += 1
            if issue.warnings:
                result.issues.append(issue)
        db.commit()
    except Exception:
        db.rollback()
        raise
    return result


def _build_record(
    db: Session,
    scope_name: str,
    children_by_name: dict[tuple[str, str], list[Child]],
    children_by_full_name: dict[str, list[Child]],
    existing: dict[tuple[str, date], HealthExamination],
    pending: dict[tuple[str, date], HealthExamination],
    dup_keys: dict[tuple[str, str], list[tuple[str | None, int]]],
    values: list[object],
    actor: User,
    issue: HealthExamRowIssue,
) -> HealthExamination | None:
    """Validate một dòng Excel và dựng entity; lỗi ghi vào issue, trả None khi lỗi chặn.

    Quy tac dinh danh:
    - Cot A (Ho va ten) chua "Ho ten (Biet danh)" la khoa doi chieu duy nhat.
    - Cot B/C (Ngay sinh, Gioi tinh) chi de doi chieu — lech thi canh bao,
      van luu theo ho so (khong chan de tranh ket ca lop vi 1 loi danh may).
    """
    cols = list(values) + [None] * (7 - len(values))
    name_text = str(cols[0]).strip() if cols[0] is not None else ""
    dob_text = str(cols[1]).strip() if cols[1] is not None else ""
    gender_text_raw = cols[2]
    issue.full_name = name_text or None

    # --- 1. Đối chiếu học sinh theo Họ tên + Biệt danh ---
    file_full_name, file_nickname = split_display_name(name_text)
    if not file_full_name:
        issue.errors.append("Thiếu họ và tên học sinh (cột A). Hãy tải lại file mẫu mới nhất.")
        return None

    file_name_key = normalize_name_key(file_full_name)
    file_nick_key = normalize_name_key(file_nickname) if file_nickname else ""
    same_name_children = list(children_by_full_name.get(file_name_key, []))
    candidates: list[Child] = []
    if file_nick_key:
        candidates = list(children_by_name.get((file_name_key, file_nick_key), []))
        if not candidates and same_name_children:
            # Có bé trùng họ tên nhưng biệt danh không khớp → báo lỗi cho rõ.
            have_nicks = ", ".join(
                f"({c.nickname})" for c in same_name_children if c.nickname
            ) or "(không có biệt danh)"
            issue.errors.append(
                f"Biệt danh '{file_nickname}' không khớp với hồ sơ của '{file_full_name}' "
                f"{have_nicks}. Vui lòng dùng đúng biệt danh như trong file mẫu."
            )
            return None
    if not candidates:
        # Không có biệt danh khớp → thử theo họ tên đơn thuần.
        candidates = same_name_children

    if not candidates:
        issue.errors.append(
            f"Không tìm thấy học sinh '{name_text}' trong {scope_name}. "
            "Vui lòng dùng đúng họ tên và biệt danh như trong file mẫu."
        )
        return None
    if len(candidates) > 1:
        issue.errors.append(
            f"Có nhiều học sinh trùng họ tên '{file_full_name}'"
            + (f" và biệt danh '{file_nickname}'" if file_nickname else "")
            + f" trong {scope_name}. Vui lòng kiểm tra lại hồ sơ."
        )
        return None

    child = candidates[0]
    issue.child_id = str(child.child_id)
    if child.status != ChildStatus.ENROLLED:
        issue.errors.append(f"Học sinh '{child.full_name}' hiện không còn theo học tại lớp.")
        return None

    # --- 2. Đối chiếu cột hồ sơ B/C với hồ sơ (lệch → cảnh báo, vẫn lưu) ---
    if dob_text:
        file_dob = parse_date_cell(cols[1])
        if file_dob is None:
            issue.warnings.append(
                f"Ngày sinh trong file ('{dob_text}') không đúng định dạng, bỏ qua."
            )
        elif child.date_of_birth and file_dob != child.date_of_birth:
            issue.warnings.append(
                f"Ngày sinh trong file ({file_dob.strftime('%d/%m/%Y')}) khác với hồ sơ "
                f"({child.date_of_birth.strftime('%d/%m/%Y')}), vẫn lưu theo hồ sơ."
            )
    file_gender = normalize_gender_cell(gender_text_raw)
    if gender_text_raw is not None and str(gender_text_raw).strip() != "":
        if file_gender is None:
            issue.warnings.append(
                f"Giới tính trong file ('{gender_text_raw}') không nhận diện được, bỏ qua."
            )
        elif child.gender and file_gender != child.gender.lower():
            gender_vi = {"male": "Nam", "female": "Nữ"}.get(child.gender.lower(), child.gender)
            issue.warnings.append(
                f"Giới tính trong file ('{gender_text_raw}') khác với hồ sơ ({gender_vi}), "
                "vẫn lưu theo hồ sơ."
            )

    # --- 3. Ngày ghi nhận (trống thì lấy hôm nay) ---
    exam_date = parse_date_cell(cols[3])
    if cols[3] is not None and str(cols[3]).strip() != "" and exam_date is None:
        issue.errors.append(f"Ngày ghi nhận '{cols[3]}' không đúng định dạng (dùng DD/MM/YYYY).")
        return None
    if exam_date is None:
        exam_date = date.today()
    if exam_date > date.today():
        issue.errors.append("Ngày ghi nhận không thể là ngày trong tương lai.")
        return None
    if child.date_of_birth and exam_date < child.date_of_birth:
        issue.errors.append(
            f"Ngày ghi nhận ({exam_date.strftime('%d/%m/%Y')}) trước ngày sinh của bé "
            f"({child.date_of_birth.strftime('%d/%m/%Y')}). Vui lòng kiểm tra lại."
        )
        return None
    age_days = (date.today() - exam_date).days
    if age_days > MAX_EXAM_DATE_AGE_DAYS:
        issue.warnings.append(
            f"Ngày ghi nhận ({exam_date.strftime('%d/%m/%Y')}) cách đây hơn 2 năm, "
            "vui lòng kiểm tra có nhầm năm không."
        )

    # --- 4. Trung ma HS + cung ngay trong 1 file (chan de tranh ghi de im lang) ---
    dup_group = dup_keys.get(_duplicate_key(values) or ("", ""))
    if dup_group:
        others = ", ".join(
            f"dòng {n}" + (f" (sheet {s})" if s else "")
            for s, n in dup_group if n != issue.row_number or s != issue.sheet_name
        )
        issue.errors.append(
            f"Học sinh '{child.full_name}' bị trùng trong file ({others} cùng ngày ghi nhận). "
            "Vui lòng gộp thành 1 dòng rồi nhập lại."
        )
        return None

    # --- 5. Chiều cao ---
    height = parse_float_cell(cols[4])
    if cols[4] is None or str(cols[4]).strip() == "":
        issue.errors.append("Thiếu chiều cao (cột E).")
        return None
    if height is None:
        issue.errors.append(f"Chiều cao '{cols[4]}' không phải là số.")
        return None
    if height <= 0:
        issue.errors.append(f"Chiều cao phải lớn hơn 0 (nhận được {cols[4]}).")
        return None
    if not (HEIGHT_MIN_CM <= height <= HEIGHT_MAX_CM):
        issue.errors.append(
            f"Chiều cao {height:g} cm không hợp lý (cho phép {HEIGHT_MIN_CM:g}–{HEIGHT_MAX_CM:g} cm)."
        )
        return None

    # --- 6. Cân nặng ---
    weight = parse_float_cell(cols[5])
    if cols[5] is None or str(cols[5]).strip() == "":
        issue.errors.append("Thiếu cân nặng (cột F).")
        return None
    if weight is None:
        issue.errors.append(f"Cân nặng '{cols[5]}' không phải là số.")
        return None
    if weight <= 0:
        issue.errors.append(f"Cân nặng phải lớn hơn 0 (nhận được {cols[5]}).")
        return None
    if not (WEIGHT_MIN_KG <= weight <= WEIGHT_MAX_KG):
        issue.errors.append(
            f"Cân nặng {weight:g} kg không hợp lý (cho phép {WEIGHT_MIN_KG:g}–{WEIGHT_MAX_KG:g} kg)."
        )
        return None

    # --- 7. BMI + phân loại (luôn tự tính phía server, xếp loại theo WHO) ---
    # File nhập không còn cột BMI/phân loại — người nhập chỉ điền số đo,
    # hệ thống tự tính BMI và xếp loại theo tuổi + giới tính của bé.
    bmi = calc_bmi(height, weight)
    health_category = classify_bmi_who(
        bmi,
        birth_date=child.date_of_birth,
        exam_date=exam_date,
        gender=child.gender,
    )
    if child.date_of_birth is None or not child.gender:
        issue.warnings.append(
            "Hồ sơ thiếu ngày sinh hoặc giới tính nên hệ thống xếp loại theo ngưỡng "
            "chung. Vui lòng bổ sung hồ sơ để đánh giá chính xác hơn."
        )

    # Canh bao neu chiều cao bất thường so với tuoi (co the do nhap sai don vi).
    if child.date_of_birth:
        months_old = age_in_months(child.date_of_birth, exam_date)
        if height < 70 and months_old >= 24:
            issue.warnings.append(
                f"Chiều cao {height:g} cm rất thấp so với {months_old} tháng tuổi. "
                "Vui lòng kiểm tra có nhầm đơn vị không."
            )
        elif height > 140 and months_old <= 36:
            issue.warnings.append(
                f"Chiều cao {height:g} cm rất cao so với {months_old} tháng tuổi. "
                "Vui lòng kiểm tra có nhầm đơn vị không."
            )

    conclusion = str(cols[6]).strip() if cols[6] is not None else ""
    if len(conclusion) > 2000:
        issue.errors.append("Kết luận chung quá dài (tối đa 2000 ký tự).")
        return None

    return HealthExamination(
        child_id=child.child_id,
        examination_date=exam_date,
        height=height,
        weight=weight,
        bmi=bmi,
        health_category=health_category,
        general_conclusion=conclusion or None,
        created_by_user_id=actor.user_id,
    )
