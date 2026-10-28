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
        assert connection.execute(sa.text("SELECT * FROM leave_request")).one() == ("old", "Giữ nguyên lý do cũ")
    engine.dispose()


def test_migration_postgresql_sql_is_additive_with_legacy_defaults():
    migration = load_migration()
    output = io.StringIO()
    context = MigrationContext.configure(dialect_name="postgresql", opts={"as_sql": True, "output_buffer": output})
    with Operations.context(context):
        migration.upgrade()
    sql = output.getvalue()
    assert "ADD COLUMN request_type VARCHAR(16) DEFAULT 'absence' NOT NULL" in sql
    assert "ADD COLUMN expected_arrival_time TIME WITHOUT TIME ZONE" in sql
    assert "ADD COLUMN meal_warning_acknowledged BOOLEAN DEFAULT false NOT NULL" in sql
    assert "DROP " not in sql and "DELETE " not in sql


def test_migration_merges_existing_heads_into_one_head():
    migration = load_migration()
    scripts = ScriptDirectory.from_config(Config(str(BACKEND / "alembic.ini")))
    assert set(migration.down_revision) == {"4d8e9f1a2b3c", "c0b673468361"}
    assert scripts.get_heads() == [REVISION]


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
