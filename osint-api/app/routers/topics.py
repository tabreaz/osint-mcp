from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List, Dict, Any, Optional

from app.database import get_db
from app.dependencies import get_api_key
from app.repositories.topic_repository import TopicRepository

router = APIRouter(
    prefix="/api/topics",
    tags=["topics"],
    dependencies=[Depends(get_api_key)]
)


@router.get("/refined", response_model=List[Dict[str, Any]])
async def get_refined_topics(
    category: Optional[str] = Query(None, description="Filter by category (e.g., 'Humanitarian Crisis')"),
    priority: Optional[str] = Query(None, description="Filter by priority: high|medium|low|ignore"),
    min_quality: Optional[float] = Query(None, ge=0, le=1, description="Minimum quality score"),
    limit: int = Query(100, le=500, description="Maximum results"),
    db: AsyncSession = Depends(get_db)
):
    """
    Get LLM-refined topics with clean names and actionable recommendations.
    This is the PRIMARY endpoint for topic data - always use refined over raw.
    """
    repo = TopicRepository(db)
    topics = await repo.get_refined_topics(
        category=category,
        monitoring_priority=priority,
        min_quality_score=min_quality,
        limit=limit
    )

    return [
        {
            'topic_id': t.topic_id,
            'name': t.refined_name,
            'label': t.refined_label,
            'category': t.category,
            'subcategory': t.subcategory,
            'priority': t.monitoring_priority,
            'quality_score': float(t.quality_score) if t.quality_score else 0,
            'relevance': float(t.relevance_to_project) if t.relevance_to_project else 0,
            'recommended_actions': t.recommended_actions or [],
            'clean_keywords': t.clean_keywords or []
        }
        for t in topics
    ]


@router.get("/refined/{topic_id}", response_model=Dict[str, Any])
async def get_refined_topic(
    topic_id: int,
    db: AsyncSession = Depends(get_db)
):
    """
    Get a single refined topic by ID with all details.
    """
    repo = TopicRepository(db)
    topic = await repo.get_refined_topic_by_id(topic_id)

    if not topic:
        raise HTTPException(status_code=404, detail=f"Topic {topic_id} not found")

    return {
        'topic_id': topic.topic_id,
        'name': topic.refined_name,
        'label': topic.refined_label,
        'category': topic.category,
        'subcategory': topic.subcategory,
        'priority': topic.monitoring_priority,
        'quality_score': float(topic.quality_score) if topic.quality_score else 0,
        'relevance': float(topic.relevance_to_project) if topic.relevance_to_project else 0,
        'recommended_actions': topic.recommended_actions or [],
        'clean_keywords': topic.clean_keywords or [],
        'entities': topic.entities or {},
        'overall_sentiment': topic.overall_sentiment,
        'stance': topic.stance or {},
        'noise_level': topic.noise_level,
        'aligned_theme_ids': topic.aligned_theme_ids or [],
        'suggested_new_theme': topic.suggested_new_theme
    }


@router.get("/by-category", response_model=Dict[str, List[Dict[str, Any]]])
async def get_topics_by_category(
    db: AsyncSession = Depends(get_db)
):
    """
    Get all refined topics grouped by category.
    Useful for understanding topic distribution and planning monitoring.
    """
    repo = TopicRepository(db)
    return await repo.get_topics_by_category()


@router.get("/actionable", response_model=List[Dict[str, Any]])
async def get_actionable_topics(
    limit: int = Query(50, le=200, description="Maximum results"),
    db: AsyncSession = Depends(get_db)
):
    """
    Get topics with specific actionable recommendations.
    Returns only topics that have concrete monitoring actions defined.
    These are ready for automated monitoring setup.
    """
    repo = TopicRepository(db)
    return await repo.get_actionable_topics(limit=limit)


@router.get("/search", response_model=List[Dict[str, Any]])
async def search_topics(
    q: str = Query(..., min_length=2, description="Search term"),
    db: AsyncSession = Depends(get_db)
):
    """
    Search refined topics by name, label, category, or keywords.
    """
    repo = TopicRepository(db)
    topics = await repo.search_refined_topics(q)

    return [
        {
            'topic_id': t.topic_id,
            'name': t.refined_name,
            'label': t.refined_label,
            'category': t.category,
            'priority': t.monitoring_priority,
            'relevance': float(t.relevance_to_project) if t.relevance_to_project else 0
        }
        for t in topics
    ]


@router.get("/statistics", response_model=Dict[str, Any])
async def get_topic_statistics(
    db: AsyncSession = Depends(get_db)
):
    """
    Get overall statistics about refined topics.
    Includes counts by category, priority, and quality metrics.
    """
    repo = TopicRepository(db)
    return await repo.get_topic_statistics()


@router.get("/{topic_id}/comparison", response_model=Dict[str, Any])
async def get_topic_comparison(
    topic_id: int,
    db: AsyncSession = Depends(get_db)
):
    """
    Get both raw and refined data for a topic to see the LLM improvements.
    Useful for understanding how topics were cleaned and categorized.
    """
    repo = TopicRepository(db)
    comparison = await repo.get_topic_with_refinement(topic_id)

    if not comparison:
        raise HTTPException(status_code=404, detail=f"Topic {topic_id} not found")

    return comparison