-- Author Semantic Intelligence Metrics
-- Advanced semantic analysis using tweet embeddings for propaganda detection
-- Content diversity, narrative clustering, and authenticity assessment

CREATE OR REPLACE FUNCTION osint.compute_author_semantic_metrics(
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
    RAISE NOTICE 'Computing author semantic metrics from % to %', v_date_start, v_date_end;

    -- ================================================================
    -- SEMANTIC INTELLIGENCE METRICS
    -- ================================================================

    WITH author_semantic_analysis AS (
        SELECT
            DATE(t.created_at) as metric_date,
            t.author_id,

            -- Basic Embedding Statistics
            COUNT(te.embedding) as tweets_with_embeddings,
            COUNT(*) as total_tweets,

            -- Content Diversity Score using cosine similarities
            -- High diversity = low average similarity between embeddings
            CASE
                WHEN COUNT(te.embedding) > 1 THEN
                    1.0 - (
                        SELECT AVG(
                            (te1.embedding <=> te2.embedding)  -- cosine distance
                        )
                        FROM osint.tweet_embeddings te1
                        CROSS JOIN osint.tweet_embeddings te2
                        WHERE te1.tweet_id != te2.tweet_id
                          AND te1.tweet_id IN (
                              SELECT t2.tweet_id
                              FROM osint.tweets_deduplicated t2
                              WHERE t2.author_id = t.author_id
                                AND DATE(t2.created_at) BETWEEN v_date_start AND v_date_end
                          )
                          AND te2.tweet_id IN (
                              SELECT t3.tweet_id
                              FROM osint.tweets_deduplicated t3
                              WHERE t3.author_id = t.author_id
                                AND DATE(t3.created_at) BETWEEN v_date_start AND v_date_end
                          )
                    )
                ELSE 0.5  -- Default for single tweet
            END as content_diversity_score,

            -- Semantic Repetition Rate
            -- Count pairs with >90% similarity (cosine distance <0.1)
            CASE
                WHEN COUNT(te.embedding) > 1 THEN
                    (
                        SELECT COUNT(*)::FLOAT
                        FROM osint.tweet_embeddings te1
                        CROSS JOIN osint.tweet_embeddings te2
                        WHERE te1.tweet_id < te2.tweet_id  -- Avoid double counting
                          AND (te1.embedding <=> te2.embedding) < 0.1  -- >90% similar
                          AND te1.tweet_id IN (
                              SELECT t2.tweet_id
                              FROM osint.tweets_deduplicated t2
                              WHERE t2.author_id = t.author_id
                                AND DATE(t2.created_at) BETWEEN v_date_start AND v_date_end
                          )
                          AND te2.tweet_id IN (
                              SELECT t3.tweet_id
                              FROM osint.tweets_deduplicated t3
                              WHERE t3.author_id = t.author_id
                                AND DATE(t3.created_at) BETWEEN v_date_start AND v_date_end
                          )
                    ) / (COUNT(te.embedding) * (COUNT(te.embedding) - 1) / 2.0)  -- Total possible pairs
                ELSE 0
            END as semantic_repetition_rate,

            -- Dominant Narrative Cluster (most common semantic region)
            -- Using k-means like clustering approximation
            CASE
                WHEN COUNT(te.embedding) >= 3 THEN
                    (
                        SELECT COUNT(*)::FLOAT / COUNT(te.embedding)
                        FROM osint.tweet_embeddings te_cluster
                        WHERE te_cluster.tweet_id IN (
                            SELECT t2.tweet_id
                            FROM osint.tweets_deduplicated t2
                            WHERE t2.author_id = t.author_id
                              AND DATE(t2.created_at) BETWEEN v_date_start AND v_date_end
                        )
                        -- Find embeddings close to the centroid
                        AND (te_cluster.embedding <=> (
                            SELECT AVG(te_avg.embedding)
                            FROM osint.tweet_embeddings te_avg
                            WHERE te_avg.tweet_id IN (
                                SELECT t3.tweet_id
                                FROM osint.tweets_deduplicated t3
                                WHERE t3.author_id = t.author_id
                                  AND DATE(t3.created_at) BETWEEN v_date_start AND v_date_end
                            )
                        )) < 0.3  -- Within 70% similarity to average
                    )
                ELSE 0
            END as dominant_narrative_ratio,

            -- Narrative Switching Detection
            -- Variance in semantic positions over time
            CASE
                WHEN COUNT(te.embedding) > 2 THEN
                    -- Calculate time-ordered semantic drift
                    (
                        SELECT AVG(
                            (te_early.embedding <=> te_late.embedding)
                        )
                        FROM osint.tweet_embeddings te_early
                        JOIN osint.tweets_deduplicated t_early ON te_early.tweet_id = t_early.tweet_id
                        CROSS JOIN osint.tweet_embeddings te_late
                        JOIN osint.tweets_deduplicated t_late ON te_late.tweet_id = t_late.tweet_id
                        WHERE t_early.author_id = t.author_id
                          AND t_late.author_id = t.author_id
                          AND t_early.created_at < t_late.created_at
                          AND DATE(t_early.created_at) BETWEEN v_date_start AND v_date_end
                          AND DATE(t_late.created_at) BETWEEN v_date_start AND v_date_end
                          AND EXTRACT(EPOCH FROM t_late.created_at - t_early.created_at) > 3600  -- At least 1 hour apart
                    )
                ELSE 0
            END as narrative_drift_score,

            -- Semantic Outlier Count
            -- Tweets that are very different from author's typical content
            (
                SELECT COUNT(*)
                FROM osint.tweet_embeddings te_outlier
                WHERE te_outlier.tweet_id IN (
                    SELECT t2.tweet_id
                    FROM osint.tweets_deduplicated t2
                    WHERE t2.author_id = t.author_id
                      AND DATE(t2.created_at) BETWEEN v_date_start AND v_date_end
                )
                AND (te_outlier.embedding <=> (
                    SELECT AVG(te_avg.embedding)
                    FROM osint.tweet_embeddings te_avg
                    WHERE te_avg.tweet_id IN (
                        SELECT t3.tweet_id
                        FROM osint.tweets_deduplicated t3
                        WHERE t3.author_id = t.author_id
                          AND DATE(t3.created_at) BETWEEN v_date_start AND v_date_end
                    )
                )) > 0.5  -- Very different from average (>50% distance)
            ) as semantic_outlier_count

        FROM osint.tweets_deduplicated t
        LEFT JOIN osint.tweet_embeddings te ON te.tweet_id = t.tweet_id

        WHERE DATE(t.created_at) BETWEEN v_date_start AND v_date_end
          AND t.author_id IS NOT NULL
        GROUP BY DATE(t.created_at), t.author_id
    ),

    -- Calculate semantic authenticity and propaganda indicators
    semantic_intelligence AS (
        SELECT
            *,
            -- Embedding Coverage Ratio
            CASE
                WHEN total_tweets > 0
                THEN tweets_with_embeddings::FLOAT / total_tweets
                ELSE 0
            END as embedding_coverage_ratio,

            -- Narrative Authenticity Score
            -- High diversity + low repetition + moderate clustering = authentic
            -- Low diversity + high repetition + high clustering = propaganda
            LEAST(1.0,
                (content_diversity_score * 0.4) +
                ((1.0 - semantic_repetition_rate) * 0.3) +
                ((1.0 - LEAST(1.0, dominant_narrative_ratio)) * 0.3)
            ) as narrative_authenticity_score,

            -- Propaganda Risk Score
            -- High repetition + low diversity + tight clustering = propaganda
            LEAST(1.0,
                (semantic_repetition_rate * 0.4) +
                ((1.0 - content_diversity_score) * 0.3) +
                (LEAST(1.0, dominant_narrative_ratio) * 0.3)
            ) as propaganda_risk_score,

            -- Content Consistency Score
            -- Measures how consistent semantic patterns are over time
            CASE
                WHEN narrative_drift_score > 0
                THEN 1.0 - narrative_drift_score
                ELSE 1.0
            END as content_consistency_score

        FROM author_semantic_analysis
    ),

    -- Pivot semantic metrics for storage
    semantic_metrics_pivot AS (
        SELECT
            metric_date,
            author_id,
            metric_name,
            value_int,
            value_float,
            unit
        FROM semantic_intelligence,
        LATERAL (VALUES
            ('tweets_with_embeddings', tweets_with_embeddings, NULL, 'count'),
            ('semantic_outlier_count', semantic_outlier_count, NULL, 'count'),
            ('embedding_coverage_ratio', NULL, embedding_coverage_ratio, 'percentage'),
            ('content_diversity_score', NULL, content_diversity_score, 'score'),
            ('semantic_repetition_rate', NULL, semantic_repetition_rate, 'percentage'),
            ('dominant_narrative_ratio', NULL, dominant_narrative_ratio, 'percentage'),
            ('narrative_drift_score', NULL, narrative_drift_score, 'score'),
            ('narrative_authenticity_score', NULL, narrative_authenticity_score, 'score'),
            ('propaganda_risk_score', NULL, propaganda_risk_score, 'score'),
            ('content_consistency_score', NULL, content_consistency_score, 'score')
        ) AS unpivoted(metric_name, value_int, value_float, unit)
    )

    -- Insert semantic metrics with UPSERT
    INSERT INTO osint.intel_metrics (time, metric_name, entity_type, entity_id, value_int, value_float, unit)
    SELECT
        metric_date::timestamptz,
        metric_name,
        'author',
        author_id,
        value_int,
        value_float,
        unit
    FROM semantic_metrics_pivot
    ON CONFLICT (time, metric_name, entity_type, entity_id)
    DO UPDATE SET
        value_int = EXCLUDED.value_int,
        value_float = EXCLUDED.value_float,
        unit = EXCLUDED.unit,
        computed_at = NOW();

    GET DIAGNOSTICS v_metrics_count = ROW_COUNT;

    -- Count unique authors processed
    SELECT COUNT(DISTINCT author_id) INTO v_authors_processed
    FROM semantic_intelligence;

    RAISE NOTICE '  - Author semantic metrics: % rows for % authors', v_metrics_count, v_authors_processed;

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

-- Create indexes for semantic analysis queries
CREATE INDEX IF NOT EXISTS idx_intel_metrics_propaganda_risk
ON osint.intel_metrics (entity_type, metric_name, value_float DESC)
WHERE entity_type = 'author' AND metric_name = 'propaganda_risk_score';

CREATE INDEX IF NOT EXISTS idx_intel_metrics_narrative_authenticity
ON osint.intel_metrics (entity_type, metric_name, value_float DESC)
WHERE entity_type = 'author' AND metric_name = 'narrative_authenticity_score';