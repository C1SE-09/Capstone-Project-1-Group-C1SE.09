"""
scripts/seed_admin.py
=====================
CLI script: tạo 1 web admin đầu tiên.

Usage:
    cd backend
    python -m scripts.seed_admin --email admin@kinderlog.dev --password "Admin@123" --name "Web Admin"

NOTE: Nên chạy script này 1 LẦN DUY NHẤT khi setup project.
Sau đó có thể tạo thêm admin qua API hoặc CLI.
"""

from __future__ import annotations

import argparse
import sys
from getpass import getpass

from app.core.database import SessionLocal
from app.services.admin_auth_service import (
    AdminAuthError,
    create_admin_user,
)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Seed web admin đầu tiên vào database"
    )
    parser.add_argument(
        "--email",
        type=str,
        help="Email đăng nhập (sẽ được nhắc nếu không truyền)",
    )
    parser.add_argument(
        "--password",
        type=str,
        help="Mật khẩu (sẽ được nhắc nếu không truyền - CHE KHI GÕ)",
    )
    parser.add_argument(
        "--name",
        type=str,
        default="Web Admin",
        help="Họ tên hiển thị (mặc định: 'Web Admin')",
    )
    parser.add_argument(
        "--super",
        action="store_true",
        help="Tạo super admin (full quyền)",
    )
    args = parser.parse_args()

    # Prompt nếu thiếu
    email = (args.email or input("Email: ")).strip()
    if not email:
        print("❌ Email không được để trống", file=sys.stderr)
        return 1

    if args.password:
        password = args.password
    else:
        password = getpass("Password (ít nhất 6 ký tự): ")

    if len(password) < 6:
        print("❌ Password phải có ít nhất 6 ký tự", file=sys.stderr)
        return 1

    name = (args.name or "Web Admin").strip()
    is_super = args.super

    # Tạo admin
    db = SessionLocal()
    try:
        admin = create_admin_user(
            db=db,
            email=email,
            password=password,
            full_name=name,
            is_super_admin=is_super,
        )
        print("✅ Đã tạo web admin:")
        print(f"   ID        : {admin.admin_user_id}")
        print(f"   Email     : {admin.email}")
        print(f"   Name      : {admin.full_name}")
        print(f"   Super     : {admin.is_super_admin}")
        print(f"   Active    : {admin.is_active}")
        print()
        print("👉 Giờ có thể đăng nhập tại: POST /api/admin-auth/login")
        return 0
    except AdminAuthError as exc:
        print(f"❌ Lỗi: {exc.message}", file=sys.stderr)
        return 1
    finally:
        db.close()


if __name__ == "__main__":
    sys.exit(main())
