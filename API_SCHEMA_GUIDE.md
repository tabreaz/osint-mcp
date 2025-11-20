# API Schema Guide

## Overview
This guide describes the data schemas and models used by the OSINT Monitoring API. It focuses on the refined, production-ready data structures that the API exposes.

## Primary Data Models

### 1. Topics (Refined & Categorized)
**Table**: `topic_definitions_refined`
**Purpose**: Clean, LLM-enhanced topics with actionable recommendations

**Key Fields**:
- `topic_id` - Unique identifier
- `refined_name` - Clean, readable name (e.g., "Sudan Humanitarian Crisis")
- `category` - High-level category (e.g., "Humanitarian Crisis", "Political Campaign")
- `subcategory` - Specific subcategory
- `monitoring_priority` - Priority level: high | medium | low | ignore
- `recommended_actions` - Machine-readable monitoring instructions
- `quality_score` - Topic quality (0-1)
- `relevance_to_project` - Project relevance (0-1)

**API Access**: `/api/v1/topics/*`

### 2. Themes (Business Categories)
**Table**: `themes`
**Purpose**: Manually defined monitoring categories

**Key Fields**:
- `id` - Theme identifier
- `name` - Theme name
- `code` - Short code
- `description` - Theme description
- `priority` - Business priority
- `is_active` - Active status

**API Access**: `/api/v1/themes/*`

### 3. Projects (Organizational Units)
**Table**: `projects`
**Purpose**: High-level project organization

**Key Fields**:
- `id` - Project identifier
- `name` - Project name
- `description` - Project description
- `is_active` - Active status

**API Access**: `/api/v1/projects/*`

### 4. Monitored Users
**Table**: `monitored_users`
**Purpose**: Tracked social media accounts

**Key Fields**:
- `user_id` - User identifier
- `username` - Social media handle
- `display_name` - Display name
- `is_active` - Monitoring status
- `monitoring_reason` - Why tracked

**API Access**: `/api/v1/monitored-users/*`

### 5. Topic Analytics

#### Author Expertise
**Table**: `author_topics`
**Purpose**: Track author expertise in topics

**Key Fields**:
- `author_id` - Author identifier
- `topic_id` - Topic identifier
- `tweet_count` - Posts on topic
- `avg_probability` - Expertise score
- `total_engagement` - Total engagement

**API Access**: `/api/v1/topic-analytics/author-expertise`

#### Topic Evolution
**Table**: `topic_evolution`
**Purpose**: Time-series topic trends

**Key Fields**:
- `topic_id` - Topic identifier
- `date` - Timestamp
- `tweet_count` - Volume
- `growth_rate` - Growth percentage
- `viral_tweets` - Viral content count

**API Access**: `/api/v1/topic-analytics/evolution-trends`

## Response Schemas

### Topic Response
```json
{
  "topic_id": 26,
  "name": "Sudan Humanitarian Crisis",
  "category": "Humanitarian Crisis",
  "priority": "high",
  "quality_score": 0.85,
  "relevance": 0.92,
  "recommended_actions": [
    {
      "action_type": "add_query",
      "query": "Sudan RSF civilians",
      "frequency": "real-time",
      "reason": "Critical monitoring"
    }
  ]
}
```

### Theme Response
```json
{
  "id": 1,
  "name": "Sudan Conflict",
  "code": "SUDAN",
  "description": "Monitoring Sudan humanitarian situation",
  "priority": 1,
  "tweet_count": 15420
}
```

### Author Expertise Response
```json
{
  "author_id": "user123",
  "topic_id": 26,
  "topic_name": "Sudan Humanitarian Crisis",
  "tweet_count": 45,
  "avg_probability": 0.78,
  "total_engagement": 12500
}
```

## Important Notes

### What We DON'T Expose
- Raw tweet data structures (internal)
- Unrefined topic definitions (messy ML output)
- Database connection details
- Internal processing tables

### What We DO Expose
- Refined, categorized topics ✅
- Clean business themes ✅
- Actionable recommendations ✅
- Computed analytics ✅

## API Design Principles

1. **Always Use Refined Data**
   - Never expose raw ML output
   - All topics come from `topic_definitions_refined`

2. **Machine-Readable Actions**
   - Recommendations include specific queries
   - Actions have clear types and frequencies

3. **Clean Abstractions**
   - Hide database complexity
   - Expose logical business entities

4. **Computed Metrics**
   - Calculate analytics on-demand if needed
   - Don't rely on empty preprocessing tables

## Quick Reference

| Entity | Primary Table | API Endpoint |
|--------|--------------|--------------|
| Topics | topic_definitions_refined | /api/v1/topics |
| Themes | themes | /api/v1/themes |
| Projects | projects | /api/v1/projects |
| Users | monitored_users | /api/v1/monitored-users |
| Topic Analytics | author_topics, topic_evolution | /api/v1/topic-analytics |

## For MCP Agents

When working with this API:
1. Use `/api/v1/topics/refined` for topic data (NOT raw)
2. Use `/api/v1/topics/actionable` for monitoring setup
3. Use `/api/v1/topic-analytics/*` for relationships
4. Ignore any mention of "raw" or "unrefined" data