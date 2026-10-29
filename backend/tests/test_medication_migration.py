"""Giữ đơn thuốc cũ khi hợp nhất model nhiều cữ và migration của hai nhánh."""

import importlib.util
import io
from pathlib import Path

import sqlalchemy as sa
from alembic.migration import MigrationContext
from alembic.operations import Operations

VERSIONS = Path(__file__).resolve().parents[1] / "alembic" / "versions"


def load_migration(filename):
    spec = importlib.util.spec_from_file_location(filename.removesuffix(".py"), VERSIONS / filename)
    migration = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(migration)
    return migration


def test_medication_creation_does_not_create_each_enum_twice():
    output = io.StringIO()
    context = MigrationContext.configure(dialect_name="postgresql", opts={"as_sql": True, "output_buffer": output})
    with Operations.context(context):
        load_migration("c7d8e9f0a1b2_add_medication_requests_table.py").upgrade()
    sql = output.getvalue()
    assert sql.count("CREATE TYPE medication_status_enum AS ENUM") == 1
    assert sql.count("CREATE TYPE medicine_category_enum AS ENUM") == 1
    assert "CREATE TABLE medication_requests" in sql


def test_reconcile_adds_model_columns_without_losing_existing_medication_or_logs():
    from app.models.medication import MedicationRequest

    engine = sa.create_engine("sqlite://")
    with engine.begin() as connection:
        connection.execute(sa.text("""CREATE TABLE medication_request (
            request_id TEXT PRIMARY KEY, child_id TEXT, class_id TEXT, parent_id TEXT,
            medication_name TEXT, dosage TEXT, instructions TEXT, sessions JSON,
            start_date DATE, end_date DATE, status TEXT, notes TEXT,
            created_at DATETIME, updated_at DATETIME)"""))
        connection.execute(sa.text("""INSERT INTO medication_request
            (request_id, medication_name, dosage, status)
            VALUES ('00000000000000000000000000000001', 'Thuốc cũ', '5ml', 'active')"""))
        connection.execute(sa.text("CREATE TABLE medication_log (log_id TEXT, request_id TEXT, is_given BOOLEAN)"))
        connection.execute(sa.text("INSERT INTO medication_log VALUES ('log-old', 'old', 1)"))
        connection.execute(sa.text("CREATE TABLE medication_requests (id TEXT PRIMARY KEY)"))
        connection.execute(sa.text("INSERT INTO medication_requests VALUES ('other-branch')"))
        migration = load_migration("f1b2c3d4e5f6_reconcile_medication_schema.py")
        with Operations.context(MigrationContext.configure(connection)):
            migration.upgrade()
        # SELECT dùng đúng table/column của ORM thật, không dùng create_all che lỗi migration.
        columns = {column.name for column in MedicationRequest.__table__.columns}
        assert columns <= {column["name"] for column in sa.inspect(connection).get_columns("medication_request")}
        connection.execute(sa.select(MedicationRequest.__table__)).all()
        for action in (migration.upgrade, migration.downgrade):
            with Operations.context(MigrationContext.configure(connection)):
                action()
            assert connection.execute(sa.text("SELECT request_id, medication_name, dosage, status, batch_id FROM medication_request")).one() == (
                '00000000000000000000000000000001', 'Thuốc cũ', '5ml', 'active', None,
            )
            assert connection.execute(sa.text("SELECT * FROM medication_log")).one() == ('log-old', 'old', 1)
            assert connection.execute(sa.text("SELECT * FROM medication_requests")).one() == ('other-branch',)
    engine.dispose()


def test_reconcile_postgresql_extends_the_table_used_by_both_medication_apis():
    output = io.StringIO()
    context = MigrationContext.configure(dialect_name="postgresql", opts={"as_sql": True, "output_buffer": output})
    with Operations.context(context):
        load_migration("f1b2c3d4e5f6_reconcile_medication_schema.py").upgrade()
    sql = output.getvalue()
    assert "ALTER TYPE medication_request_status ADD VALUE IF NOT EXISTS 'pending'" in sql
    assert "ALTER TYPE medication_request_status ADD VALUE IF NOT EXISTS 'given'" in sql
    assert "ALTER TABLE medication_request ADD COLUMN batch_id UUID" in sql
    assert "ALTER TABLE medication_request ADD COLUMN medicine_category medicine_category_enum" in sql
    assert "REFERENCES users (user_id)" in sql
    assert "REFERENCES teacher (teacher_id)" in sql
    assert "CREATE TYPE" not in sql and "RENAME" not in sql and "DROP " not in sql
