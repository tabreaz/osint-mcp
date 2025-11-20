-- Simplified Author Daily Metrics
-- Fast daily tracking for essential author activity patterns
-- Replaces the 46-metric approach with focused 12 metrics

CREATE OR REPLACE FUNCTION osint.compute_author_daily_simple(
    p_target_date DATE DEFAULT CURRENT_DATE - 1
)
RETURNS TABLE(
    metrics_computed BIGINT,
    authors_processed INTEGER,
    computation_time_ms BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_start_time TIMESTAMP := clock_timestamp();
    v_metrics_count BIGINT := 0;
    v_authors_processed INTEGER := 0;
    v_computation_time_ms BIGINT;
BEGIN
    RAISE NOTICE 'Computing simplified author daily metrics for %', p_target_date;

    -- ================================================================
    -- SIMPLIFIED DAILY AUTHOR METRICS (12 essential metrics)
    -- ================================================================

    INSERT INTO osint.author_daily_metrics (
        date,
        author_id,
        daily_tweets,
        daily_replies,
        daily_original_tweets,
        daily_retweets,
        daily_quotes,
        total_engagement_received,
        avg_engagement_per_tweet,
        active_hours,
        peak_hour,
        posting_velocity,
        viral_tweets_count,
        cross_theme_activity
    )
    SELECT
        p_target_date,
        t.author_id::BIGINT,

        -- Basic Activity Counts
        COUNT(*) as daily_tweets,
        COUNT(*) FILTER (WHERE t.in_reply_to_id IS NOT NULL) as daily_replies,
        COUNT(*) FILTER (WHERE t.in_reply_to_id IS NULL
                         AND t.retweeted_tweet_id IS NULL
                         AND t.quoted_tweet_id IS NULL) as daily_original_tweets,
        COUNT(*) FILTER (WHERE t.retweeted_tweet_id IS NOT NULL) as daily_retweets,
        COUNT(*) FILTER (WHERE t.quoted_tweet_id IS NOT NULL) as daily_quotes,

        -- Engagement Metrics
        SUM(
            COALESCE(t.like_count, 0) +
            COALESCE(t.retweet_count, 0) +
            COALESCE(t.reply_count, 0) +
            COALESCE(t.quote_count, 0) +
            COALESCE(t.bookmark_count, 0)
        ) as total_engagement_received,

        -- Average Engagement per Tweet
        CASE
            WHEN COUNT(*) > 0
            THEN SUM(
                COALESCE(t.like_count, 0) +
                COALESCE(t.retweet_count, 0) +
                COALESCE(t.reply_count, 0) +
                COALESCE(t.quote_count, 0) +
                COALESCE(t.bookmark_count, 0)
            )::FLOAT / COUNT(*)
            ELSE 0
        END as avg_engagement_per_tweet,

        -- Activity Patterns
        COUNT(DISTINCT EXTRACT(HOUR FROM t.created_at)) as active_hours,

        -- Peak Hour (hour with most tweets)
        MODE() WITHIN GROUP (ORDER BY EXTRACT(HOUR FROM t.created_at)) as peak_hour,

        -- Posting Velocity (tweets per active hour)
        CASE
            WHEN COUNT(DISTINCT EXTRACT(HOUR FROM t.created_at)) > 0
            THEN COUNT(*)::FLOAT / COUNT(DISTINCT EXTRACT(HOUR FROM t.created_at))
            ELSE 0
        END as posting_velocity,

        -- Viral Tweets Count (threshold: 200+ virality score)
        COUNT(*) FILTER (WHERE
            (COALESCE(t.retweet_count, 0) * 3.0) +
            (COALESCE(t.quote_count, 0) * 2.5) +
            (COALESCE(t.reply_count, 0) * 2.0) +
            (COALESCE(t.like_count, 0) * 1.0) +
            (COALESCE(t.bookmark_count, 0) * 1.5) +
            (COALESCE(t.view_count, 0) * 0.001) > 200
        ) as viral_tweets_count,

        -- Cross-Theme Activity (themes this author participated in)
        COUNT(DISTINCT tc.theme_code) as cross_theme_activity

    FROM osint.tweets_deduplicated t
    LEFT JOIN osint.tweet_collections tc ON tc.tweet_id = t.tweet_id
    WHERE DATE(t.created_at) = p_target_date
      AND t.author_id IS NOT NULL
      AND LENGTH(t.author_id) BETWEEN 1 AND 20  -- Performance: faster than regex validation
    GROUP BY t.author_id

    ON CONFLICT (date, author_id)
    DO UPDATE SET
        daily_tweets = EXCLUDED.daily_tweets,
        daily_replies = EXCLUDED.daily_replies,
        daily_original_tweets = EXCLUDED.daily_original_tweets,
        daily_retweets = EXCLUDED.daily_retweets,
        daily_quotes = EXCLUDED.daily_quotes,
        total_engagement_received = EXCLUDED.total_engagement_received,
        avg_engagement_per_tweet = EXCLUDED.avg_engagement_per_tweet,
        active_hours = EXCLUDED.active_hours,
        peak_hour = EXCLUDED.peak_hour,
        posting_velocity = EXCLUDED.posting_velocity,
        viral_tweets_count = EXCLUDED.viral_tweets_count,
        cross_theme_activity = EXCLUDED.cross_theme_activity,
        computed_at = NOW();

    GET DIAGNOSTICS v_metrics_count = ROW_COUNT;

    -- Count unique authors processed
    SELECT COUNT(*) INTO v_authors_processed
    FROM osint.author_daily_metrics
    WHERE date = p_target_date;

    RAISE NOTICE '  - Daily metrics: % rows for % authors', v_metrics_count, v_authors_processed;

    -- Calculate computation time
    v_computation_time_ms := EXTRACT(EPOCH FROM (clock_timestamp() - v_start_time)) * 1000;

    -- Return results
    RETURN QUERY
    SELECT
        v_metrics_count::BIGINT,
        v_authors_processed::INTEGER,
        v_computation_time_ms::BIGINT;
END;
$$;

-- ================================================================
-- BATCH PROCESSING FUNCTION (for historical data)
-- ================================================================

CREATE OR REPLACE FUNCTION osint.compute_author_daily_batch(
    p_start_date DATE,
    p_end_date DATE DEFAULT CURRENT_DATE - 1
)
RETURNS TABLE(
    date DATE,
    metrics_computed BIGINT,
    authors_processed INTEGER,
    computation_time_ms BIGINT,
    status TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_current_date DATE := p_start_date;
    v_result RECORD;
    v_total_time BIGINT := 0;
    v_total_metrics BIGINT := 0;
    v_total_authors INTEGER := 0;
    v_batch_start TIMESTAMP := clock_timestamp();
BEGIN
    RAISE NOTICE '🚀 Starting batch daily metrics computation from % to %', p_start_date, p_end_date;

    WHILE v_current_date <= p_end_date LOOP
        BEGIN
            RAISE NOTICE 'Processing date: %', v_current_date;

            SELECT * INTO v_result
            FROM osint.compute_author_daily_simple(v_current_date);

            v_total_metrics := v_total_metrics + v_result.metrics_computed;
            v_total_authors := v_total_authors + v_result.authors_processed;
            v_total_time := v_total_time + v_result.computation_time_ms;

            RETURN QUERY SELECT
                v_current_date,
                v_result.metrics_computed,
                v_result.authors_processed,
                v_result.computation_time_ms,
                'SUCCESS'::TEXT;

        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Failed processing date %: %', v_current_date, SQLERRM;
            RETURN QUERY SELECT
                v_current_date,
                0::BIGINT,
                0::INTEGER,
                0::BIGINT,
                ('ERROR: ' || SQLERRM)::TEXT;
        END;

        v_current_date := v_current_date + 1;
    END LOOP;

    DECLARE
        v_batch_time BIGINT := EXTRACT(EPOCH FROM (clock_timestamp() - v_batch_start)) * 1000;
    BEGIN
        RAISE NOTICE '✅ Batch processing completed!';
        RAISE NOTICE '   📈 Total metrics: %', v_total_metrics;
        RAISE NOTICE '   👥 Total author-days: %', v_total_authors;
        RAISE NOTICE '   ⏱️ Total time: %ms (%.2f seconds)', v_batch_time, v_batch_time / 1000.0;

        RETURN QUERY SELECT
            NULL::DATE,
            v_total_metrics,
            v_total_authors,
            v_batch_time,
            'BATCH_COMPLETED'::TEXT;
    END;
END;
$$;

-- ================================================================
-- VERIFICATION AND ANALYTICS QUERIES
-- ================================================================

-- Get daily metrics summary
CREATE OR REPLACE FUNCTION osint.get_daily_metrics_summary(
    p_target_date DATE DEFAULT CURRENT_DATE - 1
)
RETURNS TABLE(
    metric_name TEXT,
    total_authors INTEGER,
    avg_value FLOAT,
    median_value FLOAT,
    p95_value FLOAT,
    max_value FLOAT,
    min_value FLOAT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH metric_stats AS (
        SELECT
            'daily_tweets' as metric,
            COUNT(*) as authors,
            AVG(daily_tweets) as avg_val,
            PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY daily_tweets) as median_val,
            PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY daily_tweets) as p95_val,
            MAX(daily_tweets) as max_val,
            MIN(daily_tweets) as min_val
        FROM osint.author_daily_metrics
        WHERE date = p_target_date

        UNION ALL

        SELECT
            'total_engagement_received' as metric,
            COUNT(*) as authors,
            AVG(total_engagement_received) as avg_val,
            PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_engagement_received) as median_val,
            PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY total_engagement_received) as p95_val,
            MAX(total_engagement_received) as max_val,
            MIN(total_engagement_received) as min_val
        FROM osint.author_daily_metrics
        WHERE date = p_target_date

        UNION ALL

        SELECT
            'cross_theme_activity' as metric,
            COUNT(*) as authors,
            AVG(cross_theme_activity) as avg_val,
            PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY cross_theme_activity) as median_val,
            PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY cross_theme_activity) as p95_val,
            MAX(cross_theme_activity) as max_val,
            MIN(cross_theme_activity) as min_val
        FROM osint.author_daily_metrics
        WHERE date = p_target_date

        UNION ALL

        SELECT
            'viral_tweets_count' as metric,
            COUNT(*) as authors,
            AVG(viral_tweets_count) as avg_val,
            PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY viral_tweets_count) as median_val,
            PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY viral_tweets_count) as p95_val,
            MAX(viral_tweets_count) as max_val,
            MIN(viral_tweets_count) as min_val
        FROM osint.author_daily_metrics
        WHERE date = p_target_date

        UNION ALL

        SELECT
            'avg_engagement_per_tweet' as metric,
            COUNT(*) as authors,
            AVG(avg_engagement_per_tweet) as avg_val,
            PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY avg_engagement_per_tweet) as median_val,
            PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY avg_engagement_per_tweet) as p95_val,
            MAX(avg_engagement_per_tweet) as max_val,
            MIN(avg_engagement_per_tweet) as min_val
        FROM osint.author_daily_metrics
        WHERE date = p_target_date
    )
    SELECT
        metric as metric_name,
        authors::INTEGER as total_authors,
        avg_val::FLOAT as avg_value,
        median_val::FLOAT as median_value,
        p95_val::FLOAT as p95_value,
        max_val::FLOAT as max_value,
        min_val::FLOAT as min_value
    FROM metric_stats;
END;
$$;

-- Get top active authors for a date
CREATE OR REPLACE FUNCTION osint.get_top_active_authors(
    p_target_date DATE DEFAULT CURRENT_DATE - 1,
    p_limit INTEGER DEFAULT 20
)
RETURNS TABLE(
    author_id BIGINT,
    username TEXT,
    daily_tweets INTEGER,
    total_engagement BIGINT,
    viral_tweets INTEGER,
    cross_themes INTEGER,
    avg_engagement FLOAT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        adm.author_id,
        COALESCE(tup.username, 'unknown') as username,
        adm.daily_tweets,
        adm.total_engagement_received as total_engagement,
        adm.viral_tweets_count as viral_tweets,
        adm.cross_theme_activity as cross_themes,
        adm.avg_engagement_per_tweet as avg_engagement
    FROM osint.author_daily_metrics adm
    LEFT JOIN osint.twitter_user_profiles tup ON tup.user_id = adm.author_id::TEXT
    WHERE adm.date = p_target_date
    ORDER BY adm.daily_tweets DESC, adm.total_engagement_received DESC
    LIMIT p_limit;
END;
$$;

RAISE NOTICE '============================================================';
RAISE NOTICE 'Simplified Daily Author Metrics Functions Created';
RAISE NOTICE '============================================================';
RAISE NOTICE 'Functions:';
RAISE NOTICE '  - osint.compute_author_daily_simple(date) - Single day processing';
RAISE NOTICE '  - osint.compute_author_daily_batch(start, end) - Batch processing';
RAISE NOTICE '  - osint.get_daily_metrics_summary(date) - Analytics';
RAISE NOTICE '  - osint.get_top_active_authors(date, limit) - Discovery';
RAISE NOTICE '============================================================';