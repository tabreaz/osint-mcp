from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
from datetime import datetime


class TopicInfo(BaseModel):
    topic_id: int
    refined_name: str
    category: Optional[str] = None
    monitoring_priority: str = 'medium'
    tweet_count: int
    avg_probability: float
    unique_authors: int


class ThemeTopicAnalytics(BaseModel):
    theme_name: str
    topics: List[TopicInfo]
    total_tweets: int
    total_authors: int


class AuthorExpertise(BaseModel):
    author_id: str
    topic_id: int
    topic_name: str
    tweet_count: int
    avg_probability: float = Field(ge=0, le=1)
    max_probability: float = Field(ge=0, le=1)
    first_seen: Optional[str] = None
    last_seen: Optional[str] = None
    active_days: int
    total_engagement: int
    avg_engagement: float


class TopicEvolutionTrend(BaseModel):
    topic_id: int
    topic_name: str
    date: str
    hour: int
    tweet_count: int
    unique_authors: int
    new_authors: Optional[int] = None
    avg_probability: float = Field(ge=0, le=1)
    top_keywords: Optional[Dict[str, Any]] = None
    total_engagement: int
    viral_tweets: int
    growth_rate: float


class RecommendedAction(BaseModel):
    action_type: str = Field(
        description="Type of action: add_query | add_user | track_hashtag | alert_setup"
    )
    query: str = Field(
        description="Exact search query, @username, or #hashtag"
    )
    frequency: str = Field(
        description="Monitoring frequency: daily | hourly | real-time"
    )
    reason: str = Field(
        description="Brief explanation for the recommendation"
    )


class TopicRecommendation(BaseModel):
    topic_id: int
    refined_name: str
    refined_label: str
    category: str
    subcategory: Optional[str] = None
    monitoring_priority: str
    quality_score: float = Field(ge=0, le=1)
    relevance_to_project: float = Field(ge=0, le=1)
    recommended_actions: Optional[List[Dict[str, Any]]] = None
    aligned_theme_ids: Optional[List[int]] = None
    suggested_new_theme: Optional[str] = None


class TopicAnalyticsQuery(BaseModel):
    theme_id: Optional[int] = None
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None


class AuthorExpertiseQuery(BaseModel):
    topic_id: Optional[int] = None
    min_tweet_count: int = Field(default=5, ge=1)
    limit: int = Field(default=100, le=1000)


class EvolutionTrendQuery(BaseModel):
    topic_ids: Optional[List[int]] = None
    hours: int = Field(default=24, ge=1, le=720)
    min_growth_rate: Optional[float] = None


class RecommendationQuery(BaseModel):
    priority: Optional[str] = Field(
        default='high',
        description="Priority level: high | medium | low | ignore"
    )
    limit: int = Field(default=50, le=200)