from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Optional, List

from app.database import get_db
from app.auth.api_key import verify_api_key
from app.repositories.network_repository import NetworkRepository
from app.schemas.network import TopUserSchema, NetworkAnalyticsResponse

router = APIRouter(
    prefix="/analytics",
    tags=["analytics"],
    dependencies=[Depends(verify_api_key)]
)


@router.get("/network/top-users", response_model=NetworkAnalyticsResponse)
async def get_top_users(
    relationship_type: str = Query(..., description="Type of relationship (mention, retweet, hashtag, etc.)"),
    limit: int = Query(20, ge=1, le=100, description="Number of top users to return"),
    db: AsyncSession = Depends(get_db)
):
    """Get top users by relationship type based on total_count"""
    repo = NetworkRepository(db)
    network_data = await repo.get_top_users_by_relationship(
        relationship_type=relationship_type,
        limit=limit
    )

    top_users = []
    for item in network_data:
        top_users.append(TopUserSchema(
            source_user_id=item.source_user_id,
            total_count=item.total_count,
            unique_tweets=item.unique_tweets,
            total_weight=item.total_weight,
            target_username=item.target_username
        ))

    return NetworkAnalyticsResponse(
        relationship_type=relationship_type,
        top_users=top_users,
        total=len(top_users)
    )


@router.get("/network/relationship-types", response_model=List[str])
async def get_relationship_types(
    db: AsyncSession = Depends(get_db)
):
    """Get all available relationship types"""
    repo = NetworkRepository(db)
    return await repo.get_all_relationship_types()


@router.get("/network/user/{user_id}")
async def get_user_network(
    user_id: str,
    relationship_type: Optional[str] = Query(None, description="Filter by relationship type"),
    limit: int = Query(50, ge=1, le=500),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_db)
):
    """Get network relationships for a specific user"""
    repo = NetworkRepository(db)
    network_data = await repo.get_user_network(
        source_user_id=user_id,
        relationship_type=relationship_type,
        limit=limit,
        offset=offset
    )

    return {
        "user_id": user_id,
        "relationships": [
            {
                "relationship_type": item.relationship_type,
                "target_id": item.target_id,
                "target_username": item.target_username,
                "total_count": item.total_count,
                "unique_tweets": item.unique_tweets,
                "total_weight": item.total_weight,
                "first_seen": item.first_seen,
                "last_seen": item.last_seen
            }
            for item in network_data
        ],
        "total": len(network_data)
    }