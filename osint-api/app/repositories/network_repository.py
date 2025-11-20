from typing import List, Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc
from app.models.network import UserNetwork


class NetworkRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_top_users_by_relationship(
        self,
        relationship_type: str,
        limit: int = 20
    ) -> List[UserNetwork]:
        """Get top users by relationship type sorted by total_count"""
        query = (
            select(UserNetwork)
            .filter(UserNetwork.relationship_type == relationship_type)
            .order_by(desc(UserNetwork.total_count))
            .limit(limit)
        )

        result = await self.db.execute(query)
        return result.scalars().all()

    async def get_user_network(
        self,
        source_user_id: str,
        relationship_type: Optional[str] = None,
        limit: int = 50,
        offset: int = 0
    ) -> List[UserNetwork]:
        """Get network relationships for a specific user"""
        query = select(UserNetwork).filter(UserNetwork.source_user_id == source_user_id)

        if relationship_type:
            query = query.filter(UserNetwork.relationship_type == relationship_type)

        query = query.order_by(desc(UserNetwork.total_count))
        query = query.limit(limit).offset(offset)

        result = await self.db.execute(query)
        return result.scalars().all()

    async def get_relationship_stats(
        self,
        source_user_id: str,
        relationship_type: str,
        target_id: str
    ) -> Optional[UserNetwork]:
        """Get specific relationship statistics"""
        query = (
            select(UserNetwork)
            .filter(
                UserNetwork.source_user_id == source_user_id,
                UserNetwork.relationship_type == relationship_type,
                UserNetwork.target_id == target_id
            )
        )

        result = await self.db.execute(query)
        return result.scalar_one_or_none()

    async def get_all_relationship_types(self) -> List[str]:
        """Get all unique relationship types"""
        query = select(UserNetwork.relationship_type).distinct()
        result = await self.db.execute(query)
        return [row[0] for row in result]