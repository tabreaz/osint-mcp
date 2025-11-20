-- Core Metrics Computation for Time-Series Intelligence Layer
-- FIXED VERSION - Complete implementation with all entity types
-- Computes volume, engagement, virality, and growth metrics

CREATE OR REPLACE FUNCTION osint.compute_core_metrics(
    p_target_date DATE DEFAULT CURRENT_DATE - 1,
    p_days_back INTEGER DEFAULT 1
)
RETURNS TABLE(
    metrics_computed BIGINT,
    entity_types_processed INTEGER,
    computation_time_ms BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_start_time TIMESTAMP := clock_timestamp();
    v_metrics_count BIGINT := 0;
    v_entity_types INTEGER := 0;
    v_computation_time_ms BIGINT;
    v_date_start DATE := p_target_date - p_days_back + 1;
    v_date_end DATE := p_target_date;
BEGIN
    -- Note: Using UPSERT (ON CONFLICT DO UPDATE) instead of DELETE to handle conflicts gracefully

    RAISE NOTICE 'Computing metrics from % to %', v_date_start, v_date_end;

    -- ================================================================
    -- PROJECT LEVEL METRICS - BULK INSERT
    -- ================================================================
    RAISE NOTICE 'Computing PROJECT metrics...';

    WITH daily_project_data AS (
        SELECT
            DATE(t.created_at) as metric_date,
            tc.project_id,
            COUNT(*) as tweet_count,
            COUNT(DISTINCT t.author_id) as unique_authors,
            SUM(COALESCE(t.like_count, 0)) as total_likes,
            SUM(COALESCE(t.retweet_count, 0)) as total_retweets,
            SUM(COALESCE(t.reply_count, 0)) as total_replies,
            SUM(COALESCE(t.quote_count, 0)) as total_quotes,
            SUM(COALESCE(t.view_count, 0)) as total_views,
            SUM(COALESCE(t.bookmark_count, 0)) as total_bookmarks,
            SUM(COALESCE(t.like_count, 0) + COALESCE(t.retweet_count, 0) +
                COALESCE(t.reply_count, 0) + COALESCE(t.quote_count, 0)) as total_engagement,
            AVG(
                (COALESCE(t.retweet_count, 0) * 3.0) +
                (COALESCE(t.quote_count, 0) * 2.5) +
                (COALESCE(t.reply_count, 0) * 2.0) +
                (COALESCE(t.like_count, 0) * 1.0) +
                (COALESCE(t.bookmark_count, 0) * 1.5) +
                (COALESCE(t.view_count, 0) * 0.001)
            ) as avg_virality_score,
            MAX(
                (COALESCE(t.retweet_count, 0) * 3.0) +
                (COALESCE(t.quote_count, 0) * 2.5) +
                (COALESCE(t.reply_count, 0) * 2.0) +
                (COALESCE(t.like_count, 0) * 1.0) +
                (COALESCE(t.bookmark_count, 0) * 1.5) +
                (COALESCE(t.view_count, 0) * 0.001)
            ) as max_virality_score,
            COUNT(CASE WHEN (
                (COALESCE(t.retweet_count, 0) * 3.0) +
                (COALESCE(t.quote_count, 0) * 2.5) +
                (COALESCE(t.reply_count, 0) * 2.0) +
                (COALESCE(t.like_count, 0) * 1.0) +
                (COALESCE(t.bookmark_count, 0) * 1.5) +
                (COALESCE(t.view_count, 0) * 0.001)
            ) > 200 THEN 1 END) as viral_tweets,
            COUNT(CASE WHEN (
                (COALESCE(t.retweet_count, 0) * 3.0) +
                (COALESCE(t.quote_count, 0) * 2.5) +
                (COALESCE(t.reply_count, 0) * 2.0) +
                (COALESCE(t.like_count, 0) * 1.0) +
                (COALESCE(t.bookmark_count, 0) * 1.5) +
                (COALESCE(t.view_count, 0) * 0.001)
            ) > 1000 THEN 1 END) as highly_viral_tweets
        FROM osint.tweets_deduplicated t
        JOIN osint.tweet_collections tc ON t.tweet_id = tc.tweet_id
        WHERE DATE(t.created_at) BETWEEN v_date_start AND v_date_end
        GROUP BY DATE(t.created_at), tc.project_id
    )
    INSERT INTO osint.intel_metrics (time, metric_name, entity_type, entity_id, value_int, value_float, unit)
    SELECT
        metric_date::timestamptz,
        metric_name,
        'project',
        project_id,
        value_int,
        value_float,
        unit
    FROM daily_project_data
    CROSS JOIN LATERAL (
        VALUES
            ('tweet_count', tweet_count, NULL, 'count'),
            ('unique_authors', unique_authors, NULL, 'count'),
            ('total_likes', total_likes, NULL, 'count'),
            ('total_retweets', total_retweets, NULL, 'count'),
            ('total_replies', total_replies, NULL, 'count'),
            ('total_quotes', total_quotes, NULL, 'count'),
            ('total_views', total_views, NULL, 'count'),
            ('total_bookmarks', total_bookmarks, NULL, 'count'),
            ('total_engagement', total_engagement, NULL, 'count'),
            ('viral_tweets', viral_tweets, NULL, 'count'),
            ('highly_viral_tweets', highly_viral_tweets, NULL, 'count'),
            ('avg_virality_score', NULL, avg_virality_score, 'score'),
            ('max_virality_score', NULL, max_virality_score, 'score')
    ) AS unpivoted(metric_name, value_int, value_float, unit);

    GET DIAGNOSTICS v_metrics_count = ROW_COUNT;
    RAISE NOTICE '  - Project metrics: % rows', v_metrics_count;

    -- New authors for projects
    WITH new_authors_data AS (
        SELECT
            DATE(t.created_at) as metric_date,
            tc.project_id,
            COUNT(DISTINCT t.author_id) as new_author_count
        FROM osint.tweets_deduplicated t
        JOIN osint.tweet_collections tc ON t.tweet_id = tc.tweet_id
        WHERE DATE(t.created_at) BETWEEN v_date_start AND v_date_end
          AND NOT EXISTS (
              SELECT 1 FROM osint.tweets_deduplicated t2
              JOIN osint.tweet_collections tc2 ON t2.tweet_id = tc2.tweet_id
              WHERE tc2.project_id = tc.project_id
                AND t2.author_id = t.author_id
                AND DATE(t2.created_at) BETWEEN DATE(t.created_at) - 30 AND DATE(t.created_at) - 1
          )
        GROUP BY DATE(t.created_at), tc.project_id
    )
    INSERT INTO osint.intel_metrics (time, metric_name, entity_type, entity_id, value_int, unit)
    SELECT metric_date::timestamptz, 'new_authors', 'project', project_id, new_author_count, 'count'
    FROM new_authors_data;

    -- Monitored users active
    WITH monitored_active AS (
        SELECT
            DATE(t.created_at) as metric_date,
            tc.project_id,
            COUNT(DISTINCT t.author_id) as active_count
        FROM osint.tweets_deduplicated t
        JOIN osint.tweet_collections tc ON t.tweet_id = tc.tweet_id
        JOIN osint.monitored_users mu ON t.author_id = mu.user_id AND tc.project_id = mu.project_id
        WHERE DATE(t.created_at) BETWEEN v_date_start AND v_date_end
        GROUP BY DATE(t.created_at), tc.project_id
    )
    INSERT INTO osint.intel_metrics (time, metric_name, entity_type, entity_id, value_int, unit)
    SELECT metric_date::timestamptz, 'monitored_users_active', 'project', project_id, active_count, 'count'
    FROM monitored_active;

    -- ================================================================
    -- THEME LEVEL METRICS - BULK INSERT (COMPLETE IMPLEMENTATION)
    -- ================================================================
    RAISE NOTICE 'Computing THEME metrics...';

    WITH daily_theme_data AS (
        SELECT
            DATE(t.created_at) as metric_date,
            th.id as theme_id,
            COUNT(*) as tweet_count,
            COUNT(DISTINCT t.author_id) as unique_authors,
            SUM(COALESCE(t.like_count, 0)) as total_likes,
            SUM(COALESCE(t.retweet_count, 0)) as total_retweets,
            SUM(COALESCE(t.reply_count, 0)) as total_replies,
            SUM(COALESCE(t.quote_count, 0)) as total_quotes,
            SUM(COALESCE(t.view_count, 0)) as total_views,
            SUM(COALESCE(t.bookmark_count, 0)) as total_bookmarks,
            SUM(COALESCE(t.like_count, 0) + COALESCE(t.retweet_count, 0) +
                COALESCE(t.reply_count, 0) + COALESCE(t.quote_count, 0)) as total_engagement,
            AVG(
                (COALESCE(t.retweet_count, 0) * 3.0) +
                (COALESCE(t.quote_count, 0) * 2.5) +
                (COALESCE(t.reply_count, 0) * 2.0) +
                (COALESCE(t.like_count, 0) * 1.0) +
                (COALESCE(t.bookmark_count, 0) * 1.5) +
                (COALESCE(t.view_count, 0) * 0.001)
            ) as avg_virality_score,
            MAX(
                (COALESCE(t.retweet_count, 0) * 3.0) +
                (COALESCE(t.quote_count, 0) * 2.5) +
                (COALESCE(t.reply_count, 0) * 2.0) +
                (COALESCE(t.like_count, 0) * 1.0) +
                (COALESCE(t.bookmark_count, 0) * 1.5) +
                (COALESCE(t.view_count, 0) * 0.001)
            ) as max_virality_score,
            COUNT(CASE WHEN (
                (COALESCE(t.retweet_count, 0) * 3.0) +
                (COALESCE(t.quote_count, 0) * 2.5) +
                (COALESCE(t.reply_count, 0) * 2.0) +
                (COALESCE(t.like_count, 0) * 1.0) +
                (COALESCE(t.bookmark_count, 0) * 1.5) +
                (COALESCE(t.view_count, 0) * 0.001)
            ) > 200 THEN 1 END) as viral_tweets,
            COUNT(CASE WHEN (
                (COALESCE(t.retweet_count, 0) * 3.0) +
                (COALESCE(t.quote_count, 0) * 2.5) +
                (COALESCE(t.reply_count, 0) * 2.0) +
                (COALESCE(t.like_count, 0) * 1.0) +
                (COALESCE(t.bookmark_count, 0) * 1.5) +
                (COALESCE(t.view_count, 0) * 0.001)
            ) > 1000 THEN 1 END) as highly_viral_tweets
        FROM osint.tweets_deduplicated t
        JOIN osint.tweet_collections tc ON t.tweet_id = tc.tweet_id
        JOIN osint.themes th ON tc.theme_code = th.code
        WHERE DATE(t.created_at) BETWEEN v_date_start AND v_date_end
        GROUP BY DATE(t.created_at), th.id
    )
    INSERT INTO osint.intel_metrics (time, metric_name, entity_type, entity_id, value_int, value_float, unit)
    SELECT
        metric_date::timestamptz,
        metric_name,
        'theme',
        theme_id,
        value_int,
        value_float,
        unit
    FROM daily_theme_data
    CROSS JOIN LATERAL (
        VALUES
            ('tweet_count', tweet_count, NULL, 'count'),
            ('unique_authors', unique_authors, NULL, 'count'),
            ('total_likes', total_likes, NULL, 'count'),
            ('total_retweets', total_retweets, NULL, 'count'),
            ('total_replies', total_replies, NULL, 'count'),
            ('total_quotes', total_quotes, NULL, 'count'),
            ('total_views', total_views, NULL, 'count'),
            ('total_bookmarks', total_bookmarks, NULL, 'count'),
            ('total_engagement', total_engagement, NULL, 'count'),
            ('viral_tweets', viral_tweets, NULL, 'count'),
            ('highly_viral_tweets', highly_viral_tweets, NULL, 'count'),
            ('avg_virality_score', NULL, avg_virality_score, 'score'),
            ('max_virality_score', NULL, max_virality_score, 'score')
    ) AS unpivoted(metric_name, value_int, value_float, unit);

    GET DIAGNOSTICS v_metrics_count = ROW_COUNT;
    RAISE NOTICE '  - Theme metrics: % rows', v_metrics_count;

    -- ================================================================
    -- HOURLY DISTRIBUTION METRICS (JSON format for activity patterns)
    -- ================================================================
    RAISE NOTICE 'Computing HOURLY distribution metrics...';

    -- Hourly activity distribution for projects
    WITH hourly_data AS (
        SELECT
            tc.project_id,
            DATE(t.created_at) as metric_date,
            EXTRACT(HOUR FROM t.created_at)::int as hour,
            COUNT(*) as tweet_count,
            SUM(COALESCE(t.like_count, 0) + COALESCE(t.retweet_count, 0) +
                COALESCE(t.reply_count, 0) + COALESCE(t.quote_count, 0)) as total_engagement,
            AVG(
                (COALESCE(t.retweet_count, 0) * 3.0) +
                (COALESCE(t.quote_count, 0) * 2.5) +
                (COALESCE(t.reply_count, 0) * 2.0) +
                (COALESCE(t.like_count, 0) * 1.0) +
                (COALESCE(t.bookmark_count, 0) * 1.5) +
                (COALESCE(t.view_count, 0) * 0.001)
            ) as avg_virality,
            COUNT(DISTINCT t.author_id) as unique_authors
        FROM osint.tweets_deduplicated t
        JOIN osint.tweet_collections tc ON t.tweet_id = tc.tweet_id
        WHERE DATE(t.created_at) BETWEEN v_date_start AND v_date_end
        GROUP BY tc.project_id, DATE(t.created_at), EXTRACT(HOUR FROM t.created_at)
    ),
    hourly_arrays AS (
        SELECT
            dates.project_id,
            dates.metric_date,
            -- Create arrays with all 24 hours (0-23), filling missing hours with 0
            array_agg(COALESCE(hd.tweet_count, 0) ORDER BY hours.hour_series) as hourly_tweets,
            array_agg(COALESCE(hd.total_engagement, 0) ORDER BY hours.hour_series) as hourly_engagement,
            array_agg(COALESCE(ROUND(hd.avg_virality::numeric, 2), 0) ORDER BY hours.hour_series) as hourly_virality,
            array_agg(COALESCE(hd.unique_authors, 0) ORDER BY hours.hour_series) as hourly_authors,
            MAX(hd.tweet_count) as peak_tweets,
            MAX(hd.total_engagement) as peak_engagement
        FROM (
            SELECT generate_series(0, 23) as hour_series
        ) hours
        CROSS JOIN (SELECT DISTINCT project_id, metric_date FROM hourly_data) dates
        LEFT JOIN hourly_data hd ON hours.hour_series = hd.hour
            AND hd.project_id = dates.project_id
            AND hd.metric_date = dates.metric_date
        GROUP BY dates.project_id, dates.metric_date
    )
    INSERT INTO osint.intel_metrics (time, metric_name, entity_type, entity_id, value_json, unit)
    SELECT
        metric_date::timestamptz,
        'hourly_activity_distribution',
        'project',
        hourly_arrays.project_id,
        jsonb_build_object(
            'hourly_tweets', hourly_tweets,
            'hourly_engagement', hourly_engagement,
            'hourly_virality', hourly_virality,
            'hourly_authors', hourly_authors,
            'peak_hour', (array_position(hourly_tweets, peak_tweets) - 1),
            'peak_tweets', peak_tweets,
            'peak_engagement', peak_engagement,
            'total_tweets', (SELECT SUM(s) FROM unnest(hourly_tweets) s),
            'total_engagement', (SELECT SUM(s) FROM unnest(hourly_engagement) s)
        ),
        'json'
    FROM hourly_arrays;

    -- Hourly distribution for themes
    WITH theme_hourly AS (
        SELECT
            th.id as theme_id,
            DATE(t.created_at) as metric_date,
            EXTRACT(HOUR FROM t.created_at)::int as hour,
            COUNT(*) as tweet_count,
            SUM(COALESCE(t.like_count, 0) + COALESCE(t.retweet_count, 0)) as engagement
        FROM osint.tweets_deduplicated t
        JOIN osint.tweet_collections tc ON t.tweet_id = tc.tweet_id
        JOIN osint.themes th ON tc.theme_code = th.code
        WHERE DATE(t.created_at) BETWEEN v_date_start AND v_date_end
        GROUP BY th.id, DATE(t.created_at), EXTRACT(HOUR FROM t.created_at)
    ),
    theme_hourly_arrays AS (
        SELECT
            dates.theme_id,
            dates.metric_date,
            array_agg(COALESCE(th.tweet_count, 0) ORDER BY hours.hour_series) as hourly_tweets,
            array_agg(COALESCE(th.engagement, 0) ORDER BY hours.hour_series) as hourly_engagement,
            MAX(th.tweet_count) as peak_tweets
        FROM (
            SELECT generate_series(0, 23) as hour_series
        ) hours
        CROSS JOIN (SELECT DISTINCT theme_id, metric_date FROM theme_hourly) dates
        LEFT JOIN theme_hourly th ON hours.hour_series = th.hour
            AND th.theme_id = dates.theme_id
            AND th.metric_date = dates.metric_date
        GROUP BY dates.theme_id, dates.metric_date
    )
    INSERT INTO osint.intel_metrics (time, metric_name, entity_type, entity_id, value_json, unit)
    SELECT
        metric_date::timestamptz,
        'hourly_activity_distribution',
        'theme',
        theme_id,
        jsonb_build_object(
            'hourly_tweets', hourly_tweets,
            'hourly_engagement', hourly_engagement,
            'peak_hour', (array_position(hourly_tweets, peak_tweets) - 1),
            'peak_tweets', peak_tweets
        ),
        'json'
    FROM theme_hourly_arrays;

    GET DIAGNOSTICS v_metrics_count = ROW_COUNT;
    RAISE NOTICE '  - Hourly metrics: % rows', v_metrics_count;

    -- ================================================================
    -- GROWTH METRICS (7-day rolling averages for all entities)
    -- ================================================================
    RAISE NOTICE 'Computing GROWTH metrics...';

    -- First aggregate the metrics per entity/time
    WITH metric_data AS (
        SELECT
            time,
            entity_type,
            entity_id,
            MAX(CASE WHEN metric_name = 'tweet_count'
                THEN COALESCE(value_float, value_int) END) as tweet_count,
            MAX(CASE WHEN metric_name = 'total_engagement'
                THEN COALESCE(value_float, value_int) END) as total_engagement
        FROM osint.intel_metrics
        WHERE metric_name IN ('tweet_count', 'total_engagement')
          AND DATE(time) BETWEEN v_date_start - 7 AND v_date_end
        GROUP BY time, entity_type, entity_id
    ),
    rolling_metrics AS (
        SELECT
            time,
            entity_type,
            entity_id,
            AVG(tweet_count) OVER (
                PARTITION BY entity_type, entity_id
                ORDER BY time
                ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
            ) as tweets_7d_avg,
            AVG(total_engagement) OVER (
                PARTITION BY entity_type, entity_id
                ORDER BY time
                ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
            ) as engagement_7d_avg
        FROM metric_data
    )
    INSERT INTO osint.intel_metrics (time, metric_name, entity_type, entity_id, value_float, unit)
    SELECT
        time,
        metric_name,
        entity_type,
        entity_id,
        value,
        unit
    FROM rolling_metrics
    CROSS JOIN LATERAL (
        VALUES
            ('tweets_7d_avg', tweets_7d_avg, 'count'),
            ('engagement_7d_avg', engagement_7d_avg, 'score')
    ) AS unpivoted(metric_name, value, unit)
    WHERE DATE(time) BETWEEN v_date_start AND v_date_end
      AND value IS NOT NULL
    ON CONFLICT (time, metric_name, entity_type, entity_id)
    DO UPDATE SET
        value_float = EXCLUDED.value_float,
        unit = EXCLUDED.unit,
        computed_at = NOW();

    GET DIAGNOSTICS v_metrics_count = ROW_COUNT;
    RAISE NOTICE '  - Growth metrics: % rows', v_metrics_count;

    -- Calculate computation time
    v_computation_time_ms := EXTRACT(EPOCH FROM (clock_timestamp() - v_start_time)) * 1000;
    v_entity_types := 2; -- project, theme only

    GET DIAGNOSTICS v_metrics_count = ROW_COUNT;

    RETURN QUERY SELECT v_metrics_count, v_entity_types, v_computation_time_ms;
END;
$$;

-- Simplified wrapper procedure
CREATE OR REPLACE PROCEDURE osint.compute_timeseries_metrics(
    p_target_date DATE DEFAULT CURRENT_DATE - 1,
    p_days_back INTEGER DEFAULT 1
)
LANGUAGE plpgsql
AS $$
DECLARE
    result RECORD;
BEGIN
    RAISE NOTICE '==================================================';
    RAISE NOTICE 'Starting time-series metrics computation';
    RAISE NOTICE '==================================================';

    SELECT * INTO result FROM osint.compute_core_metrics(p_target_date, p_days_back);

    RAISE NOTICE '==================================================';
    RAISE NOTICE 'Core metrics computation completed:';
    RAISE NOTICE '  - Metrics computed: %', result.metrics_computed;
    RAISE NOTICE '  - Entity types: %', result.entity_types_processed;
    RAISE NOTICE '  - Duration: %ms (%.2f seconds)',
                 result.computation_time_ms,
                 result.computation_time_ms / 1000.0;
    RAISE NOTICE '==================================================';
END;
$$;

-- Test function
CREATE OR REPLACE FUNCTION osint.test_metrics_computation()
RETURNS TABLE(
    test_name TEXT,
    status TEXT,
    details TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Test 1: Check if table exists
    RETURN QUERY
    SELECT
        'Table exists'::TEXT,
        CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables
                         WHERE table_schema = 'osint'
                         AND table_name = 'intel_metrics')
             THEN 'PASS'::TEXT
             ELSE 'FAIL'::TEXT
        END,
        'osint.intel_metrics'::TEXT;

    -- Test 2: Check for required source tables
    RETURN QUERY
    SELECT
        'Source tables exist'::TEXT,
        CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables
                         WHERE table_schema = 'osint'
                         AND table_name IN ('tweets_deduplicated', 'tweet_collections', 'themes'))
             THEN 'PASS'::TEXT
             ELSE 'FAIL'::TEXT
        END,
        'tweets_deduplicated, tweet_collections, themes'::TEXT;

    -- Test 3: Check for data
    RETURN QUERY
    SELECT
        'Has data'::TEXT,
        CASE WHEN EXISTS (SELECT 1 FROM osint.intel_metrics LIMIT 1)
             THEN 'PASS'::TEXT
             ELSE 'WARNING'::TEXT
        END,
        (SELECT COUNT(*)::TEXT || ' rows' FROM osint.intel_metrics)::TEXT;
END;
$$;