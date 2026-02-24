#!/usr/bin/env python3
"""
Real-Time E-Commerce Data Generator
Produces synthetic data to MySQL, PostgreSQL, and Kafka for streaming demo
"""

import json
import time
import random
import logging
import os
from datetime import datetime, timedelta
from typing import Dict, Any
from concurrent.futures import ThreadPoolExecutor

from faker import Faker
from kafka import KafkaProducer
import mysql.connector
import psycopg2
from psycopg2 import pool

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

fake = Faker()

# Environment variables
MYSQL_HOST = os.getenv('MYSQL_HOST', 'localhost')
MYSQL_PORT = int(os.getenv('MYSQL_PORT', 3306))
MYSQL_USER = os.getenv('MYSQL_USER', 'ecom_user')
MYSQL_PASSWORD = os.getenv('MYSQL_PASSWORD', 'ecom_pass')
MYSQL_DB = os.getenv('MYSQL_DB', 'ecom')

POSTGRES_HOST = os.getenv('POSTGRES_HOST', 'localhost')
POSTGRES_PORT = int(os.getenv('POSTGRES_PORT', 5432))
POSTGRES_USER = os.getenv('POSTGRES_USER', 'dispatch_user')
POSTGRES_PASSWORD = os.getenv('POSTGRES_PASSWORD', 'dispatch_pass')
POSTGRES_DB = os.getenv('POSTGRES_DB', 'dispatch')

KAFKA_BOOTSTRAP_SERVERS = os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'localhost:9092')

# Kafka producer setup
try:
    kafka_producer = KafkaProducer(
        bootstrap_servers=KAFKA_BOOTSTRAP_SERVERS,
        value_serializer=lambda v: json.dumps(v).encode('utf-8'),
        retries=3,
        retry_backoff_ms=100
    )
    logger.info(f"Connected to Kafka at {KAFKA_BOOTSTRAP_SERVERS}")
except Exception as e:
    logger.error(f"Failed to connect to Kafka: {e}")
    kafka_producer = None


class MySQLConnector:
    """Handle MySQL connections for order data"""

    def __init__(self):
        self.connection = None
        self.connect()

    def connect(self):
        try:
            self.connection = mysql.connector.connect(
                host=MYSQL_HOST,
                port=MYSQL_PORT,
                user=MYSQL_USER,
                password=MYSQL_PASSWORD,
                database=MYSQL_DB
            )
            logger.info(f"Connected to MySQL at {MYSQL_HOST}:{MYSQL_PORT}")
        except Exception as e:
            logger.error(f"Failed to connect to MySQL: {e}")
            self.connection = None

    def insert_order(self, order: Dict[str, Any]) -> bool:
        if not self.connection:
            return False
        try:
            cursor = self.connection.cursor()
            insert_query = """
                INSERT INTO orders 
                (customer_id, order_date, total_amount, currency, payment_status, status, shipping_address, created_at, updated_at) 
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            """
            values = (
                order['customer_id'],
                order['order_date'],
                order['total_amount'],
                order['currency'],
                order['payment_status'],
                order['status'],
                order['shipping_address'],
                datetime.now(),
                datetime.now()
            )
            cursor.execute(insert_query, values)
            self.connection.commit()
            order_id = cursor.lastrowid
            cursor.close()
            logger.debug(f"Inserted order {order_id} to MySQL")
            return True
        except Exception as e:
            logger.error(f"Failed to insert order to MySQL: {e}")
            return False

    def close(self):
        if self.connection:
            self.connection.close()
            logger.info("MySQL connection closed")


class PostgresConnector:
    """Handle PostgreSQL connections for dispatch data"""

    def __init__(self):
        self.pool = None
        self.connect()

    def connect(self):
        try:
            self.pool = psycopg2.pool.SimpleConnectionPool(
                1, 5,
                host=POSTGRES_HOST,
                port=POSTGRES_PORT,
                database=POSTGRES_DB,
                user=POSTGRES_USER,
                password=POSTGRES_PASSWORD
            )
            logger.info(f"Connected to PostgreSQL at {POSTGRES_HOST}:{POSTGRES_PORT}")
        except Exception as e:
            logger.error(f"Failed to connect to PostgreSQL: {e}")
            self.pool = None

    def insert_dispatch(self, dispatch: Dict[str, Any]) -> bool:
        if not self.pool:
            return False
        conn = None
        try:
            conn = self.pool.getconn()
            cursor = conn.cursor()
            insert_query = """
                INSERT INTO dispatch_events 
                (order_id, warehouse_id, status, carrier, tracking_number, estimated_delivery, created_at, updated_at) 
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            """
            values = (
                dispatch['order_id'],
                dispatch['warehouse_id'],
                dispatch['status'],
                dispatch['carrier'],
                dispatch['tracking_number'],
                dispatch['estimated_delivery'],
                datetime.now(),
                datetime.now()
            )
            cursor.execute(insert_query, values)
            conn.commit()
            cursor.close()
            logger.debug(f"Inserted dispatch for order {dispatch['order_id']} to PostgreSQL")
            return True
        except Exception as e:
            logger.error(f"Failed to insert dispatch to PostgreSQL: {e}")
            return False
        finally:
            if conn:
                self.pool.putconn(conn)

    def close(self):
        if self.pool:
            self.pool.closeall()
            logger.info("PostgreSQL connection closed")


def generate_order() -> Dict[str, Any]:
    """Generate a realistic order"""
    return {
        'customer_id': random.randint(1, 100),
        'order_date': datetime.now() - timedelta(days=random.randint(0, 30)),
        'total_amount': round(random.uniform(10, 2000), 2),
        'currency': random.choice(['USD', 'EUR', 'GBP', 'CAD']),
        'payment_status': random.choice(['pending', 'completed', 'failed', 'refunded']),
        'status': random.choice(['pending', 'processing', 'shipped', 'delivered', 'cancelled']),
        'shipping_address': f"{fake.street_address()}, {fake.city()}, {fake.country()}"
    }


def generate_dispatch(order_id: int) -> Dict[str, Any]:
    """Generate dispatch event for order"""
    return {
        'order_id': order_id,
        'warehouse_id': random.randint(1, 4),
        'status': random.choice(['pending', 'picked', 'packed', 'shipped', 'in_transit', 'delivered', 'failed']),
        'carrier': random.choice(['FedEx', 'UPS', 'DHL', 'Local Courier']),
        'tracking_number': f"TRACK{''.join(random.choices('0123456789', k=10))}",
        'estimated_delivery': (datetime.now() + timedelta(days=random.randint(1, 14))).date()
    }


def produce_to_kafka(topic: str, data: Dict[str, Any], key: str = None):
    """Send data to Kafka"""
    if not kafka_producer:
        logger.warning("Kafka producer not initialized")
        return False
    try:
        kafka_producer.send(topic, key=key.encode() if key else None, value=data)
        kafka_producer.flush(timeout=10)
        logger.debug(f"Produced message to topic '{topic}'")
        return True
    except Exception as e:
        logger.error(f"Failed to produce to Kafka topic '{topic}': {e}")
        return False


def continuous_order_generation(mysql_conn: MySQLConnector, duration_seconds: int = 3600):
    """Continuously generate and produce orders"""
    logger.info(f"Starting order generation for {duration_seconds} seconds")
    start_time = time.time()

    while time.time() - start_time < duration_seconds:
        try:
            order = generate_order()

            # Insert to MySQL
            if mysql_conn.insert_order(order):
                # Produce to Kafka
                produce_to_kafka('ecom.woocommerce.orders', order, key=str(order['customer_id']))
                logger.info(f"Generated and produced order | Customer: {order['customer_id']}, Amount: {order['total_amount']}")

            # Random interval to simulate realistic order arrival
            time.sleep(random.uniform(1, 10))

        except Exception as e:
            logger.error(f"Error in order generation loop: {e}")
            time.sleep(5)

    logger.info("Order generation completed")


def continuous_dispatch_generation(postgres_conn: PostgresConnector, duration_seconds: int = 3600):
    """Continuously generate and produce dispatch events"""
    logger.info(f"Starting dispatch generation for {duration_seconds} seconds")
    start_time = time.time()

    while time.time() - start_time < duration_seconds:
        try:
            # Simulate dispatch for random orders
            order_id = random.randint(1, 1000)
            dispatch = generate_dispatch(order_id)

            # Insert to PostgreSQL
            if postgres_conn.insert_dispatch(dispatch):
                # Produce to Kafka
                produce_to_kafka('ecom.dispatch.dispatch', dispatch, key=str(dispatch['order_id']))
                logger.info(f"Generated and produced dispatch | Order: {order_id}, Status: {dispatch['status']}")

            # Random interval to simulate dispatch events
            time.sleep(random.uniform(2, 15))

        except Exception as e:
            logger.error(f"Error in dispatch generation loop: {e}")
            time.sleep(5)

    logger.info("Dispatch generation completed")


def main():
    """Main entry point"""
    logger.info("=== Real-Time E-Commerce Data Generator ===")

    mysql_conn = MySQLConnector()
    postgres_conn = PostgresConnector()

    # Duration in seconds (default 1 hour)
    duration = 3600

    try:
        # Run both generators in parallel
        with ThreadPoolExecutor(max_workers=2) as executor:
            executor.submit(continuous_order_generation, mysql_conn, duration)
            executor.submit(continuous_dispatch_generation, postgres_conn, duration)

            # Keep main thread alive
            time.sleep(duration + 10)

        logger.info("Data generation completed successfully")

    except KeyboardInterrupt:
        logger.info("Data generation interrupted by user")
    except Exception as e:
        logger.error(f"Fatal error in data generation: {e}")
    finally:
        mysql_conn.close()
        postgres_conn.close()
        if kafka_producer:
            kafka_producer.close()


if __name__ == '__main__':
    main()
