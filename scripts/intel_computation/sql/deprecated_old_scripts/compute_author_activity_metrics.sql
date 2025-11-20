-- Author Activity Metrics Computation
-- Computes core activity and engagement metrics for all authors
-- Part of intelligence discovery engine for OSINT monitoring

CREATE OR REPLACE FUNCTION osint.compute_author_activity_metrics(
    p_target_date DATE DEFAULT CURRENT_DATE - 1,
    p_days_back INTEGER DEFAULT 1
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
    v_date_start DATE := p_target_date - p_days_back + 1;
    v_date_end DATE := p_target_date;
BEGIN
    RAISE NOTICE 'Computing author activity metrics from % to %', v_date_start, v_date_end;

    -- ================================================================
    -- AUTHOR ACTIVITY METRICS
    -- ================================================================

    WITH author_activity AS (
        SELECT
            DATE(t.created_at) as metric_date,
            t.author_id,

            -- Basic Activity Counts
            COUNT(*) as daily_tweets,
            COUNT(*) FILTER (WHERE t.in_reply_to_id IS NULL
                             AND t.retweeted_tweet_id IS NULL
                             AND t.quoted_tweet_id IS NULL) as daily_original_tweets,
            COUNT(*) FILTER (WHERE t.retweeted_tweet_id IS NOT NULL) as daily_retweets,
            COUNT(*) FILTER (WHERE t.in_reply_to_id IS NOT NULL) as daily_replies,
            COUNT(*) FILTER (WHERE t.quoted_tweet_id IS NOT NULL) as daily_quotes,

            -- Posting Velocity (tweets per hour when active)
            CASE
                WHEN COUNT(DISTINCT EXTRACT(HOUR FROM t.created_at)) > 0
                THEN COUNT(*)::FLOAT / COUNT(DISTINCT EXTRACT(HOUR FROM t.created_at))
                ELSE 0
            END as posting_velocity,

            -- Active Hours (unique hours when posting)
            COUNT(DISTINCT EXTRACT(HOUR FROM t.created_at)) as active_hours,

            -- Peak Hour (hour with most tweets)
            MODE() WITHIN GROUP (ORDER BY EXTRACT(HOUR FROM t.created_at)) as peak_hour,

            -- Total Engagement Received
            SUM(COALESCE(t.like_count, 0)) as total_likes_received,
            SUM(COALESCE(t.retweet_count, 0)) as total_retweets_received,
            SUM(COALESCE(t.reply_count, 0)) as total_replies_received,
            SUM(COALESCE(t.quote_count, 0)) as total_quotes_received,
            SUM(COALESCE(t.view_count, 0)) as total_views_received,
            SUM(COALESCE(t.bookmark_count, 0)) as total_bookmarks_received,

            -- Total Engagement (sum of all interactions)
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

            -- Virality Score Calculation (weighted engagement)
            AVG(
                (COALESCE(t.retweet_count, 0) * 3.0) +
                (COALESCE(t.quote_count, 0) * 2.5) +
                (COALESCE(t.reply_count, 0) * 2.0) +
                (COALESCE(t.like_count, 0) * 1.0) +
                (COALESCE(t.bookmark_count, 0) * 1.5) +
                (COALESCE(t.view_count, 0) * 0.001)
            ) as avg_virality_score,

            -- Maximum Virality Score
            MAX(
                (COALESCE(t.retweet_count, 0) * 3.0) +
                (COALESCE(t.quote_count, 0) * 2.5) +
                (COALESCE(t.reply_count, 0) * 2.0) +
                (COALESCE(t.like_count, 0) * 1.0) +
                (COALESCE(t.bookmark_count, 0) * 1.5) +
                (COALESCE(t.view_count, 0) * 0.001)
            ) as max_virality_score,

            -- Viral Tweets Count (threshold: 200+ virality score)
            COUNT(*) FILTER (WHERE
                (COALESCE(t.retweet_count, 0) * 3.0) +
                (COALESCE(t.quote_count, 0) * 2.5) +
                (COALESCE(t.reply_count, 0) * 2.0) +
                (COALESCE(t.like_count, 0) * 1.0) +
                (COALESCE(t.bookmark_count, 0) * 1.5) +
                (COALESCE(t.view_count, 0) * 0.001) > 200
            ) as viral_tweets_count,

            -- Highly Viral Tweets Count (threshold: 1000+ virality score)
            COUNT(*) FILTER (WHERE
                (COALESCE(t.retweet_count, 0) * 3.0) +
                (COALESCE(t.quote_count, 0) * 2.5) +
                (COALESCE(t.reply_count, 0) * 2.0) +
                (COALESCE(t.like_count, 0) * 1.0) +
                (COALESCE(t.bookmark_count, 0) * 1.5) +
                (COALESCE(t.view_count, 0) * 0.001) > 1000
            ) as highly_viral_tweets_count,

            -- Amplification Factor (retweets received per original tweet)
            CASE
                WHEN COUNT(*) FILTER (WHERE t.retweeted_tweet_id IS NULL) > 0
                THEN SUM(COALESCE(t.retweet_count, 0))::FLOAT /
                     COUNT(*) FILTER (WHERE t.retweeted_tweet_id IS NULL)
                ELSE 0
            END as amplification_factor

        FROM osint.tweets_deduplicated t
        WHERE DATE(t.created_at) BETWEEN v_date_start AND v_date_end
          AND t.author_id IS NOT NULL
        GROUP BY DATE(t.created_at), t.author_id
    ),

    -- Pivot metrics for storage
    author_metrics_pivot AS (
        SELECT
            metric_date,
            author_id,
            metric_name,
            value_int,
            value_float,
            unit
        FROM author_activity,
        LATERAL (VALUES
            ('daily_tweets', daily_tweets, NULL, 'count'),
            ('daily_original_tweets', daily_original_tweets, NULL, 'count'),
            ('daily_retweets', daily_retweets, NULL, 'count'),
            ('daily_replies', daily_replies, NULL, 'count'),
            ('daily_quotes', daily_quotes, NULL, 'count'),
            ('active_hours', active_hours, NULL, 'count'),
            ('peak_hour', peak_hour, NULL, 'hour'),
            ('total_likes_received', total_likes_received, NULL, 'count'),
            ('total_retweets_received', total_retweets_received, NULL, 'count'),
            ('total_replies_received', total_replies_received, NULL, 'count'),
            ('total_quotes_received', total_quotes_received, NULL, 'count'),
            ('total_views_received', total_views_received, NULL, 'count'),
            ('total_bookmarks_received', total_bookmarks_received, NULL, 'count'),
            ('total_engagement_received', total_engagement_received, NULL, 'count'),
            ('viral_tweets_count', viral_tweets_count, NULL, 'count'),
            ('highly_viral_tweets_count', highly_viral_tweets_count, NULL, 'count'),
            ('posting_velocity', NULL, posting_velocity, 'tweets_per_hour'),
            ('avg_engagement_per_tweet', NULL, avg_engagement_per_tweet, 'score'),
            ('avg_virality_score', NULL, avg_virality_score, 'score'),
            ('max_virality_score', NULL, max_virality_score, 'score'),
            ('amplification_factor', NULL, amplification_factor, 'ratio')
        ) AS unpivoted(metric_name, value_int, value_float, unit)
    )

    -- Insert metrics with UPSERT for conflict resolution
    INSERT INTO osint.intel_metrics (time, metric_name, entity_type, entity_id, value_int, value_float, unit)
    SELECT
        metric_date::timestamptz,
        metric_name,
        'author',
        author_id::bigint,
        value_int,
        value_float,
        unit
    FROM author_metrics_pivot
    ON CONFLICT (time, metric_name, entity_type, entity_id)
    DO UPDATE SET
        value_int = EXCLUDED.value_int,
        value_float = EXCLUDED.value_float,
        unit = EXCLUDED.unit,
        computed_at = NOW();

    GET DIAGNOSTICS v_metrics_count = ROW_COUNT;

    -- Count unique authors processed from metrics inserted
    SELECT COUNT(DISTINCT entity_id) INTO v_authors_processed
    FROM osint.intel_metrics
    WHERE entity_type = 'author'
      AND DATE(time) = p_target_date
      AND metric_name = 'daily_tweets';

    RAISE NOTICE '  - Author activity metrics: % rows for % authors', v_metrics_count, v_authors_processed;

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

-- Create index for efficient author metrics queries
CREATE INDEX IF NOT EXISTS idx_intel_metrics_author_lookup
ON osint.intel_metrics (entity_type, entity_id, time DESC)
WHERE entity_type = 'author';

-- Create index for metric-specific queries
CREATE INDEX IF NOT EXISTS idx_intel_metrics_author_metric
ON osint.intel_metrics (entity_type, metric_name, time DESC)
WHERE entity_type = 'author';