-- Test: Check for duplicate order IDs
SELECT order_id, COUNT(*) as count
FROM {{ ref('stg_orders') }}
GROUP BY order_id
HAVING COUNT(*) > 1
