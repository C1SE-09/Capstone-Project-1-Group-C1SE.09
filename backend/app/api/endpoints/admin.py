import re
import uuid
from datetime import date

from app.core.database import get_db
from app.core.security import hash_password
from app.models.child import Child, ChildStatus, Parent, ParentChild, ParentStatus
from app.models.schedule import ClassSchedule, Subject, TimeSlot
from app.models.user import Class_, School, Teacher, TeacherStatus, User, UserRole, UserStatus
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import text
from sqlalchemy.orm import Session

router = APIRouter(prefix="/admin", tags=["admin"])


def _validate_phone_10_digits(phone: str | None) -> None:
    if phone and phone.strip():
        clean = phone.strip()
        if not re.match(r"^0\d{9}$", clean):
            raise HTTPException(
                status_code=400,
                detail="Số điện thoại phải gồm đúng 10 chữ số (bắt đầu bằng số 0).",
            )


def _validate_gmail_format(email: str | None) -> None:
    if email and email.strip():
        clean = email.strip()
        if not re.match(r"^[a-zA-Z0-9._%+-]+@gmail\.com$", clean, re.IGNORECASE):
            raise HTTPException(
                status_code=400,
                detail="Email phải đúng định dạng Gmail (@gmail.com).",
            )


# ─────────────────────────────────────────────────────────────────────────────
# Schemas
# ─────────────────────────────────────────────────────────────────────────────


class TeacherCreate(BaseModel):
    full_name: str
    email: str
    phone: str
    class_id: str | None = None
    class_ids: list[str] | None = None
    status: str = "active"
    username: str | None = None
    password: str | None = None


class TeacherUpdate(BaseModel):
    full_name: str | None = None
    email: str | None = None
    phone: str | None = None
    class_id: str | None = None
    class_ids: list[str] | None = None
    status: str | None = None
    username: str | None = None
    password: str | None = None


class ParentCreate(BaseModel):
    full_name: str
    phone: str
    email: str | None = None
    relationship: str | None = None
    child_id: str | None = None
    child_ids: list[str] | None = None
    status: str = "active"
    username: str | None = None
    password: str | None = None


class ParentUpdate(BaseModel):
    full_name: str | None = None
    phone: str | None = None
    email: str | None = None
    relationship: str | None = None
    child_id: str | None = None
    child_ids: list[str] | None = None
    status: str | None = None
    username: str | None = None
    password: str | None = None


class ChildParentItem(BaseModel):
    parent_id: str
    relationship: str | None = None
    is_primary: bool = False
    can_pickup: bool = True


class ChildCreate(BaseModel):
    full_name: str
    nickname: str | None = None
    class_id: str | None = None
    parent_id: str | None = None
    parent_ids: list[str] | None = None
    parent_items: list[ChildParentItem] | None = None
    medical_allergies: str | None = None
    date_of_birth: str | None = None
    gender: str | None = "male"
    status: str = "enrolled"


class ChildUpdate(BaseModel):
    full_name: str | None = None
    nickname: str | None = None
    class_id: str | None = None
    parent_id: str | None = None
    parent_ids: list[str] | None = None
    parent_items: list[ChildParentItem] | None = None
    medical_allergies: str | None = None
    date_of_birth: str | None = None
    gender: str | None = None
    status: str | None = None


class ScheduleCreate(BaseModel):
    activity_name: str
    content: str | None = None
    room_name: str | None = None
    time_range: str | None = None
    slot_id: str | None = None
    start_time: str | None = None
    end_time: str | None = None
    class_id: str | None = None
    teacher_id: str | None = None
    day_of_week: int = 2


class ScheduleUpdate(BaseModel):
    activity_name: str | None = None
    content: str | None = None
    room_name: str | None = None
    time_range: str | None = None
    slot_id: str | None = None
    start_time: str | None = None
    end_time: str | None = None
    day_of_week: int | None = None


# ─────────────────────────────────────────────────────────────────────────────
# 1. Teachers Endpoints
# ─────────────────────────────────────────────────────────────────────────────


@router.get("/teachers")
def list_teachers(db: Session = Depends(get_db)):
    teachers = db.query(Teacher).order_by(Teacher.created_at.desc()).all()
    results = []
    for t in teachers:
        tc_rows = db.execute(
            text("SELECT c.class_id, c.name FROM teacher_class tc JOIN class c ON tc.class_id = c.class_id WHERE tc.teacher_id = :tid ORDER BY c.name"),
            {"tid": t.teacher_id}
        ).fetchall()

        assigned = [{"id": str(r[0]), "name": r[1]} for r in tc_rows]
        if not assigned and t.class_:
            assigned = [{"id": str(t.class_.class_id), "name": t.class_.name}]

        class_ids = [c["id"] for c in assigned]
        class_name = ", ".join([c["name"] for c in assigned]) if assigned else "Chưa phân lớp"

        user = db.query(User).filter(User.teacher_id == t.teacher_id).first()

        results.append(
            {
                "id": str(t.teacher_id),
                "full_name": t.full_name,
                "email": t.email,
                "phone": t.phone,
                "username": user.username if user else None,
                "class_id": class_ids[0] if class_ids else None,
                "class_ids": class_ids,
                "class_name": class_name,
                "classes": assigned,
                "status": t.status.value if hasattr(t.status, "value") else str(t.status),
            }
        )
    return results


@router.post("/teachers", status_code=status.HTTP_201_CREATED)
def create_teacher(data: TeacherCreate, db: Session = Depends(get_db)):
    _validate_phone_10_digits(data.phone)
    _validate_gmail_format(data.email)

    if data.username and data.username.strip():
        existing_user = db.query(User).filter(User.username == data.username.strip()).first()
        if existing_user:
            raise HTTPException(status_code=400, detail="Tên đăng nhập này đã tồn tại trên hệ thống. Vui lòng chọn tên khác.")

    if data.email and data.email.strip():
        existing_email = db.query(Teacher).filter(Teacher.email == data.email.strip()).first()
        if existing_email:
            raise HTTPException(status_code=400, detail="Email này đã được sử dụng bởi giáo viên khác.")

    if data.phone and data.phone.strip():
        existing_phone = db.query(Teacher).filter(Teacher.phone == data.phone.strip()).first()
        if existing_phone:
            raise HTTPException(status_code=400, detail="Số điện thoại này đã được đăng ký cho giáo viên khác.")

    school = db.query(School).first()
    school_id = school.school_id if school else uuid.uuid4()

    c_ids = data.class_ids or ([data.class_id] if data.class_id else [])
    c_uuids = [uuid.UUID(c) for c in c_ids if c.strip()]
    primary_class_id = c_uuids[0] if c_uuids else None

    teacher = Teacher(
        teacher_id=uuid.uuid4(),
        school_id=school_id,
        class_id=primary_class_id,
        full_name=data.full_name.strip(),
        email=data.email.strip(),
        phone=data.phone.strip(),
        status=TeacherStatus.ACTIVE,
        is_verified=True,
    )
    db.add(teacher)
    db.flush()

    for cid in c_uuids:
        db.execute(
            text("INSERT INTO teacher_class (teacher_id, class_id) VALUES (:tid, :cid) ON CONFLICT DO NOTHING"),
            {"tid": teacher.teacher_id, "cid": cid}
        )

    if data.username and data.username.strip():
        pwd = data.password.strip() if data.password and data.password.strip() else "123456"
        user = User(
            user_id=uuid.uuid4(),
            username=data.username.strip(),
            password_hash=hash_password(pwd),
            role=UserRole.TEACHER,
            teacher_id=teacher.teacher_id,
            status=UserStatus.ACTIVE,
            is_verified=True,
        )
        db.add(user)

    db.commit()
    db.refresh(teacher)
    return {"message": "Tạo giáo viên thành công", "id": str(teacher.teacher_id)}


@router.put("/teachers/{teacher_id}")
def update_teacher(teacher_id: str, data: TeacherUpdate, db: Session = Depends(get_db)):
    t = db.query(Teacher).filter(Teacher.teacher_id == uuid.UUID(teacher_id)).first()
    if not t:
        raise HTTPException(status_code=404, detail="Không tìm thấy giáo viên")

    _validate_phone_10_digits(data.phone)
    _validate_gmail_format(data.email)

    if data.full_name is not None:
        t.full_name = data.full_name.strip()
    if data.email is not None and data.email.strip():
        existing_email = db.query(Teacher).filter(Teacher.email == data.email.strip(), Teacher.teacher_id != t.teacher_id).first()
        if existing_email:
            raise HTTPException(status_code=400, detail="Email này đã được sử dụng bởi giáo viên khác.")
        t.email = data.email.strip()
    if data.phone is not None and data.phone.strip():
        existing_phone = db.query(Teacher).filter(Teacher.phone == data.phone.strip(), Teacher.teacher_id != t.teacher_id).first()
        if existing_phone:
            raise HTTPException(status_code=400, detail="Số điện thoại này đã được đăng ký cho giáo viên khác.")
        t.phone = data.phone.strip()
    if data.status is not None:
        t.status = TeacherStatus(data.status) if data.status in ["active", "inactive", "on_leave"] else t.status

    if data.class_ids is not None:
        c_uuids = [uuid.UUID(c) for c in data.class_ids if c.strip()]
        t.class_id = c_uuids[0] if c_uuids else None
        db.execute(text("DELETE FROM teacher_class WHERE teacher_id = :tid"), {"tid": t.teacher_id})
        for cid in c_uuids:
            db.execute(
                text("INSERT INTO teacher_class (teacher_id, class_id) VALUES (:tid, :cid) ON CONFLICT DO NOTHING"),
                {"tid": t.teacher_id, "cid": cid}
            )
    elif data.class_id is not None:
        cid = uuid.UUID(data.class_id) if data.class_id.strip() else None
        t.class_id = cid
        db.execute(text("DELETE FROM teacher_class WHERE teacher_id = :tid"), {"tid": t.teacher_id})
        if cid:
            db.execute(
                text("INSERT INTO teacher_class (teacher_id, class_id) VALUES (:tid, :cid) ON CONFLICT DO NOTHING"),
                {"tid": t.teacher_id, "cid": cid}
            )

    # Cập nhật thông tin tài khoản đăng nhập & mật khẩu nếu có
    if data.username is not None or data.password is not None:
        user = db.query(User).filter(User.teacher_id == t.teacher_id).first()
        if user:
            if data.username and data.username.strip() and data.username.strip() != user.username:
                existing = db.query(User).filter(User.username == data.username.strip(), User.user_id != user.user_id).first()
                if existing:
                    raise HTTPException(status_code=400, detail="Tên đăng nhập này đã tồn tại trên hệ thống. Vui lòng chọn tên khác.")
                user.username = data.username.strip()
            if data.password and data.password.strip():
                user.password_hash = hash_password(data.password.strip())
        elif data.username and data.username.strip():
            existing = db.query(User).filter(User.username == data.username.strip()).first()
            if existing:
                raise HTTPException(status_code=400, detail="Tên đăng nhập này đã tồn tại trên hệ thống. Vui lòng chọn tên khác.")
            pwd = data.password.strip() if data.password and data.password.strip() else "123456"
            new_user = User(
                user_id=uuid.uuid4(),
                username=data.username.strip(),
                password_hash=hash_password(pwd),
                role=UserRole.TEACHER,
                teacher_id=t.teacher_id,
                status=UserStatus.ACTIVE,
                is_verified=True,
            )
            db.add(new_user)

    db.commit()
    return {"message": "Cập nhật giáo viên thành công"}


@router.delete("/teachers/{teacher_id}")
def delete_teacher(teacher_id: str, db: Session = Depends(get_db)):
    t = db.query(Teacher).filter(Teacher.teacher_id == uuid.UUID(teacher_id)).first()
    if not t:
        raise HTTPException(status_code=404, detail="Không tìm thấy giáo viên")

    db.delete(t)
    db.commit()
    return {"message": "Đã xóa giáo viên thành công"}


# ─────────────────────────────────────────────────────────────────────────────
# 0. Classes Endpoints
# ─────────────────────────────────────────────────────────────────────────────


@router.get("/classes")
def list_classes(db: Session = Depends(get_db)):
    classes = db.query(Class_).filter(Class_.is_active.is_(True)).order_by(Class_.name.asc()).all()
    return [
        {
            "id": str(c.class_id),
            "name": c.name,
            "grade_label": c.grade_label or "",
            "room_number": c.room_number or "",
        }
        for c in classes
    ]


# ─────────────────────────────────────────────────────────────────────────────
# 2. Parents Endpoints
# ─────────────────────────────────────────────────────────────────────────────


@router.get("/parents")
def list_parents(db: Session = Depends(get_db)):
    parents = db.query(Parent).order_by(Parent.created_at.desc()).all()
    results = []
    need_commit = False
    for p in parents:
        children_info = []
        child_ids = []
        children_list = []

        seen_child_ids = set()
        p_children = []
        for c in p.children:
            if c.child_id not in seen_child_ids:
                seen_child_ids.add(c.child_id)
                p_children.append(c)

        # Fallback: Lấy các học sinh liên kết qua khóa ngoại trực tiếp Child.parent_id (dữ liệu seed / legacy)
        legacy_children = db.query(Child).filter(Child.parent_id == p.parent_id).all()
        for c in legacy_children:
            if c.child_id not in seen_child_ids:
                seen_child_ids.add(c.child_id)
                p_children.append(c)
                # Tự động đồng bộ vào bảng parent_child để các lần truy vấn sau luôn có trong p.children
                db.execute(
                    text(
                        "INSERT INTO parent_child (id, parent_id, child_id, relationship, is_primary, can_pickup, created_at, updated_at) "
                        "VALUES (:id, :pid, :cid, :rel, true, true, now(), now()) "
                        "ON CONFLICT (parent_id, child_id) DO NOTHING"
                    ),
                    {
                        "id": uuid.uuid4(),
                        "pid": p.parent_id,
                        "cid": c.child_id,
                        "rel": p.relationship_ or "Phụ huynh",
                    },
                )
                need_commit = True

        for c in p_children:
            c_class = c.class_.name if c.class_ else ""
            children_info.append(f"{c.full_name} ({c_class})" if c_class else c.full_name)
            child_ids.append(str(c.child_id))
            children_list.append({
                "id": str(c.child_id),
                "name": c.full_name,
                "class_name": c_class,
                "class_id": str(c.class_id) if c.class_id else None,
            })

        child_desc = ", ".join(children_info) if children_info else "Chưa liên kết học sinh"
        user = db.query(User).filter(User.parent_id == p.parent_id).first()

        results.append(
            {
                "id": str(p.parent_id),
                "full_name": p.full_name,
                "phone": p.phone,
                "email": p.email or "",
                "relationship": p.relationship_ or "",
                "username": user.username if user else None,
                "status": p.status.value if hasattr(p.status, "value") else str(p.status),
                "children_summary": f"Bé: {child_desc}",
                "child_id": child_ids[0] if child_ids else None,
                "child_ids": child_ids,
                "children": children_list,
            }
        )
    if need_commit:
        db.commit()
    return results


@router.post("/parents", status_code=status.HTTP_201_CREATED)
def create_parent(data: ParentCreate, db: Session = Depends(get_db)):
    _validate_phone_10_digits(data.phone)
    _validate_gmail_format(data.email)

    if data.username and data.username.strip():
        existing_user = db.query(User).filter(User.username == data.username.strip()).first()
        if existing_user:
            raise HTTPException(status_code=400, detail="Tên đăng nhập này đã tồn tại trên hệ thống. Vui lòng chọn tên khác.")

    if data.email and data.email.strip():
        existing_email = db.query(Parent).filter(Parent.email == data.email.strip()).first()
        if existing_email:
            raise HTTPException(status_code=400, detail="Email này đã được sử dụng bởi phụ huynh khác.")

    if data.phone and data.phone.strip():
        existing_phone = db.query(Parent).filter(Parent.phone == data.phone.strip()).first()
        if existing_phone:
            raise HTTPException(status_code=400, detail="Số điện thoại này đã được đăng ký bởi phụ huynh khác.")

    parent = Parent(
        parent_id=uuid.uuid4(),
        full_name=data.full_name.strip(),
        phone=data.phone.strip(),
        email=data.email.strip() if data.email else None,
        relationship_=data.relationship.strip() if data.relationship and data.relationship.strip() else None,
        status=ParentStatus.ACTIVE,
        is_verified=True,
    )
    db.add(parent)
    db.flush()

    c_ids = data.child_ids or ([data.child_id] if data.child_id else [])
    for idx, cid in enumerate(c_ids):
        if cid and cid.strip():
            child = db.query(Child).filter(Child.child_id == uuid.UUID(cid.strip())).first()
            if child:
                # Tạo bản ghi liên kết N-N trong parent_child
                link = ParentChild(
                    id=uuid.uuid4(),
                    parent_id=parent.parent_id,
                    child_id=child.child_id,
                    relationship_=parent.relationship_ or "Phụ huynh",
                    is_primary=(idx == 0 and child.parent_id is None),
                    can_pickup=True,
                )
                db.add(link)
                if child.parent_id is None:
                    child.parent_id = parent.parent_id

    if data.username and data.username.strip():
        pwd = data.password.strip() if data.password and data.password.strip() else "123456"
        user = User(
            user_id=uuid.uuid4(),
            username=data.username.strip(),
            password_hash=hash_password(pwd),
            role=UserRole.PARENT,
            parent_id=parent.parent_id,
            status=UserStatus.ACTIVE,
            is_verified=True,
        )
        db.add(user)

    db.commit()
    db.refresh(parent)
    return {"message": "Tạo phụ huynh thành công", "id": str(parent.parent_id)}


@router.put("/parents/{parent_id}")
def update_parent(parent_id: str, data: ParentUpdate, db: Session = Depends(get_db)):
    p = db.query(Parent).filter(Parent.parent_id == uuid.UUID(parent_id)).first()
    if not p:
        raise HTTPException(status_code=404, detail="Không tìm thấy phụ huynh")

    _validate_phone_10_digits(data.phone)
    _validate_gmail_format(data.email)

    if data.full_name is not None:
        p.full_name = data.full_name.strip()
    if data.relationship is not None:
        p.relationship_ = data.relationship.strip() if data.relationship.strip() else None
    if data.email is not None and data.email.strip():
        existing_email = db.query(Parent).filter(Parent.email == data.email.strip(), Parent.parent_id != p.parent_id).first()
        if existing_email:
            raise HTTPException(status_code=400, detail="Email này đã được sử dụng bởi phụ huynh khác.")
        p.email = data.email.strip()
    elif data.email is not None and not data.email.strip():
        p.email = None

    if data.phone is not None and data.phone.strip():
        existing_phone = db.query(Parent).filter(Parent.phone == data.phone.strip(), Parent.parent_id != p.parent_id).first()
        if existing_phone:
            raise HTTPException(status_code=400, detail="Số điện thoại này đã được đăng ký bởi phụ huynh khác.")
        p.phone = data.phone.strip()

    c_ids_input = data.child_ids if data.child_ids is not None else ([data.child_id] if data.child_id is not None else None)
    if c_ids_input is not None:
        new_uuids = [uuid.UUID(cid.strip()) for cid in c_ids_input if cid and cid.strip()]
        # Đồng bộ bảng trung gian parent_child
        old_links = db.query(ParentChild).filter(ParentChild.parent_id == p.parent_id).all()
        for link in old_links:
            if link.child_id not in new_uuids:
                ch = db.query(Child).filter(Child.child_id == link.child_id).first()
                if ch and ch.parent_id == p.parent_id:
                    other_link = db.query(ParentChild).filter(
                        ParentChild.child_id == ch.child_id,
                        ParentChild.parent_id != p.parent_id,
                    ).first()
                    ch.parent_id = other_link.parent_id if other_link else None
                db.delete(link)

        existing_cids = {link.child_id for link in old_links if link.child_id in new_uuids}
        for uid in new_uuids:
            if uid not in existing_cids:
                child = db.query(Child).filter(Child.child_id == uid).first()
                if child:
                    new_link = ParentChild(
                        id=uuid.uuid4(),
                        parent_id=p.parent_id,
                        child_id=child.child_id,
                        relationship_=p.relationship_ or "Phụ huynh",
                        is_primary=(child.parent_id is None),
                        can_pickup=True,
                    )
                    db.add(new_link)
                    if child.parent_id is None:
                        child.parent_id = p.parent_id

    # Cập nhật thông tin tài khoản đăng nhập & mật khẩu nếu có
    if data.username is not None or data.password is not None:
        user = db.query(User).filter(User.parent_id == p.parent_id).first()
        if user:
            if data.username and data.username.strip() and data.username.strip() != user.username:
                existing = db.query(User).filter(User.username == data.username.strip(), User.user_id != user.user_id).first()
                if existing:
                    raise HTTPException(status_code=400, detail="Tên đăng nhập này đã tồn tại trên hệ thống. Vui lòng chọn tên khác.")
                user.username = data.username.strip()
            if data.password and data.password.strip():
                user.password_hash = hash_password(data.password.strip())
        elif data.username and data.username.strip():
            existing = db.query(User).filter(User.username == data.username.strip()).first()
            if existing:
                raise HTTPException(status_code=400, detail="Tên đăng nhập này đã tồn tại trên hệ thống. Vui lòng chọn tên khác.")
            pwd = data.password.strip() if data.password and data.password.strip() else "123456"
            new_user = User(
                user_id=uuid.uuid4(),
                username=data.username.strip(),
                password_hash=hash_password(pwd),
                role=UserRole.PARENT,
                parent_id=p.parent_id,
                status=UserStatus.ACTIVE,
                is_verified=True,
            )
            db.add(new_user)

    db.commit()
    return {"message": "Cập nhật phụ huynh thành công"}


@router.delete("/parents/{parent_id}")
def delete_parent(parent_id: str, db: Session = Depends(get_db)):
    p = db.query(Parent).filter(Parent.parent_id == uuid.UUID(parent_id)).first()
    if not p:
        raise HTTPException(status_code=404, detail="Không tìm thấy phụ huynh")

    # Xử lý cập nhật child.parent_id cho các con nếu đang trỏ tới p
    links = db.query(ParentChild).filter(ParentChild.parent_id == p.parent_id).all()
    for link in links:
        ch = db.query(Child).filter(Child.child_id == link.child_id).first()
        if ch and ch.parent_id == p.parent_id:
            other = db.query(ParentChild).filter(
                ParentChild.child_id == ch.child_id,
                ParentChild.parent_id != p.parent_id,
            ).first()
            ch.parent_id = other.parent_id if other else None

    db.delete(p)
    db.commit()
    return {"message": "Đã xóa phụ huynh thành công"}


@router.get("/check-availability")
def check_availability(
    type: str,
    username: str | None = None,
    email: str | None = None,
    phone: str | None = None,
    exclude_id: str | None = None,
    db: Session = Depends(get_db),
):
    """Kiểm tra tên đăng nhập, email hoặc số điện thoại đã tồn tại trên hệ thống hay chưa."""
    username_exists = False
    email_exists = False
    phone_exists = False

    ex_uuid = None
    if exclude_id and exclude_id.strip():
        try:
            ex_uuid = uuid.UUID(exclude_id.strip())
        except Exception:
            ex_uuid = None

    if username and username.strip():
        q_user = db.query(User).filter(User.username == username.strip())
        if ex_uuid:
            if type == "teacher":
                q_user = q_user.filter(User.teacher_id != ex_uuid)
            elif type == "parent":
                q_user = q_user.filter(User.parent_id != ex_uuid)
        username_exists = q_user.first() is not None

    if email and email.strip():
        t_email = email.strip()
        if type == "teacher":
            q_t = db.query(Teacher).filter(Teacher.email == t_email)
            if ex_uuid:
                q_t = q_t.filter(Teacher.teacher_id != ex_uuid)
            email_exists = q_t.first() is not None
        elif type == "parent":
            q_p = db.query(Parent).filter(Parent.email == t_email)
            if ex_uuid:
                q_p = q_p.filter(Parent.parent_id != ex_uuid)
            email_exists = q_p.first() is not None

    if phone and phone.strip():
        t_phone = phone.strip()
        if type == "parent":
            q_p = db.query(Parent).filter(Parent.phone == t_phone)
            if ex_uuid:
                q_p = q_p.filter(Parent.parent_id != ex_uuid)
            phone_exists = q_p.first() is not None
        elif type == "teacher":
            q_t = db.query(Teacher).filter(Teacher.phone == t_phone)
            if ex_uuid:
                q_t = q_t.filter(Teacher.teacher_id != ex_uuid)
            phone_exists = q_t.first() is not None

    return {
        "username_exists": username_exists,
        "email_exists": email_exists,
        "phone_exists": phone_exists,
    }


# ─────────────────────────────────────────────────────────────────────────────
# 3. Children (Students) Endpoints
# ─────────────────────────────────────────────────────────────────────────────


@router.get("/children")
def list_children(db: Session = Depends(get_db)):
    children = db.query(Child).order_by(Child.created_at.desc()).all()
    results = []
    for c in children:
        class_name = c.class_.name if c.class_ else "Chưa xếp lớp"
        note_str = c.medical_allergies or ""
        if note_str.strip().lower() in ["không có", "không", "none"]:
            note_str = ""

        # N-N parents list
        parents_data = []
        for link in c.parent_links:
            if link.parent:
                parents_data.append(
                    {
                        "id": str(link.parent_id),
                        "name": link.parent.full_name,
                        "phone": link.parent.phone,
                        "email": link.parent.email or "",
                        "relationship": link.relationship_ or link.parent.relationship_ or "Phụ huynh",
                        "is_primary": link.is_primary,
                        "can_pickup": link.can_pickup,
                    }
                )

        if not parents_data and c.parent:
            parents_data.append(
                {
                    "id": str(c.parent.parent_id),
                    "name": c.parent.full_name,
                    "phone": c.parent.phone,
                    "email": c.parent.email or "",
                    "relationship": c.parent.relationship_ or "Phụ huynh",
                    "is_primary": True,
                    "can_pickup": True,
                }
            )

        primary_p = next(
            (p for p in parents_data if p["is_primary"]),
            (parents_data[0] if parents_data else None),
        )
        parent_id_val = primary_p["id"] if primary_p else (str(c.parent_id) if c.parent_id else None)
        parent_name_val = primary_p["name"] if primary_p else (c.parent.full_name if c.parent else None)
        parent_phone_val = primary_p["phone"] if primary_p else (c.parent.phone if c.parent else None)

        parents_summary = (
            ", ".join([f"{p['name']} ({p['relationship']})" for p in parents_data if p["name"]])
            if parents_data
            else "Chưa liên kết phụ huynh"
        )

        results.append(
            {
                "id": str(c.child_id),
                "full_name": c.full_name,
                "nickname": c.nickname or "",
                "class_name": class_name,
                "class_id": str(c.class_id) if c.class_id else None,
                "parent_name": parent_name_val,
                "parent_id": parent_id_val,
                "parent_phone": parent_phone_val,
                "parents": parents_data,
                "parent_ids": [p["id"] for p in parents_data],
                "parents_summary": parents_summary,
                "date_of_birth": str(c.date_of_birth) if c.date_of_birth else None,
                "gender": c.gender or "male",
                "note": note_str.strip(),
                "status": c.status.value if hasattr(c.status, "value") else str(c.status),
            }
        )
    return results


@router.post("/children", status_code=status.HTTP_201_CREATED)
def create_child(data: ChildCreate, db: Session = Depends(get_db)):
    class_uuid = uuid.UUID(data.class_id) if data.class_id and data.class_id.strip() else None
    if not class_uuid:
        first_class = db.query(Class_).first()
        class_uuid = first_class.class_id if first_class else None

    note_val = data.medical_allergies.strip() if data.medical_allergies and data.medical_allergies.strip() else None

    # Xác định danh sách phụ huynh và phụ huynh chính
    parent_uuid = uuid.UUID(data.parent_id) if data.parent_id and data.parent_id.strip() else None
    p_ids: list[str] = []
    if data.parent_items:
        p_ids = [item.parent_id for item in data.parent_items if item.parent_id.strip()]
    elif data.parent_ids:
        p_ids = [pid for pid in data.parent_ids if pid and pid.strip()]
    elif data.parent_id and data.parent_id.strip():
        p_ids = [data.parent_id.strip()]

    if not parent_uuid and p_ids:
        parent_uuid = uuid.UUID(p_ids[0])

    parsed_dob = None
    if data.date_of_birth and data.date_of_birth.strip():
        try:
            parsed_dob = date.fromisoformat(data.date_of_birth.strip())
        except Exception:
            pass

    child = Child(
        child_id=uuid.uuid4(),
        full_name=data.full_name.strip(),
        nickname=data.nickname.strip() if data.nickname else None,
        class_id=class_uuid,
        parent_id=parent_uuid,
        medical_allergies=note_val,
        date_of_birth=parsed_dob,
        gender=data.gender.strip() if data.gender else "male",
        status=ChildStatus.ENROLLED,
    )
    db.add(child)
    db.flush()

    # Lưu liên kết N-N vào parent_child
    if data.parent_items:
        for item in data.parent_items:
            p_uid = uuid.UUID(item.parent_id.strip())
            p_obj = db.query(Parent).filter(Parent.parent_id == p_uid).first()
            link = ParentChild(
                id=uuid.uuid4(),
                parent_id=p_uid,
                child_id=child.child_id,
                relationship_=item.relationship or (p_obj.relationship_ if p_obj else "Phụ huynh"),
                is_primary=item.is_primary,
                can_pickup=item.can_pickup,
            )
            db.add(link)
    elif p_ids:
        for idx, pid in enumerate(p_ids):
            p_uid = uuid.UUID(pid.strip())
            p_obj = db.query(Parent).filter(Parent.parent_id == p_uid).first()
            link = ParentChild(
                id=uuid.uuid4(),
                parent_id=p_uid,
                child_id=child.child_id,
                relationship_=p_obj.relationship_ if p_obj else "Phụ huynh",
                is_primary=(idx == 0),
                can_pickup=True,
            )
            db.add(link)

    db.commit()
    db.refresh(child)
    return {"message": "Tạo học sinh thành công", "id": str(child.child_id)}


@router.put("/children/{child_id}")
def update_child(child_id: str, data: ChildUpdate, db: Session = Depends(get_db)):
    c = db.query(Child).filter(Child.child_id == uuid.UUID(child_id)).first()
    if not c:
        raise HTTPException(status_code=404, detail="Không tìm thấy học sinh")

    if data.full_name is not None:
        c.full_name = data.full_name.strip()
    if data.nickname is not None:
        c.nickname = data.nickname.strip() if data.nickname else None
    if data.class_id is not None:
        c.class_id = uuid.UUID(data.class_id.strip()) if data.class_id.strip() else None
    if data.medical_allergies is not None:
        c.medical_allergies = data.medical_allergies.strip() if data.medical_allergies.strip() else None
    if data.date_of_birth is not None:
        if data.date_of_birth.strip():
            try:
                c.date_of_birth = date.fromisoformat(data.date_of_birth.strip())
            except Exception:
                pass
        else:
            c.date_of_birth = None
    if data.gender is not None:
        c.gender = data.gender.strip() if data.gender.strip() else c.gender

    # Đồng bộ liên kết N-N trong parent_child
    if data.parent_items is not None:
        db.query(ParentChild).filter(ParentChild.child_id == c.child_id).delete(synchronize_session=False)
        primary_id = None
        for item in data.parent_items:
            p_uid = uuid.UUID(item.parent_id.strip())
            if item.is_primary or primary_id is None:
                primary_id = p_uid
            p_obj = db.query(Parent).filter(Parent.parent_id == p_uid).first()
            link = ParentChild(
                id=uuid.uuid4(),
                parent_id=p_uid,
                child_id=c.child_id,
                relationship_=item.relationship or (p_obj.relationship_ if p_obj else "Phụ huynh"),
                is_primary=item.is_primary,
                can_pickup=item.can_pickup,
            )
            db.add(link)
        c.parent_id = primary_id
    elif data.parent_ids is not None:
        new_uuids = [uuid.UUID(pid.strip()) for pid in data.parent_ids if pid and pid.strip()]
        db.query(ParentChild).filter(
            ParentChild.child_id == c.child_id,
            ~ParentChild.parent_id.in_(new_uuids),
        ).delete(synchronize_session=False)

        existing_links = db.query(ParentChild).filter(ParentChild.child_id == c.child_id).all()
        existing_pids = {link.parent_id for link in existing_links}
        for idx, p_uid in enumerate(new_uuids):
            if p_uid not in existing_pids:
                p_obj = db.query(Parent).filter(Parent.parent_id == p_uid).first()
                link = ParentChild(
                    id=uuid.uuid4(),
                    parent_id=p_uid,
                    child_id=c.child_id,
                    relationship_=p_obj.relationship_ if p_obj else "Phụ huynh",
                    is_primary=(idx == 0 and not existing_pids),
                    can_pickup=True,
                )
                db.add(link)
        c.parent_id = new_uuids[0] if new_uuids else None
    elif data.parent_id is not None:
        p_uid = uuid.UUID(data.parent_id.strip()) if data.parent_id.strip() else None
        c.parent_id = p_uid
        if p_uid:
            existing = db.query(ParentChild).filter(
                ParentChild.child_id == c.child_id,
                ParentChild.parent_id == p_uid,
            ).first()
            if not existing:
                p_obj = db.query(Parent).filter(Parent.parent_id == p_uid).first()
                link = ParentChild(
                    id=uuid.uuid4(),
                    parent_id=p_uid,
                    child_id=c.child_id,
                    relationship_=p_obj.relationship_ if p_obj else "Phụ huynh",
                    is_primary=True,
                    can_pickup=True,
                )
                db.add(link)

    db.commit()
    return {"message": "Cập nhật học sinh thành công"}


@router.delete("/children/{child_id}")
def delete_child(child_id: str, db: Session = Depends(get_db)):
    c = db.query(Child).filter(Child.child_id == uuid.UUID(child_id)).first()
    if not c:
        raise HTTPException(status_code=404, detail="Không tìm thấy học sinh")

    db.delete(c)
    db.commit()
    return {"message": "Đã xóa học sinh thành công"}


# ─────────────────────────────────────────────────────────────────────────────
# 4. Schedules & TimeSlots Endpoints
# ─────────────────────────────────────────────────────────────────────────────


@router.get("/time-slots")
def list_time_slots(db: Session = Depends(get_db)):
    slots = db.query(TimeSlot).order_by(TimeSlot.order_index.asc()).all()
    return [
        {
            "id": str(s.slot_id),
            "name": s.name,
            "start_time": s.start_time,
            "end_time": s.end_time,
            "order_index": s.order_index,
        }
        for s in slots
    ]


@router.get("/schedules")
def list_schedules(day_of_week: int | None = 2, db: Session = Depends(get_db)):
    query = db.query(ClassSchedule).join(TimeSlot, ClassSchedule.slot_id == TimeSlot.slot_id, isouter=True)
    if day_of_week is not None:
        query = query.filter(ClassSchedule.day_of_week == day_of_week)

    schedules = query.order_by(TimeSlot.order_index.asc(), ClassSchedule.created_at.asc()).all()

    results = []
    for s in schedules:
        slot_name = s.time_slot.name if s.time_slot else "07:00 - 08:00"
        start_time = s.time_slot.start_time if s.time_slot else "07:00"
        end_time = s.time_slot.end_time if s.time_slot else "08:00"
        results.append(
            {
                "id": str(s.schedule_id),
                "activity_name": s.activity_name,
                "content": s.content or "",
                "room_name": s.room_name or (s.class_.name if s.class_ else "Lớp Mầm A"),
                "time_range": slot_name,
                "slot_id": str(s.slot_id) if s.slot_id else None,
                "start_time": start_time,
                "end_time": end_time,
                "day_of_week": s.day_of_week,
                "is_active": s.is_active,
            }
        )
    return results


def _to_minutes(t_str: str) -> int:
    try:
        parts = t_str.strip().split(":")
        return int(parts[0]) * 60 + int(parts[1])
    except (ValueError, IndexError, AttributeError):
        return 0


def _resolve_and_validate_slot(
    db: Session,
    slot_id: str | None,
    start_time: str | None,
    end_time: str | None,
    day_of_week: int,
    exclude_schedule_id: uuid.UUID | None = None,
) -> TimeSlot:
    slot = None
    if slot_id and slot_id.strip():
        slot = db.query(TimeSlot).filter(TimeSlot.slot_id == uuid.UUID(slot_id.strip())).first()

    if not slot and start_time and end_time:
        st = start_time.strip()
        et = end_time.strip()
        st_min = _to_minutes(st)
        et_min = _to_minutes(et)
        if et_min <= st_min:
            raise HTTPException(
                status_code=400,
                detail=f"Khung giờ không hợp lệ: Giờ kết thúc ({et}) phải sau giờ bắt đầu ({st}).",
            )

        slot = db.query(TimeSlot).filter(TimeSlot.start_time == st, TimeSlot.end_time == et).first()
        if not slot:
            slot = TimeSlot(
                slot_id=uuid.uuid4(),
                name=f"{st} - {et}",
                start_time=st,
                end_time=et,
                order_index=st_min,
            )
            db.add(slot)
            db.flush()

    if not slot:
        slot = db.query(TimeSlot).first()

    if not slot:
        raise HTTPException(status_code=400, detail="Không tìm thấy khung giờ phù hợp.")

    # Overlap / Collision Check against other schedules on day_of_week
    t_start = _to_minutes(slot.start_time)
    t_end = _to_minutes(slot.end_time)

    query = (
        db.query(ClassSchedule)
        .join(TimeSlot, ClassSchedule.slot_id == TimeSlot.slot_id)
        .filter(ClassSchedule.day_of_week == day_of_week)
    )
    if exclude_schedule_id:
        query = query.filter(ClassSchedule.schedule_id != exclude_schedule_id)

    for other in query.all():
        if other.time_slot:
            o_start = _to_minutes(other.time_slot.start_time)
            o_end = _to_minutes(other.time_slot.end_time)
            # Overlap: t_start < o_end and t_end > o_start
            if t_start < o_end and t_end > o_start:
                raise HTTPException(
                    status_code=400,
                    detail=f"Khung giờ ({slot.name}) bị trùng hoặc đè lên hoạt động '{other.activity_name}' ({other.time_slot.name}).",
                )

    return slot


@router.post("/schedules", status_code=status.HTTP_201_CREATED)
def create_schedule(data: ScheduleCreate, db: Session = Depends(get_db)):
    first_class = db.query(Class_).first()
    first_teacher = db.query(Teacher).first()
    first_subject = db.query(Subject).first()

    target_slot = _resolve_and_validate_slot(
        db,
        slot_id=data.slot_id,
        start_time=data.start_time,
        end_time=data.end_time,
        day_of_week=data.day_of_week,
    )

    schedule = ClassSchedule(
        schedule_id=uuid.uuid4(),
        class_id=uuid.UUID(data.class_id) if data.class_id else (first_class.class_id if first_class else uuid.uuid4()),
        subject_id=first_subject.subject_id if first_subject else uuid.uuid4(),
        slot_id=target_slot.slot_id,
        teacher_id=uuid.UUID(data.teacher_id) if data.teacher_id else (first_teacher.teacher_id if first_teacher else None),
        day_of_week=data.day_of_week,
        activity_name=data.activity_name.strip(),
        content=data.content.strip() if data.content else None,
        room_name=data.room_name.strip() if data.room_name else "Phòng học",
        is_active=True,
    )
    db.add(schedule)
    db.commit()
    db.refresh(schedule)
    return {"message": "Tạo lịch sinh hoạt thành công", "id": str(schedule.schedule_id)}


@router.put("/schedules/{schedule_id}")
def update_schedule(schedule_id: str, data: ScheduleUpdate, db: Session = Depends(get_db)):
    s = db.query(ClassSchedule).filter(ClassSchedule.schedule_id == uuid.UUID(schedule_id)).first()
    if not s:
        raise HTTPException(status_code=404, detail="Không tìm thấy lịch sinh hoạt")

    if data.activity_name is not None:
        s.activity_name = data.activity_name.strip()
    if data.content is not None:
        s.content = data.content.strip()
    if data.room_name is not None:
        s.room_name = data.room_name.strip()
    if data.day_of_week is not None:
        s.day_of_week = data.day_of_week

    if data.slot_id is not None or (data.start_time is not None and data.end_time is not None):
        target_slot = _resolve_and_validate_slot(
            db,
            slot_id=data.slot_id,
            start_time=data.start_time,
            end_time=data.end_time,
            day_of_week=s.day_of_week,
            exclude_schedule_id=s.schedule_id,
        )
        s.slot_id = target_slot.slot_id

    db.commit()
    return {"message": "Cập nhật lịch sinh hoạt thành công"}


@router.delete("/schedules/{schedule_id}")
def delete_schedule(schedule_id: str, db: Session = Depends(get_db)):
    s = db.query(ClassSchedule).filter(ClassSchedule.schedule_id == uuid.UUID(schedule_id)).first()
    if not s:
        raise HTTPException(status_code=404, detail="Không tìm thấy lịch sinh hoạt")

    db.delete(s)
    db.commit()
    return {"message": "Đã xóa lịch sinh hoạt thành công"}
