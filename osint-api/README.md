# OSINT Monitoring API

REST API for OSINT monitoring platform built with FastAPI and PostgreSQL.

## Project Description

This API provides endpoints for accessing and analyzing OSINT (Open Source Intelligence) data from social media platforms. It includes features for:
- Retrieving tweets with filtering and search capabilities
- Analyzing themes and collections
- Network relationship analytics
- User profile information

## Prerequisites

- Python 3.8+
- PostgreSQL 14+
- Existing PostgreSQL database with OSINT schema

## Installation Steps

1. **Clone or navigate to the project directory:**
```bash
cd osint-api
```

2. **Create a virtual environment:**
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

3. **Install dependencies:**
```bash
pip install -r requirements.txt
```

4. **Set up environment variables:**
```bash
cp .env.example .env
# Edit .env file with your database credentials
```

5. **Configure your .env file:**
```env
DATABASE_URL=postgresql+asyncpg://tabreaz:admin@localhost:5432/neuron
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DATABASE=neuron
POSTGRES_USER=tabreaz
POSTGRES_PASSWORD=admin
POSTGRES_SCHEMA=osint
API_KEY=dev-key-12345
API_TITLE=OSINT Monitoring API
ALLOWED_ORIGINS=["http://localhost:3000"]
TWEETS_TABLE=tweets_deduplicated
COLLECTIONS_TABLE=tweet_collections
USER_NETWORK_TABLE=user_network
USER_PROFILES_TABLE=twitter_user_profiles
```

## Running the Application

Start the FastAPI server with auto-reload:
```bash
uvicorn app.main:app --reload --port 8000
```

The API will be available at: `http://localhost:8000`

## API Documentation

Interactive API documentation is available at:
- Swagger UI: `http://localhost:8000/docs`
- ReDoc: `http://localhost:8000/redoc`

## Available Endpoints

### Health Check
- `GET /health` - Check API health status (no authentication required)

### Tweets
- `GET /api/v1/tweets` - Get list of tweets with optional filtering
- `GET /api/v1/tweets/{tweet_id}` - Get a specific tweet by ID
- `GET /api/v1/tweets/search/{search_term}` - Search tweets by text

### Themes
- `GET /api/v1/themes` - Get all themes with tweet counts
- `GET /api/v1/themes/{theme_code}` - Get specific theme details
- `GET /api/v1/themes/{theme_code}/tweets` - Get tweets for a theme

### Analytics
- `GET /api/v1/analytics/network/top-users` - Get top users by relationship type
- `GET /api/v1/analytics/network/relationship-types` - Get available relationship types
- `GET /api/v1/analytics/network/user/{user_id}` - Get network relationships for a user

### Projects
- `GET /api/v1/projects` - Get projects (placeholder endpoint)

## Example API Calls

### Health Check
```bash
curl http://localhost:8000/health
```

### Get Tweets (with API key)
```bash
curl http://localhost:8000/api/v1/tweets?limit=10 \
  -H "X-API-Key: dev-key-12345"
```

### Get Themes
```bash
curl http://localhost:8000/api/v1/themes \
  -H "X-API-Key: dev-key-12345"
```

### Get Theme Tweets
```bash
curl http://localhost:8000/api/v1/themes/THEME_CODE/tweets \
  -H "X-API-Key: dev-key-12345"
```

### Get Top Users by Relationship
```bash
curl "http://localhost:8000/api/v1/analytics/network/top-users?relationship_type=mention" \
  -H "X-API-Key: dev-key-12345"
```

### Search Tweets
```bash
curl http://localhost:8000/api/v1/tweets/search/keyword \
  -H "X-API-Key: dev-key-12345"
```

## Authentication

All API endpoints (except `/health`) require an API key to be passed in the `X-API-Key` header.

## Error Handling

The API returns standard HTTP status codes:
- `200` - Success
- `401` - Unauthorized (missing API key)
- `403` - Forbidden (invalid API key)
- `404` - Resource not found
- `422` - Validation error
- `500` - Internal server error

Error responses include a JSON body with a `detail` field explaining the error.

## Project Structure

```
osint-api/
├── app/
│   ├── __init__.py
│   ├── main.py                 # FastAPI app entry point
│   ├── config.py               # Environment configuration
│   ├── database.py             # Database connection
│   ├── models/                 # SQLAlchemy ORM models
│   ├── schemas/                # Pydantic response schemas
│   ├── routers/                # API endpoints
│   ├── repositories/           # Database query layer
│   └── auth/                   # Authentication
├── tests/
├── .env.example
├── .gitignore
├── requirements.txt
└── README.md
```

## Development

- The API uses async/await patterns throughout for better performance
- Repository pattern is used for database access
- Pydantic models handle request/response validation
- SQLAlchemy 2.0 is used for ORM with async support

## Troubleshooting

1. **Database connection errors:** Ensure PostgreSQL is running and credentials in `.env` are correct
2. **Import errors:** Make sure all dependencies are installed via `pip install -r requirements.txt`
3. **API key errors:** Verify the `X-API-Key` header matches the value in your `.env` file
4. **Schema errors:** Confirm the `osint` schema exists in your PostgreSQL database