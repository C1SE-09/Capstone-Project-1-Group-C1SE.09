from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models.child import Child, ChildStatus
from app.models.user import Class_, Teacher

router = APIRouter(
    prefix="/api/class",
    tags=["class"]
)


"""
#1 API lấy thông tin lớp
"""
@router.get("/{class_id}")
def get_class(
    class_id: str,
    db: Session = Depends(get_db)  # noqa: B008
):
    class_data = (
        db.query(Class_)
        .filter(Class_.class_id == class_id)
        .first()
    )

    if not class_data:
        raise HTTPException(
            status_code=404,
            detail="Class not found"
        )

    return {
        "class_id": str(class_data.class_id),
        "name": class_data.name,
        "grade_label": class_data.grade_label,
        "room_number": class_data.room_number,
        "capacity": class_data.capacity,
        "is_activate": class_data.is_active
    }


"""
#2 API lấy danh sách học sinh
"""
@router.get("/{class_id}/{child_id}")
def get_children(
    class_id: str,
    db: Session = Depends(get_db)  # noqa: B008
):
    class_data = (
        db.query(Class_)
        .filter(Class_.class_id == class_id)
        .first()
    )

    if not class_data:
        raise HTTPException(
            status_code=404,
            detail="Class not found"
        )

    children = (
        db.query(Child)
        .filter(
            Child.class_id == class_id,
            Child.status == ChildStatus.ENROLLED
        )
        .order_by(Child.full_name)
        .all()
    )

    return {
        "class_id": str(class_id),
        "children": [
            {
                "child_id": str(child.child_id),
                "full_name": child.full_name,
                "date_of_birth": (
                    child.date_of_birth.isoformat()
                    if child.date_of_birth
                    else None
                ),
                "gender": child.gender,
                "avatar_url": child.avatar_url,
                "medical_allergies": child.medical_allergies,
                "status": child.status
            }
            for child in children
        ]
    }


"""
#3 API Lấy Danh Sách Giáo Viên
"""
@router.get("/{class_id}/{teacher_id}")
def get_teacher(
    class_id: str,
    db: Session = Depends(get_db)  # noqa: B008
):
    class_data = (
        db.query(Class_)
        .filter(Class_.class_id == class_id)
        .first()
    )

    if not class_data:
        raise HTTPException(
            status_code=404,
            detail="Class not found"
        )

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
                "email": teacher.email
            }
            for teacher in teachers
        ]
    }