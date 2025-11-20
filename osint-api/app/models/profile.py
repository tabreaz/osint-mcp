from sqlalchemy import Column, String, Integer, DateTime, Text, Boolean
from sqlalchemy.dialects.postgresql import JSONB
from app.database import Base
from app.config import settings


class UserProfile(Base):
    __tablename__ = settings.USER_PROFILES_TABLE
    __table_args__ = {"schema": settings.POSTGRES_SCHEMA}

    id = Column(Integer, primary_key=True)
    user_id = Column(String, nullable=False, unique=True)
    username = Column(String, nullable=False)
    display_name = Column(String)
    location = Column(String)
    url = Column(String)
    description = Column(Text)

    # Account status
    protected = Column(Boolean)
    verified = Column(Boolean)
    blue_verified = Column(Boolean)
    verification_type = Column(String)

    # Metrics
    followers_count = Column(Integer)
    following_count = Column(Integer)
    favourites_count = Column(Integer)
    statuses_count = Column(Integer)

    # Timestamps (checking if these exist)
    created_at = Column(DateTime(timezone=True))
    updated_at = Column(DateTime(timezone=True))