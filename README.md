# OSINT Monitoring Platform - FastAPI REST API

A high-performance REST API for OSINT (Open Source Intelligence) monitoring, built with FastAPI and PostgreSQL.

## 🚀 Features

- **FastAPI Framework**: Modern, fast web framework with automatic API documentation
- **Async PostgreSQL**: High-performance async database operations with SQLAlchemy 2.0
- **RESTful Endpoints**: Clean API design for tweets, themes, and analytics
- **API Authentication**: Secure API key-based authentication
- **Auto Documentation**: Interactive Swagger UI and ReDoc documentation
- **Network Analytics**: Analyze user relationships and interactions
- **Theme-based Filtering**: Organize content by themes and projects

## 📁 Project Structure

```
osint-mcp/
├── osint-api/                 # Main API application
│   ├── app/
│   │   ├── main.py           # FastAPI application entry
│   │   ├── config.py         # Configuration management
│   │   ├── database.py       # Database connection
│   │   ├── models/           # SQLAlchemy ORM models
│   │   ├── schemas/          # Pydantic response models
│   │   ├── routers/          # API endpoint routes
│   │   ├── repositories/     # Database query layer
│   │   └── auth/            # Authentication logic
│   ├── requirements.txt      # Python dependencies
│   └── README.md            # API documentation
├── run_api.sh               # Production server script
└── run_api_dev.sh          # Development server script
```

## 🛠️ Tech Stack

- **Framework**: FastAPI 0.104.1
- **Database**: PostgreSQL 14+ with asyncpg
- **ORM**: SQLAlchemy 2.0.23
- **Validation**: Pydantic 2.5.0
- **Server**: Uvicorn with auto-reload
- **Python**: 3.12+

## 📊 API Endpoints

### Core Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Health check (no auth required) |
| GET | `/api/v1/tweets` | List tweets with filtering |
| GET | `/api/v1/tweets/{id}` | Get specific tweet |
| GET | `/api/v1/themes` | List all themes with counts |
| GET | `/api/v1/themes/{code}/tweets` | Get tweets by theme |
| GET | `/api/v1/analytics/network/top-users` | Top users by relationship |

### Authentication
All API endpoints (except `/health`) require an `X-API-Key` header.

## 🚦 Quick Start

### Prerequisites
- Python 3.12+
- PostgreSQL 14+
- Existing OSINT database schema

### Installation

1. **Clone the repository**
```bash
git clone https://github.com/tabreaz/osint-mcp.git
cd osint-mcp
```

2. **Create virtual environment**
```bash
python3.12 -m venv .venv
source .venv/bin/activate
```

3. **Install dependencies**
```bash
pip install -r osint-api/requirements.txt
```

4. **Configure environment**
```bash
cp osint-api/.env.example osint-api/.env
# Edit .env with your database credentials
```

5. **Run the server**
```bash
# Development mode with auto-reload
./run_api_dev.sh --port 8080 --log-level debug

# Or production mode
./run_api.sh
```

6. **Access the API**
- API: http://localhost:8000/api/v1
- Documentation: http://localhost:8000/docs
- Health Check: http://localhost:8000/health

## 📝 Example Usage

### Get Tweets
```bash
curl -X GET "http://localhost:8000/api/v1/tweets?limit=10" \
  -H "X-API-Key: your-api-key"
```

### Get Themes
```bash
curl -X GET "http://localhost:8000/api/v1/themes" \
  -H "X-API-Key: your-api-key"
```

### Network Analytics
```bash
curl -X GET "http://localhost:8000/api/v1/analytics/network/top-users?relationship_type=mention" \
  -H "X-API-Key: your-api-key"
```

## 🗄️ Database Schema

The API connects to an existing PostgreSQL database with the following main tables:
- `osint.tweets_deduplicated` - Tweet data
- `osint.tweet_collections` - Theme collections
- `osint.user_network` - User relationships
- `osint.twitter_user_profiles` - User profiles

## 🔧 Configuration

Environment variables (`.env` file):
```env
DATABASE_URL=postgresql+asyncpg://user:pass@localhost:5432/dbname
POSTGRES_SCHEMA=osint
API_KEY=your-secure-api-key
API_TITLE=OSINT Monitoring API
ALLOWED_ORIGINS=["http://localhost:3000"]
```

## 🧪 Development

### Run with custom options
```bash
./run_api_dev.sh --port 8080 --log-level debug --no-reload
```

### Available run options
- `--port PORT` - Set custom port (default: 8000)
- `--host HOST` - Set host address (default: 127.0.0.1)
- `--no-reload` - Disable auto-reload
- `--log-level` - Set logging level (debug, info, warning, error)

## 📚 API Documentation

Once the server is running, visit:
- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc

These provide interactive API documentation with the ability to test endpoints directly.

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is part of an OSINT monitoring platform for research purposes.

## 🔗 Links

- **Repository**: https://github.com/tabreaz/osint-mcp
- **Issues**: https://github.com/tabreaz/osint-mcp/issues

---

Built with ❤️ using FastAPI and PostgreSQL