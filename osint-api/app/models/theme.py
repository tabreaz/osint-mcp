from sqlalchemy import Column, String, Integer, DateTime, Text, Boolean
from app.database import Base
from app.config import settings


class Theme(Base):
    __tablename__ = settings.THEMES_TABLE
    __table_args__ = {"schema": settings.POSTGRES_SCHEMA}

    id = Column(Integer, primary_key=True)
    project_id = Column(Integer, nullable=False)
    name = Column(String, nullable=False)
    code = Column(String, nullable=False)
    description = Column(Text)
    priority = Column(String)
    is_active = Column(Boolean)
    created_at = Column(DateTime)