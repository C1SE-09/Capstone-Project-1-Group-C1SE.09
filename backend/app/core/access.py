"""
app/core/access.py
==================
Quy tắc truy cập hồ sơ bé, dùng chung cho route sức khỏe và route lớp.
"""

import uuid

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models.child import Child
from app.models.user import User


def role_of(user: User) -> str:
    return user.role.value if hasattr(user.role, "value") else str(user.role)


def teacher_owns_class(user: User, class_id: uuid.UUID) -> bool:
    teacher = getattr(user, "teacher", None)
    return bool(teacher and teacher.class_id == class_id)


def resolve_child_for_actor(db: Session, child_id: uuid.UUID, user: User) -> Child:
    """Trả về bé nếu actor có quyền đọc hồ sơ, ngược lại 404/403."""
    child = db.query(Child).filter(Child.child_id == child_id).first()
    if child is None:
        raise HTTPException(status_code=404, detail="Không tìm thấy hồ sơ bé")
    role = role_of(user)
    if role == "admin":
        return child
    if role == "parent":
        linked = {link.parent_id for link in child.parent_links}
        if user.parent_id and (
            child.parent_id == user.parent_id or user.parent_id in linked
        ):
            return child
    if role == "teacher" and child.class_id and teacher_owns_class(user, child.class_id):
        return child
    raise HTTPException(status_code=403, detail="Bạn không có quyền truy cập hồ sơ này")
