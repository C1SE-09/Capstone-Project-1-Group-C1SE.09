import uuid

from app.core.database import get_db
from app.core.security import require_any_role, require_role
from app.models.child import Parent
from app.models.user import User
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

router = APIRouter(prefix="/api/parent", tags=["parent"])


class ParentUpdatePhone(BaseModel):
    """Payload self-service cập nhật số điện thoại."""

    phone: str = Field(pattern=r"^0\d{9,10}$", max_length=20)


@router.get("/me")
def get_parent_me(current_user: User = Depends(require_role("parent"))):
    return {
        "user_id": str(current_user.user_id),
        "role": current_user.role.value,
        "parent_id": str(current_user.parent_id),
    }


@router.put("/{parent_id}", summary="Cập nhật số điện thoại phụ huynh")
def update_parent_phone(
    parent_id: uuid.UUID,
    data: ParentUpdatePhone,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_any_role("parent", "admin")),
):
    """Parent tự sửa SĐT của chính mình; admin sửa được mọi ID."""
    role = (
        current_user.role.value
        if hasattr(current_user.role, "value")
        else str(current_user.role)
    )
    if role == "parent" and current_user.parent_id != parent_id:
        raise HTTPException(
            status_code=403, detail="Chỉ được cập nhật thông tin của chính mình"
        )

    parent = db.query(Parent).filter(Parent.parent_id == parent_id).first()
    if not parent:
        raise HTTPException(status_code=404, detail="Không tìm thấy phụ huynh")

    phone = data.phone.strip()
    taken = (
        db.query(Parent)
        .filter(Parent.phone == phone, Parent.parent_id != parent_id)
        .first()
    )
    if taken:
        raise HTTPException(status_code=409, detail="Số điện thoại đã được sử dụng")

    parent.phone = phone
    db.commit()
    return {"message": "Cập nhật số điện thoại thành công", "phone": parent.phone}
