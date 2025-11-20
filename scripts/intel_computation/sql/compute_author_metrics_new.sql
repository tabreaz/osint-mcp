-- New Author Metrics Computation Wrapper
-- Multi-Tier Architecture replacing the old 46-metric approach
-- Combines fast daily tracking with strategic intelligence analysis

CREATE OR REPLACE FUNCTION osint.compute_author_metrics_new(
    p_target_date DATE DEFAULT CURRENT_DATE - 1,
    p_enable_intelligence BOOLEAN DEFAULT TRUE,
    p_intelligence_period TEXT DEFAULT '7_days',
    p_min_tweet_threshold INTEGER DEFAULT 5
)
RETURNS TABLE(
    phase TEXT,
    metrics_computed BIGINT,
    authors_processed INTEGER,
    computation_time_ms BIGINT,
    status TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_start_time TIMESTAMP := clock_timestamp();
    v_total_metrics BIGINT := 0;
    v_total_authors INTEGER := 0;
    v_phase_start TIMESTAMP;
    v_result RECORD;
BEGIN
    RAISE NOTICE '🚀 Starting new author metrics computation for % (Intelligence: %)',
                 p_target_date, p_enable_intelligence;

    -- ================================================================
    -- PHASE 1: Daily Metrics (Fast Essential Tracking)
    -- ================================================================
    v_phase_start := clock_timestamp();
    RAISE NOTICE '📊 Phase 1: Computing daily essential metrics...';

    BEGIN
        SELECT * INTO v_result
        FROM osint.compute_author_daily_simple(p_target_date);

        v_total_metrics := v_total_metrics + v_result.metrics_computed;
        v_total_authors := GREATEST(v_total_authors, v_result.authors_processed);

        RETURN QUERY SELECT
            'Daily Metrics'::TEXT,
            v_result.metrics_computed,
            v_result.authors_processed,
            v_result.computation_time_ms,
            'SUCCESS'::TEXT;

    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'Phase 1 failed: %', SQLERRM;
        RETURN QUERY SELECT
            'Daily Metrics'::TEXT,
            0::BIGINT,
            0::INTEGER,
            EXTRACT(EPOCH FROM (clock_timestamp() - v_phase_start))::BIGINT * 1000,
            ('ERROR: ' || SQLERRM)::TEXT;
    END;

    -- ================================================================
    -- PHASE 2: Strategic Intelligence (Optional)
    -- ================================================================
    IF p_enable_intelligence THEN
        v_phase_start := clock_timestamp();
        RAISE NOTICE '🧠 Phase 2: Computing strategic intelligence (%)...', p_intelligence_period;

        BEGIN
            SELECT * INTO v_result
            FROM osint.compute_author_intelligence(
                p_target_date,
                p_intelligence_period,
                p_min_tweet_threshold
            );

            v_total_metrics := v_total_metrics + v_result.metrics_computed;

            RETURN QUERY SELECT
                'Strategic Intelligence'::TEXT,
                v_result.metrics_computed,
                v_result.authors_processed,
                v_result.computation_time_ms,
                'SUCCESS'::TEXT;

        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Phase 2 failed: %', SQLERRM;
            RETURN QUERY SELECT
                'Strategic Intelligence'::TEXT,
                0::BIGINT,
                0::INTEGER,
                EXTRACT(EPOCH FROM (clock_timestamp() - v_phase_start))::BIGINT * 1000,
                ('ERROR: ' || SQLERRM)::TEXT;
        END;
    ELSE
        RETURN QUERY SELECT
            'Strategic Intelligence'::TEXT,
            0::BIGINT,
            0::INTEGER,
            0::BIGINT,
            'SKIPPED'::TEXT;
    END IF;

    -- ================================================================
    -- COMPLETION SUMMARY
    -- ================================================================
    DECLARE
        v_total_time_ms BIGINT := EXTRACT(EPOCH FROM (clock_timestamp() - v_start_time)) * 1000;
    BEGIN
        RAISE NOTICE '✅ New author metrics computation completed!';
        RAISE NOTICE '   📈 Total metrics computed: %', v_total_metrics;
        RAISE NOTICE '   👥 Authors processed: %', v_total_authors;
        RAISE NOTICE '   ⏱️ Total time: %ms (%.2fs)', v_total_time_ms, v_total_time_ms / 1000.0;

        RETURN QUERY SELECT
            'TOTAL SUMMARY'::TEXT,
            v_total_metrics,
            v_total_authors,
            v_total_time_ms,
            'COMPLETED'::TEXT;
    END;
END;
$$;

-- ================================================================
-- BATCH PROCESSING FOR HISTORICAL DATA
-- ================================================================

CREATE OR REPLACE FUNCTION osint.compute_author_metrics_batch(
    p_start_date DATE,
    p_end_date DATE DEFAULT CURRENT_DATE - 1,
    p_daily_only BOOLEAN DEFAULT FALSE,
    p_intelligence_frequency INTEGER DEFAULT 7  -- Run intelligence every N days
)
RETURNS TABLE(
    date DATE,
    phase TEXT,
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
    v_batch_start TIMESTAMP := clock_timestamp();
    v_should_run_intelligence BOOLEAN;
BEGIN
    RAISE NOTICE '🚀 Starting batch author metrics computation from % to %', p_start_date, p_end_date;
    RAISE NOTICE 'Mode: % | Intelligence frequency: every % days',
                 CASE WHEN p_daily_only THEN 'Daily Only' ELSE 'Daily + Intelligence' END,
                 p_intelligence_frequency;

    WHILE v_current_date <= p_end_date LOOP
        -- Determine if we should run intelligence for this date
        v_should_run_intelligence := NOT p_daily_only AND
                                   (EXTRACT(DOY FROM v_current_date)::INTEGER % p_intelligence_frequency = 0);

        RAISE NOTICE 'Processing date: % (Intelligence: %)', v_current_date, v_should_run_intelligence;

        -- Process this date
        FOR v_result IN
            SELECT * FROM osint.compute_author_metrics_new(
                v_current_date,
                v_should_run_intelligence,
                '7_days',
                3  -- Lower threshold for batch processing
            )
        LOOP
            RETURN QUERY SELECT
                v_current_date,
                v_result.phase,
                v_result.metrics_computed,
                v_result.authors_processed,
                v_result.computation_time_ms,
                v_result.status;
        END LOOP;

        v_current_date := v_current_date + 1;
    END LOOP;

    DECLARE
        v_batch_time BIGINT := EXTRACT(EPOCH FROM (clock_timestamp() - v_batch_start)) * 1000;
    BEGIN
        RAISE NOTICE '✅ Batch processing completed in %ms (%.2f seconds)',
                     v_batch_time, v_batch_time / 1000.0;

        RETURN QUERY SELECT
            NULL::DATE,
            'BATCH_COMPLETED'::TEXT,
            0::BIGINT,
            0::INTEGER,
            v_batch_time,
            'COMPLETED'::TEXT;
    END;
END;
$$;

-- ================================================================
-- DAILY PROCEDURE FOR AUTOMATION
-- ================================================================

CREATE OR REPLACE PROCEDURE osint.compute_daily_author_metrics_new(
    p_target_date DATE DEFAULT CURRENT_DATE - 1,
    p_enable_intelligence BOOLEAN DEFAULT TRUE
)
LANGUAGE plpgsql
AS $$
DECLARE
    result_record RECORD;
    error_count INTEGER := 0;
BEGIN
    RAISE NOTICE '🌅 Starting new daily author metrics computation for %', p_target_date;

    -- Execute new multi-tier metrics for the target date
    FOR result_record IN
        SELECT * FROM osint.compute_author_metrics_new(
            p_target_date, p_enable_intelligence, '7_days', 5
        )
    LOOP
        IF result_record.status LIKE 'ERROR:%' THEN
            error_count := error_count + 1;
            RAISE WARNING 'Phase % failed: %', result_record.phase, result_record.status;
        ELSE
            RAISE NOTICE '✅ %: % metrics, % authors, %ms - %',
                result_record.phase,
                result_record.metrics_computed,
                result_record.authors_processed,
                result_record.computation_time_ms,
                result_record.status;
        END IF;
    END LOOP;

    IF error_count > 0 THEN
        RAISE EXCEPTION 'Daily author metrics computation completed with % errors', error_count;
    ELSE
        RAISE NOTICE '🎉 Daily author metrics computation completed successfully!';
    END IF;
END;
$$;

-- ================================================================
-- UNIFIED DISCOVERY FUNCTIONS (combining both daily and intelligence data)
-- ================================================================

CREATE OR REPLACE FUNCTION osint.get_author_intelligence_summary(
    p_target_date DATE DEFAULT CURRENT_DATE - 1,
    p_analysis_period TEXT DEFAULT '7_days',
    p_limit INTEGER DEFAULT 50
)
RETURNS TABLE(
    author_id BIGINT,
    username TEXT,
    -- Daily metrics
    daily_tweets INTEGER,
    total_engagement BIGINT,
    viral_tweets INTEGER,
    cross_themes INTEGER,
    -- Intelligence metrics
    influence_score FLOAT,
    coordination_risk FLOAT,
    monitoring_priority FLOAT,
    authority_score FLOAT,
    -- User profile
    followers_count INTEGER,
    verified BOOLEAN
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(adm.author_id, ai.author_id) as author_id,
        COALESCE(tup.username, 'unknown') as username,

        -- Daily metrics from author_daily_metrics
        COALESCE(adm.daily_tweets, 0) as daily_tweets,
        COALESCE(adm.total_engagement_received, 0) as total_engagement,
        COALESCE(adm.viral_tweets_count, 0) as viral_tweets,
        COALESCE(adm.cross_theme_activity, 0) as cross_themes,

        -- Intelligence metrics from author_intelligence
        COALESCE(ai.influence_score, 0.0) as influence_score,
        COALESCE(ai.coordination_risk_score, 0.0) as coordination_risk,
        COALESCE(ai.monitoring_priority_score, 0.0) as monitoring_priority,
        COALESCE(ai.authority_score, 0.0) as authority_score,

        -- User profile data
        COALESCE(tup.followers_count, 0) as followers_count,
        COALESCE(tup.verified, false) as verified

    FROM osint.author_daily_metrics adm
    FULL OUTER JOIN osint.author_intelligence ai ON
        ai.author_id = adm.author_id
        AND ai.analysis_date = p_target_date
        AND ai.analysis_period = p_analysis_period
    LEFT JOIN osint.twitter_user_profiles tup ON
        tup.user_id = COALESCE(adm.author_id, ai.author_id)::TEXT

    WHERE (adm.date = p_target_date OR adm.date IS NULL)
      AND (ai.analysis_date = p_target_date OR ai.analysis_date IS NULL)
      AND (
          COALESCE(adm.daily_tweets, 0) > 0 OR
          COALESCE(ai.influence_score, 0) > 0.3
      )

    ORDER BY
        COALESCE(ai.monitoring_priority_score, 0) DESC,
        COALESCE(ai.influence_score, 0) DESC,
        COALESCE(adm.daily_tweets, 0) DESC
    LIMIT p_limit;
END;
$$;

-- Get performance comparison between old and new systems
CREATE OR REPLACE FUNCTION osint.compare_metrics_performance()
RETURNS TABLE(
    metric_system TEXT,
    table_name TEXT,
    total_rows BIGINT,
    unique_authors INTEGER,
    date_coverage TEXT,
    storage_efficiency TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    -- Old system (intel_metrics for authors - should be 0 now)
    SELECT
        'Old System (intel_metrics)' as metric_system,
        'intel_metrics' as table_name,
        COUNT(*)::BIGINT as total_rows,
        COUNT(DISTINCT entity_id)::INTEGER as unique_authors,
        COALESCE(MIN(DATE(time))::TEXT || ' to ' || MAX(DATE(time))::TEXT, 'No data') as date_coverage,
        'Heavy (46 metrics/author/day)' as storage_efficiency
    FROM osint.intel_metrics
    WHERE entity_type = 'author'

    UNION ALL

    -- New system - Daily metrics
    SELECT
        'New System (Daily)' as metric_system,
        'author_daily_metrics' as table_name,
        COUNT(*)::BIGINT as total_rows,
        COUNT(DISTINCT author_id)::INTEGER as unique_authors,
        COALESCE(MIN(date)::TEXT || ' to ' || MAX(date)::TEXT, 'No data') as date_coverage,
        'Efficient (12 metrics/author/day)' as storage_efficiency
    FROM osint.author_daily_metrics

    UNION ALL

    -- New system - Intelligence metrics
    SELECT
        'New System (Intelligence)' as metric_system,
        'author_intelligence' as table_name,
        COUNT(*)::BIGINT as total_rows,
        COUNT(DISTINCT author_id)::INTEGER as unique_authors,
        COALESCE(MIN(analysis_date)::TEXT || ' to ' || MAX(analysis_date)::TEXT, 'No data') as date_coverage,
        'Strategic (10 metrics/author/period)' as storage_efficiency
    FROM osint.author_intelligence;
END;
$$;

RAISE NOTICE '============================================================';
RAISE NOTICE 'New Author Metrics System Created Successfully';
RAISE NOTICE '============================================================';
RAISE NOTICE 'Core Functions:';
RAISE NOTICE '  - osint.compute_author_metrics_new() - Main wrapper';
RAISE NOTICE '  - osint.compute_author_metrics_batch() - Historical processing';
RAISE NOTICE '  - osint.compute_daily_author_metrics_new() - Daily automation';
RAISE NOTICE 'Discovery Functions:';
RAISE NOTICE '  - osint.get_author_intelligence_summary() - Combined view';
RAISE NOTICE '  - osint.compare_metrics_performance() - System comparison';
RAISE NOTICE '============================================================';
RAISE NOTICE 'Architecture:';
RAISE NOTICE '  OLD: 46 metrics/author/day → intel_metrics table';
RAISE NOTICE '  NEW: 12 daily + 10 strategic → dedicated tables';
RAISE NOTICE '============================================================';