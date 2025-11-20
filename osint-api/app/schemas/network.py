from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime


class NetworkRelationshipSchema(BaseModel):
    source_user_id: str
    relationship_type: str
    target_id: str
    target_type: str
    total_count: int
    unique_tweets: int
    total_weight: int
    target_username: Optional[str]
    display_text: Optional[str]
    expanded_url: Optional[str]
    first_seen: Optional[datetime]
    last_seen: Optional[datetime]

    class Config:
        from_attributes = True


class TopUserSchema(BaseModel):
    source_user_id: str
    total_count: int
    unique_tweets: int
    total_weight: int
    target_username: Optional[str]

    class Config:
        from_attributes = True


class NetworkAnalyticsResponse(BaseModel):
    relationship_type: str
    top_users: List[TopUserSchema]
    total: int