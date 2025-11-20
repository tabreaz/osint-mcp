-- Author Influence Scoring Metrics
-- Computes composite influence scores for discovering high-impact authors
-- Identifies monitoring candidates and validates existing monitored accounts

CREATE OR REPLACE FUNCTION osint.compute_author_influence_metrics(
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
    v_max_followers INTEGER;
    v_max_engagement BIGINT;
BEGIN
    RAISE NOTICE 'Computing author influence metrics from % to %', v_date_start, v_date_end;

    -- Get normalization factors
    SELECT MAX(tup.followers_count) INTO v_max_followers
    FROM osint.twitter_user_profiles tup;

    SELECT MAX(
        COALESCE(t.like_count, 0) + COALESCE(t.retweet_count, 0) +
        COALESCE(t.reply_count, 0) + COALESCE(t.quote_count, 0)
    ) INTO v_max_engagement
    FROM osint.tweets_deduplicated t
    WHERE DATE(t.created_at) BETWEEN v_date_start AND v_date_end;

    RAISE NOTICE 'Normalization factors - Max followers: %, Max engagement: %', v_max_followers, v_max_engagement;

    -- ================================================================
    -- INFLUENCE METRICS COMPUTATION
    -- ================================================================

    WITH author_influence AS (
        SELECT
            DATE(t.created_at) as metric_date,
            t.author_id,
            tup.username,
            tup.followers_count,
            tup.following_count,
            0 as listed_count,  -- listed_count not available
            tup.verified,

            -- Amplification Factor (retweets received per original tweet)
            CASE
                WHEN COUNT(*) FILTER (WHERE t.retweeted_tweet_id IS NULL) > 0
                THEN SUM(COALESCE(t.retweet_count, 0))::FLOAT /
                     COUNT(*) FILTER (WHERE t.retweeted_tweet_id IS NULL)
                ELSE 0
            END as amplification_factor,

            -- Conversation Starter Score (replies received per tweet)
            CASE
                WHEN COUNT(*) > 0
                THEN SUM(COALESCE(t.reply_count, 0))::FLOAT / COUNT(*)
                ELSE 0
            END as conversation_starter_score,

            -- Reach Score (unique users who interacted via retweets/quotes)
            COUNT(DISTINCT
                CASE WHEN t.retweeted_tweet_id IS NOT NULL OR t.quoted_tweet_id IS NOT NULL
                THEN t.author_id ELSE NULL END
            ) as reach_score,

            -- Authority Score (followers to following ratio, capped at 10)
            LEAST(10.0,
                CASE
                    WHEN COALESCE(tup.following_count, 0) > 0
                    THEN COALESCE(tup.followers_count, 0)::FLOAT / tup.following_count
                    ELSE COALESCE(tup.followers_count, 0)::FLOAT
                END
            ) as authority_score,

            -- Engagement Rate (total engagement per follower)
            CASE
                WHEN COALESCE(tup.followers_count, 0) > 0
                THEN (SUM(
                    COALESCE(t.like_count, 0) + COALESCE(t.retweet_count, 0) +
                    COALESCE(t.reply_count, 0) + COALESCE(t.quote_count, 0)
                )::FLOAT / tup.followers_count) * 1000 -- Per 1000 followers
                ELSE 0
            END as engagement_rate_per_1k_followers,

            -- Virality Achievement (% of tweets that go viral)
            CASE
                WHEN COUNT(*) > 0
                THEN (COUNT(*) FILTER (WHERE
                    (COALESCE(t.retweet_count, 0) * 3.0) +
                    (COALESCE(t.quote_count, 0) * 2.5) +
                    (COALESCE(t.reply_count, 0) * 2.0) +
                    (COALESCE(t.like_count, 0) * 1.0) +
                    (COALESCE(t.bookmark_count, 0) * 1.5) > 200
                ))::FLOAT / COUNT(*)
                ELSE 0
            END as virality_achievement_rate,

            -- Cross-Theme Activity Count
            COUNT(DISTINCT tc.theme_code) as cross_theme_activity,

            -- Network Centrality (approximated by reply network size)
            COUNT(DISTINCT
                CASE WHEN t.in_reply_to_id IS NOT NULL
                THEN t.in_reply_to_user_id ELSE NULL END
            ) as network_centrality,

            -- Tweet Volume (daily output)
            COUNT(*) as daily_tweet_volume,

            -- Original Content Ratio
            CASE
                WHEN COUNT(*) > 0
                THEN COUNT(*) FILTER (WHERE t.retweeted_tweet_id IS NULL)::FLOAT / COUNT(*)
                ELSE 0
            END as original_content_ratio

        FROM osint.tweets_deduplicated t
        LEFT JOIN osint.twitter_user_profiles tup ON tup.user_id = t.author_id
        LEFT JOIN osint.tweet_collections tc ON tc.tweet_id = t.tweet_id
        -- No need for additional joins, using direct user IDs from main table

        WHERE DATE(t.created_at) BETWEEN v_date_start AND v_date_end
          AND t.author_id IS NOT NULL
        GROUP BY DATE(t.created_at), t.author_id, tup.username, tup.followers_count,
                 tup.following_count, tup.verified
    ),

    -- Calculate normalized scores and composite influence
    influence_scores AS (
        SELECT
            *,
            -- Normalize scores to 0-1 scale
            LEAST(1.0, amplification_factor / NULLIF(GREATEST(1, amplification_factor), 0)) as norm_amplification,
            LEAST(1.0, conversation_starter_score / 10.0) as norm_conversation,
            LEAST(1.0, reach_score::FLOAT / 100.0) as norm_reach,
            LEAST(1.0, authority_score / 10.0) as norm_authority,
            LEAST(1.0, engagement_rate_per_1k_followers / 100.0) as norm_engagement_rate,
            LEAST(1.0, network_centrality::FLOAT / 50.0) as norm_network,
            LEAST(1.0, virality_achievement_rate) as norm_virality,

            -- Follower tier scoring
            CASE
                WHEN COALESCE(followers_count, 0) >= 100000 THEN 1.0
                WHEN COALESCE(followers_count, 0) >= 10000 THEN 0.8
                WHEN COALESCE(followers_count, 0) >= 1000 THEN 0.6
                WHEN COALESCE(followers_count, 0) >= 100 THEN 0.4
                ELSE 0.2
            END as follower_tier_score,

            -- Cross-theme risk flag
            CASE WHEN cross_theme_activity >= 4 THEN 1.0 ELSE 0.0 END as cross_theme_risk_flag,

            -- Verification bonus
            CASE WHEN verified THEN 0.1 ELSE 0.0 END as verification_bonus

        FROM author_influence
    ),

    final_influence AS (
        SELECT
            *,
            -- Composite Influence Score (weighted combination)
            LEAST(1.0,
                (norm_amplification * 0.25) +          -- Retweet amplification
                (norm_conversation * 0.15) +           -- Reply generation
                (norm_reach * 0.15) +                  -- Network reach
                (norm_authority * 0.20) +              -- Authority ratio
                (norm_engagement_rate * 0.15) +        -- Engagement efficiency
                (norm_virality * 0.10) +               -- Viral content creation
                verification_bonus                      -- Verification boost
            ) as influence_score,

            -- Monitoring Priority Score (for discovering new candidates)
            CASE
                WHEN cross_theme_activity >= 4 THEN 1.0  -- High cross-theme activity
                WHEN (norm_amplification * 0.25) + (norm_conversation * 0.15) + (norm_reach * 0.15) + (norm_authority * 0.20) + (norm_engagement_rate * 0.15) + (norm_virality * 0.10) + verification_bonus > 0.7 THEN 0.9       -- High influence
                WHEN norm_amplification > 0.8 THEN 0.8    -- Strong amplification
                WHEN norm_engagement_rate > 0.7 THEN 0.7  -- High engagement
                ELSE LEAST(1.0, (norm_amplification * 0.25) + (norm_conversation * 0.15) + (norm_reach * 0.15) + (norm_authority * 0.20) + (norm_engagement_rate * 0.15) + (norm_virality * 0.10) + verification_bonus)
            END as monitoring_priority_score,

            -- Risk Assessment Score (propaganda/coordination risk)
            LEAST(1.0,
                (cross_theme_risk_flag * 0.4) +
                (CASE WHEN original_content_ratio < 0.3 THEN 0.3 ELSE 0.0 END) +
                (CASE WHEN daily_tweet_volume > 50 THEN 0.3 ELSE 0.0 END)
            ) as risk_assessment_score

        FROM influence_scores
    ),

    -- Pivot influence metrics for storage
    influence_metrics_pivot AS (
        SELECT
            metric_date,
            author_id,
            metric_name,
            value_int,
            value_float,
            unit
        FROM final_influence,
        LATERAL (VALUES
            ('amplification_factor', NULL, amplification_factor, 'ratio'),
            ('conversation_starter_score', NULL, conversation_starter_score, 'ratio'),
            ('reach_score', reach_score, NULL, 'count'),
            ('authority_score', NULL, authority_score, 'ratio'),
            ('engagement_rate_per_1k_followers', NULL, engagement_rate_per_1k_followers, 'rate'),
            ('virality_achievement_rate', NULL, virality_achievement_rate, 'percentage'),
            ('cross_theme_activity', cross_theme_activity, NULL, 'count'),
            ('network_centrality', network_centrality, NULL, 'count'),
            ('daily_tweet_volume', daily_tweet_volume, NULL, 'count'),
            ('original_content_ratio', NULL, original_content_ratio, 'percentage'),
            ('follower_tier_score', NULL, follower_tier_score, 'score'),
            ('influence_score', NULL, influence_score, 'score'),
            ('monitoring_priority_score', NULL, monitoring_priority_score, 'score'),
            ('risk_assessment_score', NULL, risk_assessment_score, 'score')
        ) AS unpivoted(metric_name, value_int, value_float, unit)
    )

    -- Insert influence metrics with UPSERT
    INSERT INTO osint.intel_metrics (time, metric_name, entity_type, entity_id, value_int, value_float, unit)
    SELECT
        metric_date::timestamptz,
        metric_name,
        'author',
        author_id::bigint,
        value_int,
        value_float,
        unit
    FROM influence_metrics_pivot
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
      AND metric_name = 'influence_score';

    RAISE NOTICE '  - Author influence metrics: % rows for % authors', v_metrics_count, v_authors_processed;

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

-- Create specialized indexes for influence discovery queries
CREATE INDEX IF NOT EXISTS idx_intel_metrics_influence_score
ON osint.intel_metrics (entity_type, metric_name, value_float DESC)
WHERE entity_type = 'author' AND metric_name = 'influence_score';

CREATE INDEX IF NOT EXISTS idx_intel_metrics_monitoring_priority
ON osint.intel_metrics (entity_type, metric_name, value_float DESC)
WHERE entity_type = 'author' AND metric_name = 'monitoring_priority_score';

CREATE INDEX IF NOT EXISTS idx_intel_metrics_cross_theme_risk
ON osint.intel_metrics (entity_type, metric_name, value_int DESC)
WHERE entity_type = 'author' AND metric_name = 'cross_theme_activity';