import logging
import secrets
import time
import uuid
from collections.abc import Callable
from datetime import datetime, timezone
from typing import Any

import redis
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from passlib.context import CryptContext
from sqlalchemy.orm import Session

from app.config import settings
from app.core.database import get_db
from app.models.user import User

logger = logging.getLogger(__name__)

# Cấu hình Token & Phiên
SECRET_KEY = getattr(settings, "jwt_secret_key", "kinderlog-secret")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_SECONDS = 15 * 60  # 15 phút
REFRESH_TOKEN_EXPIRE_SECONDS = 30 * 24 * 60 * 60  # 30 ngày
MAX_CONCURRENT_DEVICES = 4

KEY_SESSION_PREFIX = "session:"
KEY_USER_SESSIONS_PREFIX = "user_sessions:"

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/login")
oauth2_scheme_optional = OAuth2PasswordBearer(tokenUrl="/api/auth/login", auto_error=False)


def get_redis_client() -> redis.Redis:
    """Khởi tạo Redis client."""
    return redis.from_url(
        settings.redis_url,
        decode_responses=True,
        socket_timeout=3.0,
    )


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)


def create_access_token(user_id: str, role: str, session_id: str | None = None) -> str:
    now = int(time.time())
    expire = now + ACCESS_TOKEN_EXPIRE_SECONDS
    payload = {
        "sub": str(user_id),
        "role": role,
        "session_id": str(session_id) if session_id else None,
        "iat": now,
        "exp": expire,
    }
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


# ─── QUẢN LÝ PHIÊN TRÊN REDIS (TỐI ĐA 4 MÁY - ĐÁ MÁY CŨ NHẤT LRU) ───────────
def create_session(user_id: str, role: str, device_id: str, device_name: str) -> dict[str, Any]:
    client = get_redis_client()
    user_id_str = str(user_id)
    device_id_clean = (device_id or "default_device").strip()
    device_name_clean = (device_name or "Thiết bị không rõ").strip()
    user_sessions_key = f"{KEY_USER_SESSIONS_PREFIX}{user_id_str}"
    now_ts = int(time.time())

    # 1. Nếu thiết bị này đã có session cũ -> xóa trước khi cấp mới
    existing_sessions = client.zrange(user_sessions_key, 0, -1)
    for old_sid in existing_sessions:
        old_key = f"{KEY_SESSION_PREFIX}{old_sid}"
        if client.hget(old_key, "device_id") == device_id_clean:
            client.delete(old_key)
            client.zrem(user_sessions_key, old_sid)

    # 2. Vượt quá 4 thiết bị -> Đá thiết bị ít hoạt động nhất (score nhỏ nhất trong ZSET)
    if client.zcard(user_sessions_key) >= MAX_CONCURRENT_DEVICES:
        oldest = client.zrange(user_sessions_key, 0, 0)
        if oldest:
            client.delete(f"{KEY_SESSION_PREFIX}{oldest[0]}")
            client.zrem(user_sessions_key, oldest[0])

    # 3. Tạo phiên mới với TTL 30 ngày
    session_id = str(uuid.uuid4())
    refresh_token = secrets.token_urlsafe(48)
    session_key = f"{KEY_SESSION_PREFIX}{session_id}"

    client.hset(
        session_key,
        mapping={
            "session_id": session_id,
            "user_id": user_id_str,
            "role": role,
            "device_id": device_id_clean,
            "device_name": device_name_clean,
            "refresh_token": refresh_token,
            "last_active_at": datetime.now(timezone.utc).isoformat(),
        },
    )
    client.expire(session_key, REFRESH_TOKEN_EXPIRE_SECONDS)
    client.zadd(user_sessions_key, {session_id: now_ts})

    access_token = create_access_token(user_id=user_id_str, role=role, session_id=session_id)
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "session_id": session_id,
    }


def refresh_session(session_id: str, refresh_token: str) -> dict[str, Any]:
    client = get_redis_client()
    session_key = f"{KEY_SESSION_PREFIX}{session_id}"
    data = client.hgetall(session_key)

    if not data or not secrets.compare_digest(data.get("refresh_token", ""), refresh_token):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Phiên làm việc đã hết hạn. Vui lòng đăng nhập lại.",
        )

    user_id = data["user_id"]
    role = data["role"]
    new_refresh = secrets.token_urlsafe(48)
    now_ts = int(time.time())

    # Gia hạn thêm 30 ngày (Sliding Window)
    client.hset(
        session_key,
        mapping={
            "refresh_token": new_refresh,
            "last_active_at": datetime.now(timezone.utc).isoformat(),
        },
    )
    client.expire(session_key, REFRESH_TOKEN_EXPIRE_SECONDS)
    client.zadd(f"{KEY_USER_SESSIONS_PREFIX}{user_id}", {session_id: now_ts})

    new_access = create_access_token(user_id=user_id, role=role, session_id=session_id)
    return {
        "access_token": new_access,
        "refresh_token": new_refresh,
        "session_id": session_id,
        "token_type": "bearer",
    }


def validate_session(session_id: str) -> bool:
    try:
        return bool(get_redis_client().exists(f"{KEY_SESSION_PREFIX}{session_id}"))
    except redis.RedisError as e:
        logger.warning("Lỗi kiểm tra session trên Redis: %s", e)
        return True


def revoke_session(session_id: str) -> None:
    try:
        client = get_redis_client()
        session_key = f"{KEY_SESSION_PREFIX}{session_id}"
        user_id = client.hget(session_key, "user_id")
        client.delete(session_key)
        if user_id:
            client.zrem(f"{KEY_USER_SESSIONS_PREFIX}{user_id}", session_id)
    except redis.RedisError as e:
        logger.error("Lỗi khi revoke session: %s", e)


def revoke_other_sessions(user_id: str, current_session_id: str) -> None:
    try:
        client = get_redis_client()
        user_sessions_key = f"{KEY_USER_SESSIONS_PREFIX}{user_id}"
        for sid in client.zrange(user_sessions_key, 0, -1):
            if sid != current_session_id:
                client.delete(f"{KEY_SESSION_PREFIX}{sid}")
                client.zrem(user_sessions_key, sid)
    except redis.RedisError as e:
        logger.error("Lỗi khi revoke other sessions: %s", e)


# ─── XÁC THỰC CURRENT USER ──────────────────────────────────────────────────
def get_current_user(
    token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)
) -> User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Không thể xác thực thông tin đăng nhập",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id = payload.get("sub")
        session_id = payload.get("session_id")

        if user_id is None:
            raise credentials_exception

        # Nếu có session_id thì kiểm tra xem phiên còn tồn tại trên Redis không
        if session_id and not validate_session(session_id):
            raise credentials_exception

        user_uuid = uuid.UUID(str(user_id))
    except (JWTError, ValueError) as exc:
        raise credentials_exception from exc

    user = db.query(User).filter(User.user_id == user_uuid).first()
    if user is None:
        raise credentials_exception
    return user


def get_optional_current_user(
    token: str | None = Depends(oauth2_scheme_optional),
    db: Session = Depends(get_db),
) -> User | None:
    if not token:
        return None
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id = payload.get("sub")
        if user_id is None:
            return None
        user_uuid = uuid.UUID(str(user_id))
    except (JWTError, ValueError):
        return None
    return db.query(User).filter(User.user_id == user_uuid).first()


def require_role(required_role: str) -> Callable:
    def role_checker(current_user: User = Depends(get_current_user)) -> User:
        if current_user.role.value != required_role:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Bạn không có quyền truy cập",
            )
        return current_user

    return role_checker