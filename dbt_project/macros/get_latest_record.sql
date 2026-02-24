-- Macro to get the latest record for a table with timestamp
-- Usage: {{ get_latest_record(table_name, partition_column, timestamp_column) }}

{% macro get_latest_record(table_name, partition_column, timestamp_column) %}
    SELECT *
    FROM {{ table_name }}
    WHERE row_number() over (partition by {{ partition_column }} order by {{ timestamp_column }} desc) = 1
{% endmacro %}
