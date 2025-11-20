# OSINT Intelligence Architecture for MCP
## Multi-Tier Intelligence System with Strategic Analytics

---

## Executive Summary

This document outlines the **OSINT Intelligence Architecture** designed specifically for **Model Context Protocol (MCP)** integration. The system provides actionable intelligence through strategic analysis rather than basic CRUD operations.

**Architecture Philosophy**: Intelligence-driven APIs that deliver insights, patterns, and threat detection capabilities to AI agents via MCP.

---

## Database Structure & Intelligence Metrics

### **Tier 1: Project-Level Intelligence**
**Purpose**: High-level organizational intelligence and campaign monitoring

**Table**: `osint.intel_metrics` (entity_type = 'project')

**Intelligence Metrics**:
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

---

### **Tier 2: Theme-Level Intelligence**
**Purpose**: Topic-specific intelligence and narrative tracking

**Table**: `osint.intel_metrics` (entity_type = 'theme')

**Intelligence Metrics**:
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

### **Tier 3: Author Daily Intelligence**
**Purpose**: Fast daily tracking of author behavior patterns

**Table**: `osint.author_daily_metrics`

**Intelligence Metrics**:
| Metric | Purpose | Description |
|--------|---------|-------------|
| `daily_tweets` | Activity Volume | Daily posting frequency |
| `daily_replies` | Interaction Level | Reply activity indicating engagement behavior |
| `daily_original_tweets` | Original Content | Non-reply, non-retweet content creation |
| `daily_retweets` | Amplification Behavior | Content amplification patterns |
| `daily_quotes` | Commentary Activity | Quote tweet behavior (adding commentary) |
| `total_engagement_received` | Influence Indicator | Total engagement received across content |
| `avg_engagement_per_tweet` | Content Quality | Average engagement efficiency |
| `active_hours` | Activity Patterns | Hours of day when active (temporal signature) |
| `peak_hour` | Prime Time | Most active hour for activity pattern analysis |
| `posting_velocity` | Intensity Metric | Tweets per active hour (automation indicator) |
| `viral_tweets_count` | Viral Content Production | Number of viral posts created |
| `cross_theme_activity` | Scope Indicator | Number of themes author participates in |

---

### **Tier 4: Author Strategic Intelligence**
**Purpose**: Periodic deep intelligence analysis for threat detection

**Table**: `osint.author_intelligence`

**Intelligence Metrics**:
| Metric | Purpose | Description |
|--------|---------|-------------|
| `influence_score` | Power Assessment | Composite influence score (0-1) based on reach and engagement |
| `authority_score` | Credibility Indicator | Follower-to-following ratio indicating authority |
| `coordination_risk_score` | Threat Detection | Risk score for coordinated inauthentic behavior |
| `betweenness_centrality` | Network Position | Bridge position in communication networks |
| `network_reach` | Connection Scope | Number of unique accounts interacted with |
| `cross_reference_rate` | Interaction Pattern | Rate of referencing other accounts |
| `semantic_diversity_score` | Content Variety | Diversity of topics/hashtags used |
| `hashtag_coordination_score` | Coordination Indicator | Suspicious hashtag usage patterns |
| `monitoring_priority_score` | Priority Ranking | Composite score for monitoring prioritization |
| `amplification_factor` | Reach Multiplier | Retweets received per original tweet |
| `analysis_period` | Time Window | Analysis period (7_days, 30_days, 90_days) |

---

## Intelligence-Focused API Design for MCP

### **Current Problem: CRUD-Based APIs**
The existing API endpoints are designed for dashboard CRUD operations:
- `GET /themes` - List themes (basic data retrieval)
- `POST /themes` - Create theme (CRUD operation)
- `PUT /themes/{id}` - Update theme (CRUD operation)
- `DELETE /themes/{id}` - Delete theme (CRUD operation)

**These APIs don't provide intelligence - they provide data management.**

---

### **NEW: Intelligence APIs for MCP**

#### **1. Threat Detection & Assessment**
```http
GET /api/v1/intelligence/threats/coordination-risks
```
**Purpose**: Identify potential coordinated inauthentic behavior
**Response**:
```json
{
  "high_risk_authors": [
    {
      "author_id": 12345,
      "username": "suspicious_account",
      "coordination_risk_score": 0.89,
      "evidence": {
        "hashtag_coordination": 0.95,
        "timing_patterns": 0.82,
        "content_similarity": 0.91
      },
      "monitoring_priority": 1.0,
      "threat_level": "HIGH"
    }
  ],
  "coordinated_campaigns": [
    {
      "campaign_id": "camp_001",
      "participant_count": 47,
      "coordination_score": 0.94,
      "time_window": "2025-11-15 14:00 - 16:30",
      "shared_content": ["hashtag_xyz", "narrative_abc"]
    }
  ]
}
```

#### **2. Influence Network Analysis**
```http
GET /api/v1/intelligence/influence/network-analysis
```
**Purpose**: Identify key influencers and their network positions
**Response**:
```json
{
  "network_analysis": {
    "bridge_accounts": [
      {
        "author_id": 67890,
        "username": "bridge_account",
        "betweenness_centrality": 0.76,
        "network_reach": 1250,
        "role": "Information Bridge",
        "influence_score": 0.85
      }
    ],
    "emerging_influencers": [
      {
        "author_id": 54321,
        "growth_rate": 0.34,
        "influence_trajectory": "rising",
        "monitoring_priority": 0.78
      }
    ],
    "network_metrics": {
      "total_nodes": 15420,
      "total_edges": 45230,
      "cluster_count": 12,
      "network_density": 0.19
    }
  }
}
```

#### **3. Narrative Intelligence & Trends**
```http
GET /api/v1/intelligence/narratives/evolution
```
**Purpose**: Track how narratives evolve and detect emerging discussions
**Response**:
```json
{
  "narrative_intelligence": {
    "trending_themes": [
      {
        "theme_id": 15,
        "theme_name": "Climate Policy",
        "growth_rate": 0.45,
        "engagement_velocity": 234.5,
        "viral_content_count": 23,
        "risk_indicators": ["rapid_growth", "coordination_detected"]
      }
    ],
    "emerging_narratives": [
      {
        "cluster_id": "emerg_001",
        "size": 145,
        "growth_rate": 0.67,
        "distinctive_keywords": ["new_policy", "urgent_action"],
        "estimated_reach": 50000,
        "confidence": 0.82
      }
    ],
    "narrative_shifts": [
      {
        "theme_id": 8,
        "shift_type": "sentiment_change",
        "magnitude": 0.34,
        "direction": "negative",
        "timeframe": "last_48_hours"
      }
    ]
  }
}
```

#### **4. Real-Time Intelligence Alerts**
```http
GET /api/v1/intelligence/alerts/active
```
**Purpose**: Provide real-time intelligence alerts for immediate action
**Response**:
```json
{
  "active_alerts": [
    {
      "alert_id": "alert_001",
      "type": "coordination_spike",
      "severity": "HIGH",
      "detected_at": "2025-11-16T14:30:00Z",
      "description": "Unusual coordination detected in climate discussion",
      "affected_themes": [12, 15, 18],
      "participants": 67,
      "evidence_score": 0.91,
      "recommended_action": "immediate_investigation"
    },
    {
      "alert_id": "alert_002",
      "type": "influence_surge",
      "severity": "MEDIUM",
      "detected_at": "2025-11-16T13:15:00Z",
      "description": "New high-influence account emerged",
      "author_id": 98765,
      "influence_growth": 0.54,
      "monitoring_priority": 0.78
    }
  ]
}
```

#### **5. Strategic Intelligence Summary**
```http
GET /api/v1/intelligence/summary/strategic
```
**Purpose**: High-level intelligence briefing for strategic decision making
**Response**:
```json
{
  "strategic_intelligence": {
    "period": "last_7_days",
    "overall_threat_level": "MEDIUM",
    "key_findings": {
      "coordination_incidents": 3,
      "new_influencers_detected": 12,
      "narrative_shifts": 5,
      "viral_campaigns": 8
    },
    "top_threats": [
      {
        "threat_type": "coordinated_campaign",
        "confidence": 0.87,
        "impact_assessment": "medium",
        "geographic_focus": "regional",
        "themes_affected": ["climate", "policy", "energy"]
      }
    ],
    "intelligence_gaps": [
      "limited_coverage_southeast",
      "need_more_arabic_sources"
    ],
    "recommendations": [
      "increase_monitoring_theme_12",
      "investigate_author_cluster_abc",
      "expand_collection_queries"
    ]
  }
}
```

---

## Intelligence Functions for MCP Integration

### **Available SQL Intelligence Functions**:

```sql
-- Strategic Intelligence
osint.compute_author_intelligence(date, period, threshold)
osint.get_top_influencers(date, period, limit)
osint.get_coordination_risks(date, period, min_risk, limit)
osint.get_network_bridges(date, period, min_centrality, limit)

-- Trend Analysis
osint.get_intelligence_trends(start_date, metric_name)
osint.get_monthly_intelligence_summary()
osint.compute_periodic_intelligence(start_date, window, threshold)

-- Discovery & Analytics
osint.get_daily_metrics_summary(date)
osint.get_author_intelligence_summary(date, period, limit)
osint.compare_metrics_performance()
```

---

## Next Steps: API Cleanup & Redesign

### **Phase 1: Remove Non-Intelligence APIs**
**APIs to Remove/Deprecate**:
- Basic CRUD operations (`POST /themes`, `PUT /themes/{id}`, etc.)
- Simple data retrieval without intelligence value
- Dashboard-specific formatting endpoints
- Pagination-heavy list endpoints

### **Phase 2: Intelligence API Implementation**
**Priority Order**:
1. **Threat Detection APIs** - Coordination & influence analysis
2. **Real-time Alerts** - Immediate intelligence notifications
3. **Strategic Intelligence** - High-level briefings and trends
4. **Network Analysis** - Influence mapping and bridge detection
5. **Narrative Intelligence** - Content evolution and emerging discussions

### **Phase 3: MCP Integration**
**MCP-Specific Features**:
- **Context-aware responses**: APIs that understand the intelligence context
- **Actionable insights**: Every response includes recommended actions
- **Confidence scoring**: All intelligence includes confidence/reliability scores
- **Natural language summaries**: Human-readable intelligence briefings
- **Threat prioritization**: Risk-based ranking of all findings

---

## Success Metrics for Intelligence APIs

### **Intelligence Quality**:
- **Threat Detection Accuracy**: >85% true positive rate on coordination detection
- **Influence Prediction**: >80% accuracy in identifying emerging influencers
- **Alert Relevance**: >90% of alerts lead to actionable intelligence
- **Response Time**: <200ms for real-time intelligence queries

### **MCP Integration Success**:
- **Context Relevance**: AI agents can effectively use intelligence for decision-making
- **Action Rate**: >70% of intelligence leads to investigative actions
- **False Positive Rate**: <15% for high-confidence alerts
- **Intelligence Coverage**: >95% of significant events detected within 4 hours

---

**System Status**: 🚧 Ready for Intelligence API Development
**Current Focus**: Transform CRUD APIs → Intelligence APIs for MCP
**Architecture**: Multi-tier intelligence with 68,968 strategic profiles ready for analysis