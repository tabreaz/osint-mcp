from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime


class ThemeBaseSchema(BaseModel):
    id: int
    project_id: int
    name: str
    code: str
    description: Optional[str]
    priority: Optional[str]
    is_active: Optional[bool]
    created_at: Optional[datetime]

    class Config:
        from_attributes = True


class ThemeWithStatsSchema(ThemeBaseSchema):
    tweet_count: int = 0
    last_collected_at: Optional[datetime] = None
    query_count: int = 0
    monitored_user_count: int = 0


class ThemeDetailSchema(ThemeWithStatsSchema):
    project_name: Optional[str] = None


class ThemeListResponse(BaseModel):
    themes: List[ThemeWithStatsSchema]
    total: int