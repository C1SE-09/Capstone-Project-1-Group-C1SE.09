import logging

import redis
from app.core.database import get_db
from app.core.security import (
    ALGORITHM,
    SECRET_KEY,
    create_session,
    get_current_user,
    hash_password,
    oauth2_scheme,
    oauth2_scheme_optional,
    refresh_session,
    revoke_other_sessions,
    revoke_session,
    verify_password,
)
from app.models.child import Parent
from app.models.user import Teacher, User
from app.schemas.auth_schema import (
    change_password_request,
    forgot_password_request,
    login_request,
    login_response,
    refresh_token_request,
    reset_password_request,
    verify_reset_code_request,
)
from app.services.email_service import send_test_email
from app.services.password_reset_service import (
    delete_reset_code,
    generate_reset_code,
    is_reset_code_verified,
    save_reset_code,
    verify_reset_code,
)
from fastapi import APIRouter, Depends, HTTPException, status
from jose import JWTError, jwt
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login", response_model=login_response)
def login(data: login_request, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.username == data.username).first()
    if user is None or not verify_password(data.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Tên đăng nhập hoặc mật khẩu không chính xác",
        )
    role = user.role.value

    sess = create_session(
        user_id=str(user.user_id),
        role=role,
        device_id=data.device_id or "default_device",
        device_name=data.device_name or "thiết bị không rõ"
    )

    return login_response(
        access_token=sess["access_token"],
        refresh_token=sess["refresh_token"],
        session_id=sess["session_id"],
        token_type="bearer",
        role=role,
        user_id=str(user.user_id),
        username=user.username,
        teacher_id=str(user.teacher_id) if user.teacher_id else None,
        parent_id=str(user.parent_id) if user.parent_id else None,
    )

@router.post("/refresh")
def refresh_token(data: refresh_token_request):
    return refresh_session(
        session_id=data.session_id,
        refresh_token=data.refresh_token
    )
@router.post("/logout")
def logout(token: str = Depends(oauth2_scheme)):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        sid = payload.get("session_id")
        if sid:
            revoke_session(sid)
    except (JWTError, redis.RedisError) as e:
        logger.warning("Không thể thu hồi session khi đăng xuất: %s", e)
    return {"message": "Đăng xuất thành công"}


@router.post("/change-password")
def change_password(
    data: change_password_request,
    token: str | None = Depends(oauth2_scheme_optional),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if not verify_password(data.current_password, current_user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Mật khẩu hiện tại không chính xác.",
        )
    if verify_password(data.new_password, current_user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Mật khẩu mới không được trùng với mật khẩu hiện tại.",
        )

    current_user.password_hash = hash_password(data.new_password)
    db.commit()
    if data.logout_other_devices and token:
        try:
            payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
            sid = payload.get("session_id")
            if sid:
                revoke_other_sessions(str(current_user.user_id), sid)
        except (JWTError, redis.RedisError) as e:
            logger.warning("Không thể thu hồi các session khác: %s", e)
    return {"message": "Đổi mật khẩu thành công!"}

@router.post("/forgot-password")
def forgot_password(data: forgot_password_request, db: Session = Depends(get_db)):
    input_val = data.email.strip().lower()
    user = None
    target_email = input_val

    # 1. Tìm theo Teacher email
    teacher = (
        db.query(Teacher)
        .filter(Teacher.email.ilike(input_val))
        .first()
    )
    if teacher:
        user = (
            db.query(User)
            .filter(User.teacher_id == teacher.teacher_id)
            .first()
        )
        target_email = teacher.email

    # 2. Tìm theo Parent email
    if user is None:
        parent = (
            db.query(Parent)
            .filter(Parent.email.ilike(input_val))
            .first()
        )
        if parent:
            user = (
                db.query(User)
                .filter(User.parent_id == parent.parent_id)
                .first()
            )
            target_email = parent.email

    # 3. Tìm theo Username (nếu nhập 'comai', 'tuan'...)
    if user is None:
        user = db.query(User).filter(User.username.ilike(input_val)).first()
        if user:
            if user.teacher_id:
                t = db.query(Teacher).filter(Teacher.teacher_id == user.teacher_id).first()
                if t and t.email:
                    target_email = t.email
            elif user.parent_id:
                p = db.query(Parent).filter(Parent.parent_id == user.parent_id).first()
                if p and p.email:
                    target_email = p.email

    if user is None:
        logger.warning(
            f"[AUTH] Quên mật khẩu: Không tìm thấy tài khoản tương ứng với '{input_val}' trong hệ thống!"
        )
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Email hoặc tên đăng nhập không tồn tại trong hệ thống.",
        )

    reset_code = generate_reset_code()
    save_reset_code(email=input_val, reset_code=reset_code)
    if target_email != input_val:
        save_reset_code(email=target_email, reset_code=reset_code)

    try:
        send_test_email(
            to_email=target_email,
            subject="KinderLog - Mã đặt lại mật khẩu",
            body=(
                "Xin chào,\n\n"
                f"Mã xác thực đặt lại mật khẩu của bạn là: {reset_code}\n"
                "Mã này sẽ hết hạn sau 5 phút.\n\n"
                "Nếu bạn không yêu cầu đặt lại mật khẩu, "
                "vui lòng bỏ qua email này.\n\n"
                "KinderLog"
            ),
        )
    except Exception as exc:
        logger.error(f"[AUTH] Gửi email đặt lại mật khẩu thất bại: {exc!s}")
        delete_reset_code(input_val)
        if target_email != input_val:
            delete_reset_code(target_email)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Hệ thống tạm thời chưa thể gửi email xác thực. Quý phụ huynh và thầy cô vui lòng thử lại sau ít phút hoặc kiểm tra lại địa chỉ email.",
        ) from exc

    return {
        "message": (
            f"Mã xác thực đã được gửi tới {target_email}. "
            "Vui lòng kiểm tra hộp thư đến hoặc thư mục spam."
        )
    }

@router.post("/verify-reset-code")
def verify_reset_code_endpoint(data: verify_reset_code_request):
    email = data.email.strip().lower()
    is_valid = verify_reset_code(email=email, reset_code=data.reset_code)
    if not is_valid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Mã xác thực không hợp lệ hoặc đã hết hạn.",
        )
    return {"message": "Mã xác thực đã được xác nhận thành công."}

@router.post("/reset-password")
def reset_password(data: reset_password_request, db: Session = Depends(get_db)):
    input_val = data.email.strip().lower()
    if not is_reset_code_verified(input_val):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Mã đặt lại mật khẩu chưa được xác thực hoặc đã hết hạn.",
        )
    user = None
    teacher = db.query(Teacher).filter(Teacher.email.ilike(input_val)).first()
    if teacher:
        user = db.query(User).filter(User.teacher_id == teacher.teacher_id).first()
    if user is None:
        parent = db.query(Parent).filter(Parent.email.ilike(input_val)).first()
        if parent:
            user = db.query(User).filter(User.parent_id == parent.parent_id).first()
    if user is None:
        user = db.query(User).filter(User.username.ilike(input_val)).first()
    if user is None:
        delete_reset_code(input_val)
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Người dùng với email/tên đăng nhập này không tồn tại.",
        )
    user.password_hash = hash_password(data.new_password)
    db.commit()
    delete_reset_code(input_val)
    return {"message": "Mật khẩu đã được đặt lại thành công."}
@router.post("/test-email")
def test_email(to_email: str):
    try:
        send_test_email(
            to_email=to_email,
            subject="KinderLog - Test Email",
            body=(
                "Đây là email test từ hệ thống KinderLog.\n"
                "Nếu bạn nhận được email này, nghĩa là cấu hình SMTP đã thành công."
            ),
        )

        return {
            "message": "Email đã được gửi thành công"
        }

    except Exception as exc:
        logger.error(f"[AUTH] Gửi email thử nghiệm thất bại tới {to_email}: {exc!s}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Hệ thống tạm thời chưa thể gửi email thử nghiệm. Vui lòng kiểm tra lại cấu hình hòm thư.",
        ) from exc