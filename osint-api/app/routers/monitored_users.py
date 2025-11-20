from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Optional, List

from app.database import get_db
from app.auth.api_key import verify_api_key
from app.repositories.monitored_user_repository import MonitoredUserRepository
from app.schemas.monitored_user import (
    MonitoredUserWithStatsSchema,
    MonitoredUserListResponse,
    MonitoredUserRelationshipSchema
)
from app.schemas.tweet import TweetSchema, TweetListResponse

router = APIRouter(
    prefix="/monitored-users",
    tags=["monitored-users"],
    dependencies=[Depends(verify_api_key)]
)


@router.get("", response_model=MonitoredUserListResponse)
async def get_monitored_users(
    project_id: Optional[int] = Query(None, description="Filter by project ID"),
    active_only: bool = Query(False, description="Return only active users"),
    db: AsyncSession = Depends(get_db)
):
    """Get list of all monitored users with statistics"""
    repo = MonitoredUserRepository(db)

    # Get users based on filters
    if active_only:
        users = await repo.get_active_monitored_users(project_id)
    else:
        users = await repo.get_all_monitored_users(project_id)

    # Add statistics and project info to each user
    users_with_stats = []
    for user in users:
        # Get stats using the Twitter user_id if available
        if user.user_id:
            stats = await repo.get_monitored_user_stats(user.user_id)
        else:
            stats = {"tweet_count": 0, "latest_tweet_at": None, "total_engagement": 0}

        # Get project name
        user_with_project = await repo.get_monitored_user_with_project(user.id)
        project_name = user_with_project["project_name"] if user_with_project else None

        user_data = MonitoredUserWithStatsSchema(
            id=user.id,
            project_id=user.project_id,
            platform=user.platform,
            username=user.username,
            user_id=user.user_id,
            channel_url=user.channel_url,
            is_active=user.is_active,
            created_at=user.created_at,
            metadata=user.metadata_json,
            tweet_count=stats["tweet_count"],
            latest_tweet_at=stats["latest_tweet_at"],
            total_engagement=stats["total_engagement"],
            project_name=project_name
        )
        users_with_stats.append(user_data)

    return MonitoredUserListResponse(
        users=users_with_stats,
        total=len(users_with_stats)
    )


@router.get("/{user_id}", response_model=MonitoredUserWithStatsSchema)
async def get_monitored_user(
    user_id: int,
    db: AsyncSession = Depends(get_db)
):
    """Get details of a specific monitored user"""
    repo = MonitoredUserRepository(db)

    user = await repo.get_monitored_user_by_id(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="Monitored user not found")

    # Get stats
    if user.user_id:
        stats = await repo.get_monitored_user_stats(user.user_id)
    else:
        stats = {"tweet_count": 0, "latest_tweet_at": None, "total_engagement": 0}

    # Get project name
    user_with_project = await repo.get_monitored_user_with_project(user.id)
    project_name = user_with_project["project_name"] if user_with_project else None

    return MonitoredUserWithStatsSchema(
        id=user.id,
        project_id=user.project_id,
        platform=user.platform,
        username=user.username,
        user_id=user.user_id,
        channel_url=user.channel_url,
        is_active=user.is_active,
        created_at=user.created_at,
        metadata=user.metadata,
        tweet_count=stats["tweet_count"],
        latest_tweet_at=stats["latest_tweet_at"],
        total_engagement=stats["total_engagement"],
        project_name=project_name
    )


@router.get("/{user_id}/tweets", response_model=TweetListResponse)
async def get_monitored_user_tweets(
    user_id: int,
    limit: int = Query(50, ge=1, le=1000),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_db)
):
    """Get tweets from a monitored user"""
    repo = MonitoredUserRepository(db)

    # Get the monitored user
    user = await repo.get_monitored_user_by_id(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="Monitored user not found")

    if not user.user_id:
        raise HTTPException(status_code=400, detail="User has no Twitter ID associated")

    # Get tweets
    tweets = await repo.get_tweets_by_monitored_user(
        user_id=user.user_id,
        limit=limit,
        offset=offset
    )

    # Get total count
    stats = await repo.get_monitored_user_stats(user.user_id)

    return TweetListResponse(
        tweets=[TweetSchema.model_validate(tweet) for tweet in tweets],
        total=stats["tweet_count"],
        limit=limit,
        offset=offset
    )


@router.get("/{user_id}/relationships", response_model=List[MonitoredUserRelationshipSchema])
async def get_monitored_user_relationships(
    user_id: int,
    relationship_type: Optional[str] = Query(None, description="Filter by relationship type (mention, retweet, hashtag)"),
    limit: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db)
):
    """Get network relationships for a monitored user"""
    repo = MonitoredUserRepository(db)

    # Get the monitored user
    user = await repo.get_monitored_user_by_id(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="Monitored user not found")

    if not user.user_id:
        raise HTTPException(status_code=400, detail="User has no Twitter ID associated")

    # Get relationships
    relationships = await repo.get_monitored_user_relationships(
        user_id=user.user_id,
        relationship_type=relationship_type,
        limit=limit
    )

    return [
        MonitoredUserRelationshipSchema(
            user_id=rel["target_id"],
            username=rel["target_username"] or "",
            relationship_type=rel["relationship_type"],
            interaction_count=rel["interaction_count"],
            unique_tweets=rel["unique_tweets"],
            first_interaction=rel["first_interaction"],
            last_interaction=rel["last_interaction"]
        )
        for rel in relationships
    ]


@router.get("/by-username/{username}", response_model=MonitoredUserWithStatsSchema)
async def get_monitored_user_by_username(
    username: str,
    db: AsyncSession = Depends(get_db)
):
    """Get monitored user by username"""
    repo = MonitoredUserRepository(db)

    user = await repo.get_monitored_user_by_username(username)
    if not user:
        raise HTTPException(status_code=404, detail="Monitored user not found")

    # Get stats
    if user.user_id:
        stats = await repo.get_monitored_user_stats(user.user_id)
    else:
        stats = {"tweet_count": 0, "latest_tweet_at": None, "total_engagement": 0}

    # Get project name
    user_with_project = await repo.get_monitored_user_with_project(user.id)
    project_name = user_with_project["project_name"] if user_with_project else None

    return MonitoredUserWithStatsSchema(
        id=user.id,
        project_id=user.project_id,
        platform=user.platform,
        username=user.username,
        user_id=user.user_id,
        channel_url=user.channel_url,
        is_active=user.is_active,
        created_at=user.created_at,
        metadata=user.metadata,
        tweet_count=stats["tweet_count"],
        latest_tweet_at=stats["latest_tweet_at"],
        total_engagement=stats["total_engagement"],
        project_name=project_name
    )