from getpass import getpass

import mysql.connector


def main():
    connection = None
    cursor = None
    run_id = None

    try:
        password = getpass("Enter your local MySQL root password: ")

        # Autocommit preserves logs independently of the refresh.
        # The stored procedure manages its own data transaction.
        connection = mysql.connector.connect(
            host="127.0.0.1",
            port=3306,
            user="root",
            password=password,
            database="foodorder_analytics",
            autocommit=True,
        )

        cursor = connection.cursor()

        cursor.execute("""
            INSERT INTO pipeline_run_log (
                pipeline_name,
                started_at,
                run_status
            )
            VALUES (%s, CURRENT_TIMESTAMP(6), %s)
        """, ("refresh_analytics", "RUNNING"))

        run_id = cursor.lastrowid
        print(f"Started pipeline run {run_id}")

        cursor.execute("""
            SELECT COUNT(*)
            FROM foodorder_source.orders
        """)
        source_count = cursor.fetchone()[0]

        cursor.execute("""
            UPDATE pipeline_run_log
            SET source_order_count = %s
            WHERE run_id = %s
        """, (source_count, run_id))

        # Execute the existing validated refresh procedure.
        cursor.execute("CALL refresh_analytics()")

        # Consume all results returned by the procedure.
        while cursor.nextset():
            pass

        cursor.execute("SELECT COUNT(*) FROM fact_orders")
        warehouse_count = cursor.fetchone()[0]

        cursor.execute("""
            UPDATE pipeline_run_log
            SET finished_at = CURRENT_TIMESTAMP(6),
                run_status = 'SUCCESS',
                warehouse_order_count = %s
            WHERE run_id = %s
        """, (warehouse_count, run_id))

        print(f"Run {run_id}: SUCCESS")
        print(f"Source orders: {source_count:,}")
        print(f"Warehouse orders: {warehouse_count:,}")

    except Exception as error:
        if connection is not None and run_id is not None:
            try:
                if cursor is not None:
                    cursor.close()

                cursor = connection.cursor()

                cursor.execute("""
                    UPDATE pipeline_run_log
                    SET finished_at = CURRENT_TIMESTAMP(6),
                        run_status = 'FAILED',
                        error_message = %s
                    WHERE run_id = %s
                """, (str(error), run_id))

            except Exception as log_error:
                print(f"Could not save failure log: {log_error}")

        print(f"Pipeline failed: {error}")
        raise SystemExit(1)

    finally:
        if cursor is not None:
            cursor.close()
        if connection is not None:
            connection.close()


if __name__ == "__main__":
    main()