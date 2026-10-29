"""Chạy migration thật trên DB SQLite tạm và biên dịch SQL PostgreSQL offline."""

import importlib.util
import io
from pathlib import Path

import sqlalchemy as sa
from alembic.config import Config
from alembic.migration import MigrationContext
from alembic.operations import Operations
from alembic.script import ScriptDirectory

BACKEND = Path(__file__).resolve().parents[1]
REVISION = "d2e3f4a5b6c7"
MIGRATION = BACKEND / "alembic" / "versions" / f"{REVISION}_extend_leave_requests.py"


def load_migration():
    assert MIGRATION.is_file(), "Thiếu migration cộng thêm trường đơn nghỉ/báo trễ"
    spec = importlib.util.spec_from_file_location("leave_request_migration", MIGRATION)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_migration_preserves_legacy_rows_and_downgrades():
    migration = load_migration()
    engine = sa.create_engine("sqlite://")
    with engine.begin() as connection:
        connection.execute(sa.text("CREATE TABLE leave_request (request_id TEXT PRIMARY KEY, reason TEXT NOT NULL)"))
        connection.execute(sa.text("INSERT INTO leave_request VALUES ('old', 'Giữ nguyên lý do cũ')"))
        context = MigrationContext.configure(connection)
        with Operations.context(context):
            migration.upgrade()
        row = connection.execute(sa.text("SELECT * FROM leave_request")).mappings().one()
        assert dict(row) == {
            "request_id": "old", "reason": "Giữ nguyên lý do cũ", "request_type": "absence",
            "expected_arrival_time": None, "meal_warning_acknowledged": 0,
        }
        with Operations.context(context):
            migration.downgrade()
        assert connection.execute(sa.text("SELECT request_id, reason FROM leave_request")).one() == ("old", "Giữ nguyên lý do cũ")
        assert "expected_arrival_time" in {column["name"] for column in sa.inspect(connection).get_columns("leave_request")}
    engine.dispose()


def test_migration_postgresql_sql_is_additive_with_legacy_defaults():
    migration = load_migration()
    output = io.StringIO()
    context = MigrationContext.configure(dialect_name="postgresql", opts={"as_sql": True, "output_buffer": output})
    with Operations.context(context):
        migration.upgrade()
    sql = output.getvalue()
    assert "ADD COLUMN request_type VARCHAR(16) DEFAULT 'absence' NOT NULL" in sql
    assert "ADD COLUMN IF NOT EXISTS expected_arrival_time TIME WITHOUT TIME ZONE" in sql
    assert "ADD COLUMN meal_warning_acknowledged BOOLEAN DEFAULT false NOT NULL" in sql
    assert "DROP " not in sql and "DELETE " not in sql


def test_migration_merges_existing_heads_into_one_head():
    migration = load_migration()
    scripts = ScriptDirectory.from_config(Config(str(BACKEND / "alembic.ini")))
    assert set(migration.down_revision) == {"4d8e9f1a2b3c", "c0b673468361"}
    assert len(scripts.get_heads()) == 1, "Bản ghép phải có một head, không làm mất nhánh health/medicine"
    final = scripts.get_revision(scripts.get_heads()[0])
    assert final.revision == "f2c3d4e5f6a7"
    assert final.down_revision == "f1b2c3d4e5f6"
    assert set(scripts.get_revision("f1b2c3d4e5f6").down_revision) == {"f0a1b2c3d4e5", "c7d8e9f0a1b2"}
    assert set(scripts.get_revision("f0a1b2c3d4e5").down_revision) == {
        REVISION, "a2b3c4d5e6f7", "b7c8d9e0f1a2",
    }


def test_d2_preserves_eta_already_created_by_upstream():
    migration = load_migration()
    engine = sa.create_engine("sqlite://")
    with engine.begin() as connection:
        connection.execute(sa.text("CREATE TABLE leave_request (request_id TEXT PRIMARY KEY, expected_arrival_time TIME)"))
        connection.execute(sa.text("INSERT INTO leave_request VALUES ('old', '08:30:00')"))
        with Operations.context(MigrationContext.configure(connection)):
            migration.upgrade()
        assert connection.execute(sa.text("SELECT expected_arrival_time FROM leave_request")).scalar() == "08:30:00"
        with Operations.context(MigrationContext.configure(connection)):
            migration.downgrade()
        assert connection.execute(sa.text("SELECT expected_arrival_time FROM leave_request")).scalar() == "08:30:00"
    engine.dispose()


def test_leave_table_dependency_creates_status_enum_only_once():
    """Nhánh health-only cũng phải đi qua migration tạo bảng nghỉ một lần."""
    path = BACKEND / "alembic" / "versions" / "4d8e9f1a2b3c_add_leave_request_table.py"
    spec = importlib.util.spec_from_file_location("leave_table_migration", path)
    migration = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(migration)
    output = io.StringIO()
    context = MigrationContext.configure(
        dialect_name="postgresql", opts={"as_sql": True, "output_buffer": output},
    )
    with Operations.context(context):
        migration.upgrade()
    sql = output.getvalue()
    assert sql.count("CREATE TYPE leave_request_status AS ENUM") == 1
    assert "CREATE TABLE leave_request" in sql


def load_reconcile_migration():
    path = BACKEND / "alembic" / "versions" / "f0a1b2c3d4e5_reconcile_parent_requests.py"
    spec = importlib.util.spec_from_file_location("reconcile_request_migration", path)
    migration = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(migration)
    return migration


def test_reconcile_migration_preserves_ids_dates_and_review_audit():
    migration = load_reconcile_migration()
    engine = sa.create_engine("sqlite://")
    with engine.begin() as connection:
        connection.execute(sa.text("CREATE TABLE users (user_id TEXT PRIMARY KEY, teacher_id TEXT)"))
        connection.execute(sa.text("INSERT INTO users VALUES ('reviewer-user', 'reviewer-teacher')"))
        connection.execute(sa.text("""CREATE TABLE leave_request (
            request_id TEXT PRIMARY KEY, reviewed_by TEXT, reviewed_at TEXT,
            type TEXT, request_type TEXT, from_date DATE, to_date DATE, reason TEXT)"""))
        connection.execute(sa.text("""INSERT INTO leave_request VALUES
            ('legacy-late', 'reviewer-teacher', '2030-01-05T07:00:00', 'single_day', 'late_arrival', '2030-01-06', '2030-01-06', 'Báo trễ'),
            ('upstream-late', NULL, NULL, 'late', 'absence', '2030-01-06', '2030-01-06', 'Giữ late'),
            ('legacy-multi', NULL, NULL, 'single_day', 'absence', '2030-01-06', '2030-01-07', 'Giữ nhiều ngày')"""))
        connection.execute(sa.text("CREATE TABLE attendance_record (record_id TEXT PRIMARY KEY, note TEXT)"))
        connection.execute(sa.text("INSERT INTO attendance_record VALUES ('actual', 'Giữ điểm danh thực')"))
        with Operations.context(MigrationContext.configure(connection)):
            migration.upgrade()
        rows = connection.execute(sa.text("SELECT request_id, type, approved_by, reviewed_at FROM leave_request ORDER BY request_id")).all()
        assert rows == [
            ('legacy-late', 'late', 'reviewer-user', '2030-01-05T07:00:00'),
            ('legacy-multi', 'multi_day', None, None), ('upstream-late', 'late', None, None),
        ]
        assert connection.execute(sa.text("SELECT * FROM attendance_record")).one() == ('actual', 'Giữ điểm danh thực', None)
        with Operations.context(MigrationContext.configure(connection)):
            migration.downgrade()
        assert connection.execute(sa.text("SELECT request_id, type, approved_by, reviewed_at FROM leave_request ORDER BY request_id")).all() == rows
    engine.dispose()


def test_reconcile_migration_postgresql_does_not_rename_or_drop_columns():
    output = io.StringIO()
    context = MigrationContext.configure(dialect_name="postgresql", opts={"as_sql": True, "output_buffer": output})
    with Operations.context(context):
        load_reconcile_migration().upgrade()
    sql = output.getvalue()
    assert "RENAME" not in sql and "DROP " not in sql
    assert "REFERENCES leave_request (request_id)" in sql
    assert "REFERENCES users (user_id)" in sql
    assert "ELSE type::text END)::leave_type" in sql
