-- All Author Metrics Computation Wrapper
-- Executes all author-level intelligence metrics in optimized sequence
-- Part of OSINT intelligence discovery and monitoring validation system

CREATE OR REPLACE FUNCTION osint.compute_all_author_metrics(
    p_target_date DATE DEFAULT CURRENT_DATE - 1,
    p_days_back INTEGER DEFAULT 1,
    p_enable_semantic BOOLEAN DEFAULT TRUE,
    p_enable_media BOOLEAN DEFAULT TRUE
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
    RAISE NOTICE '🚀 Starting comprehensive author metrics computation for % (% days back)', p_target_date, p_days_back;
    RAISE NOTICE 'Options: Semantic Analysis = %, Media Analysis = %', p_enable_semantic, p_enable_media;

    -- ================================================================
    -- PHASE 1: Core Activity Metrics
    -- ================================================================
    v_phase_start := clock_timestamp();
    RAISE NOTICE '📊 Phase 1: Computing core activity metrics...';

    BEGIN
        SELECT * INTO v_result
        FROM osint.compute_author_activity_metrics(p_target_date, p_days_back);

        v_total_metrics := v_total_metrics + v_result.metrics_computed;
        v_total_authors := GREATEST(v_total_authors, v_result.authors_processed);

        RETURN QUERY SELECT
            'Activity Metrics'::TEXT,
            v_result.metrics_computed,
            v_result.authors_processed,
            v_result.computation_time_ms,
            'SUCCESS'::TEXT;

    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'Phase 1 failed: %', SQLERRM;
        RETURN QUERY SELECT
            'Activity Metrics'::TEXT,
            0::BIGINT,
            0::INTEGER,
            EXTRACT(EPOCH FROM (clock_timestamp() - v_phase_start))::BIGINT * 1000,
            ('ERROR: ' || SQLERRM)::TEXT;
    END;

    -- ================================================================
    -- PHASE 2: Coordination Detection
    -- ================================================================
    v_phase_start := clock_timestamp();
    RAISE NOTICE '🕵️ Phase 2: Computing coordination detection metrics...';

    BEGIN
        SELECT * INTO v_result
        FROM osint.compute_author_coordination_metrics(p_target_date, p_days_back);

        v_total_metrics := v_total_metrics + v_result.metrics_computed;

        RETURN QUERY SELECT
            'Coordination Detection'::TEXT,
            v_result.metrics_computed,
            v_result.authors_processed,
            v_result.computation_time_ms,
            'SUCCESS'::TEXT;

    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'Phase 2 failed: %', SQLERRM;
        RETURN QUERY SELECT
            'Coordination Detection'::TEXT,
            0::BIGINT,
            0::INTEGER,
            EXTRACT(EPOCH FROM (clock_timestamp() - v_phase_start))::BIGINT * 1000,
            ('ERROR: ' || SQLERRM)::TEXT;
    END;

    -- ================================================================
    -- PHASE 3: Influence Scoring
    -- ================================================================
    v_phase_start := clock_timestamp();
    RAISE NOTICE '⭐ Phase 3: Computing influence scoring metrics...';

    BEGIN
        SELECT * INTO v_result
        FROM osint.compute_author_influence_metrics(p_target_date, p_days_back);

        v_total_metrics := v_total_metrics + v_result.metrics_computed;

        RETURN QUERY SELECT
            'Influence Scoring'::TEXT,
            v_result.metrics_computed,
            v_result.authors_processed,
            v_result.computation_time_ms,
            'SUCCESS'::TEXT;

    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'Phase 3 failed: %', SQLERRM;
        RETURN QUERY SELECT
            'Influence Scoring'::TEXT,
            0::BIGINT,
            0::INTEGER,
            EXTRACT(EPOCH FROM (clock_timestamp() - v_phase_start))::BIGINT * 1000,
            ('ERROR: ' || SQLERRM)::TEXT;
    END;

    -- ================================================================
    -- PHASE 4: Semantic Analysis (Optional)
    -- ================================================================
    IF p_enable_semantic THEN
        v_phase_start := clock_timestamp();
        RAISE NOTICE '🧠 Phase 4: Computing semantic intelligence metrics...';

        BEGIN
            SELECT * INTO v_result
            FROM osint.compute_author_semantic_metrics(p_target_date, p_days_back);

            v_total_metrics := v_total_metrics + v_result.metrics_computed;

            RETURN QUERY SELECT
                'Semantic Analysis'::TEXT,
                v_result.metrics_computed,
                v_result.authors_processed,
                v_result.computation_time_ms,
                'SUCCESS'::TEXT;

        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Phase 4 failed: %', SQLERRM;
            RETURN QUERY SELECT
                'Semantic Analysis'::TEXT,
                0::BIGINT,
                0::INTEGER,
                EXTRACT(EPOCH FROM (clock_timestamp() - v_phase_start))::BIGINT * 1000,
                ('ERROR: ' || SQLERRM)::TEXT;
        END;
    ELSE
        RETURN QUERY SELECT
            'Semantic Analysis'::TEXT,
            0::BIGINT,
            0::INTEGER,
            0::BIGINT,
            'SKIPPED'::TEXT;
    END IF;

    -- ================================================================
    -- PHASE 5: Media Intelligence (Optional)
    -- ================================================================
    IF p_enable_media THEN
        v_phase_start := clock_timestamp();
        RAISE NOTICE '🖼️ Phase 5: Computing media intelligence metrics...';

        BEGIN
            SELECT * INTO v_result
            FROM osint.compute_author_media_metrics(p_target_date, p_days_back);

            v_total_metrics := v_total_metrics + v_result.metrics_computed;

            RETURN QUERY SELECT
                'Media Analysis'::TEXT,
                v_result.metrics_computed,
                v_result.authors_processed,
                v_result.computation_time_ms,
                'SUCCESS'::TEXT;

        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Phase 5 failed: %', SQLERRM;
            RETURN QUERY SELECT
                'Media Analysis'::TEXT,
                0::BIGINT,
                0::INTEGER,
                EXTRACT(EPOCH FROM (clock_timestamp() - v_phase_start))::BIGINT * 1000,
                ('ERROR: ' || SQLERRM)::TEXT;
        END;
    ELSE
        RETURN QUERY SELECT
            'Media Analysis'::TEXT,
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
        RAISE NOTICE '✅ Author metrics computation completed!';
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

-- Create a simplified procedure wrapper for daily execution
CREATE OR REPLACE PROCEDURE osint.compute_daily_author_metrics(
    p_target_date DATE DEFAULT CURRENT_DATE - 1,
    p_enable_semantic BOOLEAN DEFAULT TRUE,
    p_enable_media BOOLEAN DEFAULT TRUE
)
LANGUAGE plpgsql
AS $$
DECLARE
    result_record RECORD;
    error_count INTEGER := 0;
BEGIN
    RAISE NOTICE '🌅 Starting daily author metrics computation for %', p_target_date;

    -- Execute all author metrics for the target date
    FOR result_record IN
        SELECT * FROM osint.compute_all_author_metrics(
            p_target_date, 1, p_enable_semantic, p_enable_media
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

-- Create discovery query functions for immediate intelligence gathering
CREATE OR REPLACE FUNCTION osint.get_top_unmonitored_influencers(
    p_limit INTEGER DEFAULT 50,
    p_min_influence_score FLOAT DEFAULT 0.6
)
RETURNS TABLE(
    author_id BIGINT,
    username VARCHAR(255),
    influence_score FLOAT,
    monitoring_priority_score FLOAT,
    daily_tweets INTEGER,
    total_engagement BIGINT,
    cross_theme_activity INTEGER,
    coordination_risk FLOAT,
    follower_count INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        im_influence.entity_id as author_id,
        tup.username,
        im_influence.value_float as influence_score,
        im_priority.value_float as monitoring_priority_score,
        im_tweets.value_int as daily_tweets,
        im_engagement.value_int as total_engagement,
        COALESCE(im_themes.value_int, 0) as cross_theme_activity,
        COALESCE(im_coord.value_float, 0.0) as coordination_risk,
        tup.followers_count as follower_count

    FROM osint.intel_metrics im_influence
    JOIN osint.twitter_user_profiles tup ON tup.user_id = im_influence.entity_id::text
    LEFT JOIN osint.intel_metrics im_priority ON
        im_priority.entity_id = im_influence.entity_id
        AND im_priority.entity_type = 'author'
        AND im_priority.metric_name = 'monitoring_priority_score'
        AND DATE(im_priority.time) = DATE(im_influence.time)
    LEFT JOIN osint.intel_metrics im_tweets ON
        im_tweets.entity_id = im_influence.entity_id
        AND im_tweets.entity_type = 'author'
        AND im_tweets.metric_name = 'daily_tweets'
        AND DATE(im_tweets.time) = DATE(im_influence.time)
    LEFT JOIN osint.intel_metrics im_engagement ON
        im_engagement.entity_id = im_influence.entity_id
        AND im_engagement.entity_type = 'author'
        AND im_engagement.metric_name = 'total_engagement_received'
        AND DATE(im_engagement.time) = DATE(im_influence.time)
    LEFT JOIN osint.intel_metrics im_themes ON
        im_themes.entity_id = im_influence.entity_id
        AND im_themes.entity_type = 'author'
        AND im_themes.metric_name = 'cross_theme_activity'
        AND DATE(im_themes.time) = DATE(im_influence.time)
    LEFT JOIN osint.intel_metrics im_coord ON
        im_coord.entity_id = im_influence.entity_id
        AND im_coord.entity_type = 'author'
        AND im_coord.metric_name = 'coordination_risk_score'
        AND DATE(im_coord.time) = DATE(im_influence.time)

    WHERE im_influence.entity_type = 'author'
      AND im_influence.metric_name = 'influence_score'
      AND im_influence.value_float >= p_min_influence_score
      AND im_influence.entity_id::text NOT IN (
          SELECT user_id FROM osint.monitored_users
      )
      AND DATE(im_influence.time) >= CURRENT_DATE - 7  -- Recent data only

    ORDER BY im_influence.value_float DESC, im_priority.value_float DESC
    LIMIT p_limit;
END;
$$;