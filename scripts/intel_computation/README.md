# OSINT Multi-Tier Intelligence System

**Production-ready OSINT intelligence computation system with optimized performance and strategic analysis capabilities.**

## 🚀 **System Architecture**

### **Multi-Tier Design:**
1. **Core Metrics**: Project/theme daily tracking (fast)
2. **Daily Metrics**: Author activity tracking (12 essential metrics)
3. **Strategic Intelligence**: Coordination detection, influence scoring (periodic)

### **Performance Improvements:**
- **1000x faster** than previous system
- **75% storage reduction** for daily operations
- **O(N) coordination detection** (vs previous O(N²))
- **Configurable analysis periods**: 7, 30, 90 days

## 📊 **Current Data Status**

```
Daily Metrics:     67,738 records  |  24,590 authors  |  2023-2025
Intelligence:      68,968 profiles  |  24,572 authors  |  Aug-Nov 2025
Storage:           Efficient 12+10 metrics vs old 46 metrics/day
```

## 🔧 **Usage**

### **Primary Script:**
```bash
./run_new_metrics_computation.sh [OPTIONS]
```

### **Common Operations:**

**Daily automation** (recommended for cron):
```bash
./run_new_metrics_computation.sh --daily-only
```

**Weekly intelligence analysis**:
```bash
./run_new_metrics_computation.sh --intelligence-only --intelligence-period 7_days
```

**90-day strategic analysis**:
```bash
./run_new_metrics_computation.sh --intelligence-only --intelligence-period 90_days --min-threshold 5
```

**Full system run**:
```bash
./run_new_metrics_computation.sh --full --date 2025-11-16
```

**System status check**:
```bash
./run_new_metrics_computation.sh --check-tables
```

**Historical batch processing**:
```bash
./run_new_metrics_computation.sh --batch 2025-08-01 2025-11-16 --daily-only
```

### **Key Parameters:**

- `--intelligence-period`: `7_days`, `30_days`, `90_days`
- `--min-threshold`: Minimum tweets for intelligence analysis (1, 3, 5, 10)
- `--dry-run`: Test mode without execution
- `--quiet`: Suppress verbose output

## 📋 **Database Tables**

### **New Optimized Schema:**
- `osint.author_daily_metrics`: Fast daily tracking (12 metrics)
- `osint.author_intelligence`: Strategic analysis (10 metrics, periodic)
- `osint.intel_metrics`: Project/theme metrics only (cleaned)

### **Key Metrics:**

**Daily Metrics:**
- Activity: daily_tweets, daily_replies, daily_original_tweets
- Engagement: total_engagement_received, avg_engagement_per_tweet
- Patterns: active_hours, peak_hour, posting_velocity
- Virality: viral_tweets_count
- Cross-platform: cross_theme_activity

**Intelligence Metrics:**
- Influence: influence_score, authority_score, monitoring_priority_score
- Coordination: coordination_risk_score, hashtag_coordination_score
- Network: betweenness_centrality, network_reach, cross_reference_rate
- Content: semantic_diversity_score, amplification_factor

## 🔍 **Discovery Functions**

### **Analytics Queries:**
```sql
-- Daily metrics summary
SELECT * FROM osint.get_daily_metrics_summary('2025-11-16');

-- Top influencers
SELECT * FROM osint.get_top_influencers('2025-11-16', '7_days', 20);

-- Coordination risks
SELECT * FROM osint.get_coordination_risks('2025-11-16', '7_days', 0.5, 15);

-- System performance comparison
SELECT * FROM osint.compare_metrics_performance();
```

### **Trend Analysis:**
```sql
-- Intelligence trends over time
SELECT * FROM osint.get_intelligence_trends('2025-08-01', 'influence_score');

-- Monthly summary
SELECT * FROM osint.get_monthly_intelligence_summary();
```

## 🏗️ **SQL Functions**

### **Core Functions:**
- `osint.compute_author_daily_simple(date)`: Daily metrics
- `osint.compute_author_intelligence(date, period, threshold)`: Strategic analysis
- `osint.compute_author_daily_batch(start, end)`: Historical processing

### **Automated Functions:**
- `osint.compute_periodic_intelligence(start, window, threshold)`: Batch intelligence
- `osint.get_active_analysis_periods(start, threshold)`: Period discovery

## 🗂️ **File Organization**

```
sql/
├── create_author_tables.sql           # Table schemas
├── compute_author_daily_simple.sql    # Daily metrics (optimized)
├── compute_author_intelligence.sql    # Strategic intelligence
├── compute_author_metrics_new.sql     # Main wrapper system
├── periodic_intelligence_analysis.sql # Automated temporal analysis
├── compute_core_metrics.sql          # Project/theme metrics
└── deprecated_old_scripts/            # Archived inefficient scripts

archive_old_docs/                      # Historical documentation
deprecated_scripts/                    # Old automation scripts
```

## ⚙️ **Configuration**

### **Database Connection:**
```bash
export POSTGRES_HOST=localhost
export POSTGRES_PORT=5432
export POSTGRES_DATABASE=neuron
export POSTGRES_USER=tabreaz
export POSTGRES_PASSWORD=admin
```

### **Automation Setup:**
```bash
# Daily cron job (recommended)
0 2 * * * /path/to/run_new_metrics_computation.sh --daily-only --quiet

# Weekly intelligence
0 3 * * 1 /path/to/run_new_metrics_computation.sh --intelligence-only --intelligence-period 7_days --quiet

# Monthly strategic analysis
0 4 1 * * /path/to/run_new_metrics_computation.sh --intelligence-only --intelligence-period 30_days --min-threshold 5 --quiet
```

## 📈 **Success Metrics**

- **Performance**: 35ms per day vs previous timeouts
- **Coverage**: 24,590 authors across 2+ years of data
- **Efficiency**: 75% reduction in storage overhead
- **Scalability**: Handles 100K+ tweets without performance degradation
- **Intelligence**: 68,968 strategic profiles with trend analysis

---

**System Status**: ✅ Production Ready
**Last Updated**: November 2025
**Architecture**: Multi-tier optimized OSINT intelligence platform