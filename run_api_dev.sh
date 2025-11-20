#!/bin/bash

# OSINT API Development Server Runner Script
# This script provides additional options for development

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Function to display usage
usage() {
    echo -e "${BLUE}Usage: $0 [OPTIONS]${NC}"
    echo ""
    echo "Options:"
    echo "  --port PORT      Set the port number (default: 8000)"
    echo "  --host HOST      Set the host address (default: 127.0.0.1)"
    echo "  --no-reload      Disable auto-reload"
    echo "  --workers NUM    Number of worker processes (production mode)"
    echo "  --log-level LVL  Set log level (debug, info, warning, error)"
    echo "  --help           Display this help message"
    echo ""
    echo "Examples:"
    echo "  $0                           # Run with defaults"
    echo "  $0 --port 8080              # Run on port 8080"
    echo "  $0 --host 0.0.0.0 --port 80 # Run on all interfaces, port 80"
    echo "  $0 --log-level debug        # Run with debug logging"
    exit 0
}

# Default values
HOST="127.0.0.1"
PORT="8000"
RELOAD="--reload"
WORKERS=""
LOG_LEVEL="info"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --port)
            PORT="$2"
            shift 2
            ;;
        --host)
            HOST="$2"
            shift 2
            ;;
        --no-reload)
            RELOAD=""
            shift
            ;;
        --workers)
            WORKERS="--workers $2"
            RELOAD=""  # Workers and reload are mutually exclusive
            shift 2
            ;;
        --log-level)
            LOG_LEVEL="$2"
            shift 2
            ;;
        --help)
            usage
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            ;;
    esac
done

# Check if virtual environment exists
if [ ! -d "$SCRIPT_DIR/.venv" ]; then
    echo -e "${RED}Error: Virtual environment not found!${NC}"
    echo "Creating virtual environment..."
    python3.12 -m venv "$SCRIPT_DIR/.venv"
    source "$SCRIPT_DIR/.venv/bin/activate"
    pip install --upgrade pip
    pip install -r "$SCRIPT_DIR/osint-api/requirements.txt"
else
    # Activate virtual environment
    source "$SCRIPT_DIR/.venv/bin/activate"
fi

# Check if .env file exists
if [ ! -f "$SCRIPT_DIR/osint-api/.env" ]; then
    echo -e "${YELLOW}Warning: .env file not found!${NC}"
    echo "Creating .env from .env.example..."
    cp "$SCRIPT_DIR/osint-api/.env.example" "$SCRIPT_DIR/osint-api/.env"
    echo -e "${GREEN}.env file created. Please update it with your database credentials.${NC}"
    echo ""
fi

# Change to the API directory
cd "$SCRIPT_DIR/osint-api"

# Test database connection
echo -e "${BLUE}Testing database connection...${NC}"
python -c "
from app.config import settings
import asyncpg
import asyncio

async def test_connection():
    try:
        conn = await asyncpg.connect(settings.DATABASE_URL.replace('+asyncpg', ''))
        version = await conn.fetchval('SELECT version()')
        print(f'✓ Database connection successful')
        print(f'  PostgreSQL: {version.split()[1]}')
        await conn.close()
        return True
    except Exception as e:
        print(f'✗ Database connection failed: {e}')
        return False

asyncio.run(test_connection())
" 2>/dev/null || echo -e "${YELLOW}Warning: Could not test database connection${NC}"

echo ""

# Display startup information
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     OSINT Monitoring API - Dev Mode    ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Configuration:${NC}"
echo -e "  Host:       ${YELLOW}$HOST${NC}"
echo -e "  Port:       ${YELLOW}$PORT${NC}"
echo -e "  Log Level:  ${YELLOW}$LOG_LEVEL${NC}"
echo -e "  Auto-reload:${YELLOW}$([ -n "$RELOAD" ] && echo " Enabled" || echo " Disabled")${NC}"
[ -n "$WORKERS" ] && echo -e "  Workers:    ${YELLOW}${WORKERS#--workers }${NC}"
echo ""
echo -e "${BLUE}Endpoints:${NC}"
echo -e "  API:        ${YELLOW}http://$HOST:$PORT/api/v1${NC}"
echo -e "  Docs:       ${YELLOW}http://$HOST:$PORT/docs${NC}"
echo -e "  ReDoc:      ${YELLOW}http://$HOST:$PORT/redoc${NC}"
echo -e "  Health:     ${YELLOW}http://$HOST:$PORT/health${NC}"
echo ""
echo -e "${GREEN}Press CTRL+C to stop the server${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo ""

# Run the FastAPI server with all options
uvicorn app.main:app \
    --host $HOST \
    --port $PORT \
    --log-level $LOG_LEVEL \
    $RELOAD \
    $WORKERS