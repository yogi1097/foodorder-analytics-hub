import csv
from getpass import getpass
from pathlib import Path

import mysql.connector


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = PROJECT_ROOT / "data" / "generated"

TABLE_COLUMNS = {
    "customers": [
        "customer_id",
        "first_name",
        "last_name",
        "email",
        "city",
        "state",
        "registration_date",
        "updated_at",
    ],
    "restaurants": [
        "restaurant_id",
        "restaurant_name",
        "cuisine_type",
        "city",
        "state",
        "is_active",
        "updated_at",
    ],
    "orders": [
        "order_id",
        "customer_id",
        "restaurant_id",
        "order_date",
        "order_status",
        "payment_status",
        "total_amount",
        "updated_at",
    ],
}


def read_rows(table, columns):
    path = DATA_DIR / f"{table}.csv"

    with path.open("r", newline="", encoding="utf-8") as file:
        reader = csv.DictReader(file)

        if reader.fieldnames != columns:
            raise ValueError(f"Unexpected CSV columns in {path.name}")

        rows = [
            tuple(row[column] for column in columns)
            for row in reader
        ]

    if not rows:
        raise ValueError(f"{path.name} contains no records.")

    return rows


def main():
    connection = None
    cursor = None

    try:
        # Read all files before making database changes.
        datasets = {
            table: read_rows(table, columns)
            for table, columns in TABLE_COLUMNS.items()
        }

        password = getpass("Enter your local MySQL root password: ")

        connection = mysql.connector.connect(
            host="127.0.0.1",
            port=3306,
            user="root",
            password=password,
            database="foodorder_source",
            autocommit=False,
        )

        cursor = connection.cursor()

        # Table names come only from our fixed configuration above.
        for table in TABLE_COLUMNS:
            cursor.execute(f"SELECT COUNT(*) FROM `{table}`")
            count = cursor.fetchone()[0]

            if count > 0:
                raise ValueError(
                    f"{table} already contains {count} rows. "
                    "This initial loader requires empty tables. "
                    "No changes were made."
                )

        # Load parent tables before orders to satisfy foreign keys.
        for table, columns in TABLE_COLUMNS.items():
            column_names = ", ".join(
                f"`{column}`" for column in columns
            )
            placeholders = ", ".join(["%s"] * len(columns))

            query = (
                f"INSERT INTO `{table}` ({column_names}) "
                f"VALUES ({placeholders})"
            )

            cursor.executemany(query, datasets[table])

            cursor.execute(f"SELECT COUNT(*) FROM `{table}`")
            actual_count = cursor.fetchone()[0]
            expected_count = len(datasets[table])

            if actual_count != expected_count:
                raise ValueError(
                    f"Row count mismatch in {table}: "
                    f"expected {expected_count}, got {actual_count}"
                )

        # Save only after every table loads and counts match.
        connection.commit()

        print("\nLoad completed successfully.")
        for table, rows in datasets.items():
            print(f"{table}: {len(rows):,} rows")

    except Exception as error:
        if connection is not None:
            connection.rollback()
        print(f"\nLoad failed: {error}")
        raise SystemExit(1)

    finally:
        if cursor is not None:
            cursor.close()
        if connection is not None:
            connection.close()


if __name__ == "__main__":
    main()