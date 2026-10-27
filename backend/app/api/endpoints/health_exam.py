"""
backend/app/api/endpoints/health_exam.py
========================================
API Khám sức khỏe học sinh:
- GET /api/health-exam/template: Xuất file Excel (.xlsx) mẫu điền sẵn danh sách học sinh của lớp, khóa các cột định danh.
"""

from __future__ import annotations

import logging
import re
import unicodedata
import urllib.parse
import uuid
from datetime import date
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_user
from app.models.child import Child, ChildStatus
from app.models.user import Class_, User, UserRole
from app.services.health_exam_service import generate_health_exam_template

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
    "/template",
    summary="Tải file Excel mẫu ghi nhận khám sức khỏe của lớp",
    description=(
        "Xuất file Excel (.xlsx) mẫu khám sức khỏe điền sẵn danh sách học sinh của lớp "
        "(Mã học sinh, Họ và tên, Ngày sinh, Giới tính). "
        "Các cột định danh được khóa chống chỉnh sửa, các cột kết quả khám được mở để nhập liệu."
    ),
)
def get_health_exam_template(
    class_id: uuid.UUID = Query(..., description="ID của lớp học cần tải mẫu danh sách"),
    examination_date: Optional[date] = Query(None, description="Ngày khám dự kiến (mặc định hôm nay)"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Response:
    verify_admin_access(current_user=current_user)

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
    ascii_filename = f"Mau_Kham_Suc_Khoe_{ascii_name}_{date_str}.xlsx"
    utf8_filename = f"Mau_Kham_Suc_Khoe_{classroom.name.replace(' ', '_')}_{date_str}.xlsx"
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
