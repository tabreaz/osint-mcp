-- Author Media Intelligence Metrics
-- Visual coordination detection and media usage patterns
-- Image recycling, media type analysis, and visual authenticity assessment

CREATE OR REPLACE FUNCTION osint.compute_author_media_metrics(
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
    RAISE NOTICE 'Computing author media metrics from % to %', v_date_start, v_date_end;

    -- ================================================================
    -- MEDIA INTELLIGENCE METRICS
    -- ================================================================

    WITH author_media_analysis AS (
        SELECT
            DATE(t.created_at) as metric_date,
            t.author_id,

            -- Basic Media Statistics
            COUNT(tm.media_url) as total_media_items,
            COUNT(*) as total_tweets,
            COUNT(DISTINCT tm.media_url) as unique_media_items,

            -- Media Type Distribution
            COUNT(tm.media_url) FILTER (WHERE tm.media_type = 'photo') as photo_count,
            COUNT(tm.media_url) FILTER (WHERE tm.media_type = 'video') as video_count,
            COUNT(tm.media_url) FILTER (WHERE tm.media_type = 'gif') as gif_count,
            COUNT(tm.media_url) FILTER (WHERE tm.media_type = 'other') as other_media_count,

            -- Media Hash Analysis for Duplicate Detection
            COUNT(DISTINCT tm.media_hash) as unique_media_hashes,
            COUNT(tm.media_hash) FILTER (WHERE tm.media_hash IS NOT NULL) as hashed_media_count,

            -- Recycled Media Detection
            -- Count media items that appear multiple times
            SUM(
                CASE WHEN recycled_media.reuse_count > 1 THEN 1 ELSE 0 END
            ) as recycled_media_count,

            -- External Coordination via Shared Media
            -- Media shared with other authors
            COUNT(DISTINCT
                CASE WHEN shared_media.shared_count >= 2 THEN tm.media_url ELSE NULL END
            ) as coordinated_media_count,

            -- Media Quality Indicators
            COUNT(tm.media_url) FILTER (WHERE tm.width >= 1200 OR tm.height >= 1200) as high_quality_media_count,

            -- Suspicious Media Patterns
            COUNT(DISTINCT tm.media_hash) FILTER (WHERE suspicious_hashes.hash_reuse_count >= 5) as suspicious_hash_count

        FROM osint.tweets_deduplicated t
        LEFT JOIN osint.tweet_media tm ON tm.tweet_id = t.tweet_id

        -- Recycled Media Analysis (author reusing own media)
        LEFT JOIN (
            SELECT
                tm2.media_url,
                tm2.media_hash,
                COUNT(*) as reuse_count
            FROM osint.tweet_media tm2
            JOIN osint.tweets_deduplicated t2 ON tm2.tweet_id = t2.tweet_id
            WHERE DATE(t2.created_at) BETWEEN v_date_start AND v_date_end
            GROUP BY tm2.media_url, tm2.media_hash, t2.author_id
            HAVING COUNT(*) > 1
        ) recycled_media ON recycled_media.media_url = tm.media_url

        -- Shared Media Analysis (coordination between authors)
        LEFT JOIN (
            SELECT
                tm3.media_url,
                tm3.media_hash,
                COUNT(DISTINCT t3.author_id) as shared_count
            FROM osint.tweet_media tm3
            JOIN osint.tweets_deduplicated t3 ON tm3.tweet_id = t3.tweet_id
            WHERE DATE(t3.created_at) BETWEEN v_date_start AND v_date_end
            GROUP BY tm3.media_url, tm3.media_hash
            HAVING COUNT(DISTINCT t3.author_id) >= 2
        ) shared_media ON shared_media.media_url = tm.media_url

        -- Suspicious Hash Analysis (widely recycled content)
        LEFT JOIN (
            SELECT
                tm4.media_hash,
                COUNT(DISTINCT t4.author_id) as hash_reuse_count
            FROM osint.tweet_media tm4
            JOIN osint.tweets_deduplicated t4 ON tm4.tweet_id = t4.tweet_id
            WHERE DATE(t4.created_at) BETWEEN v_date_start AND v_date_end
              AND tm4.media_hash IS NOT NULL
            GROUP BY tm4.media_hash
            HAVING COUNT(DISTINCT t4.author_id) >= 5
        ) suspicious_hashes ON suspicious_hashes.media_hash = tm.media_hash

        WHERE DATE(t.created_at) BETWEEN v_date_start AND v_date_end
          AND t.author_id IS NOT NULL
        GROUP BY DATE(t.created_at), t.author_id
    ),

    -- Calculate media intelligence scores
    media_intelligence AS (
        SELECT
            *,
            -- Media Usage Rate (tweets with media / total tweets)
            CASE
                WHEN total_tweets > 0
                THEN total_media_items::FLOAT / total_tweets
                ELSE 0
            END as media_usage_rate,

            -- Unique Media Ratio (original vs reused content)
            CASE
                WHEN total_media_items > 0
                THEN unique_media_items::FLOAT / total_media_items
                ELSE 1.0  -- No media = perfect uniqueness
            END as unique_media_ratio,

            -- Media Hash Coverage (% of media with hash analysis)
            CASE
                WHEN total_media_items > 0
                THEN hashed_media_count::FLOAT / total_media_items
                ELSE 0
            END as hash_coverage_ratio,

            -- Image Recycling Score (tendency to reuse content)
            CASE
                WHEN total_media_items > 0
                THEN recycled_media_count::FLOAT / total_media_items
                ELSE 0
            END as image_recycling_score,

            -- Visual Coordination Risk (shared media with others)
            CASE
                WHEN unique_media_items > 0
                THEN coordinated_media_count::FLOAT / unique_media_items
                ELSE 0
            END as visual_coordination_risk,

            -- Media Type Diversity (Shannon entropy-like measure)
            CASE
                WHEN total_media_items > 0 THEN
                    GREATEST(0, 1.0 - (
                        CASE WHEN photo_count > 0 THEN (photo_count::FLOAT / total_media_items) * LOG(2, photo_count::FLOAT / total_media_items) ELSE 0 END +
                        CASE WHEN video_count > 0 THEN (video_count::FLOAT / total_media_items) * LOG(2, video_count::FLOAT / total_media_items) ELSE 0 END +
                        CASE WHEN gif_count > 0 THEN (gif_count::FLOAT / total_media_items) * LOG(2, gif_count::FLOAT / total_media_items) ELSE 0 END +
                        CASE WHEN other_media_count > 0 THEN (other_media_count::FLOAT / total_media_items) * LOG(2, other_media_count::FLOAT / total_media_items) ELSE 0 END
                    ) / LOG(2, 4))  -- Normalize by max entropy for 4 categories
                ELSE 0
            END as media_type_diversity,

            -- High Quality Media Ratio
            CASE
                WHEN total_media_items > 0
                THEN high_quality_media_count::FLOAT / total_media_items
                ELSE 0
            END as high_quality_media_ratio,

            -- Suspicious Media Score
            CASE
                WHEN unique_media_hashes > 0
                THEN suspicious_hash_count::FLOAT / unique_media_hashes
                ELSE 0
            END as suspicious_media_score,

            -- Media Authenticity Score
            -- High uniqueness + low recycling + low coordination = authentic
            LEAST(1.0,
                (unique_media_ratio * 0.4) +
                ((1.0 - image_recycling_score) * 0.3) +
                ((1.0 - visual_coordination_risk) * 0.3)
            ) as media_authenticity_score,

            -- Media Propaganda Risk Score
            -- High recycling + high coordination + suspicious patterns = propaganda
            LEAST(1.0,
                (image_recycling_score * 0.3) +
                (visual_coordination_risk * 0.4) +
                (suspicious_media_score * 0.3)
            ) as media_propaganda_risk

        FROM author_media_analysis
    ),

    -- Pivot media metrics for storage
    media_metrics_pivot AS (
        SELECT
            metric_date,
            author_id,
            metric_name,
            value_int,
            value_float,
            unit
        FROM media_intelligence,
        LATERAL (VALUES
            ('total_media_items', total_media_items, NULL, 'count'),
            ('unique_media_items', unique_media_items, NULL, 'count'),
            ('photo_count', photo_count, NULL, 'count'),
            ('video_count', video_count, NULL, 'count'),
            ('gif_count', gif_count, NULL, 'count'),
            ('recycled_media_count', recycled_media_count, NULL, 'count'),
            ('coordinated_media_count', coordinated_media_count, NULL, 'count'),
            ('high_quality_media_count', high_quality_media_count, NULL, 'count'),
            ('suspicious_hash_count', suspicious_hash_count, NULL, 'count'),
            ('media_usage_rate', NULL, media_usage_rate, 'percentage'),
            ('unique_media_ratio', NULL, unique_media_ratio, 'percentage'),
            ('hash_coverage_ratio', NULL, hash_coverage_ratio, 'percentage'),
            ('image_recycling_score', NULL, image_recycling_score, 'score'),
            ('visual_coordination_risk', NULL, visual_coordination_risk, 'score'),
            ('media_type_diversity', NULL, media_type_diversity, 'score'),
            ('high_quality_media_ratio', NULL, high_quality_media_ratio, 'percentage'),
            ('suspicious_media_score', NULL, suspicious_media_score, 'score'),
            ('media_authenticity_score', NULL, media_authenticity_score, 'score'),
            ('media_propaganda_risk', NULL, media_propaganda_risk, 'score')
        ) AS unpivoted(metric_name, value_int, value_float, unit)
    )

    -- Insert media metrics with UPSERT
    INSERT INTO osint.intel_metrics (time, metric_name, entity_type, entity_id, value_int, value_float, unit)
    SELECT
        metric_date::timestamptz,
        metric_name,
        'author',
        author_id,
        value_int,
        value_float,
        unit
    FROM media_metrics_pivot
    ON CONFLICT (time, metric_name, entity_type, entity_id)
    DO UPDATE SET
        value_int = EXCLUDED.value_int,
        value_float = EXCLUDED.value_float,
        unit = EXCLUDED.unit,
        computed_at = NOW();

    GET DIAGNOSTICS v_metrics_count = ROW_COUNT;

    -- Count unique authors processed
    SELECT COUNT(DISTINCT author_id) INTO v_authors_processed
    FROM media_intelligence;

    RAISE NOTICE '  - Author media metrics: % rows for % authors', v_metrics_count, v_authors_processed;

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

-- Create indexes for media analysis queries
CREATE INDEX IF NOT EXISTS idx_intel_metrics_media_propaganda_risk
ON osint.intel_metrics (entity_type, metric_name, value_float DESC)
WHERE entity_type = 'author' AND metric_name = 'media_propaganda_risk';

CREATE INDEX IF NOT EXISTS idx_intel_metrics_visual_coordination
ON osint.intel_metrics (entity_type, metric_name, value_float DESC)
WHERE entity_type = 'author' AND metric_name = 'visual_coordination_risk';