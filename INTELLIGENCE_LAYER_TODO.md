# Intelligence Layer Implementation TODO
## Project: Transform OSINT API from CRUD to Intelligence Layer

**Created**: 2024-11-20
**Status**: IN PROGRESS
**Philosophy**: "Compute Once, Serve Intelligence" - Pre-compute expensive analytics, serve instant insights

---

## 🎯 PROJECT CONTEXT

### Problem We're Solving
- Current API does traditional CRUD - dumps raw data
- MCP agents need intelligence, not datasets
- Queries take 2-5 seconds for complex analytics
- No pre-computation, everything calculated on-demand

### Solution Architecture
- Pre-compute expensive metrics during off-peak (1-6 AM)
- Store in `intel_*` prefixed tables
- Serve instant insights (<1ms responses)
- Focus on decisions, not data dumps

### Database Context
```
Project: Sudan-UAE Conflict Monitoring (id=1)
  └── 12 Themes (Sudan Conflict, UAE Politics, etc)
       └── 148,052 Tweets collected
       └── Monitored Users tracked

Parallel:
  └── 128 ML Topics (refined with GPT-4)
       └── Tweet-Topic assignments
       └── Author expertise scores
```

---

## 📊 SCHEMA DESIGNS

### 1. intel_daily_activity (BACKBONE TABLE)
**Purpose**: Daily aggregated metrics at multiple levels (project/theme/topic)
**Status**: ⏳ DESIGNED, NOT IMPLEMENTED

```sql
CREATE TABLE osint.intel_daily_activity (
    -- Identity
    id SERIAL PRIMARY KEY,
    summary_date DATE NOT NULL,
    entity_type VARCHAR(20) NOT NULL, -- 'project', 'theme', 'topic'
    project_id INTEGER NOT NULL REFERENCES projects(id),
    theme_id INTEGER REFERENCES themes(id),
    topic_id INTEGER REFERENCES topic_definitions_refined(topic_id),

    -- Core Volume
    tweet_count INTEGER NOT NULL,
    unique_authors INTEGER NOT NULL,
    new_authors INTEGER NOT NULL,

    -- Collection Metrics
    collected_by_query INTEGER,
    collected_by_user INTEGER,
    monitored_users_active INTEGER,

    -- Engagement Components
    total_likes INTEGER NOT NULL,
    total_retweets INTEGER NOT NULL,
    total_replies INTEGER NOT NULL,
    total_quotes INTEGER NOT NULL,

    -- Virality Metrics (using weighted formula)
    avg_virality_score FLOAT,
    max_virality_score FLOAT,
    viral_tweets INTEGER,         -- virality_score > 100
    highly_viral_tweets INTEGER,  -- virality_score > 500

    -- Topic Integration
    dominant_topic_id INTEGER,
    dominant_topic_name VARCHAR(255),
    topic_diversity FLOAT,
    topics_active INTEGER,

    -- User Quality
    verified_authors INTEGER,
    high_follower_authors INTEGER,
    bot_risk_authors INTEGER,

    -- Temporal
    peak_hour INTEGER,
    peak_hour_tweets INTEGER,

    -- Growth Metrics
    growth_rate_1d FLOAT,
    growth_rate_7d FLOAT,
    growth_rate_30d FLOAT,

    -- Pre-computed Averages
    tweets_7d_avg FLOAT,
    engagement_7d_avg FLOAT,
    tweets_30d_avg FLOAT,

    -- Anomaly Detection
    is_spike BOOLEAN DEFAULT FALSE,
    spike_score FLOAT,
    spike_type VARCHAR(50),

    -- Metadata
    computed_at TIMESTAMP DEFAULT NOW(),
    computation_duration_ms INTEGER,

    UNIQUE(summary_date, entity_type, project_id,
           COALESCE(theme_id, 0), COALESCE(topic_id, 0))
);
```

**Virality Score Formula**:
```
virality = (retweets * 3.0) + (quotes * 2.5) + (replies * 2.0) +
           (likes * 1.0) + (bookmarks * 1.5) + (views * 0.001)

Thresholds (configurable):
- viral: > 100
- highly_viral: > 500
```

### 2. intel_entity_mentions
**Purpose**: Track hashtags, mentions, domains over time
**Status**: ⏳ DESIGNED, NOT IMPLEMENTED

```sql
CREATE TABLE osint.intel_entity_mentions (
    id SERIAL PRIMARY KEY,
    summary_date DATE NOT NULL,
    project_id INTEGER NOT NULL,
    theme_id INTEGER,
    entity_type VARCHAR(20) NOT NULL, -- 'hashtag', 'mention', 'domain'
    entity_value VARCHAR(255) NOT NULL,

    occurrence_count INTEGER NOT NULL,
    unique_authors INTEGER NOT NULL,
    total_engagement BIGINT,
    daily_rank INTEGER,

    UNIQUE(summary_date, project_id, COALESCE(theme_id, 0),
           entity_type, entity_value)
);
```

### 3. intel_spike_alerts
**Purpose**: Pre-computed anomaly detection
**Status**: ⏳ PLANNED

```sql
CREATE TABLE osint.intel_spike_alerts (
    id SERIAL PRIMARY KEY,
    detected_at TIMESTAMP NOT NULL,
    alert_type VARCHAR(50), -- 'volume', 'engagement', 'new_topic'
    severity VARCHAR(20),   -- 'low', 'medium', 'high', 'critical'
    entity_type VARCHAR(20),
    entity_id INTEGER,

    current_value FLOAT,
    expected_value FLOAT,
    standard_deviations FLOAT,

    alert_message TEXT,
    recommended_action TEXT,

    acknowledged BOOLEAN DEFAULT FALSE,
    acknowledged_at TIMESTAMP
);
```

---

## 🔧 POSTGRESQL PROCEDURES

### Procedure 1: compute_intel_daily_activity()
**Status**: ⏳ TODO

```sql
CREATE OR REPLACE PROCEDURE osint.compute_intel_daily_activity(
    p_date DATE DEFAULT CURRENT_DATE - 1,
    p_days_back INTEGER DEFAULT 3
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Delete existing data for date range
    DELETE FROM intel_daily_activity
    WHERE summary_date >= p_date - p_days_back
    AND summary_date <= p_date;

    -- Insert project-level summaries
    -- Insert theme-level summaries
    -- Insert topic-level summaries

    -- Mark computation complete
    INSERT INTO intel_computation_log (
        table_name, computation_date, duration_ms
    ) VALUES (
        'intel_daily_activity', p_date, ...
    );
END;
$$;
```

### Procedure 2: detect_spikes()
**Status**: ⏳ TODO

### Procedure 3: compute_entity_mentions()
**Status**: ⏳ TODO

---

## 🐍 PYTHON IMPLEMENTATION

### 1. Scheduler Script
**File**: `/scripts/intel_computation/scheduler.py`
**Status**: ⏳ TODO

```python
import schedule
import time
from datetime import datetime, timedelta

class IntelScheduler:
    def __init__(self):
        self.setup_schedule()

    def setup_schedule(self):
        # 1 AM: Compute daily activity
        schedule.every().day.at("01:00").do(self.compute_daily_activity)

        # 2 AM: Detect spikes
        schedule.every().day.at("02:00").do(self.detect_anomalies)

        # Every 6 hours: Refresh recent days
        schedule.every(6).hours.do(self.refresh_recent)

    def compute_daily_activity(self):
        """Compute yesterday's activity"""
        # Call PostgreSQL procedure

    def refresh_recent(self):
        """Refresh last 3 days (for late-arriving data)"""
        # Call procedure with p_days_back=3
```

### 2. Manual Trigger Script
**File**: `/scripts/intel_computation/manual_compute.py`
**Status**: ⏳ TODO

---

## 📡 API ENDPOINTS (Intelligence Layer)

### Endpoint Set 1: Alerts & Insights
**Status**: ⏳ TODO

```python
GET /api/v1/intelligence/alerts
Response: {
    "critical": [
        {
            "type": "volume_spike",
            "theme": "Sudan Conflict",
            "increase": "300%",
            "action": "Monitor for campaign"
        }
    ],
    "trending": [...],
    "declining": [...]
}

GET /api/v1/intelligence/daily-brief
Response: {
    "date": "2024-11-20",
    "top_themes": [...],
    "viral_content": [...],
    "emerging_topics": [...],
    "bot_risk": "low"
}
```

### Endpoint Set 2: Focused Queries
**Status**: ⏳ TODO

```python
GET /api/v1/intelligence/trending-topics
GET /api/v1/intelligence/influential-authors
GET /api/v1/intelligence/coordination-detection
```

---

## ✅ IMPLEMENTATION CHECKLIST

### Phase 1: Foundation (Week 1)
- [x] Create intel_daily_activity table
- [x] Create intel_entity_mentions table
- [x] Write compute_intel_daily_activity() procedure
- [ ] Test with 1 day of data
- [x] Create Python scheduler script
- [ ] Add configuration for thresholds

### Phase 2: Intelligence (Week 2)
- [x] Create intel_spike_alerts table
- [x] Implement anomaly detection
- [ ] Create alert endpoints
- [ ] Add daily brief endpoint
- [x] Implement refresh strategy

### Phase 3: Optimization
- [ ] Add indexes for performance
- [ ] Implement incremental updates
- [ ] Add monitoring/logging
- [ ] Performance testing

---

## 🔄 REFRESH STRATEGY

### Approach: Smart Incremental Updates
1. **Daily**: Compute yesterday's data (1 AM)
2. **Every 6 hours**: Refresh last 3 days (late data)
3. **On-demand**: Force refresh via API parameter
4. **Historical**: One-time backfill for past 100 days

### Why Last 3 Days?
- Twitter data can update (likes, retweets increase)
- Late collection from monitored users
- Topic assignments may be refined

---

## 📝 PROGRESS LOG

### 2024-11-20
- ✅ Designed intel_daily_activity schema
- ✅ Designed virality scoring system
- ✅ Created entity_mentions tracking design
- ✅ Implemented all PostgreSQL procedures
- ✅ Created Python scheduler and manual trigger scripts
- ✅ Created setup script for database initialization
- ✅ Added computation log tracking
- ⏳ Pending: API endpoints and testing

### Completed Today
1. ✅ Created all intelligence tables (intel_daily_activity, intel_entity_mentions, intel_spike_alerts, intel_computation_log)
2. ✅ Implemented compute_intel_daily_activity() procedure - aggregates metrics at project/theme/topic levels
3. ✅ Implemented compute_intel_entity_mentions() procedure - extracts hashtags, mentions, domains
4. ✅ Implemented detect_intel_spikes() procedure - anomaly detection with severity levels
5. ✅ Created scheduler.py - automated daily/hourly computation with schedule
6. ✅ Created manual_compute.py - on-demand triggering and testing
7. ✅ Created setup_intelligence_layer.sh - one-command database initialization

### Next Steps
1. Run setup script to create tables in database
2. Test with manual_compute.py
3. Build intelligence API endpoints
4. Integrate with existing FastAPI application

---

## 🚨 IMPORTANT NOTES

1. **All thresholds are configurable** via environment variables
2. **Table prefix `intel_`** distinguishes from raw data
3. **Virality weights** can be adjusted without recomputing
4. **Focus on intelligence**, not data transfer
5. **Keep procedures idempotent** (can re-run safely)

---

## 🔗 RELATED FILES

- `/pre_compute_layer.md` - Original design document
- `/comprehensive_analytics_architecture.md` - System architecture
- `/osint-api/app/config.py` - Configuration settings
- `/scripts/intel_computation/` - Implementation scripts (TODO)

---

**Remember**: This is our source of truth during development. Update status as tasks complete!