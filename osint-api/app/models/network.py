from sqlalchemy import Column, String, Integer, DateTime, Text
from app.database import Base
from app.config import settings


class UserNetwork(Base):
    __tablename__ = settings.USER_NETWORK_TABLE
    __table_args__ = {"schema": settings.POSTGRES_SCHEMA}

    source_user_id = Column(String, primary_key=True)
    relationship_type = Column(String, primary_key=True)
    target_id = Column(String, primary_key=True)
    target_type = Column(String, nullable=False)

    total_count = Column(Integer, nullable=False)
    unique_tweets = Column(Integer, nullable=False)
    total_weight = Column(Integer, nullable=False)

    target_username = Column(String)
    display_text = Column(String)
    expanded_url = Column(Text)

    first_seen = Column(DateTime(timezone=True))
    last_seen = Column(DateTime(timezone=True))