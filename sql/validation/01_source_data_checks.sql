SELECT 'Orders without customers' AS check_name, COUNT(*) AS issues
FROM foodorder_source.orders o
LEFT JOIN foodorder_source.customers c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL

UNION ALL

SELECT 'Orders without restaurants', COUNT(*)
FROM foodorder_source.orders o
LEFT JOIN foodorder_source.restaurants r
    ON o.restaurant_id = r.restaurant_id
WHERE r.restaurant_id IS NULL

UNION ALL

SELECT 'Invalid order amounts', COUNT(*)
FROM foodorder_source.orders
WHERE total_amount <= 0

UNION ALL

SELECT 'Orders before customer registration', COUNT(*)
FROM foodorder_source.orders o
JOIN foodorder_source.customers c
    ON o.customer_id = c.customer_id
WHERE DATE(o.order_date) < c.registration_date;