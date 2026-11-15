USE foodorder_analytics;

-- Overview: all orders, with revenue restricted
-- to orders that are both completed and paid.
CREATE OR REPLACE VIEW vw_order_overview AS
SELECT
    COUNT(*) AS total_orders,

    COALESCE(SUM(
        CASE
            WHEN order_status = 'Completed'
             AND payment_status = 'Paid'
            THEN 1 ELSE 0
        END
    ), 0) AS completed_paid_orders,

    COALESCE(SUM(
        CASE
            WHEN order_status = 'Completed'
             AND payment_status = 'Paid'
            THEN total_amount ELSE 0
        END
    ), 0) AS completed_order_revenue,

    ROUND(AVG(
        CASE
            WHEN order_status = 'Completed'
             AND payment_status = 'Paid'
            THEN total_amount
        END
    ), 2) AS average_order_value,

    ROUND(
        100.0 * SUM(
            CASE WHEN order_status = 'Cancelled'
                 THEN 1 ELSE 0 END
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS cancellation_rate_pct

FROM fact_orders;


-- Restaurant performance, including restaurants with no orders.
CREATE OR REPLACE VIEW vw_restaurant_performance AS
SELECT
    r.restaurant_id,
    r.restaurant_name,
    r.cuisine_type,
    r.city,
    r.state,

    COUNT(f.order_id) AS total_orders,

    SUM(
        CASE
            WHEN f.order_status = 'Completed'
             AND f.payment_status = 'Paid'
            THEN 1 ELSE 0
        END
    ) AS completed_paid_orders,

    SUM(
        CASE
            WHEN f.order_status = 'Completed'
             AND f.payment_status = 'Paid'
            THEN f.total_amount ELSE 0
        END
    ) AS completed_order_revenue,

    ROUND(AVG(
        CASE
            WHEN f.order_status = 'Completed'
             AND f.payment_status = 'Paid'
            THEN f.total_amount
        END
    ), 2) AS average_order_value

FROM dim_restaurants r
LEFT JOIN fact_orders f
    ON r.restaurant_key = f.restaurant_key

GROUP BY
    r.restaurant_id,
    r.restaurant_name,
    r.cuisine_type,
    r.city,
    r.state;


-- Daily performance, including dates with no orders.
CREATE OR REPLACE VIEW vw_daily_performance AS
SELECT
    d.full_date,
    d.calendar_year,
    d.month_number,
    d.month_name,
    d.weekday_number,
    d.weekday_name,
    d.is_weekend,

    COUNT(f.order_id) AS total_orders,

    SUM(
        CASE
            WHEN f.order_status = 'Completed'
             AND f.payment_status = 'Paid'
            THEN 1 ELSE 0
        END
    ) AS completed_paid_orders,

    SUM(
        CASE
            WHEN f.order_status = 'Completed'
             AND f.payment_status = 'Paid'
            THEN f.total_amount ELSE 0
        END
    ) AS completed_order_revenue

FROM dim_date d
LEFT JOIN fact_orders f
    ON d.date_key = f.date_key

GROUP BY
    d.full_date,
    d.calendar_year,
    d.month_number,
    d.month_name,
    d.weekday_number,
    d.weekday_name,
    d.is_weekend;