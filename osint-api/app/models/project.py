from sqlalchemy import Column, String, Integer, DateTime, Text, Boolean
from app.database import Base
from app.config import settings


class Project(Base):
    __tablename__ = settings.PROJECTS_TABLE
    __table_args__ = {"schema": settings.POSTGRES_SCHEMA}

    id = Column(Integer, primary_key=True)
    name = Column(String, nullable=False)
    description = Column(Text)
    is_active = Column(Boolean)
    created_at = Column(DateTime)
    updated_at = Column(DateTime)