from pydantic import BaseModel
from typing import Optional, List, Dict, Any
from datetime import datetime


class TweetSchema(BaseModel):
    tweet_id: str
    author_id: Optional[str]
    author_username: Optional[str]
    text: Optional[str]
    created_at: Optional[datetime]

    # Engagement metrics
    retweet_count: Optional[int] = 0
    reply_count: Optional[int] = 0
    like_count: Optional[int] = 0
    quote_count: Optional[int] = 0
    total_engagement: Optional[int] = 0

    # Arrays and JSON fields
    hashtags: Optional[List[str]] = []
    urls: Optional[Any] = None  # Can be dict or list
    user_mentions: Optional[Any] = None  # Can be dict or list

    # Location
    place_country: Optional[str] = None
    place_name: Optional[str] = None

    # Metadata
    lang: Optional[str] = None
    is_reply: Optional[bool] = False

    class Config:
        from_attributes = True


class TweetDetailSchema(TweetSchema):
    """Extended tweet schema with additional details"""
    tweet_type: Optional[str]
    text_length: Optional[int]
    view_count: Optional[int]
    bookmark_count: Optional[int]
    engagement_rate: Optional[float]
    virality_score: Optional[float]

    # Reply information
    in_reply_to_id: Optional[str]
    in_reply_to_user_id: Optional[str]
    in_reply_to_username: Optional[str]
    conversation_id: Optional[str]

    # Referenced tweets
    quoted_tweet_id: Optional[str]
    retweeted_tweet_id: Optional[str]

    # Additional entities
    media: Optional[Dict[str, Any]]
    card: Optional[Dict[str, Any]]
    place: Optional[Dict[str, Any]]

    # Timestamps
    fetched_at: Optional[datetime]
    processed_at: Optional[datetime]


class TweetListResponse(BaseModel):
    """Response model for list of tweets"""
    tweets: List[TweetSchema]
    total: int
    limit: int
    offset: int