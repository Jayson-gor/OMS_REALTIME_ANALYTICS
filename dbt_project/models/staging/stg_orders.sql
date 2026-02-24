{{
    config(
        materialized='view',
        schema='staging'
    )
}}

SELECT
    order_id,
    customer_id,
    order_date,
    total_amount,
    currency,
    payment_status,
    status,
    shipping_address,
    created_at,
    updated_at,
    ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY updated_at DESC) AS row_num
FROM {{ source('ecom', 'orders_raw') }}
WHERE updated_at IS NOT NULL
