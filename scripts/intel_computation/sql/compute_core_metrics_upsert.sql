-- Core Metrics Computation with UPSERT for Conflict Resolution
-- Handles duplicate key conflicts gracefully using ON CONFLICT DO UPDATE

CREATE OR REPLACE FUNCTION osint.compute_core_metrics_upsert(
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
    RAISE NOTICE 'Computing metrics with UPSERT from % to %', v_date_start, v_date_end;

    -- ================================================================
    -- PROJECT LEVEL METRICS with UPSERT
    -- ================================================================
    RAISE NOTICE 'Computing PROJECT metrics with conflict resolution...';

    -- Use a single statement for all project metrics using UPSERT
    WITH project_data AS (
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
            COUNT(*) FILTER (WHERE
                (COALESCE(t.retweet_count, 0) * 3.0) +
                (COALESCE(t.quote_count, 0) * 2.5) +
                (COALESCE(t.reply_count, 0) * 2.0) +
                (COALESCE(t.like_count, 0) * 1.0) +
                (COALESCE(t.bookmark_count, 0) * 1.5) +
                (COALESCE(t.view_count, 0) * 0.001) > 200
            ) as viral_tweets,
            COUNT(*) FILTER (WHERE
                (COALESCE(t.retweet_count, 0) * 3.0) +
                (COALESCE(t.quote_count, 0) * 2.5) +
                (COALESCE(t.reply_count, 0) * 2.0) +
                (COALESCE(t.like_count, 0) * 1.0) +
                (COALESCE(t.bookmark_count, 0) * 1.5) +
                (COALESCE(t.view_count, 0) * 0.001) > 1000
            ) as highly_viral_tweets
        FROM osint.tweets_deduplicated t
        JOIN osint.tweet_collections tc ON t.tweet_id = tc.tweet_id
        WHERE DATE(t.created_at) BETWEEN v_date_start AND v_date_end
        GROUP BY DATE(t.created_at), tc.project_id
    ),
    project_metrics_pivot AS (
        SELECT
            metric_date,
            project_id,
            metric_name,
            value_int,
            value_float,
            unit
        FROM project_data,
        LATERAL (VALUES
            ('tweet_count', tweet_count, NULL, 'count'),
            ('unique_authors', unique_authors, NULL, 'count'),
            ('total_likes', total_likes, NULL, 'count'),
            ('total_retweets', total_retweets, NULL, 'count'),
            ('total_replies', total_replies, NULL, 'count'),
            ('total_quotes', total_quotes, NULL, 'count'),
            ('total_views', total_views, NULL, 'count'),
            ('total_bookmarks', total_bookmarks, NULL, 'count'),
            ('viral_tweets', viral_tweets, NULL, 'count'),
            ('highly_viral_tweets', highly_viral_tweets, NULL, 'count'),
            ('avg_virality_score', NULL, avg_virality_score, 'score'),
            ('max_virality_score', NULL, max_virality_score, 'score')
        ) AS unpivoted(metric_name, value_int, value_float, unit)
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
    FROM project_metrics_pivot
    ON CONFLICT (time, metric_name, entity_type, entity_id)
    DO UPDATE SET
        value_int = EXCLUDED.value_int,
        value_float = EXCLUDED.value_float,
        unit = EXCLUDED.unit,
        computed_at = NOW();

    GET DIAGNOSTICS v_metrics_count = ROW_COUNT;
    RAISE NOTICE '  - Project metrics: % rows', v_metrics_count;

    -- ================================================================
    -- THEME LEVEL METRICS with UPSERT
    -- ================================================================
    RAISE NOTICE 'Computing THEME metrics with conflict resolution...';

    WITH theme_data AS (
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
            COUNT(*) FILTER (WHERE
                (COALESCE(t.retweet_count, 0) * 3.0) +
                (COALESCE(t.quote_count, 0) * 2.5) +
                (COALESCE(t.reply_count, 0) * 2.0) +
                (COALESCE(t.like_count, 0) * 1.0) +
                (COALESCE(t.bookmark_count, 0) * 1.5) +
                (COALESCE(t.view_count, 0) * 0.001) > 200
            ) as viral_tweets,
            COUNT(*) FILTER (WHERE
                (COALESCE(t.retweet_count, 0) * 3.0) +
                (COALESCE(t.quote_count, 0) * 2.5) +
                (COALESCE(t.reply_count, 0) * 2.0) +
                (COALESCE(t.like_count, 0) * 1.0) +
                (COALESCE(t.bookmark_count, 0) * 1.5) +
                (COALESCE(t.view_count, 0) * 0.001) > 1000
            ) as highly_viral_tweets
        FROM osint.tweets_deduplicated t
        JOIN osint.tweet_collections tc ON t.tweet_id = tc.tweet_id
        JOIN osint.themes th ON tc.theme_code = th.code
        WHERE DATE(t.created_at) BETWEEN v_date_start AND v_date_end
        GROUP BY DATE(t.created_at), th.id
    ),
    theme_metrics_pivot AS (
        SELECT
            metric_date,
            theme_id,
            metric_name,
            value_int,
            value_float,
            unit
        FROM theme_data,
        LATERAL (VALUES
            ('tweet_count', tweet_count, NULL, 'count'),
            ('unique_authors', unique_authors, NULL, 'count'),
            ('total_likes', total_likes, NULL, 'count'),
            ('total_retweets', total_retweets, NULL, 'count'),
            ('total_replies', total_replies, NULL, 'count'),
            ('total_quotes', total_quotes, NULL, 'count'),
            ('total_views', total_views, NULL, 'count'),
            ('total_bookmarks', total_bookmarks, NULL, 'count'),
            ('viral_tweets', viral_tweets, NULL, 'count'),
            ('highly_viral_tweets', highly_viral_tweets, NULL, 'count'),
            ('avg_virality_score', NULL, avg_virality_score, 'score'),
            ('max_virality_score', NULL, max_virality_score, 'score')
        ) AS unpivoted(metric_name, value_int, value_float, unit)
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
    FROM theme_metrics_pivot
    ON CONFLICT (time, metric_name, entity_type, entity_id)
    DO UPDATE SET
        value_int = EXCLUDED.value_int,
        value_float = EXCLUDED.value_float,
        unit = EXCLUDED.unit,
        computed_at = NOW();

    GET DIAGNOSTICS v_metrics_count = ROW_COUNT;
    RAISE NOTICE '  - Theme metrics: % rows', v_metrics_count;

    -- Count entity types processed
    v_entity_types := 2; -- project and theme

    -- Calculate total computation time
    v_computation_time_ms := EXTRACT(EPOCH FROM (clock_timestamp() - v_start_time)) * 1000;

    RAISE NOTICE 'Completed in %ms', v_computation_time_ms;

    -- Return results
    RETURN QUERY
    SELECT
        v_metrics_count::BIGINT,
        v_entity_types::INTEGER,
        v_computation_time_ms::BIGINT;
END;
$$;

-- Create a procedure wrapper for easier calling
CREATE OR REPLACE PROCEDURE osint.compute_timeseries_metrics(
    p_target_date DATE DEFAULT CURRENT_DATE - 1,
    p_days_back INTEGER DEFAULT 1
)
LANGUAGE plpgsql
AS $$
DECLARE
    result_record RECORD;
BEGIN
    SELECT * INTO result_record
    FROM osint.compute_core_metrics_upsert(p_target_date, p_days_back);

    RAISE NOTICE '✅ Computation completed: % metrics, % entity types, %ms',
        result_record.metrics_computed,
        result_record.entity_types_processed,
        result_record.computation_time_ms;
END;
$$;