"""
Configuration for topic refinement scripts
"""
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv("/Users/tabreaz/code/osint_mcp_v2/osint-api/.env")

# Database Configuration
DATABASE_CONFIG = {
    "host": os.getenv("POSTGRES_HOST", "localhost"),
    "port": os.getenv("POSTGRES_PORT", "5432"),
    "database": os.getenv("POSTGRES_DATABASE", "neuron"),
    "user": os.getenv("POSTGRES_USER", "tabreaz"),
    "password": os.getenv("POSTGRES_PASSWORD", "admin"),
    "schema": os.getenv("POSTGRES_SCHEMA", "osint")
}

# OpenAI Configuration
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
OPENAI_MODEL = "gpt-4o"  # Latest GPT-4 Optimized model
OPENAI_MODEL_FALLBACK = "gpt-4o-mini"  # Cheaper fallback for large batches

# Processing Configuration
BATCH_SIZE = 10  # Number of topics to process in one LLM call
MIN_TOPIC_SIZE = 100  # Minimum tweets in topic to consider for refinement
CACHE_DIR = "/Users/tabreaz/code/osint_mcp_v2/data/refined_topics/cache"

# Cost Management
MAX_TOKENS_PER_REQUEST = 4000
MAX_COST_PER_RUN = 10.0  # Maximum $ to spend per refinement run

# Processing Modes
PROCESSING_MODES = {
    "full": {
        "model": "gpt-4o",
        "batch_size": 5,
        "include_samples": True,
        "deep_analysis": True
    },
    "quick": {
        "model": "gpt-4o-mini",
        "batch_size": 20,
        "include_samples": False,
        "deep_analysis": False
    },
    "test": {
        "model": "gpt-4o",
        "batch_size": 2,
        "include_samples": True,
        "deep_analysis": True
    }
}