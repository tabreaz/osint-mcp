from sqlalchemy import Column, String, Integer, Float, DateTime, Boolean, UniqueConstraint
from sqlalchemy.dialects.postgresql import JSONB, ARRAY
from app.database import Base
from app.config import settings


class TweetTopic(Base):
    __tablename__ = settings.TWEET_TOPICS_TABLE
    __table_args__ = {"schema": settings.POSTGRES_SCHEMA}

    tweet_id = Column(String, primary_key=True)
    topic_id = Column(Integer, primary_key=True)
    probability = Column(Float)
    is_outlier = Column(Boolean)
    secondary_topic_id = Column(Integer)
    secondary_probability = Column(Float)
    created_at = Column(DateTime)
    model_version = Column(String)
    probability_distribution = Column(JSONB)
    entropy = Column(Float)
    top_topics = Column(ARRAY(Integer))


class AuthorTopic(Base):
    __tablename__ = settings.AUTHOR_TOPICS_TABLE
    __table_args__ = {"schema": settings.POSTGRES_SCHEMA}

    author_id = Column(String, primary_key=True)
    topic_id = Column(Integer, primary_key=True)
    tweet_count = Column(Integer)
    avg_probability = Column(Float)
    max_probability = Column(Float)
    first_seen = Column(DateTime)
    last_seen = Column(DateTime)
    active_days = Column(Integer)
    total_engagement = Column(Integer)
    avg_engagement = Column(Float)


class TopicEvolution(Base):
    __tablename__ = settings.TOPIC_EVOLUTION_TABLE
    __table_args__ = (
        UniqueConstraint('topic_id', 'date', 'hour', name='topic_evolution_unique'),
        {"schema": settings.POSTGRES_SCHEMA}
    )

    id = Column(Integer, primary_key=True, autoincrement=True)
    topic_id = Column(Integer, nullable=False)
    date = Column(DateTime, nullable=False)
    hour = Column(Integer, nullable=False)
    tweet_count = Column(Integer)
    unique_authors = Column(Integer)
    new_authors = Column(Integer)
    avg_probability = Column(Float)
    top_keywords = Column(JSONB)
    total_engagement = Column(Integer)
    viral_tweets = Column(Integer)
    growth_rate = Column(Float)