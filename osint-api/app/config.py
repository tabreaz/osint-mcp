from pydantic_settings import BaseSettings
from typing import List
import json


class Settings(BaseSettings):
    DATABASE_URL: str
    POSTGRES_HOST: str
    POSTGRES_PORT: int
    POSTGRES_DATABASE: str
    POSTGRES_DB: str
    POSTGRES_USER: str
    POSTGRES_PASSWORD: str
    POSTGRES_SCHEMA: str

    API_KEY: str
    API_TITLE: str = "OSINT Monitoring API"
    API_VERSION: str = "1.0.0"
    API_DESCRIPTION: str = "REST API for OSINT monitoring platform"

    ALLOWED_ORIGINS: List[str] = ["*"]

    # Table names
    TWEETS_TABLE: str = "tweets_deduplicated"
    COLLECTIONS_TABLE: str = "tweet_collections"
    USER_NETWORK_TABLE: str = "user_network"
    USER_PROFILES_TABLE: str = "user_profiles"

    class Config:
        env_file = ".env"

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        # Parse ALLOWED_ORIGINS if it's a string
        if isinstance(self.ALLOWED_ORIGINS, str):
            try:
                self.ALLOWED_ORIGINS = json.loads(self.ALLOWED_ORIGINS)
            except json.JSONDecodeError:
                self.ALLOWED_ORIGINS = ["*"]


settings = Settings()