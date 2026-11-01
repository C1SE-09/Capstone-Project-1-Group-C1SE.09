"""
backend/tests/test_session_lru.py
=================================
Test cho cơ chế quản lý phiên trên Redis (app.core.security).

Bối cảnh bug (admin-web trên VPS bị tự đăng xuất ở trang Học sinh &
Sổ sức khoẻ, 2 trang duy nhất bắt buộc validate session):

  1. `create_session` xoá NGAY phiên cũ có cùng `device_id`.
     -> Đăng nhập ở trình duyệt B giết phiên của trình duyệt A
        (nếu cả hai dùng chung device_id) => A bị 401 liên tục.
  2. Score LRU của session là thời điểm ĐĂNG NHẬP, không phải thời điểm
     HOẠT ĐỘNG => phiên đang mở trên web bị đá chỉ vì máy khác đăng nhập sau.
  3. Entry cũ sót trong ZSET làm zcard phình to => đá nhầm phiên đang dùng.
  4. `get_current_user` không cập nhật score => không có tín hiệu hoạt động.
"""

from __future__ import annotations

from unittest.mock import MagicMock

import pytest

from app.core import security


class FakeRedis:
    """Redis giả lập đủ các lệnh mà app.core.security dùng."""

    def __init__(self) -> None:
        self.hashes: dict[str, dict[str, str]] = {}
        self.zsets: dict[str, dict[str, float]] = {}
        self.ttls: dict[str, int] = {}

    # --- Hash ---
    def hset(self, key: str, mapping: dict[str, str]) -> None:
        self.hashes.setdefault(key, {}).update(mapping)

    def hget(self, key: str, field: str) -> str | None:
        return self.hashes.get(key, {}).get(field)

    def hgetall(self, key: str) -> dict[str, str]:
        return dict(self.hashes.get(key, {}))

    # --- Key ---
    def exists(self, key: str) -> int:
        return 1 if key in self.hashes else 0

    def delete(self, *keys: str) -> None:
        for key in keys:
            self.hashes.pop(key, None)
            self.ttls.pop(key, None)

    def expire(self, key: str, seconds: int) -> None:
        self.ttls[key] = seconds

    # --- Sorted set ---
    def zadd(self, key: str, mapping: dict[str, float]) -> None:
        self.zsets.setdefault(key, {}).update(mapping)

    def zrem(self, key: str, *members: str) -> None:
        zset = self.zsets.get(key, {})
        for member in members:
            zset.pop(member, None)

    def zcard(self, key: str) -> int:
        return len(self.zsets.get(key, {}))

    def zrange(self, key: str, start: int, end: int, withscores: bool = False):
        members = sorted(
            self.zsets.get(key, {}).items(), key=lambda item: item[1]
        )
        sliced = members[start:] if end == -1 else members[start : end + 1]
        if withscores:
            return [(member, score) for member, score in sliced]
        return [member for member, _ in sliced]


@pytest.fixture()
def fake_redis(monkeypatch) -> FakeRedis:
    client = FakeRedis()
    monkeypatch.setattr(security, "get_redis_client", lambda: client)
    return client


USER_ID = "aaaaaaaa-0000-0000-0000-000000000001"


def _login(fake_redis: FakeRedis, device_id: str, device_name: str = "Web") -> dict:
    return security.create_session(
        user_id=USER_ID,
        role="admin",
        device_id=device_id,
        device_name=device_name,
    )


class TestSameDeviceReLogin:
    """AC1: Đăng nhập lại trên CÙNG thiết bị không được xoá phiên đang dùng."""

    def test_relogin_same_device_keeps_previous_session_alive(
        self, fake_redis: FakeRedis
    ) -> None:
        first = _login(fake_redis, "device_A")
        second = _login(fake_redis, "device_A")

        # Phiên cũ vẫn còn trên Redis => request đang chạy không bị 401.
        assert fake_redis.exists(f"session:{first['session_id']}") == 1
        # Phiên mới cũng tồn tại.
        assert fake_redis.exists(f"session:{second['session_id']}") == 1
        assert first["session_id"] != second["session_id"]

    def test_relogin_same_device_marks_old_session_as_least_recently_used(
        self, fake_redis: FakeRedis
    ) -> None:
        first = _login(fake_redis, "device_A")
        _login(fake_redis, "device_A")

        scores = fake_redis.zrange(f"user_sessions:{USER_ID}", 0, -1, withscores=True)
        score_map = dict(scores)
        # Phiên cũ được đẩy xuống đáy (score 0) => LRU sẽ dọn nó trước.
        assert score_map[first["session_id"]] == 0


class TestLruEviction:
    """AC2: Chỉ phiên thật sự lâu không hoạt động mới bị đá."""

    def test_active_session_is_not_evicted_when_new_device_logs_in(
        self, fake_redis: FakeRedis
    ) -> None:
        # 3 máy đã đăng nhập (dưới giới hạn 4).
        web = _login(fake_redis, "web_browser")
        phone = _login(fake_redis, "phone")
        tablet = _login(fake_redis, "tablet")

        # Phiên web vừa được dùng -> score phải mới nhất.
        security.touch_session(web["session_id"], USER_ID)

        # Máy thứ 4 đăng nhập -> vượt giới hạn 4? (đang có 3 -> thêm 1 = 4, chưa vượt)
        fourth = _login(fake_redis, "laptop")
        assert fake_redis.exists(f"session:{web['session_id']}") == 1
        assert fake_redis.exists(f"session:{phone['session_id']}") == 1
        assert fake_redis.exists(f"session:{tablet['session_id']}") == 1
        assert fake_redis.exists(f"session:{fourth['session_id']}") == 1

    def test_inactive_session_is_evicted_first(self, fake_redis: FakeRedis) -> None:
        stale = _login(fake_redis, "stale_device")
        active = _login(fake_redis, "active_device")
        third = _login(fake_redis, "third_device")
        fourth = _login(fake_redis, "fourth_device")

        # "active_device" vừa dùng -> score mới; "stale_device" giữ score cũ.
        security.touch_session(active["session_id"], USER_ID)

        # Máy thứ 5 -> vượt giới hạn 4 => phải đá phiên ít hoạt động nhất.
        _login(fake_redis, "fifth_device")

        assert fake_redis.exists(f"session:{stale['session_id']}") == 0
        assert fake_redis.exists(f"session:{active['session_id']}") == 1
        assert fake_redis.exists(f"session:{third['session_id']}") == 1
        assert fake_redis.exists(f"session:{fourth['session_id']}") == 1

    def test_stale_zset_entries_are_cleaned_before_counting(
        self, fake_redis: FakeRedis
    ) -> None:
        _login(fake_redis, "device_A")
        _login(fake_redis, "device_B")

        # Entry sót: session đã bị xoá nhưng vẫn còn trong ZSET.
        fake_redis.zsets.setdefault(f"user_sessions:{USER_ID}", {})["ghost-session"] = 1.0
        assert fake_redis.zcard(f"user_sessions:{USER_ID}") == 3

        # Đăng nhập mới phải dọn entry ghost trước khi đếm.
        _login(fake_redis, "device_C")
        assert "ghost-session" not in fake_redis.zsets[f"user_sessions:{USER_ID}"]


class TestTouchSession:
    """AC3: Mỗi lần dùng API sẽ cập nhật score LRU."""

    def test_touch_session_updates_score(self, fake_redis: FakeRedis) -> None:
        session = _login(fake_redis, "device_A")
        fake_redis.zadd(f"user_sessions:{USER_ID}", {session["session_id"]: 0})

        security.touch_session(session["session_id"], USER_ID)

        scores = dict(fake_redis.zrange(f"user_sessions:{USER_ID}", 0, -1, withscores=True))
        assert scores[session["session_id"]] > 0

    def test_touch_session_is_safe_when_redis_fails(self, monkeypatch) -> None:
        class BrokenRedis:
            def hget(self, *args, **kwargs):
                raise RuntimeError("redis down")

            def zadd(self, *args, **kwargs):
                raise RuntimeError("redis down")

        monkeypatch.setattr(security, "get_redis_client", lambda: BrokenRedis())
        # Không được ném exception ra -> request vẫn chạy bình thường.
        security.touch_session("some-session", USER_ID)


class TestGetCurrentUserTouchesSession:
    """AC4: get_current_user phải đánh dấu hoạt động."""

    def test_get_current_user_marks_session_active(
        self, fake_redis: FakeRedis, monkeypatch
    ) -> None:
        session = _login(fake_redis, "device_A")
        fake_redis.zadd(f"user_sessions:{USER_ID}", {session["session_id"]: 0})

        user = MagicMock()
        db = MagicMock()
        db.query.return_value.filter.return_value.first.return_value = user

        monkeypatch.setattr(
            security.jwt,
            "decode",
            lambda *args, **kwargs: {
                "sub": USER_ID,
                "role": "admin",
                "session_id": session["session_id"],
            },
        )

        result = security.get_current_user(token="fake.token", db=db)

        assert result is user
        scores = dict(fake_redis.zrange(f"user_sessions:{USER_ID}", 0, -1, withscores=True))
        # Score phải được nâng lên (không còn bằng 0).
        assert scores[session["session_id"]] > 0
