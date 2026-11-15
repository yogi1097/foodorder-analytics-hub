USE foodorder_analytics;

DROP PROCEDURE IF EXISTS refresh_analytics;

DELIMITER $$

CREATE PROCEDURE refresh_analytics()
BEGIN
    DECLARE source_count BIGINT;
    DECLARE fact_count BIGINT;
    DECLARE source_revenue DECIMAL(18, 2);
    DECLARE fact_revenue DECIMAL(18, 2);
    DECLARE previous_safe_updates INT DEFAULT 1;

    -- Undo the load if any statement fails.
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
BEGIN
    ROLLBACK;
    SET SESSION sql_safe_updates = previous_safe_updates;
    RESIGNAL;
END;

	SET previous_safe_updates = @@SESSION.sql_safe_updates;
	SET SESSION sql_safe_updates = 0;

    START TRANSACTION;

    SELECT COUNT(*)
    INTO source_count
    FROM foodorder_source.orders;

    IF source_count = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Source orders are empty. Load stopped.';
    END IF;

    -- Remove derived data in foreign-key dependency order.
    DELETE FROM fact_orders;
    DELETE FROM dim_customers;
    DELETE FROM dim_restaurants;
    DELETE FROM dim_date;

    -- Load one row per customer.
    INSERT INTO dim_customers (
        customer_id,
        first_name,
        last_name,
        full_name,
        city,
        state,
        registration_date
    )
    SELECT
        customer_id,
        first_name,
        last_name,
        CONCAT(first_name, ' ', last_name),
        city,
        state,
        registration_date
    FROM foodorder_source.customers;

    -- Load one row per restaurant.
    INSERT INTO dim_restaurants (
        restaurant_id,
        restaurant_name,
        cuisine_type,
        city,
        state,
        is_active
    )
    SELECT
        restaurant_id,
        restaurant_name,
        cuisine_type,
        city,
        state,
        is_active
    FROM foodorder_source.restaurants;

    -- Full calendar year for the current 2026 dataset.
    -- Weekday numbering: Monday = 1, Sunday = 7.
    INSERT INTO dim_date (
        date_key,
        full_date,
        calendar_year,
        calendar_quarter,
        month_number,
        month_name,
        day_of_month,
        weekday_number,
        weekday_name,
        is_weekend
    )
    WITH RECURSIVE calendar AS (
        SELECT DATE('2026-01-01') AS calendar_date

        UNION ALL

        SELECT DATE_ADD(calendar_date, INTERVAL 1 DAY)
        FROM calendar
        WHERE calendar_date < '2026-12-31'
    )
    SELECT
        CAST(DATE_FORMAT(calendar_date, '%Y%m%d') AS UNSIGNED),
        calendar_date,
        YEAR(calendar_date),
        QUARTER(calendar_date),
        MONTH(calendar_date),
        MONTHNAME(calendar_date),
        DAYOFMONTH(calendar_date),
        WEEKDAY(calendar_date) + 1,
        DAYNAME(calendar_date),
        CASE
            WHEN WEEKDAY(calendar_date) >= 5 THEN 1
            ELSE 0
        END
    FROM calendar;

    -- Map source IDs to warehouse keys.
    -- Keep all order statuses, including cancelled and pending.
    INSERT INTO fact_orders (
        order_id,
        customer_key,
        restaurant_key,
        date_key,
        order_date,
        order_hour,
        order_status,
        payment_status,
        total_amount,
        source_updated_at
    )
    SELECT
        o.order_id,
        c.customer_key,
        r.restaurant_key,
        d.date_key,
        o.order_date,
        HOUR(o.order_date),
        o.order_status,
        o.payment_status,
        o.total_amount,
        o.updated_at
    FROM foodorder_source.orders o
    JOIN dim_customers c
        ON o.customer_id = c.customer_id
    JOIN dim_restaurants r
        ON o.restaurant_id = r.restaurant_id
    JOIN dim_date d
        ON DATE(o.order_date) = d.full_date;

    -- Check that no orders disappeared during the joins.
    SELECT COUNT(*)
    INTO fact_count
    FROM fact_orders;

    IF source_count <> fact_count THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Order counts differ. Load rolled back.';
    END IF;

    -- Reconcile revenue using the same business rule.
    SELECT COALESCE(SUM(total_amount), 0)
    INTO source_revenue
    FROM foodorder_source.orders
    WHERE order_status = 'Completed'
      AND payment_status = 'Paid';

    SELECT COALESCE(SUM(total_amount), 0)
    INTO fact_revenue
    FROM fact_orders
    WHERE order_status = 'Completed'
      AND payment_status = 'Paid';

    IF source_revenue <> fact_revenue THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Revenue differs. Load rolled back.';
    END IF;

    COMMIT;
    SET SESSION sql_safe_updates = previous_safe_updates;
END$$

DELIMITER ;

CALL refresh_analytics();

SELECT 'dim_customers' AS table_name, COUNT(*) AS row_count
FROM dim_customers

UNION ALL

SELECT 'dim_restaurants', COUNT(*)
FROM dim_restaurants

UNION ALL

SELECT 'dim_date', COUNT(*)
FROM dim_date

UNION ALL

SELECT 'fact_orders', COUNT(*)
FROM fact_orders;