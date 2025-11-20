from typing import List, Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_
from app.models.monitored_user import MonitoredUser
from app.models.tweet import Tweet
from app.models.project import Project
from app.models.network import UserNetwork


class MonitoredUserRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_all_monitored_users(self, project_id: Optional[int] = None) -> List[MonitoredUser]:
        """Get all monitored users, optionally filtered by project"""
        query = select(MonitoredUser)
        if project_id:
            query = query.filter(MonitoredUser.project_id == project_id)
        query = query.order_by(MonitoredUser.username)
        result = await self.db.execute(query)
        return result.scalars().all()

    async def get_active_monitored_users(self, project_id: Optional[int] = None) -> List[MonitoredUser]:
        """Get only active monitored users"""
        query = select(MonitoredUser).filter(MonitoredUser.is_active == True)
        if project_id:
            query = query.filter(MonitoredUser.project_id == project_id)
        query = query.order_by(MonitoredUser.username)
        result = await self.db.execute(query)
        return result.scalars().all()

    async def get_monitored_user_by_id(self, user_id: int) -> Optional[MonitoredUser]:
        """Get monitored user by ID"""
        query = select(MonitoredUser).filter(MonitoredUser.id == user_id)
        result = await self.db.execute(query)
        return result.scalar_one_or_none()

    async def get_monitored_user_by_username(self, username: str) -> Optional[MonitoredUser]:
        """Get monitored user by username"""
        query = select(MonitoredUser).filter(MonitoredUser.username == username)
        result = await self.db.execute(query)
        return result.scalar_one_or_none()

    async def get_tweets_by_monitored_user(
        self,
        user_id: str,
        limit: int = 50,
        offset: int = 0
    ) -> List[Tweet]:
        """Get tweets from a monitored user"""
        query = (
            select(Tweet)
            .filter(Tweet.author_id == user_id)
            .order_by(Tweet.created_at.desc())
            .limit(limit)
            .offset(offset)
        )
        result = await self.db.execute(query)
        return result.scalars().all()

    async def get_monitored_user_stats(self, user_id: str) -> dict:
        """Get statistics for a monitored user"""
        # Tweet count
        tweet_count_query = select(func.count(Tweet.tweet_id)).filter(Tweet.author_id == user_id)
        tweet_count = await self.db.execute(tweet_count_query)

        # Latest tweet
        latest_tweet_query = select(func.max(Tweet.created_at)).filter(Tweet.author_id == user_id)
        latest_tweet = await self.db.execute(latest_tweet_query)

        # Total engagement
        engagement_query = select(func.sum(Tweet.total_engagement)).filter(Tweet.author_id == user_id)
        total_engagement = await self.db.execute(engagement_query)

        return {
            "tweet_count": tweet_count.scalar() or 0,
            "latest_tweet_at": latest_tweet.scalar(),
            "total_engagement": total_engagement.scalar() or 0
        }

    async def get_monitored_user_relationships(
        self,
        user_id: str,
        relationship_type: Optional[str] = None,
        limit: int = 20
    ) -> List[dict]:
        """Get relationships for a monitored user from user_network table"""
        query = select(UserNetwork).filter(UserNetwork.source_user_id == user_id)

        if relationship_type:
            query = query.filter(UserNetwork.relationship_type == relationship_type)

        query = query.order_by(UserNetwork.total_count.desc()).limit(limit)
        result = await self.db.execute(query)
        relationships = result.scalars().all()

        return [
            {
                "target_id": rel.target_id,
                "target_username": rel.target_username,
                "relationship_type": rel.relationship_type,
                "interaction_count": rel.total_count,
                "unique_tweets": rel.unique_tweets,
                "first_interaction": rel.first_seen,
                "last_interaction": rel.last_seen
            }
            for rel in relationships
        ]

    async def get_monitored_user_with_project(self, user_id: int) -> dict:
        """Get monitored user with project information"""
        query = (
            select(MonitoredUser, Project.name)
            .join(Project, MonitoredUser.project_id == Project.id)
            .filter(MonitoredUser.id == user_id)
        )
        result = await self.db.execute(query)
        row = result.first()

        if row:
            user, project_name = row
            return {
                "user": user,
                "project_name": project_name
            }
        return None