#!/bin/bash

# OSINT API Server Runner Script
# This script activates the virtual environment and starts the FastAPI server

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Check if virtual environment exists
if [ ! -d "$SCRIPT_DIR/.venv" ]; then
    echo -e "${RED}Error: Virtual environment not found!${NC}"
    echo "Please create it first by running:"
    echo "  python3.12 -m venv $SCRIPT_DIR/.venv"
    echo "  source $SCRIPT_DIR/.venv/bin/activate"
    echo "  pip install -r $SCRIPT_DIR/osint-api/requirements.txt"
    exit 1
fi

# Check if .env file exists
if [ ! -f "$SCRIPT_DIR/osint-api/.env" ]; then
    echo -e "${YELLOW}Warning: .env file not found!${NC}"
    echo "Creating .env from .env.example..."
    cp "$SCRIPT_DIR/osint-api/.env.example" "$SCRIPT_DIR/osint-api/.env"
    echo -e "${GREEN}.env file created. Please update it with your database credentials.${NC}"
fi

# Activate virtual environment
echo -e "${GREEN}Activating virtual environment...${NC}"
source "$SCRIPT_DIR/.venv/bin/activate"

# Check if dependencies are installed
if ! python -c "import fastapi" 2>/dev/null; then
    echo -e "${YELLOW}Dependencies not installed. Installing...${NC}"
    pip install -r "$SCRIPT_DIR/osint-api/requirements.txt"
fi

# Change to the API directory
cd "$SCRIPT_DIR/osint-api"

# Set default host and port
HOST=${API_HOST:-0.0.0.0}
PORT=${API_PORT:-8000}

# Display startup information
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Starting OSINT Monitoring API Server${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Server will be available at:"
echo -e "  Local:      ${YELLOW}http://localhost:$PORT${NC}"
echo -e "  Network:    ${YELLOW}http://$HOST:$PORT${NC}"
echo -e "  Docs:       ${YELLOW}http://localhost:$PORT/docs${NC}"
echo -e "  Health:     ${YELLOW}http://localhost:$PORT/health${NC}"
echo ""
echo "Press CTRL+C to stop the server"
echo -e "${GREEN}========================================${NC}"
echo ""

# Run the FastAPI server
uvicorn app.main:app --host $HOST --port $PORT --reload