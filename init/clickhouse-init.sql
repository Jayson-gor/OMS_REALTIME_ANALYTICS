-- ClickHouse initialization script for real-time e-commerce analytics

-- Create database
CREATE DATABASE IF NOT EXISTS ecom;

USE ecom;

-- Raw orders table (ingested from MySQL via Kafka)
CREATE TABLE IF NOT EXISTS orders_raw (
    order_id UInt32,
    customer_id UInt32,
    order_date DateTime,
    total_amount Decimal(12, 2),
    currency String,
    payment_status String,
    status String,
    shipping_address String,
    created_at DateTime,
    updated_at DateTime
) ENGINE = ReplacingMergeTree(updated_at)
ORDER BY (order_id, updated_at);

-- Raw dispatch events table (ingested from PostgreSQL via Kafka)
CREATE TABLE IF NOT EXISTS dispatch_events_raw (
    dispatch_id UInt32,
    order_id UInt32,
    warehouse_id UInt32,
    status String,
    carrier String,
    tracking_number String,
    estimated_delivery Date,
    actual_delivery Nullable(Date),
    notes String,
    created_at DateTime,
    updated_at DateTime
) ENGINE = ReplacingMergeTree(updated_at)
ORDER BY (dispatch_id, updated_at);

-- Summary table
CREATE TABLE IF NOT EXISTS orders_summary (
    summary_date Date,
    total_orders UInt32,
    total_revenue Decimal(15, 2),
    avg_order_value Decimal(12, 2),
    order_count UInt32
) ENGINE = SummingMergeTree()
ORDER BY summary_date;
