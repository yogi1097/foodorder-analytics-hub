CREATE DATABASE IF NOT EXISTS foodorder_analytics
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;

USE foodorder_analytics;


-- Customer dimension: one row per source customer.
CREATE TABLE IF NOT EXISTS dim_customers (
    customer_key INT NOT NULL AUTO_INCREMENT,
    customer_id INT NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    full_name VARCHAR(201) NOT NULL,
    city VARCHAR(100) NOT NULL,
    state CHAR(2) NOT NULL,
    registration_date DATE NOT NULL,

    PRIMARY KEY (customer_key),
    UNIQUE KEY uq_dim_customers_id (customer_id)
) ENGINE = InnoDB;


-- Restaurant dimension: one row per source restaurant.
CREATE TABLE IF NOT EXISTS dim_restaurants (
    restaurant_key INT NOT NULL AUTO_INCREMENT,
    restaurant_id INT NOT NULL,
    restaurant_name VARCHAR(150) NOT NULL,
    cuisine_type VARCHAR(50) NOT NULL,
    city VARCHAR(100) NOT NULL,
    state CHAR(2) NOT NULL,
    is_active TINYINT NOT NULL,

    PRIMARY KEY (restaurant_key),
    UNIQUE KEY uq_dim_restaurants_id (restaurant_id),

    CONSTRAINT chk_dim_restaurants_active
        CHECK (is_active IN (0, 1))
) ENGINE = InnoDB;


-- Date dimension: date_key uses YYYYMMDD format.
CREATE TABLE IF NOT EXISTS dim_date (
    date_key INT NOT NULL,
    full_date DATE NOT NULL,
    calendar_year SMALLINT NOT NULL,
    calendar_quarter TINYINT NOT NULL,
    month_number TINYINT NOT NULL,
    month_name VARCHAR(9) NOT NULL,
    day_of_month TINYINT NOT NULL,
    weekday_number TINYINT NOT NULL,
    weekday_name VARCHAR(9) NOT NULL,
    is_weekend TINYINT NOT NULL,

    PRIMARY KEY (date_key),
    UNIQUE KEY uq_dim_date_full_date (full_date),

    CONSTRAINT chk_dim_date_weekday
        CHECK (weekday_number BETWEEN 1 AND 7),

    CONSTRAINT chk_dim_date_weekend
        CHECK (is_weekend IN (0, 1))
) ENGINE = InnoDB;


-- Fact grain: exactly one row per source order.
CREATE TABLE IF NOT EXISTS fact_orders (
    order_key BIGINT NOT NULL AUTO_INCREMENT,
    order_id INT NOT NULL,

    customer_key INT NOT NULL,
    restaurant_key INT NOT NULL,
    date_key INT NOT NULL,

    order_date DATETIME NOT NULL,
    order_hour TINYINT NOT NULL,
    order_status VARCHAR(20) NOT NULL,
    payment_status VARCHAR(20) NOT NULL,
    total_amount DECIMAL(10, 2) NOT NULL,

    source_updated_at DATETIME NOT NULL,
    load_timestamp DATETIME NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (order_key),
    UNIQUE KEY uq_fact_orders_id (order_id),

    CONSTRAINT fk_fact_orders_customer
        FOREIGN KEY (customer_key)
        REFERENCES dim_customers (customer_key),

    CONSTRAINT fk_fact_orders_restaurant
        FOREIGN KEY (restaurant_key)
        REFERENCES dim_restaurants (restaurant_key),

    CONSTRAINT fk_fact_orders_date
        FOREIGN KEY (date_key)
        REFERENCES dim_date (date_key),

    CONSTRAINT chk_fact_orders_amount
        CHECK (total_amount > 0),

    CONSTRAINT chk_fact_orders_hour
        CHECK (order_hour BETWEEN 0 AND 23),

    CONSTRAINT chk_fact_orders_status
        CHECK (
            order_status IN ('Completed', 'Cancelled', 'Pending')
        ),

    CONSTRAINT chk_fact_orders_payment
        CHECK (
            payment_status IN ('Paid', 'Unpaid', 'Pending')
        )
) ENGINE = InnoDB;