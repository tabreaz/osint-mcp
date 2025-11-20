from pydantic import BaseModel
from typing import Optional, Any, List
from datetime import datetime


class MonitoredUserSchema(BaseModel):
    id: int
    project_id: int
    platform: Optional[str]
    username: str
    user_id: Optional[str]
    channel_url: Optional[str]
    is_active: Optional[bool]
    created_at: Optional[datetime]
    metadata: Optional[dict[str, Any]]

    class Config:
        from_attributes = True


class MonitoredUserWithStatsSchema(MonitoredUserSchema):
    tweet_count: int = 0
    latest_tweet_at: Optional[datetime] = None
    total_engagement: int = 0
    project_name: Optional[str] = None


class MonitoredUserListResponse(BaseModel):
    users: List[MonitoredUserWithStatsSchema]
    total: int


class MonitoredUserRelationshipSchema(BaseModel):
    user_id: str
    username: str
    relationship_type: str
    interaction_count: int
    unique_tweets: int
    first_interaction: Optional[datetime]
    last_interaction: Optional[datetime]