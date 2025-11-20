from typing import List, Optional, Dict, Any
from sqlalchemy import select, func, and_, or_
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.topic import TopicDefinition, TopicDefinitionRefined


class TopicRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_refined_topics(
        self,
        category: Optional[str] = None,
        monitoring_priority: Optional[str] = None,
        min_quality_score: Optional[float] = None,
        limit: int = 100
    ) -> List[TopicDefinitionRefined]:
        """
        Get refined topics - ALWAYS use refined over raw topics
        """
        query = select(TopicDefinitionRefined)

        if category:
            query = query.where(TopicDefinitionRefined.category == category)

        if monitoring_priority:
            query = query.where(TopicDefinitionRefined.monitoring_priority == monitoring_priority)

        if min_quality_score:
            query = query.where(TopicDefinitionRefined.quality_score >= min_quality_score)

        query = query.order_by(
            TopicDefinitionRefined.relevance_to_project.desc(),
            TopicDefinitionRefined.quality_score.desc()
        ).limit(limit)

        result = await self.db.execute(query)
        return result.scalars().all()

    async def get_refined_topic_by_id(self, topic_id: int) -> Optional[TopicDefinitionRefined]:
        """Get a single refined topic by ID"""
        query = select(TopicDefinitionRefined).where(
            TopicDefinitionRefined.topic_id == topic_id
        )
        result = await self.db.execute(query)
        return result.scalar_one_or_none()

    async def get_topic_with_refinement(self, topic_id: int) -> Dict[str, Any]:
        """
        Get topic with both raw and refined data for comparison
        """
        # Get refined topic (primary)
        refined = await self.get_refined_topic_by_id(topic_id)

        # Get raw topic for reference
        raw_query = select(TopicDefinition).where(
            TopicDefinition.topic_id == topic_id
        )
        raw_result = await self.db.execute(raw_query)
        raw = raw_result.scalar_one_or_none()

        if not refined and not raw:
            return None

        return {
            'topic_id': topic_id,
            'refined': {
                'name': refined.refined_name if refined else None,
                'label': refined.refined_label if refined else None,
                'category': refined.category if refined else None,
                'subcategory': refined.subcategory if refined else None,
                'monitoring_priority': refined.monitoring_priority if refined else None,
                'quality_score': float(refined.quality_score) if refined and refined.quality_score else 0,
                'relevance_to_project': float(refined.relevance_to_project) if refined and refined.relevance_to_project else 0,
                'recommended_actions': refined.recommended_actions if refined else [],
                'clean_keywords': refined.clean_keywords if refined else []
            } if refined else None,
            'raw': {
                'name': raw.topic_name if raw else None,
                'label': raw.topic_label if raw else None,
                'size': raw.topic_size if raw else 0,
                'keywords': raw.keywords if raw else {},
                'top_words': raw.top_words if raw else []
            } if raw else None
        }

    async def get_topics_by_category(self) -> Dict[str, List[Dict[str, Any]]]:
        """
        Get all refined topics grouped by category
        """
        query = select(TopicDefinitionRefined).where(
            TopicDefinitionRefined.monitoring_priority != 'ignore'
        ).order_by(
            TopicDefinitionRefined.category,
            TopicDefinitionRefined.relevance_to_project.desc()
        )

        result = await self.db.execute(query)
        topics = result.scalars().all()

        # Group by category
        categorized = {}
        for topic in topics:
            category = topic.category or 'Uncategorized'
            if category not in categorized:
                categorized[category] = []

            categorized[category].append({
                'topic_id': topic.topic_id,
                'name': topic.refined_name,
                'label': topic.refined_label,
                'subcategory': topic.subcategory,
                'priority': topic.monitoring_priority,
                'quality_score': float(topic.quality_score) if topic.quality_score else 0,
                'relevance': float(topic.relevance_to_project) if topic.relevance_to_project else 0,
                'actions_count': len(topic.recommended_actions) if topic.recommended_actions else 0
            })

        return categorized

    async def get_actionable_topics(self, limit: int = 50) -> List[Dict[str, Any]]:
        """
        Get topics with specific actionable recommendations
        Topics that have concrete monitoring actions defined
        """
        query = select(TopicDefinitionRefined).where(
            and_(
                TopicDefinitionRefined.monitoring_priority.in_(['high', 'medium']),
                TopicDefinitionRefined.recommended_actions.isnot(None),
                func.jsonb_array_length(TopicDefinitionRefined.recommended_actions) > 0
            )
        ).order_by(
            TopicDefinitionRefined.monitoring_priority,
            TopicDefinitionRefined.relevance_to_project.desc()
        ).limit(limit)

        result = await self.db.execute(query)
        topics = result.scalars().all()

        return [
            {
                'topic_id': t.topic_id,
                'name': t.refined_name,
                'category': t.category,
                'priority': t.monitoring_priority,
                'actions': t.recommended_actions,
                'relevance': float(t.relevance_to_project) if t.relevance_to_project else 0
            }
            for t in topics
        ]

    async def search_refined_topics(self, search_term: str) -> List[TopicDefinitionRefined]:
        """
        Search refined topics by name, label, or keywords
        """
        search_pattern = f'%{search_term}%'

        query = select(TopicDefinitionRefined).where(
            or_(
                TopicDefinitionRefined.refined_name.ilike(search_pattern),
                TopicDefinitionRefined.refined_label.ilike(search_pattern),
                TopicDefinitionRefined.category.ilike(search_pattern),
                TopicDefinitionRefined.subcategory.ilike(search_pattern),
                func.array_to_string(
                    TopicDefinitionRefined.clean_keywords, ' '
                ).ilike(search_pattern)
            )
        ).order_by(
            TopicDefinitionRefined.relevance_to_project.desc()
        )

        result = await self.db.execute(query)
        return result.scalars().all()

    async def get_topic_statistics(self) -> Dict[str, Any]:
        """
        Get overall statistics about refined topics
        """
        # Count by monitoring priority
        priority_query = select(
            TopicDefinitionRefined.monitoring_priority,
            func.count(TopicDefinitionRefined.topic_id).label('count')
        ).group_by(TopicDefinitionRefined.monitoring_priority)

        priority_result = await self.db.execute(priority_query)
        priority_counts = {row.monitoring_priority: row.count for row in priority_result}

        # Count by category
        category_query = select(
            TopicDefinitionRefined.category,
            func.count(TopicDefinitionRefined.topic_id).label('count')
        ).group_by(TopicDefinitionRefined.category)

        category_result = await self.db.execute(category_query)
        category_counts = {row.category: row.count for row in category_result}

        # Average scores
        stats_query = select(
            func.count(TopicDefinitionRefined.topic_id).label('total'),
            func.avg(TopicDefinitionRefined.quality_score).label('avg_quality'),
            func.avg(TopicDefinitionRefined.relevance_to_project).label('avg_relevance'),
            func.count(
                func.nullif(
                    func.jsonb_array_length(TopicDefinitionRefined.recommended_actions), 0
                )
            ).label('topics_with_actions')
        )

        stats_result = await self.db.execute(stats_query)
        stats = stats_result.first()

        return {
            'total_topics': stats.total or 0,
            'avg_quality_score': float(stats.avg_quality) if stats.avg_quality else 0,
            'avg_relevance': float(stats.avg_relevance) if stats.avg_relevance else 0,
            'topics_with_actions': stats.topics_with_actions or 0,
            'by_priority': priority_counts,
            'by_category': category_counts
        }