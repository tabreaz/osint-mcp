# Phase 2: Theme Analytics API - Claude CLI Implementation Guide

Excellent idea! Let's leverage Claude CLI just like Phase 1. This will make the implementation much cleaner and faster.

---

## 🎯 Phase 2 Objective

Extend the existing FastAPI application with **Theme Analytics endpoints** that API-ify your `theme_analytics_report.py` functionality.

---

## 📋 What We're Building

**9 New Analytics Endpoints:**
```
GET  /api/v1/analytics/themes                          # List all themes with health scores
GET  /api/v1/analytics/themes/{theme_id}/health        # Detailed theme health metrics
GET  /api/v1/analytics/themes/{theme_id}/trend         # Trend analysis (CAGR, growth status)
GET  /api/v1/analytics/themes/{theme_id}/engagement    # Engagement metrics over time
GET  /api/v1/analytics/themes/{theme_id}/timeline      # Daily activity timeline with rolling averages
GET  /api/v1/analytics/themes/{theme_id}/hashtags      # Top hashtags for theme
GET  /api/v1/analytics/themes/{theme_id}/influencers   # Top influencers in theme
GET  /api/v1/analytics/themes/{theme_id}/hourly        # Hourly activity patterns
POST /api/v1/analytics/themes/compare                  # Compare multiple themes
```

---

## 🏗️ Implementation Structure

We'll add these new components to your existing `osint-api/` project:

```
osint-api/
├── app/
│   ├── schemas/
│   │   └── analytics.py           # NEW: Analytics response schemas
│   │
│   ├── repositories/
│   │   └── theme_analytics_repository.py  # NEW: Theme analytics queries
│   │
│   ├── services/
│   │   └── theme_analytics_service.py     # NEW: Business logic & calculations
│   │
│   └── routers/
│       └── analytics/
│           ├── __init__.py        # NEW
│           └── themes.py          # NEW: Theme analytics endpoints
```

---

## 📝 Claude CLI Instructions

### **Prompt 1: Create Analytics Schemas**

```
I need to extend my FastAPI OSINT API with theme analytics endpoints. This is Phase 2 of the project.

First, create the Pydantic response schemas for theme analytics endpoints.

Create file: app/schemas/analytics.py

Requirements:
1. Create these Pydantic models (all with from_attributes = True):

   - ThemeHealthMetrics: Contains metrics (total_tweets, total_engagement, unique_authors, avg_daily_tweets, avg_engagement_per_tweet, tweets_per_author)
   
   - ThemeTrendData: Contains trend analysis (status: str, trend_color: str, cagr_percentage: float, first_period_avg: float, last_period_avg: float, percent_change: float)
   
   - EngagementTrends: Contains engagement breakdown (avg_likes_per_tweet, avg_retweets_per_tweet, avg_replies_per_tweet, engagement_rate_change: float)
   
   - ThemeHealthResponse: Main response with theme_id, theme_name, theme_code, period (start_date, end_date, days), metrics: ThemeHealthMetrics, trend: ThemeTrendData, engagement_trends: EngagementTrends
   
   - DailyActivityPoint: Single day data (activity_date, daily_tweets, daily_engagement, daily_authors, tweets_7day_avg, engagement_7day_avg)
   
   - ThemeTimelineResponse: Timeline data with theme info and daily_data: list[DailyActivityPoint]
   
   - ThemeHashtag: Hashtag data (hashtag: str, usage_count: int, unique_authors: int, total_engagement: int)
   
   - ThemeInfluencer: Influencer data (author_username: str, author_id: str, tweet_count: int, total_engagement: int, avg_engagement_per_tweet: float, avg_virality: float, active_days: int)
   
   - HourlyActivity: Hourly pattern (hour: int, tweet_count: int, avg_engagement: float)
   
   - ThemeComparisonItem: Single theme comparison (theme_id, theme_name, theme_code, total_tweets, total_engagement, cagr_percentage, trend_status)
   
   - ThemeListItem: Summary for list view (theme_id, theme_name, theme_code, priority, total_tweets, total_engagement, trend_status, trend_color, last_updated)

2. Use proper Python type hints (int, float, str, datetime, list, Optional)
3. Add docstrings explaining each model
4. Include example values in docstrings for API documentation

Reference my existing theme_analytics_report.py for the data structure patterns.
```

---

### **Prompt 2: Create Analytics Repository**

```
Now create the repository layer for theme analytics that queries the PostgreSQL database.

Create file: app/repositories/theme_analytics_repository.py

Requirements:
1. Create ThemeAnalyticsRepository class that takes AsyncSession in __init__
2. The repository should query these existing tables from osint schema:
   - osint.themes (id, project_id, name, code, description, priority, is_active)
   - osint.tweets (via collection_sessions)
   - osint.collection_sessions (session_id, theme_id, query_id, project_id)

3. Implement these async methods:

   async def get_active_themes() -> list[Theme]:
   # Fetch all active themes ordered by priority

   async def get_theme_by_id(theme_id: int) -> Theme | None:
   # Fetch single theme by ID

   async def get_theme_daily_metrics(theme_id: int, start_date: datetime, end_date: datetime) -> list[dict]:
   # Complex query that returns daily aggregated metrics:
   # - activity_date (DATE)
   # - daily_tweets (COUNT DISTINCT tweet_id)
   # - daily_authors (COUNT DISTINCT author_id)
   # - daily_sessions (COUNT DISTINCT session_id)
   # - daily_likes, daily_retweets, daily_replies, daily_quotes (SUM)
   # - daily_total_engagement (SUM of all engagement)
   # - avg_text_length, avg_virality_score
   # - tweets_with_hashtags
   # - morning_tweets, afternoon_tweets, evening_tweets, night_tweets (by hour)
   # - original_tweets, retweets, replies, quotes (by tweet_type)
   # Join: tweets t INNER JOIN collection_sessions cs ON t.session_id = cs.session_id
   # Filter: cs.theme_id = theme_id AND t.created_at BETWEEN start_date AND end_date
   # Group by: DATE(t.created_at)
   # Order by: activity_date

   async def get_theme_hashtags(theme_id: int, start_date: datetime, end_date: datetime, limit: int = 15) -> list[dict]:
   # Query top hashtags for theme
   # Unnest hashtags array, count usage, unique authors, total engagement
   # Order by usage_count DESC

   async def get_theme_top_authors(theme_id: int, start_date: datetime, end_date: datetime, limit: int = 20) -> list[dict]:
   # Query top authors/influencers for theme
   # Aggregate: tweet_count, total_engagement, avg_engagement, virality, active_days
   # Order by total_engagement DESC

   async def get_theme_hourly_activity(theme_id: int, start_date: datetime, end_date: datetime) -> list[dict]:
   # Query hourly activity patterns (0-23)
   # Group by EXTRACT(HOUR FROM created_at)
   # Return: hour, tweet_count, avg_engagement

4. Use SQLAlchemy 2.0 async syntax with select() statements
5. Reference the database schema from DATABASE_SCHEMA.md
6. Add proper error handling and type hints
7. Use parameterized queries to prevent SQL injection

Note: The tweets table joins to collection_sessions via session_id, and collection_sessions links to themes via theme_id.
```

---

### **Prompt 3: Create Analytics Service**

```
Now create the service layer that contains business logic and calculations for theme analytics.

Create file: app/services/theme_analytics_service.py

Requirements:
1. Create ThemeAnalyticsService class that takes ThemeAnalyticsRepository in __init__

2. Implement these async methods with business logic:

   async def calculate_theme_health(theme_id: int, days: int = 100) -> ThemeHealthResponse:
   # Logic:
   # - Fetch theme details
   # - Fetch daily metrics for last N days
   # - Calculate CAGR (Compound Annual Growth Rate):
   #   * Split period into first 25% and last 25%
   #   * Calculate averages for each period
   #   * CAGR = ((last_period_avg / first_period_avg) ** (1 / (days/365))) - 1) * 100
   # - Determine trend status:
   #   * If CAGR > 5%: "growing" (RED color #d32f2f)
   #   * If CAGR < -5%: "declining" (BLUE color #1976d2)
   #   * Else: "stable" (GRAY color #757575)
   # - Calculate aggregated metrics (total tweets, engagement, authors)
   # - Calculate engagement trends (likes, retweets, replies per tweet)
   # - Return ThemeHealthResponse

   async def get_theme_timeline(theme_id: int, days: int = 100) -> ThemeTimelineResponse:
   # Logic:
   # - Fetch daily metrics
   # - Calculate 7-day rolling averages for tweets, engagement, authors
   # - Return timeline with both raw and smoothed data

   async def get_theme_hashtags(theme_id: int, days: int = 100, limit: int = 15) -> list[ThemeHashtag]:
   # Fetch top hashtags from repository and return as schema objects

   async def get_theme_influencers(theme_id: int, days: int = 100, limit: int = 20) -> list[ThemeInfluencer]:
   # Fetch top authors/influencers and return as schema objects

   async def get_theme_hourly_patterns(theme_id: int, days: int = 100) -> list[HourlyActivity]:
   # Fetch hourly activity and return as schema objects

   async def compare_themes(theme_ids: list[int], days: int = 100) -> list[ThemeComparisonItem]:
   # Logic:
   # - For each theme, calculate health metrics
   # - Return comparison data for all themes
   # - Useful for cross-theme analysis

   async def list_themes_with_health() -> list[ThemeListItem]:
   # Logic:
   # - Fetch all active themes
   # - For each theme, calculate summary health metrics (light version)
   # - Return list suitable for dashboard display

3. Reference the calculation logic from my theme_analytics_report.py file
4. Use proper async/await patterns
5. Add error handling for missing themes or no data
6. Include docstrings explaining the business logic

Key calculations to implement:
- CAGR formula: ((end_value / start_value) ** (1 / periods)) - 1
- Rolling averages: Use pandas-style window calculations or manual loops
- Engagement rate: total_engagement / total_tweets
- Tweets per author: total_tweets / unique_authors
```

---

### **Prompt 4: Create Analytics Router**

```
Now create the FastAPI router for theme analytics endpoints.

Create file: app/routers/analytics/themes.py

Requirements:
1. Create APIRouter with prefix="" and tags=["Theme Analytics"]

2. Implement these endpoints:

   @router.get("/themes")
   async def list_themes_with_health(db: AsyncSession = Depends(get_db), api_key: str = Depends(verify_api_key)):
   # Return list of all themes with health scores
   # Response: list[ThemeListItem]

   @router.get("/themes/{theme_id}/health")
   async def get_theme_health(theme_id: int, days: int = 100, db: AsyncSession = Depends(get_db), api_key: str = Depends(verify_api_key)):
   # Return detailed health metrics for specific theme
   # Response: ThemeHealthResponse
   # Query param: days (default 100, min 7, max 365)

   @router.get("/themes/{theme_id}/timeline")
   async def get_theme_timeline(theme_id: int, days: int = 100, db: AsyncSession = Depends(get_db), api_key: str = Depends(verify_api_key)):
   # Return daily activity timeline with rolling averages
   # Response: ThemeTimelineResponse

   @router.get("/themes/{theme_id}/hashtags")
   async def get_theme_hashtags(theme_id: int, days: int = 100, limit: int = 15, db: AsyncSession = Depends(get_db), api_key: str = Depends(verify_api_key)):
   # Return top hashtags for theme
   # Response: list[ThemeHashtag]

   @router.get("/themes/{theme_id}/influencers")
   async def get_theme_influencers(theme_id: int, days: int = 100, limit: int = 20, db: AsyncSession = Depends(get_db), api_key: str = Depends(verify_api_key)):
   # Return top influencers for theme
   # Response: list[ThemeInfluencer]

   @router.get("/themes/{theme_id}/hourly")
   async def get_theme_hourly_activity(theme_id: int, days: int = 100, db: AsyncSession = Depends(get_db), api_key: str = Depends(verify_api_key)):
   # Return hourly activity patterns
   # Response: list[HourlyActivity]

   @router.post("/themes/compare")
   async def compare_themes(request: ThemeComparisonRequest, db: AsyncSession = Depends(get_db), api_key: str = Depends(verify_api_key)):
   # Compare multiple themes
   # Request body: {"theme_ids": [1, 2, 3], "days": 100}
   # Response: list[ThemeComparisonItem]

3. Use dependency injection: get_db() for database session, verify_api_key() for auth
4. Add proper HTTP status codes: 200 OK, 404 Not Found, 422 Validation Error
5. Add OpenAPI descriptions for each endpoint
6. Handle errors gracefully with HTTPException
7. Validate query parameters (days must be 7-365)

Also create: app/routers/analytics/__init__.py (empty file)
```

---

### **Prompt 5: Update Main Application**

```
Update the main.py file to include the new theme analytics router.

Modify file: app/main.py

Add:
1. Import the new analytics router:
   from app.routers.analytics import themes as analytics_themes_router

2. Include the router in the app:
   app.include_router(
       analytics_themes_router.router,
       prefix="/api/v1/analytics",
       tags=["Theme Analytics"]
   )

3. Update the app description to mention the new analytics capabilities:
   description = """
   OSINT Monitoring API provides endpoints for:
   - Tweet retrieval and search
   - Theme management and analytics
   - Network relationship analytics
   - User profile information
   - **NEW: Advanced theme analytics with trend detection**
   """

Keep all existing routers and configuration unchanged.
```

---

### **Prompt 6: Create Testing Script**

```
Create a comprehensive testing script for the new theme analytics endpoints.

Create file: tests/test_theme_analytics.sh

Requirements:
1. Bash script that tests all 7 new endpoints
2. Use curl with proper headers (X-API-Key)
3. Test different parameter combinations
4. Include error cases (invalid theme_id, invalid days parameter)
5. Pretty print JSON responses with jq if available
6. Add comments explaining each test

Example structure:
#!/bin/bash
API_KEY="dev-key-12345"
BASE_URL="http://localhost:8000/api/v1/analytics"

echo "Testing Theme Analytics Endpoints..."

# Test 1: List all themes with health
echo -e "\n1. List all themes with health scores"
curl -s "$BASE_URL/themes" -H "X-API-Key: $API_KEY" | jq

# Test 2: Get theme health
echo -e "\n2. Get theme health for theme_id=1"
curl -s "$BASE_URL/themes/1/health?days=100" -H "X-API-Key: $API_KEY" | jq

# Test 3: Get theme timeline
echo -e "\n3. Get theme timeline"
curl -s "$BASE_URL/themes/1/timeline?days=30" -H "X-API-Key: $API_KEY" | jq

# ... continue for all endpoints
```

---

### **Prompt 7: Update Documentation**

```
Update the README.md to document the new theme analytics endpoints.

Modify file: README.md

Add a new section after the existing endpoints:

## Theme Analytics Endpoints (Phase 2)

### Overview
Advanced analytics endpoints for theme monitoring, trend detection, and influence analysis.

### Available Endpoints

#### List Themes with Health Scores
GET /api/v1/analytics/themes
Returns all active themes with health scores and trend indicators.

#### Theme Health Metrics
GET /api/v1/analytics/themes/{theme_id}/health?days=100
Detailed health metrics including CAGR, engagement trends, and growth status.
Parameters:
- days: Analysis period (7-365, default 100)

#### Theme Timeline
GET /api/v1/analytics/themes/{theme_id}/timeline?days=100
Daily activity timeline with 7-day rolling averages.

#### Top Hashtags
GET /api/v1/analytics/themes/{theme_id}/hashtags?days=100&limit=15
Most used hashtags in theme with engagement metrics.

#### Top Influencers
GET /api/v1/analytics/themes/{theme_id}/influencers?days=100&limit=20
Top authors/influencers ranked by engagement.

#### Hourly Activity Patterns
GET /api/v1/analytics/themes/{theme_id}/hourly?days=100
Activity patterns by hour of day (0-23).

#### Compare Themes
POST /api/v1/analytics/themes/compare
Compare metrics across multiple themes.
Request body:
{
  "theme_ids": [1, 2, 3],
  "days": 100
}

### Example Requests

[Include curl examples for each endpoint]

### Understanding the Metrics

- **CAGR**: Compound Annual Growth Rate - measures theme growth velocity
- **Trend Status**: 
  - "growing" (>5% CAGR): Theme activity is increasing (RED indicator)
  - "declining" (<-5% CAGR): Theme activity is decreasing (BLUE indicator)
  - "stable": Theme activity is steady
- **Engagement Rate**: Total engagement divided by total tweets
- **7-Day Rolling Average**: Smoothed trend line for daily metrics
```

---

## 🚀 Execution Order

Run these prompts in sequence with Claude CLI:

```bash
# 1. Schemas
claude "prompt 1 content here"

# 2. Repository
claude "prompt 2 content here"

# 3. Service
claude "prompt 3 content here"

# 4. Router
claude "prompt 4 content here"

# 5. Update main
claude "prompt 5 content here"

# 6. Testing script
claude "prompt 6 content here"

# 7. Update docs
claude "prompt 7 content here"
```

---

## ✅ Testing After Implementation

```bash
# Start the server
uvicorn app.main:app --reload --port 8000

# Run the test script
chmod +x tests/test_theme_analytics.sh
./tests/test_theme_analytics.sh

# Or test individual endpoints
curl "http://localhost:8000/api/v1/analytics/themes" -H "X-API-Key: dev-key-12345" | jq

curl "http://localhost:8000/api/v1/analytics/themes/1/health?days=100" -H "X-API-Key: dev-key-12345" | jq
```

---

## 📊 Success Criteria

After completion, you should have:
- ✅ 7 new analytics endpoints working
- ✅ Proper Pydantic schemas with validation
- ✅ Repository layer with optimized queries
- ✅ Service layer with CAGR and trend calculations
- ✅ API documentation at `/docs`
- ✅ Test script covering all endpoints
- ✅ Updated README with examples

---

**Ready to start? Let me know if you want me to provide all 7 prompts in a single code block for easy copy-paste to Claude CLI!**