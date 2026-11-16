SELECT
    'Source orders missing from warehouse' AS check_name,
    COUNT(*) AS issues
FROM foodorder_source.orders s
LEFT JOIN foodorder_analytics.fact_orders f
    ON s.order_id = f.order_id
WHERE f.order_id IS NULL

UNION ALL

SELECT
    'Warehouse orders missing from source',
    COUNT(*)
FROM foodorder_analytics.fact_orders f
LEFT JOIN foodorder_source.orders s
    ON f.order_id = s.order_id
WHERE s.order_id IS NULL

UNION ALL

SELECT
    'Orders with mismatched values',
    COUNT(*)
FROM foodorder_source.orders s
JOIN foodorder_analytics.fact_orders f
    ON s.order_id = f.order_id
JOIN foodorder_analytics.dim_customers c
    ON f.customer_key = c.customer_key
JOIN foodorder_analytics.dim_restaurants r
    ON f.restaurant_key = r.restaurant_key
JOIN foodorder_analytics.dim_date d
    ON f.date_key = d.date_key
WHERE s.customer_id <> c.customer_id
   OR s.restaurant_id <> r.restaurant_id
   OR s.order_date <> f.order_date
   OR DATE(s.order_date) <> d.full_date
   OR HOUR(s.order_date) <> f.order_hour
   OR s.order_status <> f.order_status
   OR s.payment_status <> f.payment_status
   OR s.total_amount <> f.total_amount
   OR s.updated_at <> f.source_updated_at;