# FastAPI OSINT Monitoring API - Development Instructions

## Project Context
You are building a FastAPI application for an OSINT monitoring platform. The PostgreSQL database already exists with deduplicated tables. Your job is to create a clean REST API layer.

## Database Connection Details
- **Database:** PostgreSQL 14+
- **Host:** localhost
- **Port:** 5432
- **Database Name:** neuron
- **Schema:** osint
- **User:** tabreaz
- **Extensions:** pgvector

## Core Requirements

### 1. Project Structure (MUST follow exactly)
```
osint-api/
├── app/
│   ├── __init__.py
│   ├── main.py                 # FastAPI app entry point
│   ├── config.py               # Environment config with pydantic-settings
│   ├── database.py             # SQLAlchemy async engine & session
│   │
│   ├── models/                 # SQLAlchemy ORM models
│   │   ├── __init__.py
│   │   ├── tweet.py
│   │   ├── collection.py
│   │   ├── network.py
│   │   └── profile.py
│   │
│   ├── schemas/                # Pydantic response schemas
│   │   ├── __init__.py
│   │   ├── tweet.py
│   │   ├── collection.py
│   │   └── network.py
│   │
│   ├── routers/                # API endpoints
│   │   ├── __init__.py
│   │   ├── tweets.py
│   │   ├── themes.py
│   │   ├── projects.py
│   │   └── analytics.py
│   │
│   ├── repositories/           # Database query layer
│   │   ├── __init__.py
│   │   ├── tweet_repository.py
│   │   ├── collection_repository.py
│   │   └── network_repository.py
│   │
│   └── auth/                   # Authentication
│       ├── __init__.py
│       └── api_key.py
│
├── tests/
│   └── __init__.py
├── .env.example
├── .gitignore
├── requirements.txt
└── README.md
```

### 2. Technology Stack (MUST use these versions)
```txt
# requirements.txt
fastapi==0.104.1
uvicorn[standard]==0.24.0
sqlalchemy==2.0.23
asyncpg==0.29.0
pydantic==2.5.0
pydantic-settings==2.1.0
python-dotenv==1.0.0
```

### 3. Database Models (Map to existing tables)

#### Table: osint.tweets_deduplicated
**SQLAlchemy Model Requirements:**
- Table name: `tweets_deduplicated`
- Schema: `osint`
- Primary key: `tweet_id` (String, not Integer)
- MUST include: tweet_id, author_id, author_username, text, created_at, hashtags (ARRAY), place_country
- Use `__table_args__ = {'schema': 'osint'}` for schema specification

#### Table: osint.tweet_collections
**SQLAlchemy Model Requirements:**
- Composite primary key: (tweet_id, project_id, theme_code)
- Boolean fields: collected_by_query, collected_by_user
- Array field: monitored_user_ids (use postgresql.ARRAY)

#### Table: osint.user_network
**SQLAlchemy Model Requirements:**
- Composite primary key: (source_user_id, relationship_type, target_id)
- Integer fields: total_count, unique_tweets, total_weight
- Timestamp fields: first_seen, last_seen

### 4. Configuration (config.py)
**Requirements:**
- Use `pydantic-settings` BaseSettings
- Load from .env file
- MUST include:
```python
  DATABASE_URL: str
  API_TITLE: str = "OSINT Monitoring API"
  API_VERSION: str = "1.0.0"
  ALLOWED_ORIGINS: list[str] = ["*"]
```

### 5. Database Connection (database.py)
**Requirements:**
- Use async SQLAlchemy engine with asyncpg
- Create async session factory
- Provide `get_db()` dependency for FastAPI
- Example:
```python
  engine = create_async_engine(settings.DATABASE_URL)
  async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
```

### 6. API Endpoints (Start with these 5)

#### GET /api/v1/tweets
**Requirements:**
- Query params: theme_code (optional), limit (default 50, max 1000), offset (default 0)
- Response: List of TweetSchema
- Logic: Join tweets_deduplicated with tweet_collections if theme_code provided
- Sort: created_at DESC

#### GET /api/v1/tweets/{tweet_id}
**Requirements:**
- Path param: tweet_id
- Response: Single TweetSchema or 404
- Include: Full tweet details with place info

#### GET /api/v1/themes
**Requirements:**
- Response: List of themes with tweet counts
- Query: Aggregate from tweet_collections
- Include: theme_code, theme_name, tweet_count, last_collected_at

#### GET /api/v1/themes/{theme_code}/tweets
**Requirements:**
- Path param: theme_code
- Query params: limit, offset
- Response: Tweets in this theme
- Join: tweet_collections → tweets_deduplicated

#### GET /api/v1/analytics/network/top-users
**Requirements:**
- Query param: relationship_type (mention, retweet, hashtag)
- Response: Top 20 users by total_count from user_network
- Include: source_user_id, total_count, unique_tweets, total_weight

### 7. Response Schemas (Pydantic)

**TweetSchema (schemas/tweet.py):**
```python
class TweetSchema(BaseModel):
    tweet_id: str
    author_id: str
    author_username: str
    text: str
    created_at: datetime
    total_engagement: int
    hashtags: list[str] | None
    place_country: str | None
    
    class Config:
        from_attributes = True  # For SQLAlchemy 2.0
```

**NetworkRelationshipSchema:**
```python
class NetworkRelationshipSchema(BaseModel):
    source_user_id: str
    relationship_type: str
    target_id: str
    total_count: int
    unique_tweets: int
    total_weight: int
```

### 8. Repository Pattern (MUST follow)

**Example structure:**
```python
class TweetRepository:
    def __init__(self, db: AsyncSession):
        self.db = db
    
    async def get_tweets(self, theme_code: str | None, limit: int, offset: int):
        query = select(TweetModel)
        if theme_code:
            query = query.join(CollectionModel).filter(...)
        result = await self.db.execute(query)
        return result.scalars().all()
```

### 9. Main Application (main.py)

**Requirements:**
- Create FastAPI app with title, version, description
- Add CORS middleware with allowed origins from config
- Include all routers with prefix `/api/v1`
- Add health check endpoint: `GET /health`
- Example startup:
```python
  app = FastAPI(title=settings.API_TITLE, version=settings.API_VERSION)
  app.add_middleware(CORSMiddleware, allow_origins=settings.ALLOWED_ORIGINS)
  app.include_router(tweets_router, prefix="/api/v1", tags=["tweets"])
```

### 10. Authentication (Simple API Key for now)

**Requirements:**
- Header: `X-API-Key`
- Hardcoded key in .env: `API_KEY=dev-key-12345`
- Create dependency: `verify_api_key()`
- Apply to all routers except /health

### 11. Error Handling

**MUST handle:**
- 404: Resource not found
- 422: Validation error
- 500: Internal server error
- Return JSON: `{"detail": "error message"}`

### 12. Environment File (.env.example)
```env
DATABASE_URL=postgresql+asyncpg://tabreaz:admin@localhost:5432/neuron
API_KEY=dev-key-12345
API_TITLE=OSINT Monitoring API
ALLOWED_ORIGINS=["http://localhost:3000"]
```

### 13. README.md (MUST include)

Sections:
1. Project description
2. Prerequisites
3. Installation steps
4. Running the app: `uvicorn app.main:app --reload --port 8000`
5. API documentation: `http://localhost:8000/docs`
6. Example API calls with curl

### 14. Testing Instructions

After creation, verify:
```bash
# Start server
uvicorn app.main:app --reload --port 8000

# Test endpoints
curl http://localhost:8000/health
curl http://localhost:8000/api/v1/tweets?limit=10 -H "X-API-Key: dev-key-12345"
curl http://localhost:8000/api/v1/themes -H "X-API-Key: dev-key-12345"
```

---

## Critical Rules (DO NOT violate)

1. ✅ Use ASYNC everywhere (AsyncSession, async def, await)
2. ✅ Use SQLAlchemy 2.0 syntax (select(), not query())
3. ✅ Schema is 'osint', not default 'public'
4. ✅ Primary keys are STRINGS for user_id/tweet_id, not integers
5. ✅ Always use repository pattern, no direct DB queries in routers
6. ✅ Return Pydantic schemas, not SQLAlchemy models
7. ✅ Handle NULL values (use Optional[] or | None)
8. ✅ Set `from_attributes = True` in Pydantic Config
9. ❌ DO NOT create database tables (they exist)
10. ❌ DO NOT use Alembic migrations yet

---

## Success Criteria

When done, I should be able to:
1. Run `pip install -r requirements.txt`
2. Copy `.env.example` to `.env` and update credentials
3. Run `uvicorn app.main:app --reload`
4. Visit `http://localhost:8000/docs` and see 5 working endpoints
5. Call APIs with curl and get JSON responses
6. See proper error messages for invalid requests

---

## Deliverables Checklist

- [ ] All files in correct structure
- [ ] requirements.txt with exact versions
- [ ] .env.example with all variables
- [ ] README.md with clear instructions
- [ ] 5 working API endpoints
- [ ] Pydantic schemas for all responses
- [ ] Repository classes for DB access
- [ ] API key authentication working
- [ ] Health check endpoint
- [ ] CORS configured
- [ ] FastAPI auto-docs working at /docs

---

## Notes

- Focus on READ operations only (no POST/PUT/DELETE yet)
- Keep it simple - no caching, no rate limiting yet
- Use existing database - do not modify schema
- Prefer explicit over implicit (type hints everywhere)
- Follow FastAPI best practices from official docs
