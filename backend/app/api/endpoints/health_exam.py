"""
backend/app/api/endpoints/health_exam.py
========================================
API Sổ sức khoẻ học sinh (dành cho Admin trường trên admin-web):
- GET /api/health-exam/template: Xuất file Excel (.xlsx) mẫu điền sẵn danh sách học sinh của lớp, khóa các cột định danh.
- POST /api/health-exam/import: Nhập file Excel kết quả đo, validate từng dòng
  (thiếu số liệu, số vô lý như cân nặng 150kg), tự tính BMI + xếp loại thể trạng,
  lưu bản ghi và trả báo cáo lỗi theo từng dòng để sửa lại trong file.
"""

from __future__ import annotations

import logging
import re
import unicodedata
import urllib.parse
import uuid
from datetime import date
from pathlib import Path
from typing import Optional

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, Response, UploadFile, status
from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.core.database import get_db
from app.core.security import get_current_user
from app.models.child import Child, ChildStatus
from app.models.health_examination import HealthExamination
from app.models.user import Class_, User, UserRole
from app.schemas.health_exam_schema import (
    HealthExamImportResponse,
    HealthExamImportRowIssue,
    HealthExamRecord,
    HealthExamRecordsResponse,
)
from app.services.health_exam_import_service import (
    ALLOWED_EXAM_EXTENSIONS,
    CATEGORY_VI_LABEL,
    MAX_EXAM_FILE_SIZE_BYTES,
    HealthExamFileError,
    import_health_exam_file,
)
from app.services.health_exam_service import (
    generate_health_exam_template,
    generate_health_exam_templates_all,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/health-exam", tags=["health-exam"])


def verify_admin_access(current_user: User) -> None:
    """Kiểm tra phân quyền: Chỉ cho phép Quản trị viên (Admin) truy cập."""
    role_val = current_user.role.value if hasattr(current_user.role, "value") else str(current_user.role)
    if role_val != UserRole.ADMIN.value:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Chức năng này chỉ dành cho Quản trị viên (Admin)",
        )


def to_ascii_slug(text: str) -> str:
    """Chuyển chuỗi tiếng Việt có dấu sang ASCII không dấu an toàn cho HTTP Header."""
    normalized = unicodedata.normalize("NFD", text)
    ascii_text = "".join(c for c in normalized if unicodedata.category(c) != "Mn")
    ascii_text = ascii_text.replace("đ", "d").replace("Đ", "D")
    ascii_text = re.sub(r"[^a-zA-Z0-9_\-]", "_", ascii_text)
    return re.sub(r"_+", "_", ascii_text).strip("_")


@router.get(
    "/records",
    response_model=HealthExamRecordsResponse,
    summary="Danh sách bản ghi sổ sức khoẻ",
    description=(
        "Trả về các bản ghi đã ghi nhận trong sổ sức khoẻ (học sinh, lớp, ngày ghi nhận, "
        "chiều cao, cân nặng, BMI, phân loại thể trạng, kết luận chung) kèm thống kê nhanh. "
        "Có thể lọc theo class_id và ngày ghi nhận."
    ),
)
def list_health_exam_records(
    class_id: uuid.UUID | None = Query(None, description="Lọc theo lớp (bỏ trống = tất cả)"),
    examination_date: date | None = Query(None, description="Lọc theo ngày ghi nhận"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> HealthExamRecordsResponse:
    verify_admin_access(current_user=current_user)

    stmt = (
        select(HealthExamination, Child, Class_)
        .join(Child, HealthExamination.child_id == Child.child_id)
        .outerjoin(Class_, Child.class_id == Class_.class_id)
        .options(joinedload(HealthExamination.created_by_user))
    )
    if class_id is not None:
        stmt = stmt.where(Child.class_id == class_id)
    if examination_date is not None:
        stmt = stmt.where(HealthExamination.examination_date == examination_date)

    stmt = stmt.order_by(
        HealthExamination.examination_date.desc(),
        Child.full_name.asc(),
    )

    records: list[HealthExamRecord] = []
    stats = {"normal": 0, "underweight": 0, "overweight": 0}
    for exam, child, classroom in db.execute(stmt).all():
        category = exam.health_category
        category_key = category.value.lower() if hasattr(category, "value") else str(category).lower()
        if category_key in stats:
            stats[category_key] += 1

        records.append(
            HealthExamRecord(
                id=str(exam.examination_id),
                child_id=str(child.child_id),
                full_name=child.full_name,
                class_id=str(child.class_id) if child.class_id else None,
                class_name=classroom.name if classroom else None,
                date_of_birth=(
                    child.date_of_birth.strftime("%d/%m/%Y") if child.date_of_birth else None
                ),
                gender=child.gender,
                examination_date=exam.examination_date.strftime("%d/%m/%Y"),
                height=exam.height,
                weight=exam.weight,
                bmi=exam.bmi,
                health_category=category_key.upper(),
                health_category_label=CATEGORY_VI_LABEL.get(category, "Bình thường"),
                general_conclusion=exam.general_conclusion,
                created_by_name=(
                    exam.created_by_user.username
                    if exam.created_by_user_id and exam.created_by_user
                    else None
                ),
            )
        )

    return HealthExamRecordsResponse(total=len(records), records=records, stats=stats)


@router.get(
    "/template",
    summary="Tải file Excel mẫu sổ sức khoẻ",
    description=(
        "Xuất file Excel (.xlsx) mẫu sổ sức khoẻ điền sẵn danh sách học sinh "
        "(Mã học sinh, Họ và tên, Ngày sinh, Giới tính). "
        "Bỏ trống class_id để tải tất cả lớp (mỗi lớp 1 sheet). "
        "File format cơ bản, không khóa — tự do sửa, xóa hoặc thêm dòng trước khi tải lên."
    ),
)
def get_health_exam_template(
    class_id: uuid.UUID | None = Query(None, description="ID lớp cần tải mẫu (bỏ trống = tất cả lớp)"),
    examination_date: Optional[date] = Query(None, description="Ngày ghi nhận dự kiến (mặc định hôm nay)"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Response:
    verify_admin_access(current_user=current_user)

    date_str = (examination_date or date.today()).strftime("%Y%m%d")

    if class_id is None:
        # Tải tất cả lớp: mỗi lớp 1 sheet, format cơ bản như file mẫu học sinh.
        classrooms = db.scalars(
            select(Class_).where(Class_.is_active.is_(True)).order_by(Class_.name.asc())
        ).all()
        payload: list[tuple[Class_, list]] = []
        for classroom in classrooms:
            children = db.scalars(
                select(Child)
                .where(Child.class_id == classroom.class_id, Child.status == ChildStatus.ENROLLED)
                .order_by(Child.full_name.asc())
            ).all()
            payload.append((classroom, list(children)))
        content = generate_health_exam_templates_all(payload, default_date=examination_date)
        ascii_filename = f"Mau_So_Suc_Khoe_toan_truong_{date_str}.xlsx"
        utf8_filename = f"Mau_So_Suc_Khoe_toan_truong_{date_str}.xlsx"
        encoded_filename = urllib.parse.quote(utf8_filename)
        headers = {
            "Content-Disposition": f'attachment; filename="{ascii_filename}"; filename*=UTF-8\'\'{encoded_filename}',
            "Access-Control-Expose-Headers": "Content-Disposition",
        }
        return Response(
            content=content,
            media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            headers=headers,
        )

    classroom = db.scalar(select(Class_).where(Class_.class_id == class_id))
    if not classroom:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Không tìm thấy thông tin lớp học",
        )

    children = db.scalars(
        select(Child)
        .where(Child.class_id == class_id, Child.status == ChildStatus.ENROLLED)
        .order_by(Child.full_name.asc())
    ).all()

    content = generate_health_exam_template(
        classroom=classroom,
        children=list(children),
        default_date=examination_date,
    )

    date_str = (examination_date or date.today()).strftime("%Y%m%d")
    ascii_name = to_ascii_slug(classroom.name) or "lop"
    ascii_filename = f"Mau_So_Suc_Khoe_{ascii_name}_{date_str}.xlsx"
    utf8_filename = f"Mau_So_Suc_Khoe_{classroom.name.replace(' ', '_')}_{date_str}.xlsx"
    encoded_filename = urllib.parse.quote(utf8_filename)

    headers = {
        "Content-Disposition": f'attachment; filename="{ascii_filename}"; filename*=UTF-8\'\'{encoded_filename}',
        "Access-Control-Expose-Headers": "Content-Disposition",
    }

    return Response(
        content=content,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers=headers,
    )


@router.post(
    "/import",
    response_model=HealthExamImportResponse,
    status_code=status.HTTP_200_OK,
    summary="Nhập file Excel kết quả vào sổ sức khoẻ của lớp",
    description=(
        "School admin tải file Excel kết quả đo (đúng cấu trúc file mẫu của GET /template) "
        "để cập nhật số liệu cả lớp. Hệ thống validate từng dòng (thiếu mã học sinh, thiếu "
        "chiều cao/cân nặng, số vô lý như 150kg), tự tính BMI và xếp loại thể trạng, lưu các "
        "dòng hợp lệ, và trả báo cáo lỗi ghi rõ số dòng để sửa lại trong file trước khi nhập lại."
    ),
)
def import_health_exam(
    class_id: uuid.UUID | None = Form(None, description="ID lớp cần nhập (bỏ trống = nhập toàn trường, mỗi sheet 1 lớp)"),
    file: UploadFile = File(..., description="File Excel (.xlsx) kết quả vào sổ sức khoẻ"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> HealthExamImportResponse:
    verify_admin_access(current_user=current_user)

    classroom = None
    scope_name = "toàn trường"
    if class_id is not None:
        classroom = db.scalar(select(Class_).where(Class_.class_id == class_id))
        if not classroom:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Không tìm thấy thông tin lớp học",
            )
        scope_name = classroom.name

    filename = file.filename or ""
    suffix = Path(filename).suffix.lower()
    if suffix not in ALLOWED_EXAM_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File phải có định dạng Excel (.xlsx).",
        )

    file_bytes = file.file.read()
    if len(file_bytes) > MAX_EXAM_FILE_SIZE_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=(
                f"File quá lớn: {len(file_bytes) / 1024 / 1024:.1f} MB. "
                "Giới hạn tối đa là 10 MB."
            ),
        )
    if not file_bytes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File tải lên đang trống.",
        )

    try:
        result = import_health_exam_file(
            db=db,
            classroom=classroom,
            file_bytes=file_bytes,
            actor=current_user,
        )
    except HealthExamFileError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        )

    logger.info(
        "Nhập kết quả vào sổ sức khoẻ: scope=%s total=%s success=%s failed=%s (bởi %s)",
        scope_name,
        result.total_rows,
        result.success_count,
        result.failed_count,
        current_user.username,
    )

    return HealthExamImportResponse(
        total_rows=result.total_rows,
        success_count=result.success_count,
        failed_count=result.failed_count,
        created_count=result.created_count,
        updated_count=result.updated_count,
        errors=[
            HealthExamImportRowIssue(
                row_number=issue.row_number,
                sheet_name=issue.sheet_name,
                child_id=issue.child_id,
                full_name=issue.full_name,
                errors=issue.errors,
                warnings=issue.warnings,
            )
            for issue in result.issues
        ],
    )
