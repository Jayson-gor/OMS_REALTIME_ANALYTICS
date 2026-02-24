{{
    config(
        materialized='table',
        schema='marts'
    )
}}

WITH latest_orders AS (
    SELECT * FROM {{ ref('stg_orders') }}
    WHERE row_num = 1
)

SELECT
    DATE(order_date) AS order_date,
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(total_amount) AS total_revenue,
    AVG(total_amount) AS avg_order_value,
    MIN(total_amount) AS min_order_value,
    MAX(total_amount) AS max_order_value,
    COUNT(DISTINCT CASE WHEN status = 'delivered' THEN order_id END) AS delivered_orders,
    COUNT(DISTINCT CASE WHEN status = 'pending' THEN order_id END) AS pending_orders,
    COUNT(DISTINCT CASE WHEN status = 'cancelled' THEN order_id END) AS cancelled_orders,
    CURRENT_TIMESTAMP() AS refreshed_at
FROM latest_orders
GROUP BY DATE(order_date)
ORDER BY order_date DESC
