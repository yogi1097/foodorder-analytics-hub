-- Run this INSERT once.
INSERT INTO foodorder_source.orders (
    order_id,
    customer_id,
    restaurant_id,
    order_date,
    order_status,
    payment_status,
    total_amount,
    updated_at
)
SELECT
    1001,
    customer_id,
    restaurant_id,
    '2026-07-01 12:00:00',
    'Completed',
    'Paid',
    25.00,
    '2026-07-01 12:00:00'
FROM foodorder_source.orders
WHERE order_id = 1;

-- Process the new order.
CALL foodorder_analytics.load_orders_incremental();

-- Verify the warehouse totals.
SELECT
    total_orders,
    completed_paid_orders,
    completed_order_revenue
FROM foodorder_analytics.vw_order_overview;