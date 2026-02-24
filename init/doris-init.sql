-- Apache Doris initialization script
-- Creates database and raw tables for streaming ingestion

-- Create ecom database
CREATE DATABASE IF NOT EXISTS ecom;

USE ecom;

-- Raw orders table (ingested from MySQL via Kafka)
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
) ENGINE=OLAP
UNIQUE KEY(order_id)
DISTRIBUTED BY HASH(order_id) BUCKETS 10
PROPERTIES (
    "replication_num" = "1",
    "light_schema_change" = "true"
);

-- Raw dispatch events table (ingested from PostgreSQL via Kafka)
CREATE TABLE IF NOT EXISTS dispatch_events_raw (
    dispatch_id INT,
    order_id INT,
    warehouse_id INT,
    status VARCHAR(50),
    carrier VARCHAR(100),
    tracking_number VARCHAR(100),
    estimated_delivery DATE,
    actual_delivery DATE,
    notes TEXT,
    created_at DATETIME,
    updated_at DATETIME
) ENGINE=OLAP
UNIQUE KEY(dispatch_id)
DISTRIBUTED BY HASH(dispatch_id) BUCKETS 10
PROPERTIES (
    "replication_num" = "1",
    "light_schema_change" = "true"
);

-- Kafka Routine Load for orders
-- Note: This should be executed manually or via dbt after Doris is running
-- CREATE ROUTINE LOAD orders_kafka_load ON orders_raw
-- COLUMNS(order_id, customer_id, order_date, total_amount, currency, payment_status, status, shipping_address, created_at, updated_at)
-- PROPERTIES(
--   "max_batch_interval" = "10",
--   "max_batch_rows" = "100000"
-- )
-- FROM KAFKA (
--   "kafka_broker_list" = "kafka:29092",
--   "kafka_topic" = "ecom.woocommerce.orders",
--   "property.group.id" = "doris_orders_consumer",
--   "property.clients.per.group" = "3"
-- );

-- Kafka Routine Load for dispatch events
-- CREATE ROUTINE LOAD dispatch_kafka_load ON dispatch_events_raw
-- COLUMNS(dispatch_id, order_id, warehouse_id, status, carrier, tracking_number, estimated_delivery, actual_delivery, notes, created_at, updated_at)
-- PROPERTIES(
--   "max_batch_interval" = "10",
--   "max_batch_rows" = "100000"
-- )
-- FROM KAFKA (
--   "kafka_broker_list" = "kafka:29092",
--   "kafka_topic" = "ecom.dispatch.dispatch",
--   "property.group.id" = "doris_dispatch_consumer",
--   "property.clients.per.group" = "3"
-- );

-- Create a simple aggregate table for testing
CREATE TABLE IF NOT EXISTS orders_summary (
    summary_date DATE,
    total_orders INT,
    total_revenue DECIMAL(15, 2),
    avg_order_value DECIMAL(12, 2),
    order_count INT
) ENGINE=OLAP
DUPLICATE KEY(summary_date)
DISTRIBUTED BY HASH(summary_date) BUCKETS 10
PROPERTIES (
    "replication_num" = "1"
);
