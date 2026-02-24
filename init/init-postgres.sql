-- PostgreSQL initialization script for dispatch database
-- Creates tables for dispatch/logistics system

CREATE DATABASE IF NOT EXISTS dispatch;
\c dispatch;

-- Enable logical replication for CDC
ALTER SYSTEM SET wal_level = logical;

-- Create dispatch_statuses enum type
CREATE TYPE dispatch_status AS ENUM ('pending', 'picked', 'packed', 'shipped', 'in_transit', 'delivered', 'failed', 'cancelled');

-- Create warehouses table
CREATE TABLE IF NOT EXISTS warehouses (
    warehouse_id SERIAL PRIMARY KEY,
    warehouse_name VARCHAR(255) NOT NULL,
    location VARCHAR(255),
    capacity INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create dispatch_events table (main source for streaming)
CREATE TABLE IF NOT EXISTS dispatch_events (
    dispatch_id SERIAL PRIMARY KEY,
    order_id INT NOT NULL,
    warehouse_id INT,
    status dispatch_status DEFAULT 'pending',
    carrier VARCHAR(100),
    tracking_number VARCHAR(100),
    estimated_delivery DATE,
    actual_delivery DATE,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create shipment_tracking table
CREATE TABLE IF NOT EXISTS shipment_tracking (
    tracking_id SERIAL PRIMARY KEY,
    dispatch_id INT NOT NULL REFERENCES dispatch_events(dispatch_id),
    event_type VARCHAR(100),
    event_location VARCHAR(255),
    recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Add indexes for better replication performance
CREATE INDEX idx_dispatch_order_id ON dispatch_events(order_id);
CREATE INDEX idx_dispatch_status ON dispatch_events(status);
CREATE INDEX idx_dispatch_updated_at ON dispatch_events(updated_at);
CREATE INDEX idx_shipment_dispatch_id ON shipment_tracking(dispatch_id);

-- Insert sample data
INSERT INTO warehouses (warehouse_name, location, capacity) VALUES
('Main Warehouse', 'New York, USA', 5000),
('West Coast Hub', 'Los Angeles, USA', 3000),
('European Center', 'Amsterdam, Netherlands', 2000),
('APAC Hub', 'Singapore', 2500)
ON CONFLICT (warehouse_id) DO NOTHING;

-- Grant replication permission
CREATE USER IF NOT EXISTS debezium_user WITH LOGIN PASSWORD 'debezium_pass';
GRANT CONNECT ON DATABASE dispatch TO debezium_user;
GRANT USAGE ON SCHEMA public TO debezium_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO debezium_user;
GRANT CREATE ON SCHEMA public TO debezium_user;
