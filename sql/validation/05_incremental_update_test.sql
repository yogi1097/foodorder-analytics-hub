-- Change the synthetic test order.
UPDATE foodorder_source.orders
SET
    total_amount = 35.00,
    updated_at = '2026-07-01 12:05:00'
WHERE order_id = 1001;

-- Process the change.
CALL foodorder_analytics.load_orders_incremental();

-- Confirm that the warehouse order changed.
SELECT
    order_id,
    total_amount,
    source_updated_at
FROM foodorder_analytics.fact_orders
WHERE order_id = 1001;

-- Check the new totals.
SELECT
    total_orders,
    completed_paid_orders,
    completed_order_revenue
FROM foodorder_analytics.vw_order_overview;