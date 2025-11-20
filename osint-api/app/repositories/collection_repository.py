from typing import List, Dict, Any
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, desc
from app.models.collection import TweetCollection


class CollectionRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_themes(self) -> List[Dict[str, Any]]:
        """Get all unique themes with tweet counts"""
        query = (
            select(
                TweetCollection.theme_code,
                TweetCollection.theme_name,
                func.count(TweetCollection.tweet_id).label("tweet_count"),
                func.max(TweetCollection.last_collected_at).label("last_collected_at")
            )
            .group_by(TweetCollection.theme_code, TweetCollection.theme_name)
            .order_by(desc("tweet_count"))
        )

        result = await self.db.execute(query)
        themes = []
        for row in result:
            themes.append({
                "theme_code": row.theme_code,
                "theme_name": row.theme_name,
                "tweet_count": row.tweet_count,
                "last_collected_at": row.last_collected_at
            })
        return themes

    async def get_theme_by_code(self, theme_code: str) -> Dict[str, Any]:
        """Get theme details by theme code"""
        query = (
            select(
                TweetCollection.theme_code,
                TweetCollection.theme_name,
                func.count(TweetCollection.tweet_id).label("tweet_count"),
                func.max(TweetCollection.last_collected_at).label("last_collected_at")
            )
            .filter(TweetCollection.theme_code == theme_code)
            .group_by(TweetCollection.theme_code, TweetCollection.theme_name)
        )

        result = await self.db.execute(query)
        row = result.first()

        if row:
            return {
                "theme_code": row.theme_code,
                "theme_name": row.theme_name,
                "tweet_count": row.tweet_count,
                "last_collected_at": row.last_collected_at
            }
        return None

    async def get_collections_by_tweet(self, tweet_id: str) -> List[TweetCollection]:
        """Get all collections for a specific tweet"""
        query = select(TweetCollection).filter(TweetCollection.tweet_id == tweet_id)
        result = await self.db.execute(query)
        return result.scalars().all()

    async def count_themes(self) -> int:
        """Count total unique themes"""
        query = select(func.count(func.distinct(TweetCollection.theme_code)))
        result = await self.db.execute(query)
        return result.scalar() or 0