"""
app/api/child_health.py
=======================
Hồ sơ sức khỏe dài hạn của bé: phụ huynh tự cập nhật, giáo viên chỉ đọc.
"""

import uuid
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy.orm import Session

from app.api.dashboard import _child_dict
from app.core.access import resolve_child_for_actor
from app.core.database import get_db
from app.core.security import require_any_role
from app.models.user import User
from app.services.health_profile_service import apply_health_patch

router = APIRouter(prefix="/api/children", tags=["child-health"])


class HealthProfilePatch(BaseModel):
    model_config = ConfigDict(extra="forbid")

    allergy_status: Literal["unknown", "none", "present"] | None = None
    medical_allergies: str | None = None
    care_notes: str | None = None
    expected_version: int = Field(ge=1)


@router.get("/{child_id}/health-profile")
def get_health_profile(
    child_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_any_role("parent", "teacher", "admin")),
):
    """Trả hồ sơ sức khỏe của bé nếu actor có quyền đọc."""
    child = resolve_child_for_actor(db, child_id, current_user)
    return _child_dict(child)


@router.patch("/{child_id}/health-profile")
def update_health_profile(
    child_id: uuid.UUID,
    data: HealthProfilePatch,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_any_role("parent", "admin")),
):
    """Phụ huynh/admin cập nhật; lệch version ⇒ 409, không ghi đè."""
    child = resolve_child_for_actor(db, child_id, current_user)
    changes = {
        name: getattr(data, name)
        for name in data.model_fields_set
        if name != "expected_version"
    }
    if not changes:
        raise HTTPException(status_code=422, detail="Không có thay đổi để lưu")
    if "allergy_status" in changes and changes["allergy_status"] is None:
        raise HTTPException(status_code=422, detail="Trạng thái dị ứng không hợp lệ")
    child = apply_health_patch(db, child, changes, data.expected_version, current_user)
    return _child_dict(child)
