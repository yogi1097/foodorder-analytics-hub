SELECT VERSION() AS mysql_version;
CREATE DATABASE IF NOT EXISTS foodorder_source
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;

USE foodorder_source;

CREATE TABLE IF NOT EXISTS customers (
    customer_id INT NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL,
    city VARCHAR(100) NOT NULL,
    state CHAR(2) NOT NULL,
    registration_date DATE NOT NULL,
    updated_at DATETIME NOT NULL,

    PRIMARY KEY (customer_id),
    UNIQUE KEY uq_customers_email (email)
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS restaurants (
    restaurant_id INT NOT NULL,
    restaurant_name VARCHAR(150) NOT NULL,
    cuisine_type VARCHAR(50) NOT NULL,
    city VARCHAR(100) NOT NULL,
    state CHAR(2) NOT NULL,
    is_active TINYINT NOT NULL DEFAULT 1,
    updated_at DATETIME NOT NULL,

    PRIMARY KEY (restaurant_id),
    CONSTRAINT chk_restaurants_active
        CHECK (is_active IN (0, 1))
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS orders (
    order_id INT NOT NULL,
    customer_id INT NOT NULL,
    restaurant_id INT NOT NULL,
    order_date DATETIME NOT NULL,
    order_status VARCHAR(20) NOT NULL,
    payment_status VARCHAR(20) NOT NULL,
    total_amount DECIMAL(10, 2) NOT NULL,
    updated_at DATETIME NOT NULL,

    PRIMARY KEY (order_id),

    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id)
        REFERENCES customers (customer_id),

    CONSTRAINT fk_orders_restaurant
        FOREIGN KEY (restaurant_id)
        REFERENCES restaurants (restaurant_id),

    CONSTRAINT chk_orders_amount
        CHECK (total_amount > 0),

    CONSTRAINT chk_orders_status
        CHECK (
            order_status IN ('Completed', 'Cancelled', 'Pending')
        ),

    CONSTRAINT chk_orders_payment
        CHECK (
            payment_status IN ('Paid', 'Unpaid', 'Pending')
        ),

    INDEX idx_orders_order_date (order_date),
    INDEX idx_orders_updated_at (updated_at)
) ENGINE = InnoDB;