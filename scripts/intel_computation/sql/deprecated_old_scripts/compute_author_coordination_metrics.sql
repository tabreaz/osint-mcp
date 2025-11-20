-- Author Coordination Detection Metrics
-- Detects coordination patterns, shared content, and suspicious behavior
-- Key component for identifying propaganda networks and bot coordination

CREATE OR REPLACE FUNCTION osint.compute_author_coordination_metrics(
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
    RAISE NOTICE 'Computing author coordination metrics from % to %', v_date_start, v_date_end;

    -- ================================================================
    -- COORDINATION DETECTION METRICS
    -- ================================================================

    WITH author_coordination AS (
        SELECT
            DATE(t.created_at) as metric_date,
            t.author_id,

            -- Shared URL Coordination (URLs shared by multiple authors)
            COUNT(DISTINCT
                CASE WHEN url_sharing.shared_count >= 5 THEN t.tweet_id ELSE NULL END
            ) as shared_url_tweets_count,

            -- Count distinct URLs shared with coordination pattern
            COUNT(DISTINCT
                CASE WHEN url_sharing.shared_count >= 5 THEN url_sharing.url ELSE NULL END
            ) as coordinated_urls_count,

            -- Shared Hashtag Coordination
            COUNT(DISTINCT
                CASE WHEN hashtag_sharing.shared_count >= 10 THEN t.tweet_id ELSE NULL END
            ) as shared_hashtag_tweets_count,

            -- Count distinct hashtags shared with coordination pattern
            COUNT(DISTINCT
                CASE WHEN hashtag_sharing.shared_count >= 10 THEN hashtag_sharing.hashtag ELSE NULL END
            ) as coordinated_hashtags_count,

            -- Simultaneous Posting (posts within 1 minute of other accounts)
            COUNT(DISTINCT
                CASE WHEN simultaneous.other_authors >= 2 THEN t.tweet_id ELSE NULL END
            ) as simultaneous_posting_count,

            -- Cross-Theme Activity (themes this author participated in)
            COUNT(DISTINCT tc.theme_code) as daily_themes_active,

            -- Retweet Network Size (unique accounts this author retweeted)
            COUNT(DISTINCT
                CASE WHEN t.retweeted_tweet_id IS NOT NULL
                THEN rt.author_id ELSE NULL END
            ) as retweet_network_size,

            -- Reply Network Size (unique accounts this author replied to)
            COUNT(DISTINCT
                CASE WHEN t.in_reply_to_id IS NOT NULL
                THEN t.in_reply_to_user_id ELSE NULL END
            ) as reply_network_size,

            -- Media Coordination placeholder (requires tweet_media table)
            0 as coordinated_media_count,

            -- Timing Pattern Score (consistency in posting times)
            CASE
                WHEN COUNT(*) > 1 THEN
                    1.0 - (STDDEV(EXTRACT(EPOCH FROM t.created_at))::FLOAT /
                           (24 * 3600)) -- Normalize by seconds in a day
                ELSE 0
            END as timing_consistency_score

        FROM osint.tweets_deduplicated t

        -- URL Sharing Analysis (using urls jsonb column)
        LEFT JOIN (
            SELECT
                url_element->>'expanded_url' as url,
                COUNT(DISTINCT DATE(t2.created_at) || '_' || t2.author_id) as shared_count
            FROM osint.tweets_deduplicated t2,
                 jsonb_array_elements(t2.urls) as url_element
            WHERE DATE(t2.created_at) BETWEEN v_date_start AND v_date_end
              AND url_element->>'expanded_url' IS NOT NULL
            GROUP BY url_element->>'expanded_url'
        ) url_sharing ON EXISTS (
            SELECT 1 FROM jsonb_array_elements(t.urls) as url_element
            WHERE url_element->>'expanded_url' = url_sharing.url
        )

        -- Hashtag Sharing Analysis (using hashtags array)
        LEFT JOIN (
            SELECT
                hashtag,
                COUNT(DISTINCT DATE(t2.created_at) || '_' || t2.author_id) as shared_count
            FROM osint.tweets_deduplicated t2,
                 unnest(t2.hashtags) as hashtag
            WHERE DATE(t2.created_at) BETWEEN v_date_start AND v_date_end
              AND hashtag IS NOT NULL
            GROUP BY hashtag
        ) hashtag_sharing ON hashtag_sharing.hashtag = ANY(t.hashtags)

        -- Simultaneous Posting Detection
        LEFT JOIN (
            SELECT
                t3.tweet_id,
                COUNT(DISTINCT t4.author_id) as other_authors
            FROM osint.tweets_deduplicated t3
            JOIN osint.tweets_deduplicated t4 ON
                ABS(EXTRACT(EPOCH FROM t4.created_at - t3.created_at)) <= 60
                AND t3.author_id != t4.author_id
            WHERE DATE(t3.created_at) BETWEEN v_date_start AND v_date_end
            GROUP BY t3.tweet_id
        ) simultaneous ON simultaneous.tweet_id = t.tweet_id

        -- Media analysis disabled (tweet_media table not available)

        -- Theme Collections
        LEFT JOIN osint.tweet_collections tc ON tc.tweet_id = t.tweet_id

        -- Retweeted Tweet Authors
        LEFT JOIN osint.tweets_deduplicated rt ON
            rt.tweet_id = t.retweeted_tweet_id

        WHERE DATE(t.created_at) BETWEEN v_date_start AND v_date_end
          AND t.author_id IS NOT NULL
        GROUP BY DATE(t.created_at), t.author_id
    ),

    -- Calculate composite coordination risk scores
    coordination_scores AS (
        SELECT
            *,
            -- Coordination Risk Score (0-1 scale)
            LEAST(1.0,
                (COALESCE(shared_url_tweets_count, 0) * 0.25 +
                 COALESCE(shared_hashtag_tweets_count, 0) * 0.15 +
                 COALESCE(simultaneous_posting_count, 0) * 0.20 +
                 COALESCE(coordinated_media_count, 0) * 0.30 +
                 CASE WHEN daily_themes_active >= 4 THEN 0.10 ELSE 0 END) / 10.0
            ) as coordination_risk_score,

            -- Network Diversity Score (variety of interaction partners)
            CASE
                WHEN COALESCE(retweet_network_size, 0) + COALESCE(reply_network_size, 0) > 0
                THEN (COALESCE(retweet_network_size, 0) + COALESCE(reply_network_size, 0))::FLOAT /
                     GREATEST(1, COALESCE(shared_url_tweets_count, 0) + COALESCE(shared_hashtag_tweets_count, 0))
                ELSE 1.0
            END as network_diversity_score

        FROM author_coordination
    ),

    -- Pivot coordination metrics for storage
    coordination_metrics_pivot AS (
        SELECT
            metric_date,
            author_id,
            metric_name,
            value_int,
            value_float,
            unit
        FROM coordination_scores,
        LATERAL (VALUES
            ('shared_url_tweets_count', shared_url_tweets_count, NULL, 'count'),
            ('coordinated_urls_count', coordinated_urls_count, NULL, 'count'),
            ('shared_hashtag_tweets_count', shared_hashtag_tweets_count, NULL, 'count'),
            ('coordinated_hashtags_count', coordinated_hashtags_count, NULL, 'count'),
            ('simultaneous_posting_count', simultaneous_posting_count, NULL, 'count'),
            ('daily_themes_active', daily_themes_active, NULL, 'count'),
            ('retweet_network_size', retweet_network_size, NULL, 'count'),
            ('reply_network_size', reply_network_size, NULL, 'count'),
            ('coordinated_media_count', coordinated_media_count, NULL, 'count'),
            ('coordination_risk_score', NULL, coordination_risk_score, 'score'),
            ('timing_consistency_score', NULL, timing_consistency_score, 'score'),
            ('network_diversity_score', NULL, network_diversity_score, 'score')
        ) AS unpivoted(metric_name, value_int, value_float, unit)
    )

    -- Insert coordination metrics with UPSERT
    INSERT INTO osint.intel_metrics (time, metric_name, entity_type, entity_id, value_int, value_float, unit)
    SELECT
        metric_date::timestamptz,
        metric_name,
        'author',
        author_id::bigint,
        value_int,
        value_float,
        unit
    FROM coordination_metrics_pivot
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
      AND metric_name = 'coordination_risk_score';

    RAISE NOTICE '  - Author coordination metrics: % rows for % authors', v_metrics_count, v_authors_processed;

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

-- Create specialized indexes for coordination queries
CREATE INDEX IF NOT EXISTS idx_intel_metrics_coordination_risk
ON osint.intel_metrics (entity_type, metric_name, value_float DESC)
WHERE entity_type = 'author' AND metric_name = 'coordination_risk_score';

CREATE INDEX IF NOT EXISTS idx_intel_metrics_cross_theme
ON osint.intel_metrics (entity_type, metric_name, value_int DESC)
WHERE entity_type = 'author' AND metric_name = 'daily_themes_active';