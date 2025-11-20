# OSINT Monitoring Platform - FastAPI REST API

A high-performance REST API for OSINT (Open Source Intelligence) monitoring, built with FastAPI and PostgreSQL, featuring ML topic modeling and LLM-enhanced analytics.

## 🚀 Features

- **FastAPI Framework**: Modern, fast web framework with automatic API documentation
- **Async PostgreSQL**: High-performance async database operations with SQLAlchemy 2.0
- **ML Topic Analytics**: BERTopic-discovered topics refined with GPT-4
- **LLM Refinement**: Clean topic categorization with actionable recommendations
- **Embedding Search**: Semantic similarity using OpenAI embeddings
- **RESTful Endpoints**: Clean API design for tweets, themes, topics, and analytics
- **API Authentication**: Secure API key-based authentication
- **Auto Documentation**: Interactive Swagger UI and ReDoc documentation

## 📁 Project Structure

```
osint_mcp_v2/
├── osint-api/                         # Main API application
│   ├── app/
│   │   ├── main.py                   # FastAPI application entry
│   │   ├── config.py                 # Configuration management
│   │   ├── database.py               # Database connection
│   │   ├── models/                   # SQLAlchemy ORM models
│   │   │   ├── topic.py             # Topic definition models
│   │   │   └── topic_analytics.py   # Analytics models
│   │   ├── schemas/                  # Pydantic response models
│   │   ├── routers/                  # API endpoint routes
│   │   │   ├── topics.py            # Refined topics endpoints
│   │   │   └── topic_analytics.py   # Analytics endpoints
│   │   └── repositories/             # Database query layer
│   ├── requirements.txt              # Python dependencies
│   └── TOPIC_ANALYTICS_DOCUMENTATION.md  # Detailed topic docs
├── scripts/                           # Processing scripts
│   ├── topic_refinement/             # LLM topic refinement
│   └── topic_evolution/              # Evolution computation
├── comprehensive_analytics_architecture.md  # Architecture docs
└── run_api_dev.sh                    # Development server script
```

## 🛠️ Tech Stack

- **Framework**: FastAPI 0.104.1
- **Database**: PostgreSQL 14+ with asyncpg
- **ORM**: SQLAlchemy 2.0.23
- **Validation**: Pydantic 2.5.0
- **ML/AI**: OpenAI GPT-4, BERTopic, pgvector
- **Server**: Uvicorn with auto-reload
- **Python**: 3.12+

## 📊 API Endpoints

### Core Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Health check (no auth required) |
| GET | `/` | Root endpoint with API info |

### Tweets (`/api/v1/tweets`)
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/tweets` | List tweets with filtering |
| GET | `/api/v1/tweets/{id}` | Get specific tweet |
| POST | `/api/v1/tweets/search` | Search tweets |

### Themes (`/api/v1/themes`)
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/themes` | List all themes with counts |
| GET | `/api/v1/themes/{id}` | Get specific theme |
| GET | `/api/v1/themes/{id}/tweets` | Get tweets by theme |
| POST | `/api/v1/themes/search` | Search themes |

### Projects (`/api/v1/projects`)
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/projects` | List all projects |
| GET | `/api/v1/projects/{id}` | Get specific project |
| GET | `/api/v1/projects/{id}/tweets` | Get tweets for project |
| GET | `/api/v1/projects/{id}/queries` | Get queries for project |

### Monitored Users (`/api/v1/monitored-users`)
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/monitored-users` | List monitored users |
| GET | `/api/v1/monitored-users/{id}` | Get specific user |
| GET | `/api/v1/monitored-users/{id}/tweets` | Get tweets from user |

### Topics (`/api/v1/topics`) - LLM-Refined ⭐
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/topics/refined` | Get clean, categorized topics |
| GET | `/api/v1/topics/refined/{id}` | Get single topic details |
| GET | `/api/v1/topics/by-category` | Topics grouped by category |
| GET | `/api/v1/topics/actionable` | Topics with monitoring actions |
| GET | `/api/v1/topics/search` | Search topics |
| GET | `/api/v1/topics/statistics` | Overall topic metrics |

### Topic Analytics (`/api/v1/topic-analytics`)
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/topic-analytics/theme-topics` | Topics appearing in themes |
| GET | `/api/v1/topic-analytics/author-expertise` | Find topic experts |
| GET | `/api/v1/topic-analytics/evolution-trends` | Track topic momentum |

### Analytics (`/api/v1/analytics`)
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/analytics/engagement` | Engagement metrics |
| GET | `/api/v1/analytics/timeline` | Timeline analytics |
| GET | `/api/v1/analytics/top-authors` | Top authors analysis |

## 🔐 Authentication

All API endpoints (except `/health`) require an `X-API-Key` header:
```bash
curl -H "X-API-Key: your-api-key" http://localhost:8000/api/v1/topics/refined
```

## 🚦 Quick Start

### Prerequisites
- Python 3.12+
- PostgreSQL 14+ with existing OSINT schema
- OpenAI API key (for LLM refinement)

### Installation

1. **Clone the repository**
```bash
git clone https://github.com/tabreaz/osint-mcp.git
cd osint_mcp_v2
```

2. **Create virtual environment**
```bash
python3.12 -m venv .venv
source .venv/bin/activate
```

3. **Install dependencies**
```bash
pip install -r osint-api/requirements.txt
pip install -r scripts/requirements.txt  # For preprocessing scripts
```

4. **Configure environment**
```bash
cp osint-api/.env.example osint-api/.env
# Edit .env with your credentials
```

5. **Key Environment Variables**
```env
DATABASE_URL=postgresql+asyncpg://user:pass@localhost:5432/dbname
POSTGRES_SCHEMA=osint
API_KEY=your-secure-api-key
OPENAI_API_KEY=your-openai-key

# Topic tables (configurable)
TOPIC_DEFINITIONS_TABLE=topic_definitions
TOPIC_DEFINITIONS_REFINED_TABLE=topic_definitions_refined
TWEET_TOPICS_TABLE=tweet_topics
AUTHOR_TOPICS_TABLE=author_topics
TOPIC_EVOLUTION_TABLE=topic_evolution
```

6. **Run the server**
```bash
# Development mode with auto-reload
./run_api_dev.sh --port 8080 --log-level debug

# Access at:
# API: http://localhost:8080/api/v1
# Docs: http://localhost:8080/docs
```

## 📝 Example Usage

### Get Refined Topics with Actions
```bash
curl -X GET "http://localhost:8080/api/v1/topics/actionable?limit=10" \
  -H "X-API-Key: your-api-key"
```

Response includes machine-readable monitoring actions:
```json
{
  "topic_id": 26,
  "name": "Sudan Humanitarian Crisis",
  "category": "Humanitarian Crisis",
  "priority": "high",
  "actions": [{
    "action_type": "add_query",
    "query": "Sudan RSF attacks civilians",
    "frequency": "real-time",
    "reason": "Critical humanitarian monitoring"
  }]
}
```

### Find Topic Experts
```bash
curl -X GET "http://localhost:8080/api/v1/topic-analytics/author-expertise?topic_id=26" \
  -H "X-API-Key: your-api-key"
```

### Track Trending Topics
```bash
curl -X GET "http://localhost:8080/api/v1/topic-analytics/evolution-trends?hours=24" \
  -H "X-API-Key: your-api-key"
```

## 🗄️ Data Models

### Primary Entities
- **Topics** - LLM-refined, categorized topics with recommendations
- **Themes** - Business-defined monitoring categories
- **Projects** - Organizational units for grouping themes
- **Monitored Users** - Tracked social media accounts
- **Topic Analytics** - Author expertise and evolution metrics

See `API_SCHEMA_GUIDE.md` for detailed schema information.

## 🔧 Preprocessing Scripts

### Topic Refinement
```bash
cd scripts/topic_refinement
python refine_topics.py process --mode full
```

### Topic Evolution
```bash
cd scripts/topic_evolution
python compute_evolution.py --days 30
```

## 📚 Documentation

- **API Docs**: http://localhost:8080/docs (Swagger)
- **Schema Guide**: `API_SCHEMA_GUIDE.md` - Clean data model reference
- **Architecture**: `comprehensive_analytics_architecture.md` - System design
- **Topic Details**: `osint-api/TOPIC_ANALYTICS_DOCUMENTATION.md` - Implementation details

## 🎯 Key Features Explained

### LLM-Refined Topics
- Raw ML topics are messy (e.g., "#الفاشر_تباد")
- GPT-4 refines them to clean names (e.g., "Al Fashir Massacre Awareness")
- Categorized into: Humanitarian Crisis, Political Campaign, etc.
- Includes actionable monitoring recommendations

### Three-Layer Analytics
1. **Theme-based** - Business-defined categories
2. **ML Topics** - Unsupervised semantic clusters
3. **Embeddings** - Deep semantic similarity

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/NewFeature`)
3. Commit changes (`git commit -m 'Add NewFeature'`)
4. Push to branch (`git push origin feature/NewFeature`)
5. Open Pull Request

## 📄 License

This project is part of an OSINT monitoring platform for research purposes.

## 🔗 Links

- **Repository**: https://github.com/tabreaz/osint-mcp
- **Issues**: https://github.com/tabreaz/osint-mcp/issues

---

Built with ❤️ using FastAPI, PostgreSQL, and OpenAI