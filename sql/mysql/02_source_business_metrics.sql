-- Revenue includes only completed, paid orders.
SELECT
    COUNT(*) AS total_orders,

    SUM(
        CASE WHEN order_status = 'Completed'
                  AND payment_status = 'Paid'
             THEN 1 ELSE 0 END
    ) AS completed_paid_orders,

    SUM(
        CASE WHEN order_status = 'Completed'
                  AND payment_status = 'Paid'
             THEN total_amount ELSE 0 END
    ) AS completed_order_revenue,

    ROUND(
        AVG(
            CASE WHEN order_status = 'Completed'
                      AND payment_status = 'Paid'
                 THEN total_amount END
        ),
        2
    ) AS average_order_value,

    ROUND(
        100.0 * SUM(
            CASE WHEN order_status = 'Cancelled'
                 THEN 1 ELSE 0 END
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS cancellation_rate_pct

FROM foodorder_source.orders;