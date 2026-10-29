"""DDL PostgreSQL phải dùng nhãn enum đang lưu, không nhầm với giá trị Python."""

import pytest
from sqlalchemy import Enum
from sqlalchemy.dialects import postgresql
from sqlalchemy.schema import CreateTable

from app.models import Base

ENUM_DEFAULT_COLUMNS = [
    column
    for table in Base.metadata.sorted_tables
    for column in table.columns
    if isinstance(column.type, Enum) and column.server_default is not None
]


@pytest.mark.parametrize("column", ENUM_DEFAULT_COLUMNS,
                         ids=lambda column: f"{column.table.name}.{column.name}")
def test_postgresql_enum_server_default_is_a_declared_storage_label(column):
    default = str(column.server_default.arg)
    assert default in column.type.enums, (
        f"{column.table.name}.{column.name}: DEFAULT {default!r} không thuộc enum {column.type.enums}"
    )
    ddl = str(CreateTable(column.table).compile(dialect=postgresql.dialect()))
    assert f"DEFAULT '{default}'" in ddl
