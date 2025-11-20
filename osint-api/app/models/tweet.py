from sqlalchemy import Column, String, Integer, DateTime, Text, Boolean, Numeric, BigInteger
from sqlalchemy.dialects.postgresql import ARRAY, JSONB
from app.database import Base
from app.config import settings


class Tweet(Base):
    __tablename__ = settings.TWEETS_TABLE
    __table_args__ = {"schema": settings.POSTGRES_SCHEMA}

    tweet_id = Column(String, primary_key=True)
    author_id = Column(String)
    author_username = Column(String)
    tweet_type = Column(String)
    text = Column(Text)
    text_length = Column(Integer)
    source = Column(String)
    lang = Column(String)
    created_at = Column(DateTime(timezone=True))

    # Engagement metrics
    retweet_count = Column(Integer)
    reply_count = Column(Integer)
    like_count = Column(Integer)
    quote_count = Column(Integer)
    view_count = Column(BigInteger)
    bookmark_count = Column(Integer)
    total_engagement = Column(Integer)
    engagement_rate = Column(Numeric)
    virality_score = Column(Numeric)

    # Reply information
    is_reply = Column(Boolean)
    in_reply_to_id = Column(String)
    in_reply_to_user_id = Column(String)
    in_reply_to_username = Column(String)
    conversation_id = Column(String)

    # Referenced tweets
    quoted_tweet_id = Column(String)
    retweeted_tweet_id = Column(String)

    # Entities
    hashtags = Column(ARRAY(String))
    user_mentions = Column(JSONB)
    urls = Column(JSONB)
    media = Column(JSONB)
    card = Column(JSONB)

    # Location
    place = Column(JSONB)
    place_type = Column(String)
    place_name = Column(String)
    place_full_name = Column(String)
    place_country = Column(String)
    place_country_code = Column(String)

    # Raw data
    entities_raw = Column(JSONB)
    extended_entities_raw = Column(JSONB)

    # Timestamps
    fetched_at = Column(DateTime(timezone=True))
    processed_at = Column(DateTime(timezone=True))