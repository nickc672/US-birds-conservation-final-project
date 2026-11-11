# MySQL connection and SQL file helpers shared by pipeline.py and the notebook

from decimal import Decimal
from pathlib import Path
from typing import Optional

import pandas as pd
import pymysql

ROOT = Path(__file__).resolve().parent
CONFIG_FILE = ROOT / "mysql.cnf"
DATABASE = "birds"


def connect(database: Optional[str] = DATABASE):
    """Connect using the host, user, and password in mysql.cnf. database=None connects without selecting one."""
    if not CONFIG_FILE.exists():
        raise FileNotFoundError(f"{CONFIG_FILE} not found: in mysql.cnf add MySQL password.")
    return pymysql.connect(read_default_file=str(CONFIG_FILE), database=database, charset="utf8mb4", autocommit=True)


def split_statements(sql):
    """Split an SQL script into statements on ';' and ignores semicolons inside quotes and comments."""
    statements, current, has_code = [], [], False
    i, n = 0, len(sql)
    while i < n:
        ch = sql[i]
        if ch in "'\"`":
            j = i + 1
            while j < n:
                if sql[j] == "\\" and ch != "`":
                    j += 2
                    continue
                if sql[j] == ch:
                    if j + 1 < n and sql[j + 1] == ch:  # doubled quote inside the string
                        j += 2
                        continue
                    break
                j += 1
            current.append(sql[i:j + 1])
            has_code = True
            i = j + 1
        elif sql.startswith("--", i) and (i + 2 >= n or sql[i + 2].isspace()) or ch == "#":
            j = sql.find("\n", i)
            j = n if j == -1 else j
            current.append(sql[i:j])
            i = j
        elif sql.startswith("/*", i):  # block comment
            j = sql.find("*/", i + 2)
            j = n if j == -1 else j + 2
            current.append(sql[i:j])
            i = j
        elif ch == ";":
            if has_code:
                statements.append("".join(current).strip())
            current, has_code = [], False
            i += 1
        else:
            current.append(ch)
            has_code = has_code or not ch.isspace()
            i += 1
    if has_code:
        statements.append("".join(current).strip())
    return statements


def to_frame(cursor):
    """The cursor's current result as a DataFrame.
    MySQL DECIMAL values (like from SUM or ROUND) arrive as Python Decimals and they're converted to
    floats so pandas and matplotlib treat them as numbers."""
    rows = [[float(value) if isinstance(value, Decimal) else value for value in row] for row in cursor.fetchall()]
    return pd.DataFrame(rows, columns=[column[0] for column in cursor.description])


def run_sql_file(con, path):
    """Run every statement in a SQL file, this returns the last result that has rows as a DataFrame (or None)."""
    result = None
    with con.cursor() as cursor:
        for statement in split_statements(Path(path).read_text(encoding="utf-8")):
            cursor.execute(statement)
            if cursor.description:
                result = to_frame(cursor)
    return result


def query(con, sql, params=None):
    """Run one query and return its result as a DataFrame."""
    with con.cursor() as cursor:
        cursor.execute(sql, params)
        return to_frame(cursor)