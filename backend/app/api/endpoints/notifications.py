from app.core.database import get_db
from app.core.security import get_current_user
from app.models.device_token import DeviceToken
from app.models.user import User
from app.schemas.notification_schema import (
    DeviceTokenRequest,
    DeviceTokenResponse,
    TestNotificationRequest,
)
from app.services.notification_service import send_push_notification
from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

router = APIRouter(
    prefix="/api/notifications",
    tags=["Notifications"],
)


@router.post(
    "/device-token",
    response_model=DeviceTokenResponse,
    status_code=status.HTTP_201_CREATED,
)
def register_device_token(
    request: DeviceTokenRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    device_token = (
        db.query(DeviceToken)
        .filter(
            DeviceToken.user_id == current_user.user_id,
            DeviceToken.token == request.token,
        )
        .first()
    )

    if device_token:
        device_token.device_type = request.device_type
    else:
        device_token = DeviceToken(
            user_id=current_user.user_id,
            token=request.token,
            device_type=request.device_type,
        )
        db.add(device_token)

    db.commit()

    return DeviceTokenResponse(
        message="Device token registered successfully",
    )

@router.delete(
    "/device-token",
    response_model=DeviceTokenResponse,
)
def delete_device_token(
    request: DeviceTokenRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    device_token = (
        db.query(DeviceToken)
        .filter(
            DeviceToken.user_id == current_user.user_id,
            DeviceToken.token == request.token,
        )
        .first()
    )

    if device_token:
        db.delete(device_token)
        db.commit()

    return DeviceTokenResponse(
        message="Device token removed successfully",
    )

@router.post(
    "/test",
)
def send_test_notification(
    request: TestNotificationRequest,
    current_user: User = Depends(get_current_user),
):
    message_id = send_push_notification(
        token=request.token,
        title=request.title,
        body=request.body,
    )

    return {
        "message": "Test notification sent successfully",
        "message_id": message_id,
    }