{{
    config(
        materialized='table',
        schema='marts'
    )
}}

WITH latest_orders AS (
    SELECT * FROM {{ ref('stg_orders') }}
    WHERE row_num = 1
),

latest_dispatch AS (
    SELECT * FROM {{ ref('stg_dispatch_events') }}
    WHERE row_num = 1
)

SELECT
    o.order_id,
    o.customer_id,
    o.order_date,
    o.total_amount,
    o.currency,
    o.payment_status,
    o.status AS order_status,
    o.shipping_address,
    d.dispatch_id,
    d.warehouse_id,
    d.status AS dispatch_status,
    d.carrier,
    d.tracking_number,
    d.estimated_delivery,
    d.actual_delivery,
    CASE
        WHEN d.status = 'delivered' THEN 'completed'
        WHEN d.status IN ('shipped', 'in_transit') THEN 'in_transit'
        WHEN d.status = 'pending' THEN 'pending'
        WHEN d.status = 'failed' OR d.status = 'cancelled' THEN 'failed'
        ELSE 'unknown'
    END AS fulfillment_status,
    DATEDIFF(COALESCE(d.actual_delivery, CURRENT_DATE), o.order_date) AS days_to_delivery,
    o.created_at,
    CURRENT_TIMESTAMP() AS refreshed_at
FROM latest_orders o
LEFT JOIN latest_dispatch d ON o.order_id = d.order_id
