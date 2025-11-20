from sqlalchemy import Column, String, Integer, DateTime, Boolean
from sqlalchemy.dialects.postgresql import ARRAY
from app.database import Base
from app.config import settings


class TweetCollection(Base):
    __tablename__ = settings.COLLECTIONS_TABLE
    __table_args__ = {"schema": settings.POSTGRES_SCHEMA}

    tweet_id = Column(String, primary_key=True)
    project_id = Column(Integer, primary_key=True)
    theme_code = Column(String, primary_key=True)
    theme_name = Column(String, nullable=False)

    collected_by_query = Column(Boolean)
    collected_by_user = Column(Boolean)
    monitored_user_ids = Column(ARRAY(String))

    first_collected_at = Column(DateTime(timezone=True))
    last_collected_at = Column(DateTime(timezone=True))