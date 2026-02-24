# Real-Time E-Commerce Analytics Pipeline (OMS REALTIME ANALYTICS)

A production-ready, fully Dockerized proof-of-concept architecture demonstrating real-time data streaming and analytics. This replaces traditional batch ETL with low-latency, incremental CDC → Kafka → Doris → dbt → Superset pipeline.

**Tagline:** From source changes → Kafka → Doris → dbt models/tests → Superset dashboards (all in Docker)

---

## 📋 Project Overview

### Core Flow

```
[Python + Faker]
├──→ MySQL (orders table) ──→ Debezium MySQL Connector ──→ Kafka Topic: ecom.woocommerce.orders
├──→ PostgreSQL (dispatch table) ──→ Debezium PG Connector ──→ Kafka Topic: ecom.dispatch.dispatch
└──→ Simulate "Excel" uploads ──→ Direct Kafka Producer → Kafka Topic: ecom.excel_uploads
     ↓
Apache Kafka (KRaft mode)
     ↓ (Routine Load jobs – continuous)
Apache Doris (2.0.0)
     ↓ (raw tables: orders_raw, dispatch_events_raw)
dbt (transformations & tests)
     ↓ (staging views + marts tables + tests)
Superset Dashboards (connect to Doris:9030 via MySQL protocol)
```

### Key Achievements

✅ **Near real-time visibility** (seconds latency) on orders, dispatch status, sales metrics  
✅ **Much lower resource usage** than hourly Materialized View refreshes (incremental ingestion + view-based dbt)  
✅ **Easy to extend** to real sources (Zoho, 3CX, GA) later via Kafka producers/connectors  
✅ **Fully reproducible** with one `docker compose up`  
✅ **Data quality assured** via dbt tests (uniqueness, relationships, business rules)  
✅ **Production bridge** – easy to swap fake generators → real Debezium connectors  

---

## 🎯 Objectives

1. **Demonstrate** end-to-end real-time data flow with sub-minute freshness.
2. **Minimize** compute/storage costs: Use incremental CDC + Routine Load + dbt views/incrementals.
3. **Ensure** data quality via dbt tests (uniqueness, relationships, business rules).
4. **Keep** everything containerized for easy setup, teardown, and sharing.
5. **Simulate** realistic e-commerce data volume/behavior with Faker (orders, customers, dispatch).
6. **Provide** a bridge to production: Easy to swap fake generators → real Debezium connectors.

---

## 🛠 Technology Stack

| Category | Tool | Purpose | Resource Footprint |
|----------|------|---------|-------------------|
| **Orchestration** | Docker Compose | Run entire stack locally | Low |
| **Data Generation** | Python + Faker | Simulate orders, dispatch, uploads | Very Low |
| **Sources** | MySQL 8, PostgreSQL 16 | WooCommerce-like orders + dispatch | Low–Medium |
| **CDC** | Debezium (via Kafka Connect) | Capture changes from MySQL/Postgres | Medium |
| **Streaming Bus** | Apache Kafka (KRaft) | Durable, ordered event transport | Low–Medium |
| **Streaming Ingestion** | Apache Doris Routine Load | Continuous Kafka → Doris import | Low |
| **Analytics DB** | Apache Doris 2.0.0 (FE + BE) | Real-time OLAP storage & querying | Medium (scalable) |
| **Transformations & DQ** | dbt-core + dbt-doris | Clean, model, test data | Low (runs briefly) |
| **Kafka Monitoring** | AKHQ | Web UI for topics/connectors | Very Low |
| **Visualization** | Apache Superset | Dashboards on dbt models | N/A (external) |

---

## 📁 Project Structure

```
OMS_REALTIME_ANALYTICS/
├── docker-compose.yml                 # Full stack orchestration
├── Dockerfile.generator                # Python container for Faker
├── requirements-generator.txt          # Python dependencies
├── generate_data.py                    # Faker script (orders & dispatch)
├── init/
│   ├── init-mysql.sql                 # MySQL schema + sample data
│   ├── init-postgres.sql              # PostgreSQL schema + sample data
│   └── doris-init.sql                 # Doris tables + Routine Load jobs
├── dbt_project/
│   ├── dbt_project.yml                # dbt config
│   ├── profiles.yml                   # Doris connection config
│   ├── models/
│   │   ├── staging/
│   │   │   ├── stg_orders.sql         # Raw orders with dedup
│   │   │   └── stg_dispatch_events.sql # Raw dispatch events
│   │   ├── marts/
│   │   │   ├── fct_orders_enriched.sql # Orders + Dispatch joined
│   │   │   ├── dim_daily_sales.sql    # Daily sales aggregate
│   │   │   └── schema.yml             # Source & model definitions
│   ├── tests/
│   │   └── check_order_duplicates.sql # Singular test
│   └── macros/
│       └── get_latest_record.sql      # Macro for latest record by timestamp
├── scripts/
│   └── register_connectors.sh         # Debezium connector setup
└── README.md                          # This file
```

---

## 🚀 Quick Start

### Prerequisites

- **Docker** (v20.10+) and **Docker Compose** (v2.0+)
- **Git** (optional, for version control)
- **curl** (for connector registration)
- **MySQL client** (optional, `mysql` CLI for direct Doris queries)

### 1️⃣ Clone / Create Project Folder

```bash
cd /home/jaysongor
git clone https://github.com/Jayson-gor/OMS_REALTIME_ANALYTICS.git
cd OMS_REALTIME_ANALYTICS
```

### 2️⃣ Start the Docker Stack

```bash
docker compose up -d

# View logs
docker compose logs -f
```

**Services will be available at:**
- **Doris FE**: `http://localhost:8030`
- **Kafka UI (AKHQ)**: `http://localhost:8080`
- **Kafka Connect**: `http://localhost:8083`
- **MySQL**: `localhost:3306` (user: `ecom_user`, pass: `ecom_pass`)
- **PostgreSQL**: `localhost:5432` (user: `dispatch_user`, pass: `dispatch_pass`)
- **Doris MySQL Protocol**: `localhost:9030` (user: `root`, pass: `123456`)

### 3️⃣ Wait for Services to Be Healthy

```bash
docker compose ps  # All should be 'healthy' or 'running'
```

### 4️⃣ Register Debezium Connectors (Optional — for CDC Testing)

```bash
# Register MySQL connector
curl -X POST http://localhost:8083/connectors \
  -H "Content-Type: application/json" \
  -d @- << 'EOF'
{
  "name": "mysql-orders-connector",
  "config": {
    "connector.class": "io.debezium.connector.mysql.MySqlConnector",
    "database.hostname": "mysql",
    "database.port": 3306,
    "database.user": "ecom_user",
    "database.password": "ecom_pass",
    "database.server.id": 1,
    "database.server.name": "ecom",
    "table.include.list": "ecom.orders",
    "topic.prefix": "ecom",
    "include.schema.changes": true,
    "transforms": "route",
    "transforms.route.type": "org.apache.kafka.connect.transforms.RegexRouter",
    "transforms.route.regex": "([^.]+)\\.([^.]+)\\.([^.]+)",
    "transforms.route.replacement": "$1.$2.$3"
  }
}
EOF

# Register PostgreSQL connector
curl -X POST http://localhost:8083/connectors \
  -H "Content-Type: application/json" \
  -d @- << 'EOF'
{
  "name": "postgres-dispatch-connector",
  "config": {
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
    "plugin.name": "pgoutput",
    "database.hostname": "postgres",
    "database.port": 5432,
    "database.user": "dispatch_user",
    "database.password": "dispatch_pass",
    "database.dbname": "dispatch",
    "database.server.name": "ecom",
    "table.include.list": "public.dispatch_events",
    "topic.prefix": "ecom",
    "publication.name": "dbz_publication"
  }
}
EOF
```

### 5️⃣ Connect to Doris and Initialize Tables

```bash
# Connect to Doris
mysql -h 127.0.0.1 -P 9030 -u root -p123456

# In Doris SQL:
USE ecom;
SHOW TABLES;

-- After Routine Load jobs are running:
SELECT COUNT(*) FROM orders_raw;
SELECT COUNT(*) FROM dispatch_events_raw;
```

### 6️⃣ Run dbt (In Container or Locally)

#### Option A: Run in Docker Container (Recommended)
```bash
docker exec -it oms_data_generator bash

# Inside container
cd /app
pip install dbt-core dbt-doris faker
dbt debug
dbt run --select staging,marts
dbt test
```

#### Option B: Run Locally (on your host)
```bash
# Install dbt and adapter
pip install dbt-core dbt-doris

# Inside dbt_project/
cd dbt_project
dbt debug
dbt run
dbt test
```

### 7️⃣ Generate Synthetic Data

```bash
# Option A: Run in container (recommended)
docker exec -it oms_data_generator python generate_data.py

# Option B: Run on host (ensure Python dependencies installed)
pip install -r requirements-generator.txt
python generate_data.py
```

Monitor progress in Doris:
```bash
mysql -h 127.0.0.1 -P 9030 -u root -p123456
USE ecom;
SELECT COUNT(*) FROM orders_raw;
SELECT COUNT(*) FROM dispatch_events_raw;
SELECT * FROM fct_orders_enriched ORDER BY created_at DESC LIMIT 10;
```

### 8️⃣ Connect Superset (If Available)

If you have Superset running:
1. Add datasource:
   - Type: **MySQL**
   - Host: `localhost` (or `host.docker.internal` if Superset on host)
   - Port: **9030**
   - User: **root**
   - Password: **123456**
   - Database: **ecom**

2. Create charts on dbt marts:
   - `SELECT * FROM fct_orders_enriched WHERE order_date > DATE_SUB(NOW(), INTERVAL 7 DAY);`
   - `SELECT * FROM dim_daily_sales ORDER BY order_date DESC LIMIT 30;`

---

## 🔄 Data Flow Details

### 1. Data Generation (Faker)
- **generate_data.py** runs continuously:
  - Inserts realistic orders into MySQL (triggers Debezium)
  - Inserts dispatch events into PostgreSQL (triggers Debezium)
  - Publishes events directly to Kafka topics (simulating external systems)

### 2. Change Data Capture (Debezium)
- **MySQL Connector**: Captures inserts/updates/deletes from `orders` → publishes to `ecom.woocommerce.orders`
- **PostgreSQL Connector**: Captures inserts/updates/deletes from `dispatch_events` → publishes to `ecom.dispatch.dispatch`

### 3. Kafka Topics
- `ecom.woocommerce.orders` — All order changes
- `ecom.dispatch.dispatch` — All dispatch changes
- `ecom.excel_uploads` — Simulated Excel/bulk uploads (optional)

### 4. Apache Doris Routine Load
- **Continuous jobs** pull data from Kafka topics into Doris tables:
  - `orders_raw` — Kafka → Doris (deduplicated by `order_id`)
  - `dispatch_events_raw` — Kafka → Doris (deduplicated by `dispatch_id`)
  - Ingestion latency: ~10–30 seconds (configurable)

### 5. dbt Transformations
- **Staging layer** (`stg_orders`, `stg_dispatch_events`):
  - Deduplicates rows (keeps latest by timestamp)
  - Light data cleaning
  - Views (no materialization)

- **Marts layer** (`fct_orders_enriched`, `dim_daily_sales`):
  - Joins orders + dispatch for business context
  - Computes derived metrics (days to delivery, fulfillment status, etc.)
  - Materialized tables (refreshed every dbt run)

### 6. Data Quality Tests
- **Uniqueness tests** on order_id, dispatch_id
- **Not-null checks** on required columns
- **Accepted values** for status enums
- **Singular tests** (e.g., `check_order_duplicates.sql`)
- Run via `dbt test`

### 7. Superset Dashboards
- Query `fct_orders_enriched` for individual order details
- Query `dim_daily_sales` for trending metrics
- Build real-time dashboards with <1 min latency

---

## 📊 Monitoring & Debugging

### Kafka Topics & Connectors (AKHQ Web UI)

```
http://localhost:8080
```
- View topics, partitions, and message counts
- Check connector status and logs
- Inspect message payloads in JSON format

### Doris Web Console

```
http://localhost:8030
```
- Check backend health
- View table statistics
- Monitor query performance

### Docker Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f kafka
docker compose logs -f doris-fe
docker compose logs -f data-generator
```

### dbt Artifacts & Tests

```bash
# Run with --debug for detailed logs
dbt run --debug

# View compiled SQL
cat dbt_project/target/compiled/oms_realtime_analytics/models/marts/fct_orders_enriched.sql

# Run specific tests
dbt test --select stg_orders
```

---

## 💾 Data Management

### Backup Doris Tables

```bash
mysql -h 127.0.0.1 -P 9030 -u root -p123456 \
  -e "USE ecom; SELECT * FROM orders_raw LIMIT 1000;" > orders_backup.csv
```

### Reset (Clear All Data)

```bash
# Stop all containers
docker compose down

# Remove volumes (WARNING: deletes all data)
docker compose down -v

# Restart
docker compose up -d
```

### Export Data to CSV

```bash
# Query from Doris to CSV
docker exec oms_mysql mysql -h doris-fe -P 9030 -u root -p123456 \
  ecom -e "SELECT * FROM fct_orders_enriched" > fct_orders_export.csv
```

---

## 🔧 Configuration & Customization

### Adjust Data Generation Rate

Edit **generate_data.py**:
```python
# Line ~150: Increase/decrease sleep intervals
time.sleep(random.uniform(1, 10))  # Increase 1st number for slower rate
time.sleep(random.uniform(2, 15))  # Dispatch generation interval
```

### Change Kafka Retention / Partition Count

Edit **docker-compose.yml**:
```yaml
kafka:
  environment:
    KAFKA_NUM_PARTITIONS: 3  # Increase from default 1
    KAFKA_LOG_RETENTION_MS: 604800000  # 7 days (default)
```

### Doris Routine Load Batch Size

In Doris SQL:
```sql
ALTER ROUTINE LOAD orders_kafka_load PROPERTIES(
  "max_batch_rows" = "50000",  -- More rows per batch
  "max_batch_interval" = "30"  -- Or adjust interval (seconds)
);
```

### Scale dbt Threads

Edit **dbt_project/profiles.yml**:
```yaml
threads: 8  # Increase from 4 for parallel model execution
```

---

## 🚀 Moving to Production

### Multi-Node Doris Deployment
- Add more `doris-be` services in docker-compose
- Update `FE_SERVERS` and `dbt_project/profiles.yml`
- Increase `replication_num` from 1 to 3

### Real Data Sources
1. **Replace Faker** with real Debezium connectors (Zoho, Shopify, etc.)
2. **Secure Kafka**:
   - Enable authentication (SASL/SCRAM)
   - Use SSL certificates
3. **Scheduled dbt Runs**:
   - Airflow DAG (`dags/dbt_run_dag.py`)
   - Kubernetes CronJob
   - dbt Cloud Scheduler

### High-Availability Setup
```
Kafka Cluster (3+ brokers)
  ↓
Doris Cluster (3+ FE, 3+ BE)
  ↓
dbt Runner (Kubernetes pod)
  ↓
Superset + Reverse Proxy (High-Availability)
```

---

## 📋 Checklist for First Run

- [ ] Docker & Docker Compose installed and running
- [ ] Clone/create project in `/home/jaysongor/OMS_REALTIME_ANALYTICS`
- [ ] Run `docker compose up -d`
- [ ] Wait for all services to show "healthy" or "running"
- [ ] Verify AKHQ is accessible at `http://localhost:8080`
- [ ] Verify Doris FE at `http://localhost:8030`
- [ ] Connect to Doris: `mysql -h localhost -P 9030 -u root -p123456`
- [ ] Run `python generate_data.py` to start synthetic data flow
- [ ] Monitor data in `docker compose logs -f`
- [ ] Run `dbt run` in dbt container to create models
- [ ] Query results: `SELECT * FROM ecom.fct_orders_enriched LIMIT 10;`
- [ ] Connect Superset to Doris (if available)
- [ ] Build dashboards on marts

---

## 🐛 Troubleshooting

### Services Not Starting

```bash
# Check logs
docker compose logs

# Ensure ports are free
lsof -i :9030 -i :3306 -i :5432 -i :9092

# Rebuild images
docker compose build --no-cache
docker compose up -d
```

### Kafka Producer Errors

```bash
# Check Kafka broker health
docker exec oms_kafka kafka-broker-api-versions.sh --bootstrap-server localhost:9092

# Test producer
docker exec oms_kafka kafka-console-producer.sh \
  --broker-list localhost:9092 --topic test
```

### Doris Connection Errors

```bash
# Check Doris FE is ready
docker exec oms_doris_fe curl http://localhost:8030/api/bootstrap

# Verify MySQL protocol listener
docker exec oms_doris_fe ss -tlnp | grep 9030
```

### dbt Compilation Errors

```bash
# Debug profile
cd dbt_project && dbt debug

# Check profiles.yml: hostnames should be 'localhost' (dev) or 'doris-fe' (in-container)
```

### Routine Load Not Running

```sql
-- In Doris, check routine load status
SHOW ROUTINE LOAD;
SHOW ROUTINE LOAD TASK WHERE NAME = 'orders_kafka_load';

-- View last events
SELECT * FROM information_schema.routine_load_task_job;
```

---

## 📚 Additional Resources

- **Doris Documentation**: https://doris.apache.org/
- **dbt Adapter for Doris**: https://github.com/selectdb/dbt-doris
- **Debezium Connectors**: https://debezium.io/
- **Kafka Documentation**: https://kafka.apache.org/documentation/
- **dbt Documentation**: https://docs.getdbt.com/

---

## 📝 Contributing

Contributions welcome! Please:
1. Create a feature branch (`git checkout -b feature/your-feature`)
2. Commit changes (`git commit -am 'Add feature'`)
3. Push to branch (`git push origin feature/your-feature`)
4. Open a Pull Request

---

## 📄 License

This project is provided as-is for educational and demo purposes.

---

## 👥 Support & Contact

For issues, feature requests, or questions:
- **GitHub Issues**: https://github.com/Jayson-gor/OMS_REALTIME_ANALYTICS/issues
- **Email**: jayson.gor@example.com (replace with your email)

---

## 🎓 Learning Path

**Beginner**: Run `docker compose up`, generate data, query in Doris, explore AKHQ  
**Intermediate**: Customize dbt models, adjust Kafka settings, understand CDC flow  
**Advanced**: Deploy multi-node Doris, integrate real sources, scale to production  

**Estimated Time to Completion**:
- Quick start (just run): **15 min**
- Full setup with dbt + dashboards: **1–2 hours**
- Production readiness: **2–4 weeks** (depending on integration complexity)

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-02-24 | Initial release with Doris 2.0.0, KRaft Kafka, dbt staging/marts |

---

**Happy streaming! 🎉**
