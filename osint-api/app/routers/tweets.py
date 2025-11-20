from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Optional

from app.database import get_db
from app.auth.api_key import verify_api_key
from app.repositories.tweet_repository import TweetRepository
from app.schemas.tweet import TweetSchema, TweetDetailSchema, TweetListResponse

router = APIRouter(
    prefix="/tweets",
    tags=["tweets"],
    dependencies=[Depends(verify_api_key)]
)


@router.get("", response_model=TweetListResponse)
async def get_tweets(
    theme_code: Optional[str] = Query(None, description="Filter by theme code"),
    limit: int = Query(50, ge=1, le=1000, description="Number of results"),
    offset: int = Query(0, ge=0, description="Offset for pagination"),
    db: AsyncSession = Depends(get_db)
):
    """Get list of tweets with optional theme filtering"""
    repo = TweetRepository(db)
    tweets = await repo.get_tweets(theme_code=theme_code, limit=limit, offset=offset)
    total = await repo.count_tweets(theme_code=theme_code)

    return TweetListResponse(
        tweets=[TweetSchema.model_validate(tweet) for tweet in tweets],
        total=total,
        limit=limit,
        offset=offset
    )


@router.get("/{tweet_id}", response_model=TweetDetailSchema)
async def get_tweet(
    tweet_id: str,
    db: AsyncSession = Depends(get_db)
):
    """Get a single tweet by ID"""
    repo = TweetRepository(db)
    tweet = await repo.get_tweet_by_id(tweet_id)

    if not tweet:
        raise HTTPException(status_code=404, detail="Tweet not found")

    return TweetDetailSchema.model_validate(tweet)


@router.get("/search/{search_term}", response_model=TweetListResponse)
async def search_tweets(
    search_term: str,
    limit: int = Query(50, ge=1, le=1000),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_db)
):
    """Search tweets by text content"""
    repo = TweetRepository(db)
    tweets = await repo.search_tweets(search_term=search_term, limit=limit, offset=offset)

    return TweetListResponse(
        tweets=[TweetSchema.model_validate(tweet) for tweet in tweets],
        total=len(tweets),
        limit=limit,
        offset=offset
    )