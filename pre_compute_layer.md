# 🎯 Pre-Computation Strategy - Detailed Implementation Plan

## Executive Summary

**Goal**: Make MCP responses **instant** (<1s) by pre-computing expensive analytics once daily/hourly, then serving cached results.

**Philosophy**: **Compute Once, Serve Many** - Instead of calculating metrics on every API call, compute them during off-peak hours and store results.

---

## 📊 **Current Problem**

### **Without Pre-Computation** (Current State)
```
MCP Request → API Endpoint → Repository Query
                              ↓
                         Complex SQL Aggregations
                              ↓
                         2-5 seconds processing
                              ↓
                         Return Results
```

**Issues**:
- Every request triggers expensive calculations
- CAGR, trends, rolling averages computed on-demand
- Cross-join operations for similarity (1M+ comparisons)
- Database load scales with API requests

### **With Pre-Computation** (Target State)
```
Background Job (Daily 2 AM)
    ↓
Compute All Metrics
    ↓
Store in Cache Tables
    ↓
MCP Request → API Endpoint → SELECT * FROM cache
                              ↓
                         <1ms retrieval
                              ↓
                         Return Results
```

**Benefits**:
- Instant responses
- Database load independent of API traffic
- Predictable performance
- Can handle 1000s of concurrent MCP requests

---

## 🗄️ **Pre-Computation Tables Design**

### **Table 1: `theme_health_cache`**

**Purpose**: Store complete theme health metrics (replaces real-time CAGR calculations)

```sql
CREATE TABLE osint.theme_health_cache (
    theme_id INTEGER PRIMARY KEY,
    period_days INTEGER DEFAULT 100,
    
    -- Volume Metrics
    total_tweets INTEGER NOT NULL,
    total_engagement BIGINT NOT NULL,
    unique_authors INTEGER NOT NULL,
    unique_hashtags INTEGER NOT NULL,
    
    -- Growth Metrics (CAGR calculation pre-computed)
    cagr_percentage FLOAT NOT NULL,
    trend_status VARCHAR(20) NOT NULL,  -- 'growing', 'declining', 'stable'
    trend_color VARCHAR(7) NOT NULL,     -- '#d32f2f' (red), '#1976d2' (blue)
    first_period_avg FLOAT NOT NULL,     -- First 25% average
    last_period_avg FLOAT NOT NULL,      -- Last 25% average
    percent_change FLOAT NOT NULL,
    
    -- Engagement Breakdown
    avg_likes_per_tweet FLOAT,
    avg_retweets_per_tweet FLOAT,
    avg_replies_per_tweet FLOAT,
    avg_quotes_per_tweet FLOAT,
    avg_engagement_per_tweet FLOAT,
    engagement_rate_change FLOAT,
    
    -- Quality Metrics
    tweets_per_author FLOAT,
    avg_text_length FLOAT,
    avg_virality_score FLOAT,
    
    -- Temporal Patterns
    peak_activity_hour INTEGER,
    peak_activity_day VARCHAR(10),
    
    -- Metadata
    computed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    data_start_date DATE NOT NULL,
    data_end_date DATE NOT NULL,
    computation_duration_ms INTEGER,
    
    CONSTRAINT valid_trend_status CHECK (trend_status IN ('growing', 'declining', 'stable'))
);

CREATE INDEX idx_theme_health_computed_at ON osint.theme_health_cache(computed_at);
CREATE INDEX idx_theme_health_trend ON osint.theme_health_cache(trend_status);
CREATE INDEX idx_theme_health_cagr ON osint.theme_health_cache(cagr_percentage DESC);
```

**What Gets Pre-Computed**:
- ✅ CAGR from your `calculate_growth_metrics()` function
- ✅ Trend status (growing/declining/stable)
- ✅ All engagement averages
- ✅ Peak activity analysis

**Update Frequency**: Daily at 2 AM (cron job)

**API Endpoint Impact**:
```python
# BEFORE (2-5 seconds)
GET /api/v1/analytics/themes/1/health
→ Fetches 100 days of tweets
→ Calculates daily aggregations
→ Computes CAGR
→ Returns result

# AFTER (<1ms)
GET /api/v1/analytics/themes/1/health
→ SELECT * FROM theme_health_cache WHERE theme_id = 1
→ Returns pre-computed result
```

---

### **Table 2: `daily_activity_summary`**

**Purpose**: Pre-aggregated daily metrics (replaces real-time timeline queries)

```sql
CREATE TABLE osint.daily_activity_summary (
    id SERIAL PRIMARY KEY,
    summary_date DATE NOT NULL,
    theme_id INTEGER NOT NULL,
    topic_id INTEGER,  -- NULL for theme-level, specific for topic-level
    
    -- Volume
    daily_tweets INTEGER NOT NULL,
    daily_authors INTEGER NOT NULL,
    daily_sessions INTEGER NOT NULL,
    
    -- Engagement
    daily_likes INTEGER NOT NULL,
    daily_retweets INTEGER NOT NULL,
    daily_replies INTEGER NOT NULL,
    daily_quotes INTEGER NOT NULL,
    daily_total_engagement BIGINT NOT NULL,
    
    -- Averages
    avg_text_length FLOAT,
    avg_virality_score FLOAT,
    avg_engagement_per_tweet FLOAT,
    
    -- Tweet Types
    original_tweets INTEGER NOT NULL,
    retweets INTEGER NOT NULL,
    replies INTEGER NOT NULL,
    quotes INTEGER NOT NULL,
    
    -- Hourly Peak
    peak_hour INTEGER,  -- 0-23
    peak_hour_tweets INTEGER,
    
    -- Rolling Averages (PRE-COMPUTED!)
    tweets_7day_avg FLOAT,
    engagement_7day_avg FLOAT,
    authors_7day_avg FLOAT,
    tweets_30day_avg FLOAT,
    engagement_30day_avg FLOAT,
    
    -- Metadata
    computed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(summary_date, theme_id, COALESCE(topic_id, -1))
);

CREATE INDEX idx_daily_summary_date ON osint.daily_activity_summary(summary_date DESC);
CREATE INDEX idx_daily_summary_theme ON osint.daily_activity_summary(theme_id);
CREATE INDEX idx_daily_summary_topic ON osint.daily_activity_summary(topic_id);
CREATE INDEX idx_daily_summary_theme_date ON osint.daily_activity_summary(theme_id, summary_date);
```

**What Gets Pre-Computed**:
- ✅ Daily tweet counts
- ✅ Daily engagement totals
- ✅ 7-day and 30-day rolling averages (expensive to calculate on-demand)
- ✅ Hourly peak detection

**Update Frequency**: Daily at 1 AM (for previous day)

**API Endpoint Impact**:
```python
# BEFORE (2-3 seconds)
GET /api/v1/analytics/themes/1/timeline?days=100
→ Fetches all tweets for 100 days
→ Groups by day
→ Calculates rolling averages
→ Returns timeline

# AFTER (<10ms)
GET /api/v1/analytics/themes/1/timeline?days=100
→ SELECT * FROM daily_activity_summary 
  WHERE theme_id = 1 AND summary_date >= date_sub(now(), interval 100 day)
  ORDER BY summary_date
→ Returns pre-computed timeline with rolling averages
```

---

### **Table 3: `topic_summary_cache`**

**Purpose**: Pre-computed topic metrics (replaces topic aggregation queries)

```sql
CREATE TABLE osint.topic_summary_cache (
    topic_id INTEGER NOT NULL,
    theme_id INTEGER,  -- NULL if cross-theme
    period_days INTEGER DEFAULT 100,
    
    -- Topic Metadata
    topic_name VARCHAR(500),
    topic_label VARCHAR(500),
    category VARCHAR(100),
    top_keywords TEXT[],
    coherence_score FLOAT,
    
    -- Volume Metrics
    total_tweets INTEGER NOT NULL,
    unique_authors INTEGER NOT NULL,
    avg_probability FLOAT,
    
    -- Growth Metrics
    daily_growth_rate FLOAT,
    weekly_growth_rate FLOAT,
    trend_status VARCHAR(20),  -- 'emerging', 'trending', 'declining', 'stable'
    first_seen_date DATE,
    peak_date DATE,
    peak_volume INTEGER,
    
    -- Engagement
    total_engagement BIGINT,
    avg_engagement_per_tweet FLOAT,
    
    -- Cross-Theme Presence
    theme_count INTEGER,  -- How many themes this topic appears in
    dominant_theme_id INTEGER,
    dominant_theme_percentage FLOAT,
    
    -- Metadata
    computed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    data_start_date DATE NOT NULL,
    data_end_date DATE NOT NULL,
    
    PRIMARY KEY (topic_id, COALESCE(theme_id, -1), period_days)
);

CREATE INDEX idx_topic_summary_theme ON osint.topic_summary_cache(theme_id);
CREATE INDEX idx_topic_summary_category ON osint.topic_summary_cache(category);
CREATE INDEX idx_topic_summary_trend ON osint.topic_summary_cache(trend_status);
CREATE INDEX idx_topic_summary_growth ON osint.topic_summary_cache(daily_growth_rate DESC);
```

**What Gets Pre-Computed**:
- ✅ Topic size and engagement
- ✅ Growth rates (daily, weekly)
- ✅ Trend classification
- ✅ Cross-theme presence

**Update Frequency**: Daily at 3 AM

---

### **Table 4: `author_expertise_cache`**

**Purpose**: Pre-computed author expertise scores (replaces author_topics aggregations)

```sql
CREATE TABLE osint.author_expertise_cache (
    author_id VARCHAR(50) NOT NULL,
    author_username VARCHAR(255),
    topic_id INTEGER NOT NULL,
    theme_id INTEGER,  -- NULL for cross-theme
    
    -- Expertise Metrics
    expertise_score FLOAT NOT NULL,  -- Weighted avg_probability
    tweet_count INTEGER NOT NULL,
    total_engagement BIGINT,
    avg_engagement_per_tweet FLOAT,
    
    -- Consistency (how focused is this author?)
    consistency_score FLOAT,  -- Std dev of probabilities (lower = more consistent)
    topic_focus_score FLOAT,  -- Shannon entropy across all topics (lower = specialized)
    
    -- Activity
    first_tweet_date DATE,
    last_tweet_date DATE,
    active_days INTEGER,
    avg_tweets_per_day FLOAT,
    
    -- Coordination Indicators
    tweets_per_author_ratio FLOAT,  -- For bot detection
    coordination_risk VARCHAR(20),   -- 'low', 'medium', 'high', 'critical'
    coordination_score FLOAT,        -- 0-1 score
    
    -- Rankings
    theme_rank INTEGER,  -- Rank within theme (1 = top expert)
    topic_rank INTEGER,  -- Rank within topic
    global_rank INTEGER, -- Overall rank
    
    -- Metadata
    computed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (author_id, topic_id, COALESCE(theme_id, -1))
);

CREATE INDEX idx_author_expertise_author ON osint.author_expertise_cache(author_id);
CREATE INDEX idx_author_expertise_topic ON osint.author_expertise_cache(topic_id);
CREATE INDEX idx_author_expertise_theme ON osint.author_expertise_cache(theme_id);
CREATE INDEX idx_author_expertise_score ON osint.author_expertise_cache(expertise_score DESC);
CREATE INDEX idx_author_expertise_risk ON osint.author_expertise_cache(coordination_risk);
CREATE INDEX idx_author_expertise_ranking ON osint.author_expertise_cache(theme_id, expertise_score DESC);
```

**What Gets Pre-Computed**:
- ✅ Expertise scores from `author_topics`
- ✅ Consistency metrics
- ✅ Coordination risk scores
- ✅ Rankings within theme/topic

**Update Frequency**: Daily at 4 AM

**Bot Detection Logic**:
```python
# Pre-computed in background job
if tweets_per_author_ratio > 50:
    coordination_risk = 'critical'
    coordination_score = 0.95
elif tweets_per_author_ratio > 20:
    coordination_risk = 'high'
    coordination_score = 0.75
elif tweets_per_author_ratio > 10:
    coordination_risk = 'medium'
    coordination_score = 0.50
else:
    coordination_risk = 'low'
    coordination_score = 0.25
```

---

### **Table 5: `semantic_cohesion_cache`**

**Purpose**: Pre-computed embedding similarity (replaces expensive cross-joins)

```sql
CREATE TABLE osint.semantic_cohesion_cache (
    id SERIAL PRIMARY KEY,
    entity_type VARCHAR(20) NOT NULL,  -- 'theme', 'topic', 'campaign'
    entity_id INTEGER NOT NULL,
    period_days INTEGER DEFAULT 100,
    
    -- Cohesion Metrics
    cohesion_score FLOAT NOT NULL,  -- 0-1, average pairwise cosine similarity
    cohesion_interpretation VARCHAR(50),  -- 'very_high', 'high', 'moderate', 'low', 'very_low'
    
    -- Cluster Analysis
    optimal_clusters INTEGER,  -- From k-means elbow method
    silhouette_score FLOAT,    -- Cluster quality
    sub_cluster_count INTEGER,
    
    -- Centroid (stored as vector for future similarity queries)
    centroid_embedding vector(512),
    avg_distance_to_centroid FLOAT,
    std_distance_to_centroid FLOAT,
    
    -- Outliers
    outlier_count INTEGER,
    outlier_percentage FLOAT,
    outlier_tweet_ids TEXT[],  -- Top 10 outlier tweets for investigation
    
    -- Distribution Percentiles
    similarity_p25 FLOAT,
    similarity_p50 FLOAT,
    similarity_p75 FLOAT,
    similarity_p95 FLOAT,
    
    -- Quality Score (combined metric)
    quality_score FLOAT,  -- Weighted: cohesion * 0.6 + silhouette * 0.4
    
    -- Sample Info
    sample_size INTEGER,  -- How many tweets were analyzed
    
    -- Metadata
    computed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    computation_duration_ms INTEGER,
    
    UNIQUE(entity_type, entity_id, period_days)
);

CREATE INDEX idx_cohesion_entity ON osint.semantic_cohesion_cache(entity_type, entity_id);
CREATE INDEX idx_cohesion_score ON osint.semantic_cohesion_cache(cohesion_score DESC);
CREATE INDEX idx_cohesion_quality ON osint.semantic_cohesion_cache(quality_score DESC);
```

**What Gets Pre-Computed**:
- ✅ Semantic cohesion (expensive cross-join avoided)
- ✅ Cluster analysis
- ✅ Centroid embeddings
- ✅ Outlier detection

**Update Frequency**: Daily at 5 AM (most expensive computation)

**Computation Optimization**:
```python
# Instead of cross-joining 1000 x 1000 embeddings (1M comparisons)
# Use centroid method (1000 comparisons)

# Compute centroid
centroid = np.mean(all_embeddings, axis=0)

# Compute distances to centroid
distances = [cosine_similarity(emb, centroid) for emb in all_embeddings]

# Cohesion = average similarity to centroid
cohesion_score = np.mean(distances)
```

---

## ⏰ **ETL Job Schedule**

```python
# Celery Beat Schedule

app.conf.beat_schedule = {
    # 1 AM: Daily activity summary (foundation for other jobs)
    'daily-activity-summary': {
        'task': 'compute_daily_activity_summary',
        'schedule': crontab(hour=1, minute=0),
        'args': ()
    },
    
    # 2 AM: Theme health (depends on daily summaries)
    'theme-health-cache': {
        'task': 'compute_theme_health',
        'schedule': crontab(hour=2, minute=0),
        'args': ()
    },
    
    # 3 AM: Topic summaries
    'topic-summary-cache': {
        'task': 'compute_topic_summaries',
        'schedule': crontab(hour=3, minute=0),
        'args': ()
    },
    
    # 4 AM: Author expertise
    'author-expertise-cache': {
        'task': 'compute_author_expertise',
        'schedule': crontab(hour=4, minute=0),
        'args': ()
    },
    
    # 5 AM: Semantic cohesion (most expensive)
    'semantic-cohesion-cache': {
        'task': 'compute_semantic_cohesion',
        'schedule': crontab(hour=5, minute=0),
        'args': ()
    },
    
    # 6 AM: Cross-theme similarity
    'cross-theme-similarity': {
        'task': 'compute_cross_theme_similarity',
        'schedule': crontab(hour=6, minute=0),
        'args': ()
    },
    
    # Every 6 hours: Campaign detection (near real-time)
    'campaign-detection': {
        'task': 'detect_campaigns',
        'schedule': crontab(minute=0, hour='*/6'),  # 12 AM, 6 AM, 12 PM, 6 PM
        'args': ()
    },
}
```

---

## 📊 **Performance Impact**

| Endpoint | Before (No Cache) | After (With Cache) | Improvement |
|----------|-------------------|-------------------|-------------|
| Theme Health | 2-5 seconds | <1ms | **5000x faster** |
| Timeline (100 days) | 2-3 seconds | <10ms | **300x faster** |
| Topic Summary | 1-2 seconds | <1ms | **2000x faster** |
| Author Expertise | 500ms | <1ms | **500x faster** |
| Semantic Cohesion | 30-60 seconds | <1ms | **60,000x faster** |
| Campaign Detection | 10-20 seconds | <1ms | **20,000x faster** |

---

## 💾 **Storage Requirements**

Estimated for **10 themes, 100 topics, 10K authors, 150K tweets**:

| Table | Rows | Size/Row | Total Size |
|-------|------|----------|------------|
| theme_health_cache | 10 | 500 bytes | 5 KB |
| daily_activity_summary | 1,000 | 200 bytes | 200 KB |
| topic_summary_cache | 1,000 | 400 bytes | 400 KB |
| author_expertise_cache | 100,000 | 300 bytes | 30 MB |
| semantic_cohesion_cache | 110 | 2 KB | 220 KB |

**Total: ~31 MB** (negligible compared to benefits)

---

## 🔄 **Cache Invalidation Strategy**

### **Time-Based (Primary)**
```python
{
    "computed_at": "2025-04-25T02:00:00Z",
    "data_freshness_hours": 6,
    "next_update": "2025-04-26T02:00:00Z"
}
```

### **On-Demand Refresh (Optional)**
```
GET /api/v1/analytics/themes/1/health?force_refresh=true
```
- Triggers immediate recalculation
- Updates cache
- Returns fresh results
- **Use sparingly** (expensive)

---

## 🚀 **Implementation Priority**

### **Phase 1: Essential Pre-Computation** (Week 1)
1. ✅ `daily_activity_summary` - Foundation for all analytics
2. ✅ `theme_health_cache` - Most requested by MCP
3. ✅ `topic_summary_cache` - Topic trending

### **Phase 2: Intelligence Pre-Computation** (Week 2)
4. ✅ `author_expertise_cache` - Expert identification
5. ✅ `semantic_cohesion_cache` - Embedding analysis

---

## ✅ **Benefits Summary**

### **For MCP**:
- ⚡ **Instant responses** (<100ms total)
- 🎯 **Reliable performance** (no query timeouts)
- 📊 **Consistent data** (all agents see same metrics)

### **For Database**:
- 📉 **Reduced load** (90% fewer complex queries)
- ⏰ **Off-peak computation** (runs when DB is idle)
- 🔒 **Predictable resource usage**

### **For Users**:
- 🚀 **Fast API responses**
- 💰 **Lower infrastructure costs**
- 📈 **Scalable to 1000s of requests**

---

## 🎯 **Next Steps**

**Should I provide:**
1. **SQL schema creation script** for all 5 cache tables?
2. **Python ETL job implementations** (Celery tasks)?
3. **Updated API endpoint code** to read from cache?
4. **Migration guide** from current on-demand to pre-computed?

**Let me know and I'll generate the complete implementation! 🚀**