import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.dashboard import _child_dict
from app.core.access import role_of, teacher_owns_class
from app.core.database import get_db
from app.core.security import require_any_role
from app.models.child import Child, ChildStatus
from app.models.user import Class_, Teacher, User

router = APIRouter(prefix="/api/class", tags=["class"])


"""
#1 API lấy thông tin lớp
"""


@router.get("/{class_id}")
def get_class(
    class_id: str,
    db: Session = Depends(get_db),
):
    class_data = db.query(Class_).filter(Class_.class_id == class_id).first()

    if not class_data:
        raise HTTPException(status_code=404, detail="Class not found")

    return {
        "class_id": str(class_data.class_id),
        "school_id": str(class_data.school_id),
        "name": class_data.name,
        "grade_label": class_data.grade_label,
        "room_number": class_data.room_number,
        "capacity": class_data.capacity,
        "is_active": class_data.is_active,
    }


"""
#2 API lấy danh sách học sinh
"""


@router.get("/{class_id}/children")
def get_children(
    class_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_any_role("teacher", "admin")),
):
    try:
        class_uuid = uuid.UUID(class_id)
    except ValueError:
        raise HTTPException(status_code=404, detail="Class not found") from None

    if role_of(current_user) == "teacher" and not teacher_owns_class(
        current_user, class_uuid
    ):
        raise HTTPException(status_code=403, detail="Bạn không có quyền truy cập")

    class_data = db.query(Class_).filter(Class_.class_id == class_uuid).first()

    if not class_data:
        raise HTTPException(status_code=404, detail="Class not found")

    children = (
        db.query(Child)
        .filter(Child.class_id == class_uuid, Child.status == ChildStatus.ENROLLED)
        .order_by(Child.full_name)
        .all()
    )

    return {
        "class_id": str(class_uuid),
        "children": [
            {
                **_child_dict(child),
                "status": child.status.value
                if hasattr(child.status, "value")
                else str(child.status),
            }
            for child in children
        ],
    }


"""
#3 API Lấy Danh Sách Giáo Viên
"""


@router.get("/{class_id}/teachers")
def get_teacher(
    class_id: str,
    db: Session = Depends(get_db),
):
    class_data = db.query(Class_).filter(Class_.class_id == class_id).first()

    if not class_data:
        raise HTTPException(status_code=404, detail="Class not found")

    teachers = (
        db.query(Teacher)
        .filter(Teacher.class_id == class_id)
        .order_by(Teacher.full_name)
        .all()
    )

    return {
        "class_id": str(class_id),
        "teachers": [
            {
                "teacher_id": str(teacher.teacher_id),
                "full_name": teacher.full_name,
                "email": teacher.email,
            }
            for teacher in teachers
        ],
    }
