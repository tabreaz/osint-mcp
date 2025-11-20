from sqlalchemy import Column, String, Integer, DateTime, Text, Boolean
from sqlalchemy.dialects.postgresql import ARRAY, JSONB
from app.database import Base
from app.config import settings


class Query(Base):
    __tablename__ = settings.QUERIES_TABLE
    __table_args__ = {"schema": settings.POSTGRES_SCHEMA}

    id = Column(Integer, primary_key=True)
    theme_id = Column(Integer, nullable=False)
    code = Column(String, nullable=False)
    platform = Column(String)
    query_text = Column(Text, nullable=False)
    language = Column(String)
    hashtags = Column(ARRAY(String))
    plain_text_covered = Column(ARRAY(String))
    is_active = Column(Boolean)
    created_at = Column(DateTime)
    metadata_json = Column("metadata", JSONB)