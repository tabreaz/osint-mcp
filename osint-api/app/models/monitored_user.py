from sqlalchemy import Column, String, Integer, DateTime, Boolean
from sqlalchemy.dialects.postgresql import JSONB
from app.database import Base
from app.config import settings


class MonitoredUser(Base):
    __tablename__ = settings.MONITORED_USERS_TABLE
    __table_args__ = {"schema": settings.POSTGRES_SCHEMA}

    id = Column(Integer, primary_key=True)
    project_id = Column(Integer, nullable=False)
    platform = Column(String)
    username = Column(String, nullable=False)
    user_id = Column(String)
    channel_url = Column(String)
    is_active = Column(Boolean)
    created_at = Column(DateTime)
    metadata_json = Column("metadata", JSONB)