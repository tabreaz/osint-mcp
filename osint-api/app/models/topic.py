from sqlalchemy import Column, String, Integer, Float, DateTime, Text, ARRAY
from sqlalchemy.dialects.postgresql import JSONB
from app.database import Base
from app.config import settings


class TopicDefinition(Base):
    __tablename__ = settings.TOPIC_DEFINITIONS_TABLE
    __table_args__ = {"schema": settings.POSTGRES_SCHEMA}

    topic_id = Column(Integer, primary_key=True)
    topic_name = Column(String)
    topic_label = Column(String)
    topic_size = Column(Integer)
    keywords = Column(JSONB)
    top_words = Column(ARRAY(Text))
    representative_tweet_ids = Column(ARRAY(Text))
    representative_texts = Column(ARRAY(Text))
    model_version = Column(String)
    created_at = Column(DateTime)
    updated_at = Column(DateTime)
    coherence_score = Column(Float)
    diversity_score = Column(Float)


class TopicDefinitionRefined(Base):
    __tablename__ = settings.TOPIC_DEFINITIONS_REFINED_TABLE
    __table_args__ = {"schema": settings.POSTGRES_SCHEMA}

    topic_id = Column(Integer, primary_key=True)
    refined_name = Column(String)
    refined_label = Column(String)
    category = Column(String)
    subcategory = Column(String)
    aligned_theme_ids = Column(ARRAY(Integer))
    suggested_new_theme = Column(String)
    alignment_confidence = Column(Float)
    clean_keywords = Column(ARRAY(Text))
    entities = Column(JSONB)
    overall_sentiment = Column(String)
    stance = Column(JSONB)
    quality_score = Column(Float)
    relevance_to_project = Column(Float)
    noise_level = Column(String)
    llm_model = Column(String)
    processed_at = Column(DateTime)
    processing_metadata = Column(JSONB)
    monitoring_priority = Column(String)
    recommended_actions = Column(JSONB)