from app.core.database import get_db
from app.core.security import (
    create_access_token,
    get_current_user,
    hash_password,
    verify_password,
)
from app.models.child import Parent
from app.models.user import Teacher, User
from app.schemas.auth_schema import (
    change_password_request,
    forgot_password_request,
    login_request,
    login_response,
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
from sqlalchemy.orm import Session

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
    access_token = create_access_token(user_id=str(user.user_id), role=role)
    return login_response(
        access_token=access_token,
        token_type="bearer",
        role=role,
        user_id=str(user.user_id),
        teacher_id=str(user.teacher_id) if user.teacher_id else None,
        parent_id=str(user.parent_id) if user.parent_id else None,
    )


@router.post("/logout")
def logout(current_user: User = Depends(get_current_user)):
    return {"message": "Đăng xuất thành công!"}


@router.post("/change-password")
def change_password(
    data: change_password_request,
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
    return {"message": "Đổi mật khẩu thành công!"}

@router.post("/forgot-password")
def forgot_password(data: forgot_password_request, db: Session = Depends(get_db)):
    email = data.email.strip().lower()
    user = None
    teacher = (
        db.query(Teacher)
        .filter(Teacher.email.ilike(email))
        .first()
    )
    if teacher:
        user = (
            db.query(User)
            .filter(User.teacher_id == teacher.teacher_id)
            .first()
        )
    if user is None:
        parent = (
            db.query(Parent)
            .filter(Parent.email.ilike(email))
            .first()
        )
        if parent:
            user = (
                db.query(User)
                .filter(User.parent_id == parent.parent_id)
                .first()
            )
    if user is not None:
        reset_code = generate_reset_code()
        save_reset_code(email=email, reset_code=reset_code)
        try:
            send_test_email(
                to_email=email,
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
            delete_reset_code(email)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Gửi email thất bại: {exc!s}",
            ) from exc
    return {
        "message": (
            "Nếu email tồn tại trong hệ thống, "
            "mã xác thực đã được gửi. "
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
    email = data.email.strip().lower()
    if not is_reset_code_verified(email):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Mã đặt lại mật khẩu chưa được xác thực hoặc đã hết hạn.",
        )
    user = None
    teacher = db.query(Teacher).filter(Teacher.email.ilike(email)).first()
    if teacher:
        user = db.query(User).filter(User.teacher_id == teacher.teacher_id).first()
    if user is None:
        parent = db.query(Parent).filter(Parent.email.ilike(email)).first()
        if parent:
            user = db.query(User).filter(User.parent_id == parent.parent_id).first()
    if user is None:
        delete_reset_code(email)
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Người dùng với email này không tồn tại.",
        )
    user.password_hash = hash_password(data.new_password)
    db.commit()
    delete_reset_code(email)
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
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Gửi email thất bại: {exc!s}",
        ) from exc