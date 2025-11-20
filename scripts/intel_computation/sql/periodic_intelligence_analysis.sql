-- Automated Periodic Intelligence Analysis System
-- Data-driven approach for temporal intelligence tracking
-- Builds intelligence over time periods automatically

-- ================================================================
-- DYNAMIC PERIOD DETECTION
-- ================================================================

CREATE OR REPLACE FUNCTION osint.get_active_analysis_periods(
    p_start_date DATE DEFAULT '2025-08-01',
    p_min_tweets_threshold INTEGER DEFAULT 1000
)
RETURNS TABLE(
    period_type TEXT,
    period_start DATE,
    period_end DATE,
    tweets INTEGER,
    authors INTEGER,
    active_days INTEGER,
    avg_daily_activity NUMERIC
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    -- Monthly periods with significant activity
    SELECT
        'monthly' as period_type,
        DATE_TRUNC('month', created_at)::DATE as period_start,
        (DATE_TRUNC('month', created_at) + INTERVAL '1 month - 1 day')::DATE as period_end,
        COUNT(*)::INTEGER as tweets,
        COUNT(DISTINCT author_id)::INTEGER as authors,
        COUNT(DISTINCT DATE(created_at))::INTEGER as active_days,
        (COUNT(*)::FLOAT / COUNT(DISTINCT DATE(created_at)))::NUMERIC(10,1) as avg_daily_activity
    FROM osint.tweets_deduplicated
    WHERE created_at >= p_start_date
    GROUP BY DATE_TRUNC('month', created_at)
    HAVING COUNT(*) >= p_min_tweets_threshold
    ORDER BY period_start;
END;
$$;

-- ================================================================
-- AUTOMATED PERIODIC INTELLIGENCE COMPUTATION
-- ================================================================

CREATE OR REPLACE FUNCTION osint.compute_periodic_intelligence(
    p_start_date DATE DEFAULT '2025-08-01',
    p_analysis_window INTEGER DEFAULT 7,  -- days for rolling analysis
    p_min_tweet_threshold INTEGER DEFAULT 1
)
RETURNS TABLE(
    period_start DATE,
    period_end DATE,
    analysis_type TEXT,
    metrics_computed BIGINT,
    authors_processed INTEGER,
    computation_time_ms BIGINT,
    status TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_period RECORD;
    v_analysis_date DATE;
    v_result RECORD;
    v_batch_start TIMESTAMP := clock_timestamp();
BEGIN
    RAISE NOTICE '🚀 Starting periodic intelligence analysis from %', p_start_date;
    RAISE NOTICE 'Analysis window: % days, Min threshold: % tweets', p_analysis_window, p_min_tweet_threshold;

    -- Get all active periods
    FOR v_period IN
        SELECT * FROM osint.get_active_analysis_periods(p_start_date, 500)
    LOOP
        RAISE NOTICE '📊 Processing period: % to % (% tweets, % authors)',
                     v_period.period_start, v_period.period_end, v_period.tweets, v_period.authors;

        -- Weekly analyses throughout the period
        v_analysis_date := v_period.period_start + p_analysis_window - 1; -- First analysis date

        WHILE v_analysis_date <= v_period.period_end LOOP
            BEGIN
                -- Run 7-day intelligence analysis
                SELECT * INTO v_result
                FROM osint.compute_author_intelligence(
                    v_analysis_date,
                    p_analysis_window || '_days',
                    p_min_tweet_threshold
                );

                RETURN QUERY SELECT
                    (v_analysis_date - p_analysis_window + 1)::DATE as period_start,
                    v_analysis_date as period_end,
                    (p_analysis_window || '-day analysis')::TEXT as analysis_type,
                    v_result.metrics_computed,
                    v_result.authors_processed,
                    v_result.computation_time_ms,
                    'SUCCESS'::TEXT;

                RAISE NOTICE '   ✅ Week ending %: % authors, %ms',
                             v_analysis_date, v_result.authors_processed, v_result.computation_time_ms;

            EXCEPTION WHEN OTHERS THEN
                RAISE WARNING 'Week ending % failed: %', v_analysis_date, SQLERRM;
                RETURN QUERY SELECT
                    (v_analysis_date - p_analysis_window + 1)::DATE,
                    v_analysis_date,
                    (p_analysis_window || '-day analysis')::TEXT,
                    0::BIGINT,
                    0::INTEGER,
                    0::BIGINT,
                    ('ERROR: ' || SQLERRM)::TEXT;
            END;

            -- Move to next week
            v_analysis_date := v_analysis_date + 7;
        END LOOP;

        -- Monthly summary analysis for the full period
        BEGIN
            SELECT * INTO v_result
            FROM osint.compute_author_intelligence(
                v_period.period_end,
                '30_days',
                p_min_tweet_threshold
            );

            RETURN QUERY SELECT
                v_period.period_start,
                v_period.period_end,
                'Monthly Summary'::TEXT as analysis_type,
                v_result.metrics_computed,
                v_result.authors_processed,
                v_result.computation_time_ms,
                'SUCCESS'::TEXT;

            RAISE NOTICE '   🎯 Monthly summary for %: % authors, %ms',
                         TO_CHAR(v_period.period_start, 'YYYY-MM'), v_result.authors_processed, v_result.computation_time_ms;

        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Monthly summary for % failed: %', TO_CHAR(v_period.period_start, 'YYYY-MM'), SQLERRM;
        END;

    END LOOP;

    DECLARE
        v_total_time BIGINT := EXTRACT(EPOCH FROM (clock_timestamp() - v_batch_start)) * 1000;
    BEGIN
        RAISE NOTICE '✅ Periodic intelligence analysis completed in %ms (%.2f seconds)',
                     v_total_time, v_total_time / 1000.0;

        RETURN QUERY SELECT
            NULL::DATE,
            NULL::DATE,
            'BATCH COMPLETED'::TEXT,
            0::BIGINT,
            0::INTEGER,
            v_total_time,
            'COMPLETED'::TEXT;
    END;
END;
$$;

-- ================================================================
-- TREND ANALYSIS AND COMPARISON FUNCTIONS
-- ================================================================

-- Compare intelligence metrics across time periods
CREATE OR REPLACE FUNCTION osint.get_intelligence_trends(
    p_start_date DATE DEFAULT '2025-08-01',
    p_metric_name TEXT DEFAULT 'influence_score'
)
RETURNS TABLE(
    analysis_period TEXT,
    analysis_date DATE,
    total_authors INTEGER,
    avg_score FLOAT,
    median_score FLOAT,
    top_10_percent_avg FLOAT,
    authors_above_threshold INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH intelligence_data AS (
        SELECT
            ai.analysis_period,
            ai.analysis_date,
            CASE
                WHEN p_metric_name = 'influence_score' THEN ai.influence_score
                WHEN p_metric_name = 'coordination_risk_score' THEN ai.coordination_risk_score
                WHEN p_metric_name = 'authority_score' THEN ai.authority_score
                WHEN p_metric_name = 'monitoring_priority_score' THEN ai.monitoring_priority_score
                ELSE ai.influence_score
            END as metric_value
        FROM osint.author_intelligence ai
        WHERE ai.analysis_date >= p_start_date
          AND ai.analysis_period IN ('7_days', '30_days')
    ),
    period_stats AS (
        SELECT
            analysis_period,
            analysis_date,
            COUNT(*) as total_authors,
            AVG(metric_value) as avg_score,
            PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY metric_value) as median_score,
            AVG(metric_value) FILTER (WHERE metric_value >= (
                SELECT PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY metric_value)
                FROM intelligence_data id2
                WHERE id2.analysis_date = intelligence_data.analysis_date
                  AND id2.analysis_period = intelligence_data.analysis_period
            )) as top_10_percent_avg,
            COUNT(*) FILTER (WHERE metric_value > 0.5) as authors_above_threshold
        FROM intelligence_data
        GROUP BY analysis_period, analysis_date
    )
    SELECT
        ps.analysis_period,
        ps.analysis_date,
        ps.total_authors::INTEGER,
        ps.avg_score::FLOAT,
        ps.median_score::FLOAT,
        ps.top_10_percent_avg::FLOAT,
        ps.authors_above_threshold::INTEGER
    FROM period_stats ps
    ORDER BY ps.analysis_period, ps.analysis_date;
END;
$$;

-- Get top influencers across different time periods
CREATE OR REPLACE FUNCTION osint.get_trending_influencers(
    p_start_date DATE DEFAULT '2025-08-01',
    p_limit INTEGER DEFAULT 20
)
RETURNS TABLE(
    author_id BIGINT,
    username TEXT,
    latest_influence FLOAT,
    latest_monitoring_priority FLOAT,
    trend_direction TEXT,
    appearances_count INTEGER,
    avg_influence FLOAT,
    peak_influence FLOAT,
    latest_analysis_date DATE
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH author_trends AS (
        SELECT
            ai.author_id,
            COUNT(*) as appearances,
            AVG(ai.influence_score) as avg_influence,
            MAX(ai.influence_score) as peak_influence,
            LAG(ai.influence_score) OVER (PARTITION BY ai.author_id ORDER BY ai.analysis_date) as prev_influence,
            LAST_VALUE(ai.influence_score) OVER (
                PARTITION BY ai.author_id
                ORDER BY ai.analysis_date
                ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
            ) as latest_influence,
            LAST_VALUE(ai.monitoring_priority_score) OVER (
                PARTITION BY ai.author_id
                ORDER BY ai.analysis_date
                ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
            ) as latest_priority,
            LAST_VALUE(ai.analysis_date) OVER (
                PARTITION BY ai.author_id
                ORDER BY ai.analysis_date
                ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
            ) as latest_date,
            ROW_NUMBER() OVER (PARTITION BY ai.author_id ORDER BY ai.analysis_date DESC) as rn
        FROM osint.author_intelligence ai
        WHERE ai.analysis_date >= p_start_date
          AND ai.analysis_period = '7_days'  -- Focus on weekly trends
          AND ai.influence_score > 0.1  -- Filter out very low influence
    ),
    top_authors AS (
        SELECT
            author_id,
            appearances,
            avg_influence,
            peak_influence,
            latest_influence,
            latest_priority,
            latest_date,
            CASE
                WHEN latest_influence > avg_influence * 1.2 THEN 'Rising ↗'
                WHEN latest_influence < avg_influence * 0.8 THEN 'Declining ↘'
                ELSE 'Stable →'
            END as trend_direction
        FROM author_trends
        WHERE rn = 1  -- Latest record per author
        ORDER BY latest_influence DESC, latest_priority DESC
        LIMIT p_limit
    )
    SELECT
        ta.author_id,
        COALESCE(tup.username, 'unknown')::TEXT as username,
        ta.latest_influence::FLOAT,
        ta.latest_priority::FLOAT,
        ta.trend_direction::TEXT,
        ta.appearances::INTEGER,
        ta.avg_influence::FLOAT,
        ta.peak_influence::FLOAT,
        ta.latest_date
    FROM top_authors ta
    LEFT JOIN osint.twitter_user_profiles tup ON tup.user_id = ta.author_id::TEXT
    ORDER BY ta.latest_influence DESC;
END;
$$;

-- Monthly intelligence summary comparison
CREATE OR REPLACE FUNCTION osint.get_monthly_intelligence_summary()
RETURNS TABLE(
    month_year TEXT,
    total_analyses INTEGER,
    unique_authors INTEGER,
    avg_influence_score FLOAT,
    high_influence_count INTEGER,
    coordination_risks INTEGER,
    new_influencers INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH monthly_data AS (
        SELECT
            TO_CHAR(analysis_date, 'YYYY-MM') as month_year,
            COUNT(*) as analyses,
            COUNT(DISTINCT author_id) as authors,
            AVG(influence_score) as avg_influence,
            COUNT(*) FILTER (WHERE influence_score > 0.7) as high_influence,
            COUNT(*) FILTER (WHERE coordination_risk_score > 0.5) as coordination_risks
        FROM osint.author_intelligence
        WHERE analysis_period = '7_days'
        GROUP BY TO_CHAR(analysis_date, 'YYYY-MM')
    ),
    previous_authors AS (
        SELECT
            TO_CHAR(analysis_date, 'YYYY-MM') as month_year,
            author_id,
            MIN(analysis_date) as first_seen
        FROM osint.author_intelligence
        WHERE analysis_period = '7_days'
        GROUP BY TO_CHAR(analysis_date, 'YYYY-MM'), author_id
    ),
    new_author_counts AS (
        SELECT
            month_year,
            COUNT(*) FILTER (WHERE first_seen = (
                SELECT MIN(analysis_date)
                FROM osint.author_intelligence ai2
                WHERE TO_CHAR(ai2.analysis_date, 'YYYY-MM') = previous_authors.month_year
            )) as new_influencers
        FROM previous_authors
        GROUP BY month_year
    )
    SELECT
        md.month_year::TEXT,
        md.analyses::INTEGER,
        md.authors::INTEGER,
        md.avg_influence::FLOAT,
        md.high_influence::INTEGER,
        md.coordination_risks::INTEGER,
        COALESCE(nac.new_influencers, 0)::INTEGER
    FROM monthly_data md
    LEFT JOIN new_author_counts nac ON nac.month_year = md.month_year
    ORDER BY md.month_year;
END;
$$;

RAISE NOTICE '============================================================';
RAISE NOTICE 'Periodic Intelligence Analysis System Created';
RAISE NOTICE '============================================================';
RAISE NOTICE 'Data Discovery:';
RAISE NOTICE '  - osint.get_active_analysis_periods() - Find active periods';
RAISE NOTICE 'Automated Analysis:';
RAISE NOTICE '  - osint.compute_periodic_intelligence() - Batch processing';
RAISE NOTICE 'Trend Analysis:';
RAISE NOTICE '  - osint.get_intelligence_trends() - Metric trends over time';
RAISE NOTICE '  - osint.get_trending_influencers() - Top influencer trends';
RAISE NOTICE '  - osint.get_monthly_intelligence_summary() - Monthly comparison';
RAISE NOTICE '============================================================';