USE foodorder_analytics;

CREATE TABLE IF NOT EXISTS pipeline_watermarks (
    pipeline_name VARCHAR(100) NOT NULL,
    last_successful_watermark DATETIME NOT NULL,
    last_successful_run_at DATETIME(6),

    PRIMARY KEY (pipeline_name)
);

-- Initialize only if this pipeline has no watermark yet.
INSERT INTO pipeline_watermarks (
    pipeline_name,
    last_successful_watermark
)
SELECT
    'incremental_orders',
    '1900-01-01 00:00:00'
WHERE NOT EXISTS (
    SELECT 1
    FROM pipeline_watermarks
    WHERE pipeline_name = 'incremental_orders'
);

SELECT *
FROM pipeline_watermarks;