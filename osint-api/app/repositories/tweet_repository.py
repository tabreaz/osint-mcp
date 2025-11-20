from typing import Optional, List
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, desc
from sqlalchemy.orm import selectinload

from app.models.tweet import Tweet
from app.models.collection import TweetCollection


class TweetRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_tweets(
        self,
        theme_code: Optional[str] = None,
        limit: int = 50,
        offset: int = 0
    ) -> List[Tweet]:
        """Get tweets with optional theme filtering"""
        query = select(Tweet)

        if theme_code:
            query = query.join(
                TweetCollection,
                Tweet.tweet_id == TweetCollection.tweet_id
            ).filter(TweetCollection.theme_code == theme_code)

        query = query.order_by(desc(Tweet.created_at))
        query = query.limit(limit).offset(offset)

        result = await self.db.execute(query)
        return result.scalars().all()

    async def get_tweet_by_id(self, tweet_id: str) -> Optional[Tweet]:
        """Get a single tweet by ID"""
        query = select(Tweet).filter(Tweet.tweet_id == tweet_id)
        result = await self.db.execute(query)
        return result.scalar_one_or_none()

    async def count_tweets(self, theme_code: Optional[str] = None) -> int:
        """Count total tweets with optional theme filtering"""
        query = select(func.count(Tweet.tweet_id))

        if theme_code:
            query = query.select_from(Tweet).join(
                TweetCollection,
                Tweet.tweet_id == TweetCollection.tweet_id
            ).filter(TweetCollection.theme_code == theme_code)

        result = await self.db.execute(query)
        return result.scalar() or 0

    async def get_tweets_by_theme(
        self,
        theme_code: str,
        limit: int = 50,
        offset: int = 0
    ) -> List[Tweet]:
        """Get tweets for a specific theme"""
        query = (
            select(Tweet)
            .join(TweetCollection, Tweet.tweet_id == TweetCollection.tweet_id)
            .filter(TweetCollection.theme_code == theme_code)
            .order_by(desc(Tweet.created_at))
            .limit(limit)
            .offset(offset)
        )

        result = await self.db.execute(query)
        return result.scalars().all()

    async def search_tweets(
        self,
        search_term: str,
        limit: int = 50,
        offset: int = 0
    ) -> List[Tweet]:
        """Search tweets by text content"""
        query = (
            select(Tweet)
            .filter(Tweet.text.ilike(f"%{search_term}%"))
            .order_by(desc(Tweet.created_at))
            .limit(limit)
            .offset(offset)
        )

        result = await self.db.execute(query)
        return result.scalars().all()