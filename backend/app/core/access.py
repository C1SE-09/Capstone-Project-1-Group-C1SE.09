"""
app/core/access.py
==================
Quy tắc truy cập hồ sơ bé, dùng chung cho route sức khỏe và route lớp.
"""

import uuid

from fastapi import HTTPException
from sqlalchemy import or_, text
from sqlalchemy.engine import Row
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.models.child import Child, ParentChild
from app.models.user import User


def role_of(user: User) -> str:
    return user.role.value if hasattr(user.role, "value") else str(user.role)


def teacher_id_owns_class(
    db: Session, teacher_id: uuid.UUID, class_id: uuid.UUID
) -> bool:
    """Kiểm tra teacher_id có phụ trách class_id qua bảng M2M `teacher_class` không."""
    try:
        row = db.execute(
            text(
                "SELECT 1 FROM teacher_class "
                "WHERE teacher_id = :tid AND class_id = :cid LIMIT 1"
            ),
            {"tid": teacher_id, "cid": class_id},
        ).fetchone()
        return isinstance(row, (tuple, Row))
    except SQLAlchemyError:
        return False


def teacher_owns_class(
    user: User,
    class_id: uuid.UUID,
    db: Session | None = None,
) -> bool:
    teacher = getattr(user, "teacher", None)
    if teacher and teacher.class_id == class_id:
        return True
    teacher_id = getattr(teacher, "teacher_id", None) or getattr(
        user, "teacher_id", None
    )
    if db is not None and teacher_id is not None:
        return teacher_id_owns_class(db, teacher_id, class_id)
    return False


def parent_has_child_in_class(
    db: Session, user: User, class_id: uuid.UUID
) -> bool:
    """Kiểm tra phụ huynh có ít nhất một bé đang học trong lớp `class_id` không."""
    parent_id = getattr(user, "parent_id", None)
    if parent_id is None:
        return False
    linked_child_ids = (
        db.query(ParentChild.child_id)
        .filter(ParentChild.parent_id == parent_id)
        .subquery()
    )
    child = (
        db.query(Child.child_id)
        .filter(
            Child.class_id == class_id,
            or_(
                Child.parent_id == parent_id,
                Child.child_id.in_(linked_child_ids),
            ),
        )
        .first()
    )
    return child is not None


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
    if (
        role == "teacher"
        and child.class_id
        and teacher_owns_class(user, child.class_id, db)
    ):
        return child
    raise HTTPException(status_code=403, detail="Bạn không có quyền truy cập hồ sơ này")
