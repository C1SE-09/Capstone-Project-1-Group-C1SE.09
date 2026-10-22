"""
app/services/health_profile_service.py
======================================
Quy tắc chuẩn hóa và ghi dữ liệu hồ sơ sức khỏe dài hạn của bé.

Dùng chung cho route phụ huynh (PATCH có kiểm tra version) và route admin
(PUT last-write-wins), để hai nơi không lưu lệch nhau.
"""

from datetime import UTC, datetime

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.core.access import role_of
from app.models.child import Child
from app.models.user import User

MAX_HEALTH_TEXT = 1000
NO_ALLERGY_VALUES = {"không", "không có", "none"}
ALLERGY_STATUSES = {"unknown", "none", "present"}
WRITE_SOURCES = {"parent", "admin"}


def classify_legacy_allergy(text: str | None) -> str:
    """Phân loại text dị ứng cũ (trước khi có allergy_status)."""
    raw = (text or "").strip()
    if not raw:
        return "unknown"
    if raw.casefold() in NO_ALLERGY_VALUES:
        return "none"
    return "present"


def normalize_health_values(
    *, allergy_status: str, medical_allergies: str | None, care_notes: str | None
) -> dict[str, str | None]:
    if allergy_status not in ALLERGY_STATUSES:
        raise HTTPException(status_code=422, detail="Trạng thái dị ứng không hợp lệ")
    allergy_text = (medical_allergies or "").strip() or None
    notes = (care_notes or "").strip() or None
    if allergy_status == "present":
        if not allergy_text:
            raise HTTPException(
                status_code=422, detail="Vui lòng nhập mô tả dị ứng của bé"
            )
    else:
        allergy_text = None
    return {
        "allergy_status": allergy_status,
        "medical_allergies": allergy_text,
        "care_notes": notes,
    }


def ensure_within_limits(
    *, medical_allergies: str | None, care_notes: str | None
) -> None:
    """Chỉ kiểm tra field client thực sự gửi (None = không kiểm tra)."""
    if medical_allergies is not None and len(medical_allergies) > MAX_HEALTH_TEXT:
        raise HTTPException(status_code=422, detail="Mô tả dị ứng vượt quá 1000 ký tự")
    if care_notes is not None and len(care_notes) > MAX_HEALTH_TEXT:
        raise HTTPException(status_code=422, detail="Lưu ý chăm sóc vượt quá 1000 ký tự")


def apply_health_patch(
    db: Session,
    child: Child,
    changes: dict,
    expected_version: int,
    actor: User,
) -> Child:
    """Ghi thay đổi sức khỏe; 409 nếu version lệch, không đổi gì nếu giá trị như cũ."""
    source = role_of(actor)
    if source not in WRITE_SOURCES:
        raise HTTPException(status_code=403, detail="Bạn không có quyền cập nhật")

    status = changes.get("allergy_status")
    text = (
        changes["medical_allergies"]
        if "medical_allergies" in changes
        else child.medical_allergies
    )
    notes = changes["care_notes"] if "care_notes" in changes else child.care_notes
    if status is None:
        status = child.allergy_status or "unknown"
        # Client gửi mô tả dị ứng mà không gửi trạng thái ⇒ hiểu là "có dị ứng",
        # tránh việc nuốt mất text vì trạng thái cũ là none/unknown.
        if (text or "").strip() and status != "present":
            status = "present"

    values = normalize_health_values(
        allergy_status=status, medical_allergies=text, care_notes=notes
    )

    current = (
        child.allergy_status or "unknown",
        child.medical_allergies,
        child.care_notes,
    )
    if (
        values["allergy_status"],
        values["medical_allergies"],
        values["care_notes"],
    ) == current:
        return child

    # Dữ liệu cũ dài hơn 1000 chỉ bị chặn khi thực sự thay đổi.
    ensure_within_limits(
        medical_allergies=(
            values["medical_allergies"]
            if values["medical_allergies"] != child.medical_allergies
            else None
        ),
        care_notes=(
            values["care_notes"] if values["care_notes"] != child.care_notes else None
        ),
    )

    result = (
        db.query(Child)
        .filter(
            Child.child_id == child.child_id,
            Child.health_version == expected_version,
        )
        .update(
            {
                **values,
                "health_updated_at": datetime.now(UTC),
                "health_updated_by_user_id": actor.user_id,
                "health_update_source": source,
                "health_version": Child.health_version + 1,
            },
            synchronize_session=False,
        )
    )
    if result != 1:
        db.rollback()
        raise HTTPException(
            status_code=409, detail="Hồ sơ vừa được cập nhật ở nơi khác"
        )
    db.commit()
    db.refresh(child)
    return child
