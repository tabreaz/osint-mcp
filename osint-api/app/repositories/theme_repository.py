from typing import List, Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from app.models.theme import Theme
from app.models.collection import TweetCollection
from app.models.query import Query
from app.models.project import Project


class ThemeRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_all_themes(self) -> List[Theme]:
        """Get all themes"""
        query = select(Theme).order_by(Theme.project_id, Theme.id)
        result = await self.db.execute(query)
        return result.scalars().all()

    async def get_themes_by_project(self, project_id: int) -> List[Theme]:
        """Get themes for a specific project"""
        query = select(Theme).filter(Theme.project_id == project_id).order_by(Theme.id)
        result = await self.db.execute(query)
        return result.scalars().all()

    async def get_theme_by_code(self, theme_code: str) -> Optional[Theme]:
        """Get theme by code"""
        query = select(Theme).filter(Theme.code == theme_code)
        result = await self.db.execute(query)
        return result.scalar_one_or_none()

    async def get_theme_by_id(self, theme_id: int) -> Optional[Theme]:
        """Get theme by ID"""
        query = select(Theme).filter(Theme.id == theme_id)
        result = await self.db.execute(query)
        return result.scalar_one_or_none()

    async def get_active_themes(self) -> List[Theme]:
        """Get only active themes"""
        query = select(Theme).filter(Theme.is_active == True).order_by(Theme.project_id, Theme.id)
        result = await self.db.execute(query)
        return result.scalars().all()

    async def get_theme_stats(self, theme_code: str) -> dict:
        """Get statistics for a theme"""
        # Get tweet count from collections
        tweet_query = (
            select(
                func.count(func.distinct(TweetCollection.tweet_id)).label("tweet_count"),
                func.max(TweetCollection.last_collected_at).label("last_collected_at")
            )
            .filter(TweetCollection.theme_code == theme_code)
        )
        tweet_result = await self.db.execute(tweet_query)
        tweet_stats = tweet_result.first()

        # Get query count
        theme = await self.get_theme_by_code(theme_code)
        if theme:
            query_count_query = select(func.count(Query.id)).filter(Query.theme_id == theme.id)
            query_count_result = await self.db.execute(query_count_query)
            query_count = query_count_result.scalar() or 0
        else:
            query_count = 0

        return {
            "tweet_count": tweet_stats.tweet_count if tweet_stats else 0,
            "last_collected_at": tweet_stats.last_collected_at if tweet_stats else None,
            "query_count": query_count
        }

    async def get_theme_with_project(self, theme_code: str) -> dict:
        """Get theme with project information"""
        query = (
            select(Theme, Project.name)
            .join(Project, Theme.project_id == Project.id)
            .filter(Theme.code == theme_code)
        )
        result = await self.db.execute(query)
        row = result.first()

        if row:
            theme, project_name = row
            return {
                "theme": theme,
                "project_name": project_name
            }
        return None