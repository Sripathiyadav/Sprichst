"""The gateway has no database. This keeps it that way, or forces a decision.

If a SQL database is ever added, use parameterised statements only (never build
a query from user input with string formatting), then update this test and
SECURITY.md.
"""

import re
from pathlib import Path

APP = Path(__file__).resolve().parents[1] / "app"
REQUIREMENTS = (Path(__file__).resolve().parents[1] / "requirements.txt").read_text()

SQL = re.compile(
    r"\b(select\b[^;\n]{1,80}\bfrom\b|insert\s+into|update\s+\w+\s+set|"
    r"delete\s+from|drop\s+table|create\s+table|alter\s+table)\b",
    re.IGNORECASE,
)
DRIVERS = ("sqlite3", "sqlalchemy", "psycopg", "pymysql", "asyncpg", "aiosqlite", "peewee", "sqlmodel", "databases")


def test_no_source_file_builds_sql():
    offenders = [p.name for p in APP.glob("*.py") if SQL.search(p.read_text())]
    assert offenders == []


def test_no_database_driver_is_imported_or_required():
    for path in APP.glob("*.py"):
        text = path.read_text()
        for driver in DRIVERS:
            assert not re.search(rf"^\s*(import|from)\s+{driver}\b", text, re.MULTILINE), (path.name, driver)
    for driver in DRIVERS:
        assert driver not in REQUIREMENTS.lower(), driver
