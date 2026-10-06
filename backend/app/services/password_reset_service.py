import secrets

import redis
from app.config import settings

OTP_EXPIRATION_SECONDS = 300  # 5 minutes
MAX_OTP_ATTEMPTS = 5  # Maximum number of attempts to verify OTP
OTP_KEY_PREFIX = "password_reset:"  # Prefix for OTP keys in Redis

def get_redis_client():
    return redis.from_url(
        settings.redis_url,
        decode_responses=True
    )

def generate_reset_code() -> str:
    """Generate a secure random 6-digit reset code."""
    return f"{secrets.randbelow(1_000_000):06d}"

def save_reset_code(email: str, reset_code: str):
    client = get_redis_client()
    key = f"{OTP_KEY_PREFIX}{email.lower().strip()}"

    client.hset(
        key,
        mapping = {
            "reset_code": reset_code,
            "attempts": 0
        }
    )
    client.expire(key, OTP_EXPIRATION_SECONDS)

def verify_reset_code(email: str, reset_code: str) -> bool:
    client = get_redis_client()
    key = f"{OTP_KEY_PREFIX}{email.lower().strip()}"

    data = client.hgetall(key)

    if not data:
        return False

    if int(data.get("attempts", 0)) >= MAX_OTP_ATTEMPTS:
        client.delete(key)
        return False

    if data.get("reset_code") != reset_code:
        client.hincrby(key, "attempts", 1)
        return False

    client.hset(key, "verified", "1")
    return True

def is_reset_code_verified(email: str) -> bool:
    client = get_redis_client()
    key = f"{OTP_KEY_PREFIX}{email.lower().strip()}"

    data = client.hgetall(key)

    return bool(data) and data.get("verified") == "1"

def delete_reset_code(email: str):
    client = get_redis_client()
    key = f"{OTP_KEY_PREFIX}{email.lower().strip()}"
    client.delete(key)
