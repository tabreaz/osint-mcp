-- Author Strategic Intelligence Computation
-- Weekly/Monthly analysis for coordination detection, influence scoring, network analysis
-- Stores results in author_intelligence table with analysis periods

CREATE OR REPLACE FUNCTION osint.compute_author_intelligence(
    p_analysis_date DATE DEFAULT CURRENT_DATE - 1,
    p_analysis_period TEXT DEFAULT '7_days',
    p_min_tweet_threshold INTEGER DEFAULT 5
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
    v_days_back INTEGER;
    v_date_start DATE;
    v_date_end DATE;
    v_max_followers INTEGER;
    v_max_engagement BIGINT;
BEGIN
    -- Determine analysis window
    CASE p_analysis_period
        WHEN '7_days' THEN v_days_back := 7;
        WHEN '30_days' THEN v_days_back := 30;
        WHEN '90_days' THEN v_days_back := 90;
        ELSE
            RAISE EXCEPTION 'Invalid analysis_period: %. Use 7_days, 30_days, or 90_days', p_analysis_period;
    END CASE;

    v_date_start := p_analysis_date - v_days_back + 1;
    v_date_end := p_analysis_date;

    RAISE NOTICE 'Computing author intelligence for % period from % to %', p_analysis_period, v_date_start, v_date_end;

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
    -- STRATEGIC INTELLIGENCE COMPUTATION
    -- ================================================================

    INSERT INTO osint.author_intelligence (
        analysis_date,
        author_id,
        analysis_period,
        influence_score,
        authority_score,
        coordination_risk_score,
        betweenness_centrality,
        network_reach,
        cross_reference_rate,
        semantic_diversity_score,
        hashtag_coordination_score,
        monitoring_priority_score,
        amplification_factor
    )

    WITH author_base_data AS (
        SELECT
            t.author_id::BIGINT,
            COUNT(DISTINCT t.tweet_id) as total_tweets,  -- CRITICAL: DISTINCT to avoid duplication

            -- User Profile Data
            MAX(tup.followers_count) as followers_count,
            MAX(tup.following_count) as following_count,
            MAX(CASE WHEN tup.verified THEN 1 ELSE 0 END) as verified,
            MAX(tup.username) as username,

            -- Basic Engagement Metrics
            SUM(COALESCE(t.like_count, 0)) as total_likes,
            SUM(COALESCE(t.retweet_count, 0)) as total_retweets,
            SUM(COALESCE(t.reply_count, 0)) as total_replies,
            SUM(COALESCE(t.quote_count, 0)) as total_quotes,
            SUM(
                COALESCE(t.like_count, 0) + COALESCE(t.retweet_count, 0) +
                COALESCE(t.reply_count, 0) + COALESCE(t.quote_count, 0)
            ) as total_engagement,

            -- Content Type Breakdown
            COUNT(DISTINCT t.tweet_id) FILTER (WHERE t.retweeted_tweet_id IS NULL
                            AND t.in_reply_to_id IS NULL
                            AND t.quoted_tweet_id IS NULL) as original_tweets,
            COUNT(DISTINCT t.tweet_id) FILTER (WHERE t.retweeted_tweet_id IS NOT NULL) as retweets,
            COUNT(DISTINCT t.tweet_id) FILTER (WHERE t.in_reply_to_id IS NOT NULL) as replies,
            COUNT(DISTINCT t.tweet_id) FILTER (WHERE t.quoted_tweet_id IS NOT NULL) as quotes,

            -- Virality Metrics
            COUNT(DISTINCT t.tweet_id) FILTER (WHERE
                (COALESCE(t.retweet_count, 0) * 3.0) +
                (COALESCE(t.quote_count, 0) * 2.5) +
                (COALESCE(t.reply_count, 0) * 2.0) +
                (COALESCE(t.like_count, 0) * 1.0) +
                (COALESCE(t.bookmark_count, 0) * 1.5) > 200
            ) as viral_tweets,

            -- Network Metrics
            COUNT(DISTINCT t.in_reply_to_user_id) FILTER (WHERE t.in_reply_to_user_id IS NOT NULL) as unique_reply_targets,
            COUNT(DISTINCT rt_orig.author_id) FILTER (WHERE rt_orig.author_id IS NOT NULL) as unique_retweet_sources,

            -- Cross-Platform Activity
            COUNT(DISTINCT tc.theme_code) as themes_active,
            COUNT(DISTINCT tc.project_id) as projects_active,

            -- Hashtag Usage (subquery to avoid LATERAL cartesian explosion)
            (SELECT COUNT(DISTINCT hashtag)
             FROM osint.tweets_deduplicated t2, unnest(t2.hashtags) hashtag
             WHERE t2.author_id = t.author_id
               AND DATE(t2.created_at) BETWEEN v_date_start AND v_date_end
               AND hashtag IS NOT NULL
            ) as unique_hashtags_used,

            -- URL Sharing (subquery to avoid LATERAL cartesian explosion)
            (SELECT COUNT(DISTINCT url_elem->>'expanded_url')
             FROM osint.tweets_deduplicated t2, jsonb_array_elements(t2.urls) url_elem
             WHERE t2.author_id = t.author_id
               AND DATE(t2.created_at) BETWEEN v_date_start AND v_date_end
               AND url_elem->>'expanded_url' IS NOT NULL
            ) as unique_urls_shared

        FROM osint.tweets_deduplicated t
        LEFT JOIN osint.twitter_user_profiles tup ON tup.user_id = t.author_id
        LEFT JOIN osint.tweet_collections tc ON tc.tweet_id = t.tweet_id
        LEFT JOIN osint.tweets_deduplicated rt_orig ON rt_orig.tweet_id = t.retweeted_tweet_id

        WHERE DATE(t.created_at) BETWEEN v_date_start AND v_date_end
          AND t.author_id IS NOT NULL
          AND LENGTH(t.author_id) BETWEEN 1 AND 20  -- Performance: faster than regex
        GROUP BY t.author_id
        HAVING COUNT(DISTINCT t.tweet_id) >= p_min_tweet_threshold
    ),

    -- PRE-COMPUTE shared entities for MASSIVE performance boost
    shared_urls AS (
        SELECT
            url_element->>'expanded_url' as url,
            COUNT(DISTINCT t2.author_id) as shared_count,
            ARRAY_AGG(DISTINCT t2.author_id) as authors
        FROM osint.tweets_deduplicated t2,
             jsonb_array_elements(t2.urls) url_element
        WHERE DATE(t2.created_at) BETWEEN v_date_start AND v_date_end
          AND url_element->>'expanded_url' IS NOT NULL
        GROUP BY url_element->>'expanded_url'
        HAVING COUNT(DISTINCT t2.author_id) >= 5  -- Pre-filter for coordination threshold
    ),
    shared_hashtags AS (
        SELECT
            hashtag,
            COUNT(DISTINCT t2.author_id) as shared_count,
            ARRAY_AGG(DISTINCT t2.author_id) as authors
        FROM osint.tweets_deduplicated t2,
             unnest(t2.hashtags) hashtag
        WHERE DATE(t2.created_at) BETWEEN v_date_start AND v_date_end
          AND hashtag IS NOT NULL
        GROUP BY hashtag
        HAVING COUNT(DISTINCT t2.author_id) >= 10  -- Pre-filter for coordination threshold
    ),
    -- Timing coordination using time buckets (O(N) instead of O(N²))
    time_buckets AS (
        SELECT
            t.tweet_id,
            t.author_id,
            DATE_TRUNC('minute', t.created_at) -
            (EXTRACT(MINUTE FROM t.created_at)::INTEGER % 5) * INTERVAL '1 minute' as time_bucket
        FROM osint.tweets_deduplicated t
        WHERE DATE(t.created_at) BETWEEN v_date_start AND v_date_end
          AND t.author_id IS NOT NULL
    ),
    coordinated_time_buckets AS (
        SELECT
            time_bucket,
            COUNT(DISTINCT author_id) as authors_in_bucket
        FROM time_buckets
        GROUP BY time_bucket
        HAVING COUNT(DISTINCT author_id) >= 3  -- Pre-filter coordination threshold
    ),
    -- Coordination Detection (optimized)
    coordination_analysis AS (
        SELECT
            t.author_id::BIGINT,

            -- Shared URL Coordination (using pre-computed shared_urls)
            COUNT(DISTINCT t.tweet_id) FILTER (WHERE su.shared_count IS NOT NULL) as coordinated_url_tweets,
            COUNT(DISTINCT su.url) as coordinated_urls,

            -- Shared Hashtag Coordination (using pre-computed shared_hashtags)
            COUNT(DISTINCT t.tweet_id) FILTER (WHERE sh.shared_count IS NOT NULL) as coordinated_hashtag_tweets,
            COUNT(DISTINCT sh.hashtag) as coordinated_hashtags,

            -- Timing Coordination (using time buckets)
            COUNT(DISTINCT t.tweet_id) FILTER (WHERE ctb.authors_in_bucket IS NOT NULL) as coordinated_timing_tweets

        FROM osint.tweets_deduplicated t

        -- Join with pre-computed shared URLs (much faster!)
        LEFT JOIN shared_urls su ON EXISTS (
            SELECT 1 FROM jsonb_array_elements(t.urls) url_elem
            WHERE url_elem->>'expanded_url' = su.url
        )

        -- Join with pre-computed shared hashtags (much faster!)
        LEFT JOIN shared_hashtags sh ON sh.hashtag = ANY(t.hashtags)

        -- Join with coordinated time buckets (O(N) instead of O(N²))
        LEFT JOIN time_buckets tb ON tb.tweet_id = t.tweet_id
        LEFT JOIN coordinated_time_buckets ctb ON ctb.time_bucket = tb.time_bucket

        WHERE DATE(t.created_at) BETWEEN v_date_start AND v_date_end
          AND t.author_id IS NOT NULL
          AND LENGTH(t.author_id) BETWEEN 1 AND 20
        GROUP BY t.author_id
    ),

    -- Combine and calculate final intelligence scores
    intelligence_scores AS (
        SELECT
            abd.author_id,

            -- Authority Score (followers to following ratio, capped at 10)
            LEAST(10.0,
                CASE
                    WHEN COALESCE(abd.following_count, 0) > 0
                    THEN COALESCE(abd.followers_count, 0)::FLOAT / abd.following_count
                    ELSE COALESCE(abd.followers_count, 0)::FLOAT
                END
            ) as authority_score,

            -- Influence Score (weighted composite)
            LEAST(1.0,
                -- Amplification component
                (CASE WHEN abd.original_tweets > 0
                 THEN abd.total_retweets::FLOAT / abd.original_tweets ELSE 0 END / 50.0 * 0.3) +
                -- Engagement rate component
                (CASE WHEN COALESCE(abd.followers_count, 0) > 0
                 THEN (abd.total_engagement::FLOAT / abd.followers_count) * 1000 ELSE 0 END / 100.0 * 0.25) +
                -- Conversation starter component
                (abd.total_replies::FLOAT / GREATEST(1, abd.total_tweets) / 10.0 * 0.2) +
                -- Network reach component
                (GREATEST(abd.unique_reply_targets, abd.unique_retweet_sources)::FLOAT / 100.0 * 0.15) +
                -- Cross-platform activity
                (LEAST(abd.themes_active::FLOAT / 5.0, 1.0) * 0.1)
            ) as influence_score,

            -- Coordination Risk Score
            LEAST(1.0,
                (COALESCE(ca.coordinated_url_tweets, 0)::FLOAT / GREATEST(abd.total_tweets, 1) * 0.4) +
                (COALESCE(ca.coordinated_hashtag_tweets, 0)::FLOAT / GREATEST(abd.total_tweets, 1) * 0.3) +
                (COALESCE(ca.coordinated_timing_tweets, 0)::FLOAT / GREATEST(abd.total_tweets, 1) * 0.3)
            ) as coordination_risk_score,

            -- Betweenness Centrality (approximated by network bridge behavior)
            LEAST(1.0,
                (abd.unique_reply_targets + abd.unique_retweet_sources)::FLOAT /
                GREATEST(abd.total_tweets, 1) / 2.0
            ) as betweenness_centrality,

            -- Network Reach
            GREATEST(abd.unique_reply_targets, abd.unique_retweet_sources) as network_reach,

            -- Cross-Reference Rate (how often they interact with others)
            CASE WHEN abd.total_tweets > 0
                THEN (abd.replies + abd.retweets + abd.quotes)::FLOAT / abd.total_tweets
                ELSE 0
            END as cross_reference_rate,

            -- Semantic Diversity (approximated by hashtag diversity)
            CASE WHEN abd.total_tweets > 0
                THEN LEAST(1.0, abd.unique_hashtags_used::FLOAT / abd.total_tweets)
                ELSE 0
            END as semantic_diversity_score,

            -- Hashtag Coordination Score
            CASE WHEN abd.unique_hashtags_used > 0 AND abd.total_tweets > 0
                THEN COALESCE(ca.coordinated_hashtags, 0)::FLOAT / abd.unique_hashtags_used
                ELSE 0
            END as hashtag_coordination_score,

            -- Amplification Factor
            CASE WHEN abd.original_tweets > 0
                THEN abd.total_retweets::FLOAT / abd.original_tweets
                ELSE 0
            END as amplification_factor

        FROM author_base_data abd
        LEFT JOIN coordination_analysis ca ON ca.author_id = abd.author_id
    ),

    final_intelligence AS (
        SELECT
            author_id,
            authority_score,
            influence_score,
            coordination_risk_score,
            betweenness_centrality,
            network_reach,
            cross_reference_rate,
            semantic_diversity_score,
            hashtag_coordination_score,
            amplification_factor,

            -- Monitoring Priority Score
            CASE
                WHEN coordination_risk_score > 0.7 THEN 1.0  -- High coordination risk
                WHEN influence_score > 0.8 THEN 0.9          -- High influence
                WHEN amplification_factor > 20 THEN 0.8      -- Strong amplification
                WHEN betweenness_centrality > 0.6 THEN 0.7   -- Network bridge
                ELSE LEAST(1.0, influence_score + (coordination_risk_score * 0.5))
            END as monitoring_priority_score

        FROM intelligence_scores
    )

    SELECT
        p_analysis_date,
        author_id,
        p_analysis_period,
        influence_score,
        authority_score,
        coordination_risk_score,
        betweenness_centrality,
        network_reach,
        cross_reference_rate,
        semantic_diversity_score,
        hashtag_coordination_score,
        monitoring_priority_score,
        amplification_factor
    FROM final_intelligence

    ON CONFLICT (analysis_date, author_id, analysis_period)
    DO UPDATE SET
        influence_score = EXCLUDED.influence_score,
        authority_score = EXCLUDED.authority_score,
        coordination_risk_score = EXCLUDED.coordination_risk_score,
        betweenness_centrality = EXCLUDED.betweenness_centrality,
        network_reach = EXCLUDED.network_reach,
        cross_reference_rate = EXCLUDED.cross_reference_rate,
        semantic_diversity_score = EXCLUDED.semantic_diversity_score,
        hashtag_coordination_score = EXCLUDED.hashtag_coordination_score,
        monitoring_priority_score = EXCLUDED.monitoring_priority_score,
        amplification_factor = EXCLUDED.amplification_factor,
        computed_at = NOW();

    GET DIAGNOSTICS v_metrics_count = ROW_COUNT;

    -- Count unique authors processed
    SELECT COUNT(*) INTO v_authors_processed
    FROM osint.author_intelligence
    WHERE analysis_date = p_analysis_date
      AND analysis_period = p_analysis_period;

    RAISE NOTICE '  - Intelligence metrics: % rows for % authors', v_metrics_count, v_authors_processed;

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
-- DISCOVERY AND ANALYSIS FUNCTIONS
-- ================================================================

-- Get top influencers from intelligence analysis
CREATE OR REPLACE FUNCTION osint.get_top_influencers(
    p_analysis_date DATE DEFAULT CURRENT_DATE - 1,
    p_analysis_period TEXT DEFAULT '7_days',
    p_limit INTEGER DEFAULT 50
)
RETURNS TABLE(
    author_id BIGINT,
    username TEXT,
    influence_score FLOAT,
    authority_score FLOAT,
    coordination_risk FLOAT,
    monitoring_priority FLOAT,
    followers_count INTEGER,
    amplification_factor FLOAT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        ai.author_id,
        COALESCE(tup.username, 'unknown') as username,
        ai.influence_score,
        ai.authority_score,
        ai.coordination_risk_score as coordination_risk,
        ai.monitoring_priority_score as monitoring_priority,
        COALESCE(tup.followers_count, 0) as followers_count,
        ai.amplification_factor
    FROM osint.author_intelligence ai
    LEFT JOIN osint.twitter_user_profiles tup ON tup.user_id = ai.author_id::TEXT
    WHERE ai.analysis_date = p_analysis_date
      AND ai.analysis_period = p_analysis_period
      AND ai.influence_score > 0.4  -- Minimum threshold
    ORDER BY ai.influence_score DESC, ai.monitoring_priority_score DESC
    LIMIT p_limit;
END;
$$;

-- Get coordination risk candidates
CREATE OR REPLACE FUNCTION osint.get_coordination_risks(
    p_analysis_date DATE DEFAULT CURRENT_DATE - 1,
    p_analysis_period TEXT DEFAULT '7_days',
    p_min_risk_score FLOAT DEFAULT 0.5,
    p_limit INTEGER DEFAULT 30
)
RETURNS TABLE(
    author_id BIGINT,
    username TEXT,
    coordination_risk FLOAT,
    hashtag_coordination FLOAT,
    network_reach INTEGER,
    monitoring_priority FLOAT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        ai.author_id,
        COALESCE(tup.username, 'unknown') as username,
        ai.coordination_risk_score as coordination_risk,
        ai.hashtag_coordination_score as hashtag_coordination,
        ai.network_reach,
        ai.monitoring_priority_score as monitoring_priority
    FROM osint.author_intelligence ai
    LEFT JOIN osint.twitter_user_profiles tup ON tup.user_id = ai.author_id::TEXT
    WHERE ai.analysis_date = p_analysis_date
      AND ai.analysis_period = p_analysis_period
      AND ai.coordination_risk_score >= p_min_risk_score
    ORDER BY ai.coordination_risk_score DESC, ai.monitoring_priority_score DESC
    LIMIT p_limit;
END;
$$;

-- Get network bridge accounts (high betweenness centrality)
CREATE OR REPLACE FUNCTION osint.get_network_bridges(
    p_analysis_date DATE DEFAULT CURRENT_DATE - 1,
    p_analysis_period TEXT DEFAULT '7_days',
    p_min_centrality FLOAT DEFAULT 0.4,
    p_limit INTEGER DEFAULT 20
)
RETURNS TABLE(
    author_id BIGINT,
    username TEXT,
    betweenness_centrality FLOAT,
    network_reach INTEGER,
    cross_reference_rate FLOAT,
    influence_score FLOAT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        ai.author_id,
        COALESCE(tup.username, 'unknown') as username,
        ai.betweenness_centrality,
        ai.network_reach,
        ai.cross_reference_rate,
        ai.influence_score
    FROM osint.author_intelligence ai
    LEFT JOIN osint.twitter_user_profiles tup ON tup.user_id = ai.author_id::TEXT
    WHERE ai.analysis_date = p_analysis_date
      AND ai.analysis_period = p_analysis_period
      AND ai.betweenness_centrality >= p_min_centrality
    ORDER BY ai.betweenness_centrality DESC, ai.network_reach DESC
    LIMIT p_limit;
END;
$$;

RAISE NOTICE '============================================================';
RAISE NOTICE 'Author Strategic Intelligence Functions Created';
RAISE NOTICE '============================================================';
RAISE NOTICE 'Core Function:';
RAISE NOTICE '  - osint.compute_author_intelligence(date, period, threshold)';
RAISE NOTICE 'Discovery Functions:';
RAISE NOTICE '  - osint.get_top_influencers(date, period, limit)';
RAISE NOTICE '  - osint.get_coordination_risks(date, period, min_risk, limit)';
RAISE NOTICE '  - osint.get_network_bridges(date, period, min_centrality, limit)';
RAISE NOTICE '============================================================';