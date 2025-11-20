from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List, Optional

from app.database import get_db
from app.auth.api_key import verify_api_key
from app.repositories.theme_repository import ThemeRepository
from app.repositories.tweet_repository import TweetRepository
from app.schemas.theme import ThemeWithStatsSchema, ThemeDetailSchema, ThemeListResponse
from app.schemas.tweet import TweetSchema, TweetListResponse

router = APIRouter(
    prefix="/themes",
    tags=["themes"],
    dependencies=[Depends(verify_api_key)]
)


@router.get("", response_model=ThemeListResponse)
async def get_themes(
    project_id: Optional[int] = Query(None, description="Filter by project ID"),
    active_only: bool = Query(False, description="Return only active themes"),
    db: AsyncSession = Depends(get_db)
):
    """Get list of all themes with statistics"""
    repo = ThemeRepository(db)

    # Get themes based on filters
    if active_only:
        themes = await repo.get_active_themes()
    elif project_id:
        themes = await repo.get_themes_by_project(project_id)
    else:
        themes = await repo.get_all_themes()

    # Add statistics to each theme
    themes_with_stats = []
    for theme in themes:
        stats = await repo.get_theme_stats(theme.code)
        theme_data = ThemeWithStatsSchema(
            id=theme.id,
            project_id=theme.project_id,
            name=theme.name,
            code=theme.code,
            description=theme.description,
            priority=theme.priority,
            is_active=theme.is_active,
            created_at=theme.created_at,
            tweet_count=stats["tweet_count"],
            last_collected_at=stats["last_collected_at"],
            query_count=stats["query_count"]
        )
        themes_with_stats.append(theme_data)

    return ThemeListResponse(
        themes=themes_with_stats,
        total=len(themes_with_stats)
    )


@router.get("/{theme_code}", response_model=ThemeDetailSchema)
async def get_theme(
    theme_code: str,
    db: AsyncSession = Depends(get_db)
):
    """Get details of a specific theme with project info"""
    repo = ThemeRepository(db)

    # Get theme with project
    theme_data = await repo.get_theme_with_project(theme_code)
    if not theme_data:
        raise HTTPException(status_code=404, detail="Theme not found")

    theme = theme_data["theme"]
    project_name = theme_data["project_name"]

    # Get statistics
    stats = await repo.get_theme_stats(theme_code)

    return ThemeDetailSchema(
        id=theme.id,
        project_id=theme.project_id,
        name=theme.name,
        code=theme.code,
        description=theme.description,
        priority=theme.priority,
        is_active=theme.is_active,
        created_at=theme.created_at,
        tweet_count=stats["tweet_count"],
        last_collected_at=stats["last_collected_at"],
        query_count=stats["query_count"],
        project_name=project_name
    )


@router.get("/{theme_code}/tweets", response_model=TweetListResponse)
async def get_theme_tweets(
    theme_code: str,
    limit: int = Query(50, ge=1, le=1000),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_db)
):
    """Get tweets for a specific theme"""
    tweet_repo = TweetRepository(db)

    # Verify theme exists
    theme_repo = ThemeRepository(db)
    theme = await theme_repo.get_theme_by_code(theme_code)
    if not theme:
        raise HTTPException(status_code=404, detail="Theme not found")

    # Get tweets
    tweets = await tweet_repo.get_tweets_by_theme(
        theme_code=theme_code,
        limit=limit,
        offset=offset
    )
    total = await tweet_repo.count_tweets(theme_code=theme_code)

    return TweetListResponse(
        tweets=[TweetSchema.model_validate(tweet) for tweet in tweets],
        total=total,
        limit=limit,
        offset=offset
    )