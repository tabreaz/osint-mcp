from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime


class ThemeSchema(BaseModel):
    theme_code: str
    theme_name: str
    tweet_count: int
    last_collected_at: Optional[datetime]

    class Config:
        from_attributes = True


class ThemeListResponse(BaseModel):
    themes: List[ThemeSchema]
    total: int


class CollectionSchema(BaseModel):
    tweet_id: str
    project_id: int
    theme_code: str
    theme_name: str
    collected_by_query: Optional[bool]
    collected_by_user: Optional[bool]
    monitored_user_ids: Optional[List[str]]
    first_collected_at: Optional[datetime]
    last_collected_at: Optional[datetime]

    class Config:
        from_attributes = True