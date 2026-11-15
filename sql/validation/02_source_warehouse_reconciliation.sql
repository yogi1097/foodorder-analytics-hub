SELECT
    'source' AS data_layer,
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
    ) AS completed_order_revenue
FROM foodorder_source.orders

UNION ALL

SELECT
    'warehouse',
    COUNT(*),
    SUM(
        CASE WHEN order_status = 'Completed'
                  AND payment_status = 'Paid'
             THEN 1 ELSE 0 END
    ),
    SUM(
        CASE WHEN order_status = 'Completed'
                  AND payment_status = 'Paid'
             THEN total_amount ELSE 0 END
    )
FROM foodorder_analytics.fact_orders;