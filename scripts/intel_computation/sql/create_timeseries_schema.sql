-- Time-series Intelligence Metrics Schema
-- Optimized for MCP compatibility and high-performance analytics

-- Drop existing tables if they exist
DROP TABLE IF EXISTS osint.intel_metrics CASCADE;

-- ================================================================
-- Main time-series metrics table
-- ================================================================
CREATE TABLE osint.intel_metrics (
    -- TIME DIMENSION (primary)
    time TIMESTAMPTZ NOT NULL,

    -- TAGS (indexed dimensions)
    metric_name VARCHAR(100) NOT NULL,
    entity_type VARCHAR(20) NOT NULL,
    entity_id INTEGER NOT NULL,

    -- VALUES (flexible storage for different data types)
    value_float DOUBLE PRECISION,        -- Numeric metrics
    value_int BIGINT,                    -- Integer counts
    value_text TEXT,                     -- Text values (e.g., 'stable', 'growing')
    value_json JSONB,                    -- Complex objects

    -- METADATA
    unit VARCHAR(50),                    -- 'count', 'percentage', 'score', 'rate'
    computation_version VARCHAR(10) DEFAULT '1.0',
    data_quality DOUBLE PRECISION DEFAULT 1.0,       -- Confidence score (0-1)
    computed_at TIMESTAMPTZ DEFAULT NOW(),

    PRIMARY KEY (time, metric_name, entity_type, entity_id)
);

-- ================================================================
-- Indexes (optimized for time-series queries)
-- ================================================================
CREATE INDEX idx_metrics_time_desc ON osint.intel_metrics(time DESC);
CREATE INDEX idx_metrics_entity ON osint.intel_metrics(entity_type, entity_id);
CREATE INDEX idx_metrics_name ON osint.intel_metrics(metric_name);
CREATE INDEX idx_metrics_time_name ON osint.intel_metrics(time, metric_name);
CREATE INDEX idx_metrics_entity_time ON osint.intel_metrics(entity_type, entity_id, time DESC);

-- GIN index for JSONB queries
CREATE INDEX idx_metrics_json ON osint.intel_metrics USING GIN (value_json);

-- Constraint for valid entity types
ALTER TABLE osint.intel_metrics
ADD CONSTRAINT check_entity_type
CHECK (entity_type IN ('project', 'theme'));

-- Table comment
COMMENT ON TABLE osint.intel_metrics IS
'InfluxDB-style time-series metrics storage. Each row is a single measurement at a point in time.';

-- ================================================================
-- Helper functions for querying metrics
-- ================================================================

-- Get metric values for an entity over time
CREATE OR REPLACE FUNCTION osint.get_metric_series(
    p_metric_name VARCHAR,
    p_entity_type VARCHAR,
    p_entity_id INTEGER,
    p_start_time TIMESTAMPTZ DEFAULT NOW() - INTERVAL '30 days',
    p_end_time TIMESTAMPTZ DEFAULT NOW()
)
RETURNS TABLE(
    metric_time TIMESTAMPTZ,
    value_numeric DOUBLE PRECISION,
    value_text TEXT,
    unit VARCHAR(50)
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        m.time as metric_time,
        COALESCE(m.value_float, m.value_int::double precision) as value_numeric,
        m.value_text,
        m.unit
    FROM osint.intel_metrics m
    WHERE m.metric_name = p_metric_name
        AND m.entity_type = p_entity_type
        AND m.entity_id = p_entity_id
        AND m.time >= p_start_time
        AND m.time <= p_end_time
    ORDER BY m.time;
END;
$$;

-- Get all metrics for an entity at a specific time
CREATE OR REPLACE FUNCTION osint.get_entity_snapshot(
    p_entity_type VARCHAR,
    p_entity_id INTEGER,
    p_time TIMESTAMPTZ DEFAULT DATE_TRUNC('day', NOW())
)
RETURNS TABLE(
    metric_name VARCHAR(100),
    value_numeric DOUBLE PRECISION,
    value_text TEXT,
    value_json JSONB,
    unit VARCHAR(50)
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        m.metric_name,
        COALESCE(m.value_float, m.value_int::double precision) as value_numeric,
        m.value_text,
        m.value_json,
        m.unit
    FROM osint.intel_metrics m
    WHERE m.entity_type = p_entity_type
        AND m.entity_id = p_entity_id
        AND m.time = p_time
    ORDER BY m.metric_name;
END;
$$;

-- ================================================================
-- Views for common queries
-- ================================================================

-- Latest metrics for all entities
CREATE OR REPLACE VIEW osint.v_latest_metrics AS
SELECT DISTINCT ON (entity_type, entity_id, metric_name)
    entity_type,
    entity_id,
    metric_name,
    time,
    COALESCE(value_float, value_int::double precision) as value_numeric,
    value_text,
    value_json,
    unit
FROM osint.intel_metrics
ORDER BY entity_type, entity_id, metric_name, time DESC;

-- Daily summaries across all projects
CREATE OR REPLACE VIEW osint.v_daily_project_summary AS
SELECT
    DATE(time) as summary_date,
    entity_id as project_id,
    MAX(CASE WHEN metric_name = 'tweet_count' THEN COALESCE(value_float, value_int) END) as tweets,
    MAX(CASE WHEN metric_name = 'unique_authors' THEN COALESCE(value_float, value_int) END) as authors,
    MAX(CASE WHEN metric_name = 'total_engagement' THEN COALESCE(value_float, value_int) END) as engagement,
    MAX(CASE WHEN metric_name = 'viral_tweets' THEN COALESCE(value_float, value_int) END) as viral_tweets
FROM osint.intel_metrics
WHERE entity_type = 'project'
    AND metric_name IN ('tweet_count', 'unique_authors', 'total_engagement', 'viral_tweets')
GROUP BY DATE(time), entity_id
ORDER BY summary_date DESC, project_id;

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'Time-series metrics schema created successfully!';
    RAISE NOTICE 'Tables: intel_metrics';
    RAISE NOTICE 'Functions: get_metric_series(), get_entity_snapshot()';
    RAISE NOTICE 'Views: v_latest_metrics, v_daily_project_summary';
    RAISE NOTICE 'Ready for computation procedures!';
END $$;