"""
app/schemas/health_exam_schema.py
=================================
Pydantic schemas cho API Sổ sức khoẻ học sinh:
- Danh sách bản ghi đã ghi nhận (GET /api/health-exam/records) để hiển thị bảng dữ liệu.
- Báo cáo lỗi từng dòng (số dòng Excel + danh sách lỗi) để school admin sửa lại trước khi lưu.
"""

from __future__ import annotations

from datetime import date

from pydantic import BaseModel, Field


class HealthExamRecord(BaseModel):
    """Một dòng trong bảng sổ sức khoẻ — theo học sinh (có thể chưa có số liệu)."""

    id: str | None = Field(default=None, description="ID bản ghi (None = bé chưa có số liệu)")
    child_id: str = Field(..., description="Mã học sinh")
    full_name: str = Field(..., description="Họ tên học sinh")
    nickname: str | None = Field(default=None, description="Biệt danh học sinh")
    class_id: str | None = Field(default=None, description="ID lớp")
    class_name: str | None = Field(default=None, description="Tên lớp")
    date_of_birth: str | None = Field(default=None, description="Ngày sinh (DD/MM/YYYY)")
    gender: str | None = Field(default=None, description="Giới tính")
    examination_date: str | None = Field(default=None, description="Ngày ghi nhận (DD/MM/YYYY)")
    height: float | None = Field(default=None, description="Chiều cao (cm)")
    weight: float | None = Field(default=None, description="Cân nặng (kg)")
    bmi: float | None = Field(default=None, description="Chỉ số BMI")
    health_category: str | None = Field(default=None, description="Phân loại thể trạng (NORMAL/UNDERWEIGHT/OVERWEIGHT)")
    health_category_label: str | None = Field(default=None, description="Phân loại thể trạng tiếng Việt")
    general_conclusion: str | None = Field(default=None, description="Kết luận chung")
    created_by_name: str | None = Field(default=None, description="Người thực hiện ghi nhận")
    has_record: bool = Field(default=False, description="Bé đã có số liệu sức khoẻ hay chưa")


class HealthExamRecordsResponse(BaseModel):
    """Danh sách bản ghi sổ sức khoẻ kèm thống kê nhanh."""

    total: int = Field(..., description="Tổng số bản ghi")
    records: list[HealthExamRecord] = Field(default_factory=list, description="Các bản ghi chi tiết")
    stats: dict[str, int] = Field(
        default_factory=dict,
        description="Thống kê: normal / underweight / overweight",
    )


class HealthExamUpdate(BaseModel):
    """Payload sửa 1 bản ghi sức khoẻ (chỉ số đo + kết luận chung).

    Cho phép bỏ trống chiều cao hoặc cân nặng — chỉ cần có 1 trong 3 thông tin
    (chiều cao, cân nặng, kết luận chung). BMI + phân loại thể trạng chỉ được
    tính khi có đủ chiều cao và cân nặng.
    """

    height: float | None = Field(default=None, gt=0, le=200, description="Chiều cao (cm)")
    weight: float | None = Field(default=None, gt=0, le=100, description="Cân nặng (kg)")
    general_conclusion: str | None = Field(
        default=None,
        max_length=2000,
        description="Kết luận chung của đợt ghi nhận",
    )


class HealthExamCreate(HealthExamUpdate):
    """Payload tạo mới bản ghi sức khoẻ cho một học sinh."""

    child_id: str = Field(..., description="Mã học sinh")
    examination_date: date | None = Field(
        default=None,
        description="Ngày ghi nhận (mặc định hôm nay)",
    )


class HealthExamImportRowIssue(BaseModel):
    """Mô tả lỗi/cảnh báo của một dòng trong file Excel tải lên."""

    row_number: int = Field(..., description="Số dòng trong sheet Excel (dòng 1 là tiêu đề)")
    sheet_name: str | None = Field(default=None, description="Tên sheet chứa dòng lỗi (file nhiều sheet)")
    child_id: str | None = Field(default=None, description="Mã học sinh đã đối chiếu được (nếu có)")
    full_name: str | None = Field(default=None, description="Họ tên học sinh (nếu xác định được)")
    errors: list[str] = Field(default_factory=list, description="Các lỗi khiến dòng này không được lưu")
    warnings: list[str] = Field(default_factory=list, description="Cảnh báo không chặn việc lưu")


class HealthExamImportResponse(BaseModel):
    """Kết quả tổng hợp sau khi nhập file Excel vào sổ sức khoẻ."""

    total_rows: int = Field(..., description="Tổng số dòng dữ liệu trong file (không tính tiêu đề và dòng trống)")
    success_count: int = Field(..., description="Số dòng hợp lệ đã được lưu")
    failed_count: int = Field(..., description="Số dòng lỗi bị bỏ qua")
    created_count: int = Field(..., description="Số bản ghi sức khoẻ mới được tạo")
    updated_count: int = Field(..., description="Số bản ghi sức khoẻ đã tồn tại và được cập nhật")
    errors: list[HealthExamImportRowIssue] = Field(
        default_factory=list,
        description="Chi tiết lỗi từng dòng để người dùng sửa lại trong file",
    )
