from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List, Dict, Any, Optional
from datetime import datetime

from app.database import get_db
from app.dependencies import get_api_key
from app.repositories.topic_analytics import TopicAnalyticsRepository
from app.schemas.topic_analytics import (
    ThemeTopicAnalytics,
    AuthorExpertise,
    TopicEvolutionTrend,
    TopicAnalyticsQuery,
    AuthorExpertiseQuery,
    EvolutionTrendQuery
)

router = APIRouter(
    prefix="/api/topic-analytics",
    tags=["topic-analytics"],
    dependencies=[Depends(get_api_key)]
)


@router.get("/topics-per-theme", response_model=Dict[str, ThemeTopicAnalytics])
async def get_topics_per_theme(
    theme_id: Optional[int] = Query(None, description="Filter by theme ID"),
    start_date: Optional[datetime] = Query(None, description="Start date filter"),
    end_date: Optional[datetime] = Query(None, description="End date filter"),
    db: AsyncSession = Depends(get_db)
):
    """
    Get analytics on topics related to themes.
    Shows which topics are most prevalent in each theme's content.
    """
    repo = TopicAnalyticsRepository(db)
    return await repo.get_topic_theme_analytics(
        theme_id=theme_id,
        start_date=start_date,
        end_date=end_date
    )


@router.get("/top-authors-by-topic", response_model=List[AuthorExpertise])
async def get_top_authors_by_topic(
    topic_id: Optional[int] = Query(None, description="Filter by topic ID"),
    min_tweet_count: int = Query(5, ge=1, description="Minimum tweets per topic"),
    limit: int = Query(100, le=1000, description="Maximum results to return"),
    db: AsyncSession = Depends(get_db)
):
    """
    Get top authors who post about specific topics.
    Returns authors ranked by post count and engagement on the topic.
    """
    repo = TopicAnalyticsRepository(db)
    return await repo.get_author_expertise(
        topic_id=topic_id,
        min_tweet_count=min_tweet_count,
        limit=limit
    )


@router.get("/topic-trends-over-time", response_model=List[TopicEvolutionTrend])
async def get_topic_trends_over_time(
    topic_ids: Optional[str] = Query(None, description="Comma-separated topic IDs"),
    hours: int = Query(24, ge=1, le=720, description="Hours to look back"),
    min_growth_rate: Optional[float] = Query(None, description="Minimum growth rate filter"),
    db: AsyncSession = Depends(get_db)
):
    """
    Get topic popularity trends over time.
    Shows hourly volume changes and growth rates for topics.
    Note: If empty, data is computed on-demand from tweet history.
    """
    # Parse topic IDs if provided
    parsed_topic_ids = None
    if topic_ids:
        parsed_topic_ids = [int(id.strip()) for id in topic_ids.split(',')]

    repo = TopicAnalyticsRepository(db)
    return await repo.get_topic_evolution_trends(
        topic_ids=parsed_topic_ids,
        hours=hours,
        min_growth_rate=min_growth_rate
    )




@router.post("/topics-per-theme", response_model=Dict[str, ThemeTopicAnalytics])
async def post_topics_per_theme(
    query: TopicAnalyticsQuery,
    db: AsyncSession = Depends(get_db)
):
    """
    Get theme-topic analytics with POST body parameters.
    """
    repo = TopicAnalyticsRepository(db)
    return await repo.get_topic_theme_analytics(
        theme_id=query.theme_id,
        start_date=query.start_date,
        end_date=query.end_date
    )


@router.post("/top-authors-by-topic", response_model=List[AuthorExpertise])
async def post_top_authors_by_topic(
    query: AuthorExpertiseQuery,
    db: AsyncSession = Depends(get_db)
):
    """
    Get author expertise with POST body parameters.
    """
    repo = TopicAnalyticsRepository(db)
    return await repo.get_author_expertise(
        topic_id=query.topic_id,
        min_tweet_count=query.min_tweet_count,
        limit=query.limit
    )


@router.post("/topic-trends-over-time", response_model=List[TopicEvolutionTrend])
async def post_topic_trends_over_time(
    query: EvolutionTrendQuery,
    db: AsyncSession = Depends(get_db)
):
    """
    Get evolution trends with POST body parameters.
    """
    repo = TopicAnalyticsRepository(db)
    return await repo.get_topic_evolution_trends(
        topic_ids=query.topic_ids,
        hours=query.hours,
        min_growth_rate=query.min_growth_rate
    )


