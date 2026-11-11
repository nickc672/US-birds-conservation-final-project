#Build the birds database in MySQL, from schema to download pages to SQL transformations.

# Usage:
# python pipeline.py (reuses downloaded pages if the database already has them)
# python pipeline.py --refresh (downloads the Wiki pages again)

import argparse
import db
import load_pages

SQL_DIR = db.ROOT / "sql"
SETUP = ["01_helpers.sql", "02_schema.sql"]
TRANSFORMS = [
    "03_parse_us_list.sql",
    "04_species_master.sql",
    "05_parse_state_lists.sql",
    "06_match_sightings.sql",
    "07_load_final_tables.sql",
    "08_species_detail_view.sql",
]


def run(con, name):
    print(f"Running sql/{name}")
    db.run_sql_file(con, SQL_DIR / name)


def report(con):
    print("\nFirst and last U.S. page sections kept (all four should be bird groups,")
    print("and if not then adjust the section bounds in sql/03_parse_us_list.sql):")
    kept = db.query(con, """
        WITH kept AS (
            SELECT section_idx, heading, COUNT(*) AS n_lines
            FROM us_species_line
            GROUP BY section_idx, heading
        ),
        ranked AS (
            SELECT kept.*,
                ROW_NUMBER() OVER (ORDER BY section_idx) AS from_start,
                ROW_NUMBER() OVER (ORDER BY section_idx DESC) AS from_end
            FROM kept
        )
        SELECT section_idx, heading, n_lines
        FROM ranked
        WHERE from_start <= 2 OR from_end <= 2
        ORDER BY section_idx
    """)
    for row in kept.itertuples():
        print(f"  section {row.section_idx:>3}: {row.heading} ({row.n_lines} lines)")

    print("\nRow counts:")
    for table in ["species", "bird_family", "species_group", "species_state"]:
        n = db.query(con, f"SELECT COUNT(*) AS n FROM {table}")["n"][0]
        print(f"  {table:<14} {n:>7,}")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--refresh", action="store_true", help="download the Wikipedia pages again")
    args = parser.parse_args()

    con = db.connect(database=None)
    try:
        with con.cursor() as cursor:
            cursor.execute(f"CREATE DATABASE IF NOT EXISTS {db.DATABASE} CHARACTER SET utf8mb4")
            cursor.execute(f"USE {db.DATABASE}")
        for name in SETUP:
            run(con, name)
        load_pages.load(con, refresh=args.refresh)
        for name in TRANSFORMS:
            run(con, name)
        report(con)
    finally:
        con.close()
    print(f"\nDone: MySQL database '{db.DATABASE}'")


if __name__ == "__main__":
    main()
