"""
backend/app/api/endpoints/health_incident.py
============================================
API Cảnh báo sự cố sức khỏe khẩn cấp tại lớp cho Giáo viên (Task #285):
- POST  /api/teacher/health-incidents: Phát cảnh báo khẩn cấp 1 chạm (< 30s) + trả về danh bạ gọi trực tiếp
- GET   /api/teacher/health-incidents/emergency-contacts/{child_id}: Lấy nhanh SĐT bố/mẹ để gọi 1 chạm tức thì
- PATCH /api/teacher/health-incidents/{incident_id}: Cập nhật bổ sung biên bản sau khi bé đã ổn định
"""

from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.core.database import get_db
from app.core.security import get_current_user
from app.models.child import Child, ParentChild
from app.models.health_incident import HealthIncident, HealthIncidentType
from app.models.user import Teacher, User, UserRole
from app.schemas.health_incident_schema import (
    ChildEmergencyContactsResponse,
    EmergencyContactInfo,
    HealthIncidentCreate,
    HealthIncidentResponse,
    HealthIncidentUpdate,
)
from app.tasks.incident_notifications import (
    INCIDENT_LABELS,
    deliver_health_incident_alert_sync,
    send_health_incident_alert_task,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/teacher/health-incidents", tags=["teacher-health-incidents"])


def verify_child_access(child: Child, current_user: User, db: Session) -> None:
    """Kiểm tra giáo viên có quyền quản lý học sinh này không."""
    role_val = current_user.role.value if hasattr(current_user.role, "value") else str(current_user.role)
    if role_val == UserRole.ADMIN.value:
        return

    if role_val == UserRole.TEACHER.value:
        if not current_user.teacher_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Tài khoản giáo viên chưa được liên kết với hồ sơ nhân sự",
            )
        teacher = db.scalar(select(Teacher).where(Teacher.teacher_id == current_user.teacher_id))
        if not teacher or teacher.class_id != child.class_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Bạn không có quyền quản lý học sinh thuộc lớp này",
            )
        return

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Chức năng này chỉ dành cho Giáo viên phụ trách lớp và Quản trị viên",
    )


def extract_emergency_contacts(child: Child, db: Session) -> list[EmergencyContactInfo]:
    """
    Trích xuất toàn bộ danh bạ liên lạc khẩn cấp của bố và mẹ bé
    (hỗ trợ cả quan hệ N-N ParentChild và quan hệ 1-N truyền thống).
    """
    contacts: list[EmergencyContactInfo] = []
    seen_phones: set[str] = set()

    # 1. Kiểm tra bảng liên kết N-N (ParentChild)
    parent_links = db.scalars(
        select(ParentChild)
        .options(joinedload(ParentChild.parent))
        .where(ParentChild.child_id == child.child_id)
    ).all()

    for link in parent_links:
        p = link.parent
        if p and p.phone and p.phone not in seen_phones:
            seen_phones.add(p.phone)
            rel_name = link.relationship or (p.relationship if p else None) or "Phụ huynh"
            contacts.append(
                EmergencyContactInfo(
                    name=p.full_name or "Phụ huynh",
                    relationship=rel_name,
                    phone=p.phone,
                )
            )

    # 2. Kiểm tra phụ huynh liên kết trực tiếp (child.parent) nếu chưa có trong danh sách
    if child.parent and child.parent.phone and child.parent.phone not in seen_phones:
        seen_phones.add(child.parent.phone)
        contacts.append(
            EmergencyContactInfo(
                name=child.parent.full_name or "Phụ huynh",
                relationship=child.parent.relationship or "Phụ huynh",
                phone=child.parent.phone,
            )
        )

    return contacts


# ===========================================================================
# 1. POST /api/teacher/health-incidents (1 chạm phát cảnh báo khẩn cấp)
# ===========================================================================
@router.post("", response_model=HealthIncidentResponse, status_code=status.HTTP_201_CREATED)
def create_health_incident(
    payload: HealthIncidentCreate,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    [TASK #285] Phát cảnh báo khẩn cấp 1 chạm:
    - Tối ưu cho tình huống nguy cấp: Hỗ trợ ZERO-TYPING (không bắt buộc cô phải gõ chữ).
    - Tự động sinh mô tả khẩn cấp nếu cô không nhập.
    - Kích hoạt Priority Push Alert (< 30s) đến tất cả các tài khoản phụ huynh.
    - Trả về danh bạ SĐT Bố/Mẹ để màn hình cô hiện ngay nút bấm gọi điện thoại khẩn cấp.
    """
    # 1. Tìm học sinh và kiểm tra quyền
    child = db.scalar(
        select(Child)
        .options(joinedload(Child.parent))
        .where(Child.child_id == payload.child_id)
    )
    if not child:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Không tìm thấy thông tin học sinh",
        )
    if not child.class_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Học sinh chưa được phân vào lớp học",
        )

    verify_child_access(child, current_user, db)

    # 2. Tự động sinh câu mô tả chuẩn nếu cô không gõ (Zero-typing friendly)
    desc = payload.description.strip() if payload.description and payload.description.strip() else None
    type_val = payload.incident_type.value if hasattr(payload.incident_type, "value") else str(payload.incident_type)
    type_label = INCIDENT_LABELS.get(type_val, "Sự cố sức khỏe")

    if not desc:
        if type_val == HealthIncidentType.HIGH_FEVER.value:
            temp_text = f" ({payload.temperature}°C)" if payload.temperature else ""
            desc = f"Bé sốt cao đột xuất{temp_text}, người mệt và quấy khóc."
        elif type_val == HealthIncidentType.SEVERE_INJURY.value:
            desc = "Bé gặp tai nạn / chấn thương tại lớp, cô đang sơ cứu và cần gia đình phối hợp gấp."
        elif type_val == HealthIncidentType.ACUTE_ALLERGY.value:
            desc = "Bé có dấu hiệu dị ứng cấp tính (nổi mẩn, khó chịu), cần gia đình hỗ trợ gấp."
        else:
            desc = "Bé gặp sự cố sức khỏe đột xuất tại lớp, cô giáo đang theo dõi và chăm sóc."

    now_utc = datetime.now(timezone.utc)
    teacher_name = None
    if current_user.teacher_id:
        teacher = db.scalar(select(Teacher).where(Teacher.teacher_id == current_user.teacher_id))
        teacher_name = teacher.full_name if teacher else current_user.username
    else:
        teacher_name = current_user.username

    # 3. Lưu vào Database
    incident = HealthIncident(
        incident_id=uuid.uuid4(),
        child_id=child.child_id,
        class_id=child.class_id,
        reported_by_id=current_user.teacher_id,
        incident_type=type_val,
        description=desc,
        temperature=payload.temperature,
        action_taken=payload.action_taken,
        reported_at=now_utc,
    )
    db.add(incident)
    db.commit()
    db.refresh(incident)

    # 4. Bắn Push Alert khẩn cấp mức ưu tiên cao (< 30s)
    try:
        send_health_incident_alert_task.delay(str(incident.incident_id))
    except Exception as exc:
        logger.info(
            "[Incident] Celery queue không khả dụng, gửi qua FastAPI BackgroundTasks: %s",
            exc,
        )
        background_tasks.add_task(
            deliver_health_incident_alert_sync,
            str(incident.incident_id),
        )

    # 5. Lấy danh bạ khẩn cấp của phụ huynh để cô bấm gọi ngay
    emergency_contacts = extract_emergency_contacts(child, db)

    return HealthIncidentResponse(
        incident_id=incident.incident_id,
        child_id=child.child_id,
        child_name=child.full_name,
        child_nickname=child.nickname,
        child_avatar_url=child.avatar_url,
        class_id=child.class_id,
        incident_type=type_val,
        incident_type_label=type_label,
        description=incident.description,
        temperature=incident.temperature,
        action_taken=incident.action_taken,
        reported_at=incident.reported_at,
        reported_by_id=current_user.teacher_id,
        reported_by_name=teacher_name,
        emergency_contacts=emergency_contacts,
    )


# ===========================================================================
# 2. GET /api/teacher/health-incidents/emergency-contacts/{child_id} (Tra cứu SĐT gọi ngay)
# ===========================================================================
@router.get("/emergency-contacts/{child_id}", response_model=ChildEmergencyContactsResponse)
def get_child_emergency_contacts(
    child_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Tra cứu nhanh danh bạ khẩn cấp của học sinh:
    Cô có thể bấm vào thẻ học sinh để lấy ngay số Bố/Mẹ và gọi điện SIM trực tiếp
    mà không nhất thiết phải tạo cảnh báo sự cố trước.
    """
    child = db.scalar(
        select(Child)
        .options(joinedload(Child.parent), joinedload(Child.class_))
        .where(Child.child_id == child_id)
    )
    if not child:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Không tìm thấy thông tin học sinh",
        )

    verify_child_access(child, current_user, db)
    contacts = extract_emergency_contacts(child, db)

    class_name = child.class_.name if child.class_ else None

    return ChildEmergencyContactsResponse(
        child_id=child.child_id,
        child_name=child.full_name,
        class_name=class_name,
        emergency_contacts=contacts,
    )


# ===========================================================================
# 3. PATCH /api/teacher/health-incidents/{incident_id} (Bổ sung biên bản sau khi bé đã ổn định)
# ===========================================================================
@router.patch("/{incident_id}", response_model=HealthIncidentResponse)
def update_health_incident(
    incident_id: uuid.UUID,
    payload: HealthIncidentUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Bổ sung biên bản chi tiết sự việc:
    Sau khi cô đã gọi điện cho bố mẹ và tình trạng của bé đã an toàn/ổn định,
    cô có thể vào cập nhật thêm nhiệt độ, diễn biến hoặc biện pháp xử lý.
    """
    incident = db.scalar(
        select(HealthIncident)
        .options(
            joinedload(HealthIncident.child),
            joinedload(HealthIncident.reported_by),
        )
        .where(HealthIncident.incident_id == incident_id)
    )
    if not incident or not incident.child:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Không tìm thấy sự cố sức khỏe",
        )

    verify_child_access(incident.child, current_user, db)

    if payload.description is not None:
        incident.description = payload.description
    if payload.temperature is not None:
        incident.temperature = payload.temperature
    if payload.action_taken is not None:
        incident.action_taken = payload.action_taken

    db.commit()
    db.refresh(incident)

    child = incident.child
    teacher_name = incident.reported_by.full_name if incident.reported_by else current_user.username
    emergency_contacts = extract_emergency_contacts(child, db)

    return HealthIncidentResponse(
        incident_id=incident.incident_id,
        child_id=child.child_id,
        child_name=child.full_name,
        child_nickname=child.nickname,
        child_avatar_url=child.avatar_url,
        class_id=incident.class_id,
        incident_type=incident.incident_type,
        incident_type_label=INCIDENT_LABELS.get(incident.incident_type, "Sự cố sức khỏe"),
        description=incident.description,
        temperature=incident.temperature,
        action_taken=incident.action_taken,
        reported_at=incident.reported_at,
        reported_by_id=incident.reported_by_id,
        reported_by_name=teacher_name,
        emergency_contacts=emergency_contacts,
    )
