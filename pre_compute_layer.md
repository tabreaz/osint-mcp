# OSINT Multi-Tier Metrics Documentation

**Current System**: Production-ready multi-tier intelligence system with optimized performance

## 🏗️ **Architecture Overview**

### **Multi-Tier Design Philosophy**
Instead of computing 46 metrics per author per day (causing timeouts), we use a strategic 3-tier approach:

1. **Tier 1: Core Metrics** - Project/theme daily tracking (fast)
2. **Tier 2: Daily Metrics** - Author activity tracking (12 essential metrics)
3. **Tier 3: Strategic Intelligence** - Coordination detection, influence scoring (periodic)

---

## 📊 **Tier 1: Core Metrics**

### **Table**: `osint.intel_metrics`
**Scope**: Project and theme level daily aggregation
**Update**: Daily via `osint.compute_timeseries_metrics()`

**Project-Level Metrics** (`entity_type = 'project'`):
| Metric | Purpose | Description |
|--------|---------|-------------|
| `tweet_count` | Volume Intelligence | Daily tweet activity for project monitoring |
| `unique_authors` | Network Size | Author diversity indicating campaign reach |
| `total_engagement` | Impact Assessment | Combined engagement across all project content |
| `viral_tweets` | Viral Intelligence | Content breaking viral thresholds (200+ score) |
| `highly_viral_tweets` | High-Impact Content | Extremely viral content (1000+ score) |
| `new_authors` | Growth Intelligence | New participants entering the conversation |
| `monitored_users_active` | Known Actor Activity | Activity from pre-identified important accounts |
| `hourly_activity_distribution` | Temporal Patterns | JSON array of hourly activity for pattern analysis |

**Theme-Level Metrics** (`entity_type = 'theme'`):
| Metric | Purpose | Description |
|--------|---------|-------------|
| `tweet_count` | Theme Volume | Daily discussion volume per theme |
| `unique_authors` | Theme Participation | Author diversity in theme discussions |
| `total_engagement` | Theme Impact | Engagement levels indicating theme resonance |
| `viral_tweets` | Viral Narratives | Viral content within specific themes |
| `avg_virality_score` | Theme Quality | Average content quality/impact |
| `max_virality_score` | Peak Performance | Highest performing content per theme |
| `hourly_activity_distribution` | Theme Patterns | Temporal patterns for narrative timing |

---

## 📈 **Tier 2: Daily Author Metrics**

### **Table**: `osint.author_daily_metrics`
**Scope**: Fast daily tracking of author behavior patterns
**Update**: Daily via `osint.compute_author_daily_simple()`
**Performance**: 35ms per day vs previous system timeouts

### **Daily Metrics (12 Optimized)**:

**Activity Volume**:
- `daily_tweets` - Daily posting frequency
- `daily_replies` - Reply activity indicating engagement behavior
- `daily_original_tweets` - Non-reply, non-retweet content creation
- `daily_retweets` - Content amplification patterns
- `daily_quotes` - Quote tweet behavior (adding commentary)

**Engagement Metrics**:
- `total_engagement_received` - Total engagement received across content
- `avg_engagement_per_tweet` - Average engagement efficiency

**Behavioral Patterns**:
- `active_hours` - Hours of day when active (temporal signature)
- `peak_hour` - Most active hour for activity pattern analysis
- `posting_velocity` - Tweets per active hour (automation indicator)

**Content Quality**:
- `viral_tweets_count` - Number of viral posts created
- `cross_theme_activity` - Number of themes author participates in

### **Performance Comparison**:
```
Old System: 46 metrics/author/day = Timeouts & Cartesian explosions
New System: 12 metrics/author/day = 35ms execution
Storage: 75% reduction in daily overhead
Coverage: 67,738 records for 24,590 authors (2023-2025)
```

---

## 🎯 **Tier 3: Strategic Intelligence**

### **Table**: `osint.author_intelligence`
**Scope**: Periodic deep intelligence analysis for threat detection
**Update**: Configurable periods (7, 30, 90 days) via `osint.compute_author_intelligence()`
**Coverage**: 68,968 strategic profiles

### **Intelligence Metrics (10 Strategic)**:

**Influence Assessment**:
- `influence_score` - Composite influence score (0-1) based on reach and engagement
- `authority_score` - Follower-to-following ratio indicating authority
- `monitoring_priority_score` - Composite score for monitoring prioritization
- `amplification_factor` - Retweets received per original tweet

**Coordination & Threat Detection**:
- `coordination_risk_score` - Risk score for coordinated inauthentic behavior
- `hashtag_coordination_score` - Suspicious hashtag usage patterns

**Network Analysis**:
- `betweenness_centrality` - Bridge position in communication networks
- `network_reach` - Number of unique accounts interacted with
- `cross_reference_rate` - Rate of referencing other accounts

**Content Analysis**:
- `semantic_diversity_score` - Diversity of topics/hashtags used

### **Analysis Periods**:
- `analysis_period` - Time window (7_days, 30_days, 90_days)
- Configurable thresholds: Minimum tweets for analysis (1, 3, 5, 10)

---

## 🔧 **Key Optimizations Implemented**

### **1. Coordination Detection Optimization**
**Problem**: O(N²) complexity causing timeouts
```sql
-- OLD: Cartesian explosion
SELECT ... FROM authors a1
CROSS JOIN authors a2
WHERE a1.hashtags && a2.hashtags  -- 1M+ comparisons
```

**Solution**: O(N) with time bucketing
```sql
-- NEW: Pre-computed shared entities with buckets
WITH shared_entities AS (
    SELECT hashtag, array_agg(DISTINCT author_id) as authors
    FROM hashtag_usage
    WHERE date_bucket >= analysis_start
    GROUP BY hashtag
    HAVING count(DISTINCT author_id) BETWEEN 2 AND coordination_threshold
)
SELECT author_id,
       COUNT(DISTINCT shared_hashtags) / total_hashtags::float as coordination_score
-- 1000x performance improvement
```

### **2. LATERAL Join Elimination**
**Problem**: LATERAL joins causing Cartesian explosions
```sql
-- OLD: Memory explosion
FROM tweets t
LATERAL (SELECT unnest(t.hashtags) as hashtag) h
LATERAL (SELECT unnest(t.urls) as url) u
-- 1 tweet × N hashtags × M URLs = massive rows
```

**Solution**: Aggregate-first approach
```sql
-- NEW: Count distinct tweet_ids
SELECT COUNT(DISTINCT t.tweet_id),
       array_agg(DISTINCT hashtag) as all_hashtags
FROM tweets t, unnest(t.hashtags) as hashtag
-- Fixed Cartesian explosion
```

### **3. Mixed Granularity Separation**
**Problem**: 46 daily metrics causing storage bloat and confusion
**Solution**: Strategic separation:
- **Daily**: 12 essential activity metrics (fast)
- **Strategic**: 10 intelligence metrics (periodic, expensive)
- **Core**: Project/theme aggregations (organizational)

---

## 📊 **Discovery & Analytics Functions**

### **Daily Metrics Analytics**:
```sql
-- Daily metrics summary
SELECT * FROM osint.get_daily_metrics_summary('2025-11-16');

-- Batch processing for historical data
SELECT * FROM osint.compute_author_daily_batch('2025-05-01', '2025-11-16');
```

### **Intelligence Analytics**:
```sql
-- Top influencers
SELECT * FROM osint.get_top_influencers('2025-11-16', '7_days', 20);

-- Coordination risks
SELECT * FROM osint.get_coordination_risks('2025-11-16', '7_days', 0.5, 15);

-- Network bridges
SELECT * FROM osint.get_network_bridges('2025-11-16', '7_days', 0.3, 10);
```

### **Trend Analysis**:
```sql
-- Intelligence trends over time
SELECT * FROM osint.get_intelligence_trends('2025-08-01', 'influence_score');

-- Monthly intelligence summary
SELECT * FROM osint.get_monthly_intelligence_summary();

-- System performance comparison
SELECT * FROM osint.compare_metrics_performance();
```

### **Automated Temporal Analysis**:
```sql
-- Periodic intelligence with data-driven period detection
SELECT * FROM osint.compute_periodic_intelligence('2025-08-01', 7, 1);

-- Get active analysis periods
SELECT * FROM osint.get_active_analysis_periods('2025-08-01', 1);
```

---

## 🚀 **Production Automation**

### **Primary Script**: `run_new_metrics_computation.sh`

**Daily Automation** (recommended for cron):
```bash
./run_new_metrics_computation.sh --daily-only
```

**Weekly Intelligence Analysis**:
```bash
./run_new_metrics_computation.sh --intelligence-only --intelligence-period 7_days
```

**90-Day Strategic Analysis**:
```bash
./run_new_metrics_computation.sh --intelligence-only --intelligence-period 90_days --min-threshold 5
```

**Historical Batch Processing**:
```bash
./run_new_metrics_computation.sh --batch 2025-08-01 2025-11-16 --daily-only
```

### **Recommended Cron Schedule**:
```bash
# Daily metrics at 2 AM
0 2 * * * /path/to/run_new_metrics_computation.sh --daily-only --quiet

# Weekly intelligence at 3 AM Monday
0 3 * * 1 /path/to/run_new_metrics_computation.sh --intelligence-only --intelligence-period 7_days --quiet

# Monthly strategic analysis at 4 AM on 1st of month
0 4 1 * * /path/to/run_new_metrics_computation.sh --intelligence-only --intelligence-period 30_days --min-threshold 5 --quiet
```

---

## 📈 **System Performance**

### **Achieved Metrics**:
- **Performance**: 35ms per day vs previous timeouts
- **Coverage**: 24,590 authors across 2+ years of data
- **Efficiency**: 75% reduction in storage overhead
- **Scalability**: Handles 100K+ tweets without performance degradation
- **Intelligence**: 68,968 strategic profiles with trend analysis
- **Improvement**: ~1000x faster than previous 46-metric approach

### **Data Status**:
```
Daily Metrics:     67,738 records  |  24,590 authors  |  2023-2025
Intelligence:      68,968 profiles  |  24,572 authors  |  Aug-Nov 2025
Storage:           Efficient 12+10 metrics vs old 46 metrics/day
```

---

## 📂 **File Organization**

```
scripts/intel_computation/
├── run_new_metrics_computation.sh     # Main automation script
├── sql/
│   ├── create_author_tables.sql       # Table schemas
│   ├── compute_author_daily_simple.sql # Daily metrics (optimized)
│   ├── compute_author_intelligence.sql # Strategic intelligence
│   ├── periodic_intelligence_analysis.sql # Automated temporal analysis
│   ├── compute_core_metrics.sql       # Project/theme metrics
│   └── deprecated_old_scripts/         # Archived inefficient scripts
├── deprecated_scripts/                 # Old automation scripts
└── archive_old_docs/                  # Historical documentation
```

---

**System Status**: ✅ Production Ready
**Architecture**: Multi-tier optimized OSINT intelligence platform
**Performance**: 1000x improvement with strategic metric separation