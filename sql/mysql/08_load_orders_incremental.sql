USE foodorder_analytics;

DROP PROCEDURE IF EXISTS load_orders_incremental;

DELIMITER $$

CREATE PROCEDURE load_orders_incremental()
BEGIN
    DECLARE v_watermark DATETIME;
    DECLARE v_cutoff DATETIME;
    DECLARE v_batch_count BIGINT DEFAULT 0;
    DECLARE v_missing_keys BIGINT DEFAULT 0;
    DECLARE v_inserted BIGINT DEFAULT 0;
    DECLARE v_updated BIGINT DEFAULT 0;
    DECLARE v_safe_updates INT DEFAULT 1;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        DROP TEMPORARY TABLE IF EXISTS tmp_order_batch;
        SET SESSION sql_safe_updates = v_safe_updates;
        RESIGNAL;
    END;

    SET v_safe_updates = @@SESSION.sql_safe_updates;

    DROP TEMPORARY TABLE IF EXISTS tmp_order_batch;

    CREATE TEMPORARY TABLE tmp_order_batch
        LIKE foodorder_source.orders;

    SET SESSION sql_safe_updates = 0;

    START TRANSACTION;

    -- Lock this pipeline's watermark to serialize incremental runs.
    SET v_watermark = NULL;

    SELECT last_successful_watermark
    INTO v_watermark
    FROM pipeline_watermarks
    WHERE pipeline_name = 'incremental_orders'
    FOR UPDATE;

    IF v_watermark IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Pipeline watermark is missing.';
    END IF;

    -- Use the source timestamp as the upper boundary.
    SELECT GREATEST(
        COALESCE(MAX(updated_at), v_watermark),
        v_watermark
    )
    INTO v_cutoff
    FROM foodorder_source.orders;

    -- Re-read a one-minute overlap to handle timestamp ties.
    INSERT INTO tmp_order_batch
    SELECT *
    FROM foodorder_source.orders
    WHERE updated_at >= DATE_SUB(v_watermark, INTERVAL 1 MINUTE)
      AND updated_at <= v_cutoff;

    SELECT COUNT(*)
    INTO v_batch_count
    FROM tmp_order_batch;

    -- Reject the batch if any warehouse lookup is missing.
    SELECT COUNT(*)
    INTO v_missing_keys
    FROM tmp_order_batch b
    LEFT JOIN dim_customers c
        ON b.customer_id = c.customer_id
    LEFT JOIN dim_restaurants r
        ON b.restaurant_id = r.restaurant_id
    LEFT JOIN dim_date d
        ON DATE(b.order_date) = d.full_date
    WHERE c.customer_key IS NULL
       OR r.restaurant_key IS NULL
       OR d.date_key IS NULL;

    IF v_missing_keys > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
                'Missing dimension keys or dates. Batch rolled back.';
    END IF;

    -- Update existing facts only when their source values differ.
    UPDATE fact_orders f
    JOIN tmp_order_batch b
        ON f.order_id = b.order_id
    JOIN dim_customers c
        ON b.customer_id = c.customer_id
    JOIN dim_restaurants r
        ON b.restaurant_id = r.restaurant_id
    JOIN dim_date d
        ON DATE(b.order_date) = d.full_date
    SET
        f.customer_key = c.customer_key,
        f.restaurant_key = r.restaurant_key,
        f.date_key = d.date_key,
        f.order_date = b.order_date,
        f.order_hour = HOUR(b.order_date),
        f.order_status = b.order_status,
        f.payment_status = b.payment_status,
        f.total_amount = b.total_amount,
        f.source_updated_at = b.updated_at,
        f.load_timestamp = CURRENT_TIMESTAMP
    WHERE NOT (
        f.customer_key = c.customer_key
        AND f.restaurant_key = r.restaurant_key
        AND f.date_key = d.date_key
        AND f.order_date = b.order_date
        AND f.order_hour = HOUR(b.order_date)
        AND f.order_status = b.order_status
        AND f.payment_status = b.payment_status
        AND f.total_amount = b.total_amount
        AND f.source_updated_at = b.updated_at
    );

    SET v_updated = ROW_COUNT();

    -- Insert orders that do not already exist.
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
        b.order_id,
        c.customer_key,
        r.restaurant_key,
        d.date_key,
        b.order_date,
        HOUR(b.order_date),
        b.order_status,
        b.payment_status,
        b.total_amount,
        b.updated_at
    FROM tmp_order_batch b
    JOIN dim_customers c
        ON b.customer_id = c.customer_id
    JOIN dim_restaurants r
        ON b.restaurant_id = r.restaurant_id
    JOIN dim_date d
        ON DATE(b.order_date) = d.full_date
    LEFT JOIN fact_orders f
        ON b.order_id = f.order_id
    WHERE f.order_id IS NULL;

    SET v_inserted = ROW_COUNT();

    -- Commit facts and watermark together.
    UPDATE pipeline_watermarks
    SET
        last_successful_watermark = v_cutoff,
        last_successful_run_at = CURRENT_TIMESTAMP(6)
    WHERE pipeline_name = 'incremental_orders';

    COMMIT;

    DROP TEMPORARY TABLE IF EXISTS tmp_order_batch;

    SET SESSION sql_safe_updates = v_safe_updates;

    SELECT
        v_batch_count AS batch_orders_read,
        v_inserted AS orders_inserted,
        v_updated AS orders_updated,
        v_cutoff AS new_watermark;
END$$

DELIMITER ;

CALL load_orders_incremental();