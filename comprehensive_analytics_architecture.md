# Comprehensive OSINT Analytics Architecture
## Unified Theme, Topic, and Embedding Analytics System

---

## Executive Summary

This document outlines a comprehensive analytics architecture that unifies three complementary approaches:
1. **Theme-based Analytics** - Business-defined categories with traditional metrics
2. **ML Topic Modeling** - Unsupervised discovery of semantic clusters
3. **Embedding Similarity** - Deep semantic understanding via vector operations

---

## Current Database Infrastructure

### Core Tables
1. **Tweets & Collections**
   - `tweets_deduplicated` - Core tweet data with engagement metrics
   - `tweet_collections` - Collection session metadata
   - `collection_sessions` - Links tweets to themes/queries

2. **Themes & Projects**
   - `themes` - Manually defined monitoring themes
   - `projects` - High-level organizational units
   - `queries` - Search queries associated with themes
   - `monitored_users` - Tracked user accounts

3. **Network & Relationships**
   - `user_network` - User interaction patterns
   - `twitter_user_profiles` - User profile information

### ML/AI Tables (Advanced Analytics)
4. **Embeddings**
   - `tweet_embeddings` - 512-dim vectors from OpenAI text-embedding-3-small
   - IVFFlat index for fast similarity search

5. **Topic Modeling**
   - `topic_definitions` - ML-discovered topics with keywords and coherence scores
   - `tweet_topics` - Tweet-to-topic assignments with probabilities
   - `author_topics` - Author expertise tracking
   - `topic_evolution` - Time-series topic trends
   - `topic_relationships` - Inter-topic connections

6. **Media**
   - `tweet_media` - Media URLs and metadata

---

## Three-Layer Analytics Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Layer 1: Theme Analytics                  │
│                 (Business/Operational View)                  │
├─────────────────────────────────────────────────────────────┤
│ • Human-defined categories based on business needs           │
│ • Query-based data collection                                │
│ • Traditional metrics (CAGR, engagement, reach)              │
│ • Time-series analysis                                       │
│ • Hashtag frequency analysis                                 │
└─────────────────────────────────────────────────────────────┘
                              ↓↑
┌─────────────────────────────────────────────────────────────┐
│                  Layer 2: Topic Modeling                     │
│               (ML-Discovered Semantic Clusters)              │
├─────────────────────────────────────────────────────────────┤
│ • Unsupervised topic discovery (LDA/BERTopic)               │
│ • Probability distributions per tweet                        │
│ • Author expertise identification                            │
│ • Topic coherence and diversity scores                       │
│ • Evolution tracking over time                               │
└─────────────────────────────────────────────────────────────┘
                              ↓↑
┌─────────────────────────────────────────────────────────────┐
│                 Layer 3: Embedding Similarity                │
│                (Deep Semantic Understanding)                 │
├─────────────────────────────────────────────────────────────┤
│ • Vector similarity search                                   │
│ • Semantic cohesion measurement                              │
│ • Narrative drift detection                                  │
│ • Duplicate/near-duplicate detection                         │
│ • Cross-language semantic matching                           │
└─────────────────────────────────────────────────────────────┘
```

---

## Unified Analytics Capabilities

### 1. Theme Health & Performance (Original Phase 2)
**Purpose**: Monitor performance of manually defined themes

#### Endpoints:
- `GET /api/v1/analytics/themes` - List themes with health scores
- `GET /api/v1/analytics/themes/{id}/health` - Detailed metrics with CAGR
- `GET /api/v1/analytics/themes/{id}/timeline` - Daily activity with rolling averages
- `GET /api/v1/analytics/themes/{id}/hashtags` - Top hashtags
- `GET /api/v1/analytics/themes/{id}/influencers` - Top authors by engagement
- `GET /api/v1/analytics/themes/{id}/hourly` - Hourly activity patterns
- `POST /api/v1/analytics/themes/compare` - Compare multiple themes

#### Key Metrics:
- **CAGR (Compound Annual Growth Rate)**: Growth velocity indicator
- **Engagement Trends**: Likes, retweets, replies over time
- **Author Diversity**: Unique authors vs total tweets
- **Temporal Patterns**: Peak activity hours/days

---

### 2. Semantic Cohesion & Quality

**Purpose**: Measure how semantically focused themes and topics are

#### New Endpoints:
- `GET /api/v1/analytics/themes/{id}/semantic-cohesion`
  ```json
  {
    "theme_id": 1,
    "cohesion_score": 0.73,  // 0-1, higher = more focused
    "interpretation": "moderately cohesive",
    "sub_clusters": 3,
    "outlier_percentage": 5.2,
    "representative_centroid": [0.123, -0.456, ...],
    "variance": 0.31
  }
  ```

- `GET /api/v1/analytics/topics/{id}/semantic-quality`
  ```json
  {
    "topic_id": 42,
    "coherence_score": 0.81,  // From topic_definitions
    "embedding_cohesion": 0.76,  // From embeddings
    "combined_quality": 0.785,
    "interpretation": "high quality, well-defined topic"
  }
  ```

#### Implementation:
```sql
-- Calculate semantic cohesion for a theme
WITH theme_embeddings AS (
    SELECT e.embedding
    FROM tweet_embeddings e
    JOIN tweets t ON e.tweet_id = t.tweet_id
    JOIN collection_sessions cs ON t.session_id = cs.session_id
    WHERE cs.theme_id = :theme_id
    LIMIT 1000  -- Sample for performance
),
pairwise_similarities AS (
    SELECT
        1 - (e1.embedding <=> e2.embedding) as similarity
    FROM theme_embeddings e1
    CROSS JOIN theme_embeddings e2
    WHERE e1.embedding != e2.embedding
)
SELECT
    AVG(similarity) as cohesion_score,
    STDDEV(similarity) as variance,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY similarity) as median_similarity
FROM pairwise_similarities;
```

---

### 3. Theme-Topic Alignment Analysis

**Purpose**: Understand how ML topics map to business themes

#### New Endpoints:
- `GET /api/v1/analytics/themes/{id}/topic-alignment`
  ```json
  {
    "theme_id": 1,
    "theme_name": "Climate Policy",
    "dominant_topics": [
      {
        "topic_id": 23,
        "topic_name": "renewable_energy",
        "tweet_percentage": 34.5,
        "avg_probability": 0.67,
        "keywords": ["solar", "wind", "renewable"]
      }
    ],
    "topic_diversity": 0.68,  // Shannon entropy
    "unexpected_topics": [...]  // Topics with low expected probability
  }
  ```

- `GET /api/v1/analytics/alignment/matrix`
  - Returns theme-to-topic correlation matrix
  - Identifies themes with overlapping topics

#### Use Cases:
- Validate if themes capture intended content
- Discover unexpected discussions within themes
- Identify theme drift over time

---

### 4. Expert Network Discovery

**Purpose**: Identify subject matter experts and influencers

#### New Endpoints:
- `GET /api/v1/analytics/experts/by-topic/{topic_id}`
  ```json
  {
    "topic_id": 23,
    "experts": [
      {
        "author_id": "12345",
        "username": "@energy_expert",
        "expertise_score": 0.89,  // avg_probability from author_topics
        "tweet_count": 156,
        "total_engagement": 45000,
        "consistency": 0.92  // How consistently they discuss this topic
      }
    ]
  }
  ```

- `GET /api/v1/analytics/themes/{id}/expert-network`
  - Cross-references theme tweets with author expertise
  - Returns network graph data for visualization

#### Implementation:
```sql
-- Find experts for a theme based on topic expertise
WITH theme_topics AS (
    SELECT DISTINCT tt.topic_id, COUNT(*) as topic_count
    FROM tweets t
    JOIN collection_sessions cs ON t.session_id = cs.session_id
    JOIN tweet_topics tt ON t.tweet_id = tt.tweet_id
    WHERE cs.theme_id = :theme_id
    GROUP BY tt.topic_id
),
expert_scores AS (
    SELECT
        at.author_id,
        up.username,
        SUM(at.avg_probability * tt.topic_count) / SUM(tt.topic_count) as expertise_score,
        SUM(at.tweet_count) as total_tweets,
        SUM(at.total_engagement) as total_engagement
    FROM author_topics at
    JOIN theme_topics tt ON at.topic_id = tt.topic_id
    LEFT JOIN twitter_user_profiles up ON at.author_id = up.user_id
    GROUP BY at.author_id, up.username
)
SELECT * FROM expert_scores
ORDER BY expertise_score DESC
LIMIT 20;
```

---

### 5. Narrative Evolution & Drift Detection

**Purpose**: Track how discussions evolve over time

#### New Endpoints:
- `GET /api/v1/analytics/themes/{id}/narrative-evolution`
  ```json
  {
    "theme_id": 1,
    "time_periods": [
      {
        "period": "2024-01-01 to 2024-01-07",
        "dominant_topics": [23, 45, 67],
        "centroid_embedding": [...],
        "drift_from_previous": 0.23  // Semantic distance
      }
    ],
    "total_drift": 0.67,
    "drift_interpretation": "significant narrative shift detected"
  }
  ```

- `GET /api/v1/analytics/topics/{id}/evolution`
  - Uses topic_evolution table
  - Tracks keyword changes over time
  - Identifies topic splits/merges

#### Visualization Support:
- Time-series of topic distributions
- Embedding space trajectory over time
- Sankey diagrams for topic flow

---

### 6. Emerging Patterns & Anomaly Detection

**Purpose**: Early warning system for new narratives

#### New Endpoints:
- `GET /api/v1/analytics/themes/{id}/emerging-clusters`
  ```json
  {
    "emerging_clusters": [
      {
        "cluster_id": "temporal_cluster_1",
        "size": 45,
        "growth_rate": 0.34,  // per day
        "representative_tweets": [...],
        "distinctive_keywords": ["new_term", "emerging_issue"],
        "centroid_distance_from_theme": 0.56
      }
    ]
  }
  ```

- `GET /api/v1/analytics/anomalies/detect`
  - Outlier tweets (low topic probability + far from embeddings)
  - Sudden topic distribution changes
  - Unusual author behavior patterns

#### Detection Methods:
1. **Statistical**: Z-score on engagement, topic probabilities
2. **Embedding-based**: Distance from cluster centroids
3. **Temporal**: Sudden changes in topic evolution

---

### 7. Cross-Theme Intelligence

**Purpose**: Discover hidden connections between themes

#### New Endpoints:
- `GET /api/v1/analytics/cross-theme/similarity-matrix`
  ```json
  {
    "similarity_matrix": [
      [1.0, 0.45, 0.23],  // Theme similarities
      [0.45, 1.0, 0.67],
      [0.23, 0.67, 1.0]
    ],
    "theme_ids": [1, 2, 3],
    "method": "embedding_centroid_similarity"
  }
  ```

- `GET /api/v1/analytics/cross-theme/topic-bridges`
  - Topics appearing in multiple themes
  - Information cascade paths
  - Narrative migration patterns

---

### 8. Content Authentication & Campaign Detection

**Purpose**: Identify coordinated inauthentic behavior

#### New Endpoints:
- `GET /api/v1/analytics/campaigns/detect`
  ```json
  {
    "potential_campaigns": [
      {
        "cluster_id": "campaign_1",
        "indicators": {
          "temporal_coordination": 0.89,  // Tweets at same time
          "semantic_similarity": 0.94,     // Very similar content
          "author_network_density": 0.76,  // Authors connected
          "media_reuse": 0.82             // Same media shared
        },
        "tweet_count": 234,
        "unique_authors": 12,
        "time_window": "2 hours",
        "confidence": 0.85
      }
    ]
  }
  ```

#### Detection Algorithm:
1. Find high-similarity tweet clusters (embeddings)
2. Check temporal patterns
3. Analyze author relationships
4. Verify media reuse patterns
5. Calculate confidence score

---

### 9. Media Pattern Analysis

**Purpose**: Track visual narrative trends

#### New Endpoints:
- `GET /api/v1/analytics/themes/{id}/media-patterns`
  ```json
  {
    "unique_media_items": 345,
    "media_reuse_rate": 0.34,
    "viral_media": [
      {
        "media_url": "...",
        "share_count": 567,
        "unique_authors": 234,
        "velocity": 45.3  // shares per hour
      }
    ],
    "media_clusters": [...]  // Similar media grouped
  }
  ```

---

## Implementation Roadmap

### Phase 1: Foundation (Week 1)
1. ✅ Create models for all ML tables
2. ✅ Build base repositories with vector operations
3. ✅ Implement original Phase 2 theme analytics

### Phase 2: Semantic Layer (Week 2)
1. Add embedding similarity endpoints
2. Implement cohesion scoring
3. Create clustering services

### Phase 3: Topic Integration (Week 3)
1. Theme-topic alignment analysis
2. Expert network discovery
3. Cross-reference all three layers

### Phase 4: Advanced Analytics (Week 4)
1. Narrative evolution tracking
2. Anomaly detection
3. Campaign identification

### Phase 5: Optimization & UI (Week 5)
1. Performance optimization
2. Caching strategies
3. Visualization support
4. Dashboard integration

---

## Performance Considerations

### Caching Strategy
```python
# Redis cache for expensive calculations
@cache.memoize(timeout=3600)
async def get_theme_cohesion(theme_id: int):
    # Expensive embedding calculations
    pass
```

### Batch Processing
```python
# Background jobs for heavy computations
@celery.task
def update_theme_clusters():
    # Run nightly cluster updates
    pass
```

### Query Optimization
- Use materialized views for frequently accessed aggregations
- Implement pagination for large result sets
- Sample embeddings for real-time calculations

---

## Success Metrics

### Technical KPIs
- API response time < 500ms for most endpoints
- Clustering accuracy > 80% (silhouette score)
- Anomaly detection precision > 70%

### Business Value
- 50% reduction in time to identify emerging narratives
- 80% improvement in expert identification accuracy
- 90% accuracy in coordinated campaign detection

---

## Security & Privacy

### Data Protection
- No PII in embeddings
- Author anonymization options
- Rate limiting on API endpoints

### Access Control
- Role-based permissions
- Audit logging
- API key rotation

---

## Future Enhancements

### Near-term (3-6 months)
1. Multi-language support via multilingual embeddings
2. Real-time streaming analytics
3. Custom topic model training

### Long-term (6-12 months)
1. Graph neural networks for network analysis
2. Transformer-based narrative prediction
3. Automated report generation

---

## Conclusion

This unified architecture leverages:
- **Traditional metrics** for business understanding
- **ML topics** for semantic discovery
- **Embeddings** for deep similarity analysis

Together, they provide unprecedented insight into information flows, narrative evolution, and influence networks in your OSINT data.

The system is designed to be:
- **Modular**: Each layer can function independently
- **Scalable**: PostgreSQL + caching handles large volumes
- **Actionable**: Clear metrics and interpretations
- **Extensible**: Easy to add new analytics capabilities