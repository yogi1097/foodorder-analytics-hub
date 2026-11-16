import argparse
from getpass import getpass

import mysql.connector


def main():
    parser = argparse.ArgumentParser(
        description="Run and log a warehouse load."
    )
    parser.add_argument(
        "--mode",
        choices=["full", "incremental"],
        default="full",
        help="Choose full refresh or incremental order loading.",
    )
    parser.add_argument(
        "--simulate-failure",
        action="store_true",
        help="Test failure logging before loading warehouse data.",
    )
    args = parser.parse_args()

    procedures = {
        "full": "refresh_analytics",
        "incremental": "load_orders_incremental",
    }
    procedure = procedures[args.mode]

    connection = None
    cursor = None
    run_id = None

    try:
        password = getpass("Enter your local MySQL root password: ")

        connection = mysql.connector.connect(
            host="127.0.0.1",
            port=3306,
            user="root",
            password=password,
            database="foodorder_analytics",
            autocommit=True,
        )

        cursor = connection.cursor()

        cursor.execute(
            """
            INSERT INTO pipeline_run_log (
                pipeline_name,
                started_at,
                run_status
            )
            VALUES (%s, CURRENT_TIMESTAMP(6), %s)
            """,
            (procedure, "RUNNING"),
        )

        run_id = cursor.lastrowid
        print(f"Started pipeline run {run_id}: {args.mode}")

        cursor.execute(
            "SELECT COUNT(*) FROM foodorder_source.orders"
        )
        source_count = cursor.fetchone()[0]

        cursor.execute(
            """
            UPDATE pipeline_run_log
            SET source_order_count = %s
            WHERE run_id = %s
            """,
            (source_count, run_id),
        )

        if args.simulate_failure:
            raise RuntimeError(
                "Intentional test failure before warehouse load."
            )

        # Procedure name comes only from the fixed mapping above.
        cursor.execute(f"CALL {procedure}()")

        procedure_results = []

        while True:
            if cursor.with_rows:
                column_names = cursor.column_names

                for row in cursor.fetchall():
                    procedure_results.append(
                        dict(zip(column_names, row))
                    )

            if not cursor.nextset():
                break

        cursor.execute("SELECT COUNT(*) FROM fact_orders")
        warehouse_count = cursor.fetchone()[0]

        cursor.execute(
            """
            UPDATE pipeline_run_log
            SET finished_at = CURRENT_TIMESTAMP(6),
                run_status = 'SUCCESS',
                warehouse_order_count = %s
            WHERE run_id = %s
            """,
            (warehouse_count, run_id),
        )

        print(f"Run {run_id}: SUCCESS")
        print(f"Source orders: {source_count:,}")
        print(f"Warehouse orders: {warehouse_count:,}")

        for result in procedure_results:
            for name, value in result.items():
                print(f"{name}: {value}")

    except Exception as error:
        if connection is not None and run_id is not None:
            try:
                if cursor is not None:
                    cursor.close()
                    cursor = None

                cursor = connection.cursor()

                cursor.execute(
                    """
                    UPDATE pipeline_run_log
                    SET finished_at = CURRENT_TIMESTAMP(6),
                        run_status = 'FAILED',
                        error_message = %s
                    WHERE run_id = %s
                    """,
                    (str(error), run_id),
                )

            except Exception as log_error:
                print(f"Could not save failure log: {log_error}")

        print(f"Pipeline failed: {error}")
        raise SystemExit(1)

    finally:
        try:
            if cursor is not None:
                cursor.close()
        finally:
            if connection is not None:
                connection.close()


if __name__ == "__main__":
    main()