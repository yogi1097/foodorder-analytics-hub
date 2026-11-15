CREATE TABLE IF NOT EXISTS foodorder_analytics.pipeline_run_log (
    run_id BIGINT NOT NULL AUTO_INCREMENT,
    pipeline_name VARCHAR(100) NOT NULL,
    started_at DATETIME(6) NOT NULL,
    finished_at DATETIME(6),
    run_status VARCHAR(20) NOT NULL,
    source_order_count BIGINT,
    warehouse_order_count BIGINT,
    error_message TEXT,

    PRIMARY KEY (run_id),

    CONSTRAINT chk_pipeline_run_status
        CHECK (run_status IN ('RUNNING', 'SUCCESS', 'FAILED'))
);