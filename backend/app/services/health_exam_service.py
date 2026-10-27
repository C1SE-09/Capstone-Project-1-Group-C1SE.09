"""
app/services/health_exam_service.py
====================================
Dịch vụ tạo file Excel (.xlsx) mẫu khám sức khỏe định kỳ cho học sinh trong lớp:
- Điền sẵn thông tin định danh học sinh (Mã học sinh, Họ và tên, Ngày sinh, Giới tính).
- Khóa bảo vệ (Lock / Sheet Protection) các cột định danh để tránh sửa đổi hoặc xóa nhầm.
- Mở khóa (Unlock) các cột nhập kết quả khám (Ngày khám, Chiều cao, Cân nặng, BMI, Thể trạng, Kết luận).
"""

from __future__ import annotations

import re
from datetime import date
from io import BytesIO
from typing import TYPE_CHECKING, Optional

import openpyxl
from openpyxl.styles import Alignment, Border, Font, PatternFill, Protection, Side
from openpyxl.worksheet.datavalidation import DataValidation

if TYPE_CHECKING:
    from app.models.child import Child
    from app.models.user import Class_


def sanitize_sheet_title(name: str) -> str:
    """Loại bỏ ký tự cấm trong tên sheet Excel và giới hạn tối đa 31 ký tự."""
    clean = re.sub(r"[\\/?*\[\]:]", "-", name).strip()
    return clean[:31] or "HealthExam"


def generate_health_exam_template(
    classroom: Class_,
    children: list[Child],
    default_date: Optional[date] = None,
) -> bytes:
    """Tạo file Excel (.xlsx) mẫu điền sẵn danh sách học sinh của lớp.

    Các cột thông tin học sinh (A -> D) được khóa bảo vệ chống chỉnh sửa.
    Các cột nhập liệu kết quả khám (E -> J) được mở khóa để người dùng điền.
    """
    wb = openpyxl.Workbook()
    ws = wb.active

    sheet_title = sanitize_sheet_title(f"Kham_{classroom.name}")
    ws.title = sheet_title

    headers = [
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
    ws.append(headers)

    # Đặt chiều cao dòng tiêu đề
    ws.row_dimensions[1].height = 28

    # Style cho Header
    header_font = Font(name="Calibri", size=11, bold=True, color="FFFFFF")
    header_fill = PatternFill(start_color="1E3A8A", end_color="1E3A8A", fill_type="solid")  # Dark Blue
    thin_border_side = Side(border_style="thin", color="CBD5E1")
    header_border = Border(
        left=thin_border_side,
        right=thin_border_side,
        top=thin_border_side,
        bottom=thin_border_side,
    )
    center_align = Alignment(horizontal="center", vertical="center", wrap_text=True)

    for col_idx in range(1, len(headers) + 1):
        cell = ws.cell(row=1, column=col_idx)
        cell.font = header_font
        cell.fill = header_fill
        cell.alignment = center_align
        cell.border = header_border
        cell.protection = Protection(locked=True)

    # Style cho các dòng dữ liệu
    data_font = Font(name="Calibri", size=11, color="1E293B")
    locked_fill = PatternFill(start_color="F1F5F9", end_color="F1F5F9", fill_type="solid")  # Light gray
    unlocked_fill = PatternFill(start_color="FFFFFF", end_color="FFFFFF", fill_type="solid")  # White
    data_border = Border(
        left=thin_border_side,
        right=thin_border_side,
        top=thin_border_side,
        bottom=thin_border_side,
    )
    left_align = Alignment(horizontal="left", vertical="center")
    date_align = Alignment(horizontal="center", vertical="center")
    number_align = Alignment(horizontal="right", vertical="center")

    exam_date_str = (default_date or date.today()).strftime("%d/%m/%Y")

    # Xác định số dòng cần ghi
    num_rows = len(children)
    max_data_row = max(num_rows + 1, 10)  # Tạo ít nhất đến dòng 10 nếu lớp trống

    for i, child in enumerate(children, start=2):
        ws.row_dimensions[i].height = 22

        # Cột A: Mã học sinh (UUID) - Locked
        c_id = ws.cell(row=i, column=1, value=str(child.child_id))
        c_id.number_format = "@"
        c_id.alignment = left_align
        c_id.fill = locked_fill
        c_id.protection = Protection(locked=True)

        # Cột B: Họ và tên - Locked
        c_name = ws.cell(row=i, column=2, value=child.full_name)
        c_name.alignment = left_align
        c_name.fill = locked_fill
        c_name.protection = Protection(locked=True)

        # Cột C: Ngày sinh - Locked
        dob_str = child.date_of_birth.strftime("%d/%m/%Y") if child.date_of_birth else ""
        c_dob = ws.cell(row=i, column=3, value=dob_str)
        c_dob.alignment = date_align
        c_dob.fill = locked_fill
        c_dob.protection = Protection(locked=True)

        # Cột D: Giới tính - Locked
        gender_str = "Nam" if child.gender == "male" else ("Nữ" if child.gender == "female" else (child.gender or ""))
        c_gender = ws.cell(row=i, column=4, value=gender_str)
        c_gender.alignment = date_align
        c_gender.fill = locked_fill
        c_gender.protection = Protection(locked=True)

        # Cột E: Ngày khám - Unlocked (Mặc định ngày hôm nay/ngày truyền vào)
        c_exam_date = ws.cell(row=i, column=5, value=exam_date_str)
        c_exam_date.alignment = date_align
        c_exam_date.fill = unlocked_fill
        c_exam_date.protection = Protection(locked=False)

        # Cột F: Chiều cao (cm) - Unlocked
        c_height = ws.cell(row=i, column=6)
        c_height.number_format = "0.0"
        c_height.alignment = number_align
        c_height.fill = unlocked_fill
        c_height.protection = Protection(locked=False)

        # Cột G: Cân nặng (kg) - Unlocked
        c_weight = ws.cell(row=i, column=7)
        c_weight.number_format = "0.0"
        c_weight.alignment = number_align
        c_weight.fill = unlocked_fill
        c_weight.protection = Protection(locked=False)

        # Cột H: BMI - Công thức tự động tính khi có Chiều cao & Cân nặng (Unlocked để xem/sửa nếu cần)
        bmi_formula = f'=IF(AND(ISNUMBER(F{i}), ISNUMBER(G{i}), F{i}>0, G{i}>0), ROUND(G{i}/((F{i}/100)*(F{i}/100)), 2), "")'
        c_bmi = ws.cell(row=i, column=8, value=bmi_formula)
        c_bmi.number_format = "0.00"
        c_bmi.alignment = number_align
        c_bmi.fill = unlocked_fill
        c_bmi.protection = Protection(locked=False)

        # Cột I: Phân loại thể trạng - Unlocked
        c_cat = ws.cell(row=i, column=9)
        c_cat.alignment = center_align
        c_cat.fill = unlocked_fill
        c_cat.protection = Protection(locked=False)

        # Cột J: Kết luận chung - Unlocked
        c_notes = ws.cell(row=i, column=10)
        c_notes.alignment = left_align
        c_notes.fill = unlocked_fill
        c_notes.protection = Protection(locked=False)

        for col_idx in range(1, len(headers) + 1):
            cell = ws.cell(row=i, column=col_idx)
            cell.font = data_font
            cell.border = data_border

    # Thêm Dropdown Data Validation cho cột Phân loại thể trạng (Cột I)
    dv = DataValidation(
        type="list",
        formula1='"Bình thường,Suy dinh dưỡng,Thừa cân,Béo phì"',
        allow_blank=True,
    )
    dv.error = "Vui lòng chọn giá trị từ danh sách gợi ý"
    dv.errorTitle = "Giá trị không hợp lệ"
    ws.add_data_validation(dv)
    dv.add(f"I2:I{max_data_row}")

    # Thiết lập độ rộng cột tối ưu
    col_widths = {
        "A": 38,  # Mã học sinh
        "B": 26,  # Họ và tên
        "C": 15,  # Ngày sinh
        "D": 12,  # Giới tính
        "E": 15,  # Ngày khám
        "F": 16,  # Chiều cao (cm)
        "G": 16,  # Cân nặng (kg)
        "H": 12,  # BMI
        "I": 24,  # Phân loại thể trạng
        "J": 35,  # Kết luận chung
    }
    for col_letter, width in col_widths.items():
        ws.column_dimensions[col_letter].width = width

    # Bật AutoFilter cho tiêu đề
    ws.auto_filter.ref = f"A1:J{max(len(children) + 1, 2)}"

    # Kích hoạt Sheet Protection: Khóa các cột A-D, chỉ cho phép chỉnh sửa các ô Unlocked
    ws.protection.sheet = True
    ws.protection.enable()
    ws.protection.selectLockedCells = True
    ws.protection.selectUnlockedCells = True
    ws.protection.sort = True
    ws.protection.autoFilter = True

    output = BytesIO()
    wb.save(output)
    output.seek(0)
    return output.getvalue()
