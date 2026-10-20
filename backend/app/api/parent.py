import uuid
from datetime import date

from app.core.database import get_db
from app.core.security import require_any_role, require_role
from app.models.child import Child, Parent
from app.models.user import User
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

router = APIRouter(prefix="/api/parent", tags=["parent"])


class ParentUpdatePhone(BaseModel):
    """Payload self-service cập nhật thông tin phụ huynh (SĐT, Email, Quan hệ)."""

    phone: str | None = Field(None, pattern=r"^0\d{9,10}$", max_length=20)
    email: str | None = Field(None, max_length=255)
    relationship: str | None = Field(None, max_length=50)


ParentUpdateProfile = ParentUpdatePhone


class ParentUpdateChild(BaseModel):
    """Payload self-service phụ huynh cập nhật thông tin của bé."""

    full_name: str | None = Field(None, min_length=1, max_length=150)
    nickname: str | None = Field(None, max_length=50)
    date_of_birth: date | None = None
    gender: str | None = Field(None, max_length=10)
    medical_allergies: str | None = None


@router.get("/me")
def get_parent_me(current_user: User = Depends(require_role("parent"))):
    return {
        "user_id": str(current_user.user_id),
        "role": current_user.role.value,
        "parent_id": str(current_user.parent_id),
    }


@router.put("/{parent_id}", summary="Cập nhật thông tin phụ huynh")
def update_parent_phone(
    parent_id: uuid.UUID,
    data: ParentUpdatePhone,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_any_role("parent", "admin")),
):
    """Parent tự sửa thông tin của chính mình (SĐT, Email, Quan hệ); admin sửa được mọi ID."""
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

    if data.phone is not None:
        phone = data.phone.strip()
        taken = (
            db.query(Parent)
            .filter(Parent.phone == phone, Parent.parent_id != parent_id)
            .first()
        )
        if taken:
            raise HTTPException(status_code=409, detail="Số điện thoại đã được sử dụng")
        parent.phone = phone

    if data.email is not None:
        email = data.email.strip()
        if email:
            if "@" not in email or "." not in email:
                raise HTTPException(status_code=422, detail="Email không đúng định dạng")
            taken_email = (
                db.query(Parent)
                .filter(Parent.email == email, Parent.parent_id != parent_id)
                .first()
            )
            if taken_email:
                raise HTTPException(status_code=409, detail="Email đã được sử dụng")
            parent.email = email
        else:
            parent.email = None

    if data.relationship is not None:
        rel = data.relationship.strip()
        parent.relationship = rel if rel else None

    db.commit()
    db.refresh(parent)
    return {
        "message": "Cập nhật thông tin phụ huynh thành công",
        "phone": parent.phone,
        "email": parent.email,
        "relationship": parent.relationship,
    }


@router.put("/{parent_id}/child/{child_id}", summary="Phụ huynh cập nhật thông tin bé")
def update_parent_child(
    parent_id: uuid.UUID,
    child_id: uuid.UUID,
    data: ParentUpdateChild,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_any_role("parent", "admin")),
):
    """Phụ huynh cập nhật thông tin con của mình (họ tên, biệt danh, ngày sinh, giới tính, dị ứng)."""
    role = (
        current_user.role.value
        if hasattr(current_user.role, "value")
        else str(current_user.role)
    )
    if role == "parent" and current_user.parent_id != parent_id:
        raise HTTPException(
            status_code=403, detail="Chỉ được cập nhật thông tin trong tài khoản của chính mình"
        )

    child = db.query(Child).filter(Child.child_id == child_id).first()
    if not child:
        raise HTTPException(status_code=404, detail="Không tìm thấy thông tin của bé")

    if role == "parent":
        is_owner = (child.parent_id == parent_id) or any(
            p.parent_id == parent_id for p in child.parents
        )
        if not is_owner:
            raise HTTPException(
                status_code=403, detail="Bạn không có quyền chỉnh sửa thông tin của trẻ này"
            )

    if data.full_name is not None and data.full_name.strip():
        child.full_name = data.full_name.strip()
    if data.nickname is not None:
        child.nickname = data.nickname.strip() if data.nickname.strip() else None
    if data.date_of_birth is not None:
        child.date_of_birth = data.date_of_birth
    if data.gender is not None:
        child.gender = data.gender.strip() if data.gender.strip() else None
    if data.medical_allergies is not None:
        child.medical_allergies = (
            data.medical_allergies.strip() if data.medical_allergies.strip() else None
        )

    db.commit()
    db.refresh(child)

    from app.api.dashboard import _child_dict

    return {
        "message": "Cập nhật thông tin bé thành công",
        "child": _child_dict(child),
    }
