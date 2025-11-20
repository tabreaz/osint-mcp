from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List

from app.database import get_db
from app.auth.api_key import verify_api_key
from app.repositories.collection_repository import CollectionRepository
from app.repositories.tweet_repository import TweetRepository
from app.schemas.collection import ThemeSchema, ThemeListResponse
from app.schemas.tweet import TweetSchema, TweetListResponse

router = APIRouter(
    prefix="/themes",
    tags=["themes"],
    dependencies=[Depends(verify_api_key)]
)


@router.get("", response_model=ThemeListResponse)
async def get_themes(
    db: AsyncSession = Depends(get_db)
):
    """Get list of all themes with tweet counts"""
    repo = CollectionRepository(db)
    themes_data = await repo.get_themes()
    total = await repo.count_themes()

    themes = [ThemeSchema(**theme) for theme in themes_data]

    return ThemeListResponse(
        themes=themes,
        total=total
    )


@router.get("/{theme_code}", response_model=ThemeSchema)
async def get_theme(
    theme_code: str,
    db: AsyncSession = Depends(get_db)
):
    """Get details of a specific theme"""
    repo = CollectionRepository(db)
    theme = await repo.get_theme_by_code(theme_code)

    if not theme:
        raise HTTPException(status_code=404, detail="Theme not found")

    return ThemeSchema(**theme)


@router.get("/{theme_code}/tweets", response_model=TweetListResponse)
async def get_theme_tweets(
    theme_code: str,
    limit: int = Query(50, ge=1, le=1000),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_db)
):
    """Get tweets for a specific theme"""
    tweet_repo = TweetRepository(db)
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