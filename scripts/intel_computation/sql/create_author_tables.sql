-- Author Tables Creation Script
-- Multi-Tier Architecture for OSINT Author Intelligence
-- Replaces the 46-metric daily approach with focused tables

-- ================================================================
-- TIER 2: AUTHOR DAILY METRICS TABLE
-- Fast daily tracking (8-12 essential metrics)
-- ================================================================

DROP TABLE IF EXISTS osint.author_daily_metrics CASCADE;

CREATE TABLE osint.author_daily_metrics (
    date DATE NOT NULL,
    author_id BIGINT NOT NULL,

    -- Basic Activity Counts
    daily_tweets INTEGER DEFAULT 0,
    daily_replies INTEGER DEFAULT 0,
    daily_original_tweets INTEGER DEFAULT 0,
    daily_retweets INTEGER DEFAULT 0,
    daily_quotes INTEGER DEFAULT 0,

    -- Engagement Metrics
    total_engagement_received BIGINT DEFAULT 0,
    avg_engagement_per_tweet FLOAT DEFAULT 0,

    -- Activity Patterns
    active_hours INTEGER DEFAULT 0,
    peak_hour INTEGER DEFAULT NULL,
    posting_velocity FLOAT DEFAULT 0, -- tweets per active hour

    -- Virality Indicators
    viral_tweets_count INTEGER DEFAULT 0,

    -- Cross-Theme Activity (if needed)
    cross_theme_activity INTEGER DEFAULT 0,

    -- Metadata
    computed_at TIMESTAMPTZ DEFAULT NOW(),

    PRIMARY KEY (date, author_id)
);

-- ================================================================
-- TIER 3: AUTHOR INTELLIGENCE TABLE
-- Strategic intelligence analysis (weekly/monthly)
-- ================================================================

DROP TABLE IF EXISTS osint.author_intelligence CASCADE;

CREATE TABLE osint.author_intelligence (
    analysis_date DATE NOT NULL,
    author_id BIGINT NOT NULL,
    analysis_period TEXT NOT NULL, -- '7_days', '30_days', '90_days'

    -- Influence & Authority
    influence_score FLOAT DEFAULT 0,
    authority_score FLOAT DEFAULT 0,

    -- Network Intelligence
    coordination_risk_score FLOAT DEFAULT 0,
    betweenness_centrality FLOAT DEFAULT 0,
    network_reach INTEGER DEFAULT 0,
    cross_reference_rate FLOAT DEFAULT 0,

    -- Content Intelligence
    semantic_diversity_score FLOAT DEFAULT 0,
    hashtag_coordination_score FLOAT DEFAULT 0,

    -- Strategic Metrics
    monitoring_priority_score FLOAT DEFAULT 0,
    amplification_factor FLOAT DEFAULT 0,

    -- Metadata
    computed_at TIMESTAMPTZ DEFAULT NOW(),

    PRIMARY KEY (analysis_date, author_id, analysis_period)
);

-- ================================================================
-- INDEXES FOR PERFORMANCE
-- ================================================================

-- Daily metrics indexes
CREATE INDEX IF NOT EXISTS idx_author_daily_date
ON osint.author_daily_metrics (date DESC);

CREATE INDEX IF NOT EXISTS idx_author_daily_author
ON osint.author_daily_metrics (author_id, date DESC);

CREATE INDEX IF NOT EXISTS idx_author_daily_tweets
ON osint.author_daily_metrics (daily_tweets DESC)
WHERE daily_tweets > 0;

CREATE INDEX IF NOT EXISTS idx_author_daily_engagement
ON osint.author_daily_metrics (total_engagement_received DESC)
WHERE total_engagement_received > 0;

-- Intelligence table indexes
CREATE INDEX IF NOT EXISTS idx_author_intel_date
ON osint.author_intelligence (analysis_date DESC);

CREATE INDEX IF NOT EXISTS idx_author_intel_author
ON osint.author_intelligence (author_id, analysis_date DESC);

CREATE INDEX IF NOT EXISTS idx_author_intel_period
ON osint.author_intelligence (analysis_period, analysis_date DESC);

CREATE INDEX IF NOT EXISTS idx_author_intel_influence
ON osint.author_intelligence (influence_score DESC)
WHERE influence_score > 0.5;

CREATE INDEX IF NOT EXISTS idx_author_intel_coordination
ON osint.author_intelligence (coordination_risk_score DESC)
WHERE coordination_risk_score > 0.3;

CREATE INDEX IF NOT EXISTS idx_author_intel_priority
ON osint.author_intelligence (monitoring_priority_score DESC)
WHERE monitoring_priority_score > 0.6;

-- ================================================================
-- VERIFICATION QUERIES
-- ================================================================

-- Check table structure
SELECT
    'author_daily_metrics' as table_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'osint'
  AND table_name = 'author_daily_metrics'
ORDER BY ordinal_position;

SELECT
    'author_intelligence' as table_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'osint'
  AND table_name = 'author_intelligence'
ORDER BY ordinal_position;



-- Check constraints
SELECT
    constraint_name,
    constraint_type
FROM information_schema.table_constraints
WHERE table_schema = 'osint'
  AND table_name IN ('author_daily_metrics', 'author_intelligence');

RAISE NOTICE '============================================================';
RAISE NOTICE 'Author Tables Created Successfully';
RAISE NOTICE '============================================================';
RAISE NOTICE 'Tier 2: author_daily_metrics - Fast daily tracking';
RAISE NOTICE 'Tier 3: author_intelligence - Strategic analysis';
RAISE NOTICE '============================================================';