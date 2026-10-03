from fastapi import APIRouter, Depends

from app.core.security import require_role
from app.models.user import User

router = APIRouter(
    prefix="/api/parent",
    tags=["parent"]
)

@router.get("/me")
def get_parent_me(current_user: User = Depends(require_role("parent"))):
    return{
        "user_id": str(current_user.user_id),
        "role": current_user.role.value,
        "parent_id": str(current_user.parent_id)
    }