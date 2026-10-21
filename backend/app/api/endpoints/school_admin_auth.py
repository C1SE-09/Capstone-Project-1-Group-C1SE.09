"""
app/api/endpoints/school_admin_auth.py
=====================================
Endpoint đăng nhập cho School Admin Web.

Mục đích: Cho phép admin trường (users.role='admin') đăng nhập trên web admin.
Tài khoản này KHÁC với web admin (AdminUser) — admin trường có quyền quản lý
giáo viên, học sinh, phụ huynh, lịch học thông qua các endpoint /api/admin/*.

Flow:
    POST /api/school-admin/login
    → xác thực user (find_user_by_identifier + verify_password)
    → kiểm tra role == 'admin'
    → tạo session (create_session)
    → trả token + thông tin user + tên trường
"""

from __future__ import annotations

import logging

from app.api.endpoints.auth import find_user_by_identifier
from app.core.database import get_db
from app.core.security import (
    create_session,
    verify_password,
)
from app.models.user import School, User, UserRole
from app.schemas.school_admin_auth import (
    SchoolAdminLoginRequest,
    SchoolAdminLoginResponse,
)
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/school-admin", tags=["school-admin"])


def _resolve_school(db: Session, user: User) -> tuple[str | None, str | None]:
    """Lấy school_id + school_name cho admin.

    Trong schema hiện tại User.role='admin' không bắt buộc phải gắn với teacher,
    nên school có thể đến từ teacher đầu tiên trong DB, hoặc school đầu tiên.
    """
    school = db.query(School).first()
    if school:
        return str(school.school_id), school.name
    return None, None


@router.post(
    "/login",
    response_model=SchoolAdminLoginResponse,
    summary="Đăng nhập School Admin trên Web",
    description=(
        "Endpoint đăng nhập dành cho admin trường (users.role='admin') trên web. "
        "Trả về access token + refresh token + thông tin trường để dùng cho "
        "các API quản lý giáo viên / học sinh / phụ huynh / lịch học."
    ),
)
def school_admin_login(
    payload: SchoolAdminLoginRequest,
    db: Session = Depends(get_db),
) -> SchoolAdminLoginResponse:
    user = find_user_by_identifier(payload.username, db)

    if user is None or not verify_password(payload.password, user.password_hash):
        logger.warning("[school-admin-login] Sai tài khoản: %s", payload.username)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Tên đăng nhập hoặc mật khẩu không chính xác",
        )

    role_val = user.role.value if hasattr(user.role, "value") else str(user.role)
    if role_val != UserRole.ADMIN.value:
        logger.warning(
            "[school-admin-login] User %s cố đăng nhập admin trường với role=%s",
            payload.username, role_val,
        )
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Tài khoản này không phải admin trường. Vui lòng sử dụng đúng cổng đăng nhập tương ứng.",
        )

    if user.status and hasattr(user.status, "value"):
        status_val = user.status.value
        if status_val != "active":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Tài khoản admin trường đã bị vô hiệu hóa. Liên hệ quản trị viên cấp cao.",
            )

    sess = create_session(
        user_id=str(user.user_id),
        role=role_val,
        device_id=payload.device_id or "school_admin_web",
        device_name=payload.device_name or "KinderLog Admin Web",
    )

    school_id, school_name = _resolve_school(db, user)

    logger.info(
        "[school-admin-login] OK: user=%s school=%s", user.username, school_name,
    )

    return SchoolAdminLoginResponse(
        access_token=sess["access_token"],
        refresh_token=sess["refresh_token"],
        session_id=sess["session_id"],
        token_type="bearer",
        role=role_val,
        user_id=str(user.user_id),
        username=user.username,
        full_name=user.username or "Admin trường",
        school_id=school_id,
        school_name=school_name,
    )


@router.post(
    "/logout",
    summary="Đăng xuất School Admin",
)
def school_admin_logout(
    token: str | None = None,
    db: Session = Depends(get_db),
):
    """Logout đơn giản - frontend xóa token là đủ. Endpoint tồn tại cho tài liệu API."""
    return {"message": "Đã đăng xuất. Hãy xóa token ở phía client."}


@router.get(
    "/me",
    summary="Thông tin School Admin hiện tại",
)
def get_school_admin_me(
    # Có thể truyền token qua header Authorization
    db: Session = Depends(get_db),
):
    """Trả về thông tin admin trường dựa trên token hiện tại.

    Frontend nên truyền Authorization: Bearer <token> header.
    """
    raise HTTPException(
        status_code=501,
        detail="Endpoint này được xử lý ở client. Hãy đọc thông tin từ localStorage.",
    )