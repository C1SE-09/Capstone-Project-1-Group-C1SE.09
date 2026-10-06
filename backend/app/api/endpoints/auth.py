from app.core.database import get_db
from app.core.security import create_access_token, get_current_user, verify_password
from app.models.user import User
from app.schemas.auth_schema import login_request, login_response
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
