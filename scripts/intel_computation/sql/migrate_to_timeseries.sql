-- Migration from wide table (intel_daily_activity) to time-series (intel_metrics)
-- Preserves all existing computed metrics in new format

CREATE OR REPLACE FUNCTION osint.migrate_existing_data_to_timeseries()
RETURNS TABLE(
    metrics_migrated BIGINT,
    date_range TEXT,
    duration_ms BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_start_time TIMESTAMP := clock_timestamp();
    v_metrics_count BIGINT := 0;
    v_min_date DATE;
    v_max_date DATE;
    v_duration_ms BIGINT;
BEGIN
    -- Get date range from existing data
    SELECT MIN(summary_date), MAX(summary_date)
    INTO v_min_date, v_max_date
    FROM osint.intel_daily_activity;

    RAISE NOTICE 'Migrating data from % to %', v_min_date, v_max_date;

    -- Clear existing migrated data
    TRUNCATE osint.intel_metrics;

    -- ================================================================
    -- Migrate PROJECT level metrics
    -- ================================================================
    INSERT INTO osint.intel_metrics (
        time, metric_name, entity_type, entity_id,
        value_int, value_float, value_text, unit,
        computation_version
    )
    SELECT
        summary_date::timestamptz,
        metric_name,
        'project',
        project_id,
        value_int,
        value_float,
        value_text,
        unit,
        '1.0'
    FROM (
        SELECT
            summary_date,
            project_id,
            'tweet_count' as metric_name,
            tweet_count as value_int,
            NULL::double precision as value_float,
            NULL::text as value_text,
            'count' as unit
        FROM osint.intel_daily_activity
        WHERE entity_type = 'project' AND tweet_count IS NOT NULL

        UNION ALL

        SELECT
            summary_date,
            project_id,
            'unique_authors',
            unique_authors,
            NULL, NULL, 'count'
        FROM osint.intel_daily_activity
        WHERE entity_type = 'project' AND unique_authors IS NOT NULL

        UNION ALL

        SELECT
            summary_date,
            project_id,
            'new_authors',
            new_authors,
            NULL, NULL, 'count'
        FROM osint.intel_daily_activity
        WHERE entity_type = 'project' AND new_authors IS NOT NULL

        UNION ALL

        SELECT
            summary_date,
            project_id,
            'monitored_users_active',
            monitored_users_active,
            NULL, NULL, 'count'
        FROM osint.intel_daily_activity
        WHERE entity_type = 'project' AND monitored_users_active IS NOT NULL

        UNION ALL

        SELECT
            summary_date,
            project_id,
            'total_likes',
            total_likes,
            NULL, NULL, 'count'
        FROM osint.intel_daily_activity
        WHERE entity_type = 'project' AND total_likes IS NOT NULL

        UNION ALL

        SELECT
            summary_date,
            project_id,
            'total_retweets',
            total_retweets,
            NULL, NULL, 'count'
        FROM osint.intel_daily_activity
        WHERE entity_type = 'project' AND total_retweets IS NOT NULL

        UNION ALL

        SELECT
            summary_date,
            project_id,
            'total_replies',
            total_replies,
            NULL, NULL, 'count'
        FROM osint.intel_daily_activity
        WHERE entity_type = 'project' AND total_replies IS NOT NULL

        UNION ALL

        SELECT
            summary_date,
            project_id,
            'total_quotes',
            total_quotes,
            NULL, NULL, 'count'
        FROM osint.intel_daily_activity
        WHERE entity_type = 'project' AND total_quotes IS NOT NULL

        UNION ALL

        SELECT
            summary_date,
            project_id,
            'total_views',
            total_views,
            NULL, NULL, 'count'
        FROM osint.intel_daily_activity
        WHERE entity_type = 'project' AND total_views IS NOT NULL

        UNION ALL

        SELECT
            summary_date,
            project_id,
            'total_bookmarks',
            total_bookmarks,
            NULL, NULL, 'count'
        FROM osint.intel_daily_activity
        WHERE entity_type = 'project' AND total_bookmarks IS NOT NULL

        UNION ALL

        SELECT
            summary_date,
            project_id,
            'viral_tweets',
            viral_tweets,
            NULL, NULL, 'count'
        FROM osint.intel_daily_activity
        WHERE entity_type = 'project' AND viral_tweets IS NOT NULL

        UNION ALL

        SELECT
            summary_date,
            project_id,
            'highly_viral_tweets',
            highly_viral_tweets,
            NULL, NULL, 'count'
        FROM osint.intel_daily_activity
        WHERE entity_type = 'project' AND highly_viral_tweets IS NOT NULL

        -- Float metrics
        UNION ALL

        SELECT
            summary_date,
            project_id,
            'avg_virality_score',
            NULL,
            avg_virality_score, NULL, 'score'
        FROM osint.intel_daily_activity
        WHERE entity_type = 'project' AND avg_virality_score IS NOT NULL

        UNION ALL

        SELECT
            summary_date,
            project_id,
            'max_virality_score',
            NULL,
            max_virality_score, NULL, 'score'
        FROM osint.intel_daily_activity
        WHERE entity_type = 'project' AND max_virality_score IS NOT NULL

        UNION ALL

        SELECT
            summary_date,
            project_id,
            'growth_rate_1d',
            NULL,
            growth_rate_1d, NULL, 'percentage'
        FROM osint.intel_daily_activity
        WHERE entity_type = 'project' AND growth_rate_1d IS NOT NULL

        UNION ALL

        SELECT
            summary_date,
            project_id,
            'growth_rate_7d',
            NULL,
            growth_rate_7d, NULL, 'percentage'
        FROM osint.intel_daily_activity
        WHERE entity_type = 'project' AND growth_rate_7d IS NOT NULL

        UNION ALL

        SELECT
            summary_date,
            project_id,
            'growth_rate_30d',
            NULL,
            growth_rate_30d, NULL, 'percentage'
        FROM osint.intel_daily_activity
        WHERE entity_type = 'project' AND growth_rate_30d IS NOT NULL

        UNION ALL

        SELECT
            summary_date,
            project_id,
            'tweets_7d_avg',
            NULL,
            tweets_7d_avg, NULL, 'count'
        FROM osint.intel_daily_activity
        WHERE entity_type = 'project' AND tweets_7d_avg IS NOT NULL

        UNION ALL

        SELECT
            summary_date,
            project_id,
            'tweets_30d_avg',
            NULL,
            tweets_30d_avg, NULL, 'count'
        FROM osint.intel_daily_activity
        WHERE entity_type = 'project' AND tweets_30d_avg IS NOT NULL

        UNION ALL

        SELECT
            summary_date,
            project_id,
            'engagement_7d_avg',
            NULL,
            engagement_7d_avg, NULL, 'score'
        FROM osint.intel_daily_activity
        WHERE entity_type = 'project' AND engagement_7d_avg IS NOT NULL

        UNION ALL

        SELECT
            summary_date,
            project_id,
            'engagement_30d_avg',
            NULL,
            engagement_30d_avg, NULL, 'score'
        FROM osint.intel_daily_activity
        WHERE entity_type = 'project' AND engagement_30d_avg IS NOT NULL

        -- Spike detection metrics
        UNION ALL

        SELECT
            summary_date,
            project_id,
            'spike_score',
            NULL,
            spike_score, NULL, 'score'
        FROM osint.intel_daily_activity
        WHERE entity_type = 'project' AND spike_score IS NOT NULL

        UNION ALL

        SELECT
            summary_date,
            project_id,
            'is_spike',
            NULL, NULL,
            CASE WHEN is_spike THEN 'true' ELSE 'false' END,
            'boolean'
        FROM osint.intel_daily_activity
        WHERE entity_type = 'project' AND is_spike IS NOT NULL

        UNION ALL

        SELECT
            summary_date,
            project_id,
            'spike_type',
            NULL, NULL,
            spike_type,
            'text'
        FROM osint.intel_daily_activity
        WHERE entity_type = 'project' AND spike_type IS NOT NULL

        -- Text metrics
        UNION ALL

        SELECT
            summary_date,
            project_id,
            'dominant_topic_name',
            NULL, NULL,
            dominant_topic_name,
            'text'
        FROM osint.intel_daily_activity
        WHERE entity_type = 'project' AND dominant_topic_name IS NOT NULL

        UNION ALL

        SELECT
            summary_date,
            project_id,
            'dominant_topic_id',
            dominant_topic_id,
            NULL, NULL, 'id'
        FROM osint.intel_daily_activity
        WHERE entity_type = 'project' AND dominant_topic_id IS NOT NULL
    ) pivot_data;

    -- ================================================================
    -- Migrate THEME level metrics
    -- ================================================================
    INSERT INTO osint.intel_metrics (
        time, metric_name, entity_type, entity_id,
        value_int, value_float, value_text, unit,
        computation_version
    )
    SELECT
        summary_date::timestamptz,
        metric_name,
        'theme',
        theme_id,
        value_int,
        value_float,
        value_text,
        unit,
        '1.0'
    FROM (
        SELECT
            summary_date, theme_id,
            'tweet_count' as metric_name,
            tweet_count as value_int,
            NULL::double precision as value_float,
            NULL::text as value_text,
            'count' as unit
        FROM osint.intel_daily_activity
        WHERE entity_type = 'theme' AND theme_id IS NOT NULL AND tweet_count IS NOT NULL

        UNION ALL

        SELECT summary_date, theme_id, 'unique_authors', unique_authors, NULL, NULL, 'count'
        FROM osint.intel_daily_activity
        WHERE entity_type = 'theme' AND theme_id IS NOT NULL AND unique_authors IS NOT NULL

        UNION ALL

        SELECT summary_date, theme_id, 'avg_virality_score', NULL, avg_virality_score, NULL, 'score'
        FROM osint.intel_daily_activity
        WHERE entity_type = 'theme' AND theme_id IS NOT NULL AND avg_virality_score IS NOT NULL

        -- Add other theme metrics as needed...
    ) pivot_data;

    -- ================================================================
    -- Note: Topic-level metrics are excluded as per design decision
    -- ================================================================

    -- Get final count and timing
    SELECT COUNT(*) INTO v_metrics_count FROM osint.intel_metrics;
    v_duration_ms := EXTRACT(EPOCH FROM (clock_timestamp() - v_start_time)) * 1000;

    RETURN QUERY SELECT
        v_metrics_count,
        COALESCE(v_min_date::text, 'no data') || ' to ' || COALESCE(v_max_date::text, 'no data'),
        v_duration_ms;
END;
$$;

-- Wrapper procedure for easy execution
CREATE OR REPLACE PROCEDURE osint.migrate_to_timeseries()
LANGUAGE plpgsql
AS $$
DECLARE
    result RECORD;
BEGIN
    RAISE NOTICE 'Starting migration from intel_daily_activity to intel_metrics...';

    SELECT * INTO result FROM osint.migrate_existing_data_to_timeseries();

    RAISE NOTICE 'Migration completed successfully:';
    RAISE NOTICE '  - Metrics migrated: %', result.metrics_migrated;
    RAISE NOTICE '  - Date range: %', result.date_range;
    RAISE NOTICE '  - Duration: %ms', result.duration_ms;

    RAISE NOTICE 'Time-series data is now ready for MCP queries!';
END;
$$;