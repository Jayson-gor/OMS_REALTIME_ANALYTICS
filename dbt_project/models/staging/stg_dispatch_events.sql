{{
    config(
        materialized='view',
        schema='staging'
    )
}}

SELECT
    dispatch_id,
    order_id,
    warehouse_id,
    status,
    carrier,
    tracking_number,
    estimated_delivery,
    actual_delivery,
    notes,
    created_at,
    updated_at,
    ROW_NUMBER() OVER (PARTITION BY dispatch_id ORDER BY updated_at DESC) AS row_num
FROM {{ source('ecom', 'dispatch_events_raw') }}
WHERE updated_at IS NOT NULL
