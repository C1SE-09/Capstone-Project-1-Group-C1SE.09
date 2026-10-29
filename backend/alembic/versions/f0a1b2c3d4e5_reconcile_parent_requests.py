"""[Fix][ParentRequests] hợp nhất các head và giữ nguyên khóa/cột DB hiện có.

Không rename request_id/reviewed_at, không xóa dữ liệu cũ. Bổ sung người duyệt
theo tài khoản và nguồn bản ghi điểm danh để hủy đơn không xóa điểm danh thực.
"""

import sqlalchemy as sa
from alembic import op

revision = "f0a1b2c3d4e5"
down_revision = ("a2b3c4d5e6f7", "b7c8d9e0f1a2", "d2e3f4a5b6c7")
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    offline = op.get_context().as_sql
    columns = {"request_id"} if offline else {
        column["name"] for column in sa.inspect(bind).get_columns("leave_request")
    }
    if "request_id" not in columns:
        raise RuntimeError("Schema leave_request khác migration chuẩn: cần kiểm tra khóa DB, không tự rename/xóa dữ liệu")
    if "approved_by" not in columns:
        op.add_column("leave_request", sa.Column("approved_by", sa.UUID(), nullable=True))
        if bind.dialect.name == "postgresql":
            op.create_foreign_key("fk_leave_request_approved_user", "leave_request", "users",
                                  ["approved_by"], ["user_id"], ondelete="SET NULL")
    op.execute("""UPDATE leave_request SET approved_by = (
        SELECT users.user_id FROM users WHERE users.teacher_id = leave_request.reviewed_by
        ORDER BY users.user_id LIMIT 1
    ) WHERE approved_by IS NULL AND reviewed_by IS NOT NULL""")
    expression = """CASE WHEN request_type = 'late_arrival' THEN 'late'
        WHEN type = 'single_day' AND to_date > from_date THEN 'multi_day'
        ELSE type END"""
    if bind.dialect.name == "postgresql":
        expression = """(CASE WHEN request_type = 'late_arrival' THEN 'late'
            WHEN type = 'single_day' AND to_date > from_date THEN 'multi_day'
            ELSE type::text END)::leave_type"""
    op.execute(sa.text(f"UPDATE leave_request SET type = {expression}"))
    attendance_columns = set() if offline else {
        column["name"] for column in sa.inspect(bind).get_columns("attendance_record")
    }
    if "source_leave_id" not in attendance_columns:
        op.add_column("attendance_record", sa.Column("source_leave_id", sa.UUID(), nullable=True))
        if bind.dialect.name == "postgresql":
            op.create_foreign_key("fk_attendance_source_leave", "attendance_record", "leave_request",
                                  ["source_leave_id"], ["request_id"], ondelete="SET NULL")


def downgrade() -> None:
    # Expand-only: giữ cột nullable và audit để rollback code không xóa dữ liệu.
    op.execute("SELECT 1")
