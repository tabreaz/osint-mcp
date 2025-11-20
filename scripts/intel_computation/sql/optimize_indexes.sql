-- Performance optimizations for intel_metrics time-series table
-- Run after initial setup for production-ready performance

-- ================================================================
-- RECOMMENDED: Partial index for recent data (dashboard queries)
-- ================================================================

-- This index dramatically speeds up dashboard and API queries
-- that focus on recent data (last 7 days)
CREATE INDEX CONCURRENTLY idx_metrics_latest_7d
ON osint.intel_metrics(entity_type, entity_id, metric_name, time DESC)
WHERE time > NOW() - INTERVAL '7 days';

COMMENT ON INDEX osint.idx_metrics_latest_7d IS
'Optimizes dashboard queries for recent metrics (last 7 days). Rebuilds automatically as time window moves.';

-- ================================================================
-- OPTIONAL: Additional performance indexes based on common queries
-- ================================================================

-- For MCP queries by specific metric across entities
CREATE INDEX CONCURRENTLY idx_metrics_by_metric_time
ON osint.intel_metrics(metric_name, time DESC)
INCLUDE (entity_type, entity_id, value_float, value_int);

-- For entity comparison queries (comparing themes within project)
CREATE INDEX CONCURRENTLY idx_metrics_entity_comparison
ON osint.intel_metrics(entity_type, metric_name, time)
INCLUDE (entity_id, value_float, value_int);

-- ================================================================
-- ALTERNATIVE: Application-level constraint instead of DB constraint
-- ================================================================

-- Instead of a CHECK constraint, create a function to validate data
-- This gives more flexibility and better error messages

CREATE OR REPLACE FUNCTION osint.validate_metric_value(
    p_value_float DOUBLE PRECISION,
    p_value_int BIGINT,
    p_value_text TEXT,
    p_value_json JSONB
) RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
    -- At least one value must be provided
    IF p_value_float IS NULL AND p_value_int IS NULL AND
       p_value_text IS NULL AND p_value_json IS NULL THEN
        RAISE EXCEPTION 'Metric must have at least one value (float, int, text, or json)';
    END IF;

    RETURN TRUE;
END;
$$;

-- ================================================================
-- Index maintenance and monitoring
-- ================================================================

-- Query to monitor index usage
CREATE OR REPLACE VIEW osint.v_index_usage AS
SELECT
    schemaname,
    indexname,
    idx_scan as times_used,
    idx_tup_read as tuples_read,
    idx_tup_fetch as tuples_fetched,
    pg_size_pretty(pg_relation_size(indexname::regclass)) as index_size
FROM pg_stat_user_indexes
WHERE schemaname = 'osint' AND relname = 'intel_metrics'
ORDER BY idx_scan DESC;

-- Query to check partial index effectiveness
CREATE OR REPLACE VIEW osint.v_recent_data_coverage AS
SELECT
    COUNT(*) as total_metrics,
    COUNT(*) FILTER (WHERE time > NOW() - INTERVAL '7 days') as recent_metrics,
    ROUND(
        COUNT(*) FILTER (WHERE time > NOW() - INTERVAL '7 days') * 100.0 / COUNT(*),
        2
    ) as recent_percentage
FROM osint.intel_metrics;

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'Performance optimizations applied successfully!';
    RAISE NOTICE 'Monitor index usage with: SELECT * FROM osint.v_index_usage;';
    RAISE NOTICE 'Check recent data coverage: SELECT * FROM osint.v_recent_data_coverage;';
    RAISE NOTICE 'Use validation function in application layer instead of constraint.';
END $$;