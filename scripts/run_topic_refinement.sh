#!/bin/bash

# Script to run topic refinement with proper environment

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Topic Refinement Script${NC}"
echo "================================"

# Check if virtual environment exists
if [ ! -d "../.venv" ]; then
    echo -e "${RED}Virtual environment not found at ../.venv${NC}"
    echo "Creating virtual environment..."
    python3 -m venv ../.venv
fi

# Activate virtual environment
source ../.venv/bin/activate

# Install required packages if needed
echo -e "${YELLOW}Checking dependencies...${NC}"
pip install -q psycopg2-binary openai python-dotenv

# Navigate to scripts directory
cd "$(dirname "$0")/topic_refinement" || exit

# Check for command
if [ $# -eq 0 ]; then
    echo -e "${YELLOW}Usage:${NC}"
    echo "  $0 process [--mode {full|quick|test}] [--limit N] [--dry-run]"
    echo "  $0 view [--category CATEGORY] [--priority {high|medium|low|ignore}]"
    echo "  $0 stats"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  $0 process --mode test --limit 5        # Test with 5 topics"
    echo "  $0 process --mode quick --limit 20      # Quick processing of 20 topics"
    echo "  $0 process --mode full                  # Full processing of all topics"
    echo "  $0 view --priority high                 # View high priority topics"
    echo "  $0 stats                                # Show processing statistics"
    exit 1
fi

# Run the refinement script
python3 refine_topics.py "$@"

# Check exit status
if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}✓ Topic refinement completed successfully${NC}"
else
    echo -e "\n${RED}✗ Topic refinement failed${NC}"
    exit 1
fi