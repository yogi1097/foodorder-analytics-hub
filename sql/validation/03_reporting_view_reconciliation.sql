SELECT
    'overview' AS reporting_view,
    total_orders,
    completed_order_revenue
FROM foodorder_analytics.vw_order_overview

UNION ALL

SELECT
    'restaurants',
    SUM(total_orders),
    SUM(completed_order_revenue)
FROM foodorder_analytics.vw_restaurant_performance

UNION ALL

SELECT
    'daily',
    SUM(total_orders),
    SUM(completed_order_revenue)
FROM foodorder_analytics.vw_daily_performance;