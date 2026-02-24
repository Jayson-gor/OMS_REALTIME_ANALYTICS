-- Apache Doris initialization script
-- Creates database and tables for streaming ingestion via Kafka

CREATE DATABASE IF NOT EXISTS ecom;
USE ecom;

-- Raw orders table (will be populated from MySQL via Kafka CDC)
CREATE TABLE IF NOT EXISTS orders_raw (
    order_id INT,
    customer_id INT,
    order_date DATETIME,
    total_amount DECIMAL(12, 2),
    currency VARCHAR(10),
    payment_status VARCHAR(50),
    status VARCHAR(50),
    shipping_address VARCHAR(255),
    created_at DATETIME,
    updated_at DATETIME
) DUPLICATE KEY(order_id)
DISTRIBUTED BY HASH(order_id) BUCKETS 10
PROPERTIES (
    "replication_num" = "1",
    "light_schema_change" = "true"
);

-- Raw dispatch events table
CREATE TABLE IF NOT EXISTS dispatch_events_raw (
    dispatch_id INT,
    order_id INT,
    warehouse_id INT,
    status VARCHAR(50),
    carrier VARCHAR(100),
    tracking_number VARCHAR(100),
    estimated_delivery DATE,
    actual_delivery DATE,
    notes VARCHAR(255),
    created_at DATETIME,
    updated_at DATETIME
) DUPLICATE KEY(dispatch_id)
DISTRIBUTED BY HASH(dispatch_id) BUCKETS 10
PROPERTIES (
    "replication_num" = "1",
    "light_schema_change" = "true"
);

-- Summary table for testing
CREATE TABLE IF NOT EXISTS orders_summary (
    summary_date DATE,
    total_orders INT,
    total_revenue DECIMAL(15, 2),
    avg_order_value DECIMAL(12, 2)
) DUPLICATE KEY(summary_date)
DISTRIBUTED BY HASH(summary_date) BUCKETS 5
PROPERTIES (
    "replication_num" = "1"
);
