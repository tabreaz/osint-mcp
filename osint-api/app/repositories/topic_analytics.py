from typing import List, Optional, Dict, Any
from datetime import datetime, timedelta
from sqlalchemy import select, func, and_, or_, case, text
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
from app.models.topic import TopicDefinition, TopicDefinitionRefined
from app.models.topic_analytics import TweetTopic, AuthorTopic, TopicEvolution
from app.models.tweet import Tweet
from app.models.theme import Theme
from app.models.collection import TweetCollection


class TopicAnalyticsRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_topic_theme_analytics(
        self,
        theme_id: Optional[int] = None,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None
    ) -> Dict[str, Any]:
        """Get analytics on topics related to themes"""

        # Base query to link themes with topics via tweet collections
        base_query = (
            select(
                TweetCollection.theme_name,
                TweetTopic.topic_id,
                func.count(func.distinct(TweetTopic.tweet_id)).label('tweet_count'),
                func.avg(TweetTopic.probability).label('avg_probability'),
                func.count(func.distinct(Tweet.author_id)).label('unique_authors')
            )
            .join(TweetTopic, TweetTopic.tweet_id == TweetCollection.tweet_id)
            .join(Tweet, Tweet.tweet_id == TweetCollection.tweet_id)
            .where(TweetTopic.topic_id != -1)  # Exclude outliers
        )

        # Apply filters
        if theme_id:
            # Get theme by ID to get the theme_code
            theme_query = select(Theme).where(Theme.id == theme_id)
            theme_result = await self.db.execute(theme_query)
            theme = theme_result.scalar_one_or_none()
            if theme:
                base_query = base_query.where(TweetCollection.theme_code == theme.code)

        if start_date:
            base_query = base_query.where(Tweet.created_at >= start_date)
        if end_date:
            base_query = base_query.where(Tweet.created_at <= end_date)

        # Group by theme and topic
        base_query = base_query.group_by(
            TweetCollection.theme_name,
            TweetTopic.topic_id
        )

        result = await self.db.execute(base_query)
        raw_data = result.all()

        # Get refined topic information
        refined_query = select(TopicDefinitionRefined)
        refined_result = await self.db.execute(refined_query)
        refined_topics = {t.topic_id: t for t in refined_result.scalars().all()}

        # Organize results by theme
        analytics = {}
        for row in raw_data:
            theme_name = row.theme_name
            if theme_name not in analytics:
                analytics[theme_name] = {
                    'theme_name': theme_name,
                    'topics': [],
                    'total_tweets': 0,
                    'total_authors': 0
                }

            refined = refined_topics.get(row.topic_id)
            topic_info = {
                'topic_id': row.topic_id,
                'refined_name': refined.refined_name if refined else f"Topic {row.topic_id}",
                'category': refined.category if refined else None,
                'monitoring_priority': refined.monitoring_priority if refined else 'medium',
                'tweet_count': row.tweet_count,
                'avg_probability': float(row.avg_probability) if row.avg_probability else 0,
                'unique_authors': row.unique_authors
            }

            analytics[theme_name]['topics'].append(topic_info)
            analytics[theme_name]['total_tweets'] += row.tweet_count
            analytics[theme_name]['total_authors'] += row.unique_authors

        # Sort topics within each theme by tweet count
        for theme_data in analytics.values():
            theme_data['topics'].sort(key=lambda x: x['tweet_count'], reverse=True)

        return analytics

    async def get_author_expertise(
        self,
        topic_id: Optional[int] = None,
        min_tweet_count: int = 5,
        limit: int = 100
    ) -> List[Dict[str, Any]]:
        """Get authors with expertise in specific topics"""

        query = (
            select(AuthorTopic)
            .where(AuthorTopic.tweet_count >= min_tweet_count)
        )

        if topic_id:
            query = query.where(AuthorTopic.topic_id == topic_id)

        query = query.order_by(
            AuthorTopic.total_engagement.desc(),
            AuthorTopic.tweet_count.desc()
        ).limit(limit)

        result = await self.db.execute(query)
        author_topics = result.scalars().all()

        # Get refined topic names
        topic_ids = list(set(at.topic_id for at in author_topics))
        refined_query = select(TopicDefinitionRefined).where(
            TopicDefinitionRefined.topic_id.in_(topic_ids)
        )
        refined_result = await self.db.execute(refined_query)
        refined_topics = {t.topic_id: t for t in refined_result.scalars().all()}

        return [
            {
                'author_id': at.author_id,
                'topic_id': at.topic_id,
                'topic_name': refined_topics.get(at.topic_id).refined_name
                             if at.topic_id in refined_topics else f"Topic {at.topic_id}",
                'tweet_count': at.tweet_count,
                'avg_probability': float(at.avg_probability) if at.avg_probability else 0,
                'max_probability': float(at.max_probability) if at.max_probability else 0,
                'first_seen': at.first_seen.isoformat() if at.first_seen else None,
                'last_seen': at.last_seen.isoformat() if at.last_seen else None,
                'active_days': at.active_days,
                'total_engagement': at.total_engagement,
                'avg_engagement': float(at.avg_engagement) if at.avg_engagement else 0
            }
            for at in author_topics
        ]

    async def get_topic_evolution_trends(
        self,
        topic_ids: Optional[List[int]] = None,
        hours: int = 24,
        min_growth_rate: Optional[float] = None
    ) -> List[Dict[str, Any]]:
        """Get topic evolution trends over time"""

        # If topic_evolution is empty, compute on the fly
        count_query = select(func.count()).select_from(TopicEvolution)
        count_result = await self.db.execute(count_query)
        evolution_count = count_result.scalar()

        if evolution_count == 0:
            # Compute evolution metrics on the fly
            return await self._compute_evolution_metrics(topic_ids, hours, min_growth_rate)

        # Use existing evolution data
        cutoff_date = datetime.now() - timedelta(hours=hours)

        query = (
            select(TopicEvolution)
            .where(TopicEvolution.date >= cutoff_date)
        )

        if topic_ids:
            query = query.where(TopicEvolution.topic_id.in_(topic_ids))

        if min_growth_rate is not None:
            query = query.where(TopicEvolution.growth_rate >= min_growth_rate)

        query = query.order_by(
            TopicEvolution.date.desc(),
            TopicEvolution.growth_rate.desc()
        )

        result = await self.db.execute(query)
        evolutions = result.scalars().all()

        # Get refined topic names
        unique_topic_ids = list(set(e.topic_id for e in evolutions))
        refined_query = select(TopicDefinitionRefined).where(
            TopicDefinitionRefined.topic_id.in_(unique_topic_ids)
        )
        refined_result = await self.db.execute(refined_query)
        refined_topics = {t.topic_id: t for t in refined_result.scalars().all()}

        return [
            {
                'topic_id': e.topic_id,
                'topic_name': refined_topics.get(e.topic_id).refined_name
                             if e.topic_id in refined_topics else f"Topic {e.topic_id}",
                'date': e.date.isoformat(),
                'hour': e.hour,
                'tweet_count': e.tweet_count,
                'unique_authors': e.unique_authors,
                'new_authors': e.new_authors,
                'avg_probability': float(e.avg_probability) if e.avg_probability else 0,
                'top_keywords': e.top_keywords,
                'total_engagement': e.total_engagement,
                'viral_tweets': e.viral_tweets,
                'growth_rate': float(e.growth_rate) if e.growth_rate else 0
            }
            for e in evolutions
        ]

    async def _compute_evolution_metrics(
        self,
        topic_ids: Optional[List[int]],
        hours: int,
        min_growth_rate: Optional[float]
    ) -> List[Dict[str, Any]]:
        """Compute evolution metrics on the fly when table is empty"""

        cutoff_date = datetime.now() - timedelta(hours=hours)

        # Build the query to compute metrics
        query = text("""
        WITH hourly_stats AS (
            SELECT
                tt.topic_id,
                DATE_TRUNC('hour', t.created_at) as date,
                EXTRACT(HOUR FROM t.created_at)::integer as hour,
                COUNT(DISTINCT tt.tweet_id) as tweet_count,
                COUNT(DISTINCT t.author_id) as unique_authors,
                AVG(tt.probability) as avg_probability,
                SUM(t.total_engagement) as total_engagement,
                COUNT(DISTINCT CASE WHEN t.total_engagement > 1000 THEN t.tweet_id END) as viral_tweets
            FROM tweet_topics tt
            JOIN tweets_deduplicated t ON tt.tweet_id = t.tweet_id
            WHERE tt.topic_id != -1
            AND t.created_at >= :cutoff_date
            AND (:topic_ids IS NULL OR tt.topic_id = ANY(:topic_ids))
            GROUP BY tt.topic_id, DATE_TRUNC('hour', t.created_at), EXTRACT(HOUR FROM t.created_at)
        ),
        with_growth AS (
            SELECT
                *,
                LAG(tweet_count) OVER (PARTITION BY topic_id ORDER BY date) as prev_count,
                CASE
                    WHEN LAG(tweet_count) OVER (PARTITION BY topic_id ORDER BY date) > 0
                    THEN (tweet_count - LAG(tweet_count) OVER (PARTITION BY topic_id ORDER BY date))::float /
                         LAG(tweet_count) OVER (PARTITION BY topic_id ORDER BY date)
                    ELSE 0
                END as growth_rate
            FROM hourly_stats
        )
        SELECT *
        FROM with_growth
        WHERE (:min_growth_rate IS NULL OR growth_rate >= :min_growth_rate)
        ORDER BY date DESC, growth_rate DESC
        LIMIT 500
        """)

        result = await self.db.execute(
            query,
            {
                'cutoff_date': cutoff_date,
                'topic_ids': topic_ids if topic_ids else None,
                'min_growth_rate': min_growth_rate
            }
        )

        rows = result.all()

        # Get refined topic names
        unique_topic_ids = list(set(row.topic_id for row in rows))
        if unique_topic_ids:
            refined_query = select(TopicDefinitionRefined).where(
                TopicDefinitionRefined.topic_id.in_(unique_topic_ids)
            )
            refined_result = await self.db.execute(refined_query)
            refined_topics = {t.topic_id: t for t in refined_result.scalars().all()}
        else:
            refined_topics = {}

        return [
            {
                'topic_id': row.topic_id,
                'topic_name': refined_topics.get(row.topic_id).refined_name
                             if row.topic_id in refined_topics else f"Topic {row.topic_id}",
                'date': row.date.isoformat(),
                'hour': row.hour,
                'tweet_count': row.tweet_count,
                'unique_authors': row.unique_authors,
                'avg_probability': float(row.avg_probability) if row.avg_probability else 0,
                'total_engagement': row.total_engagement,
                'viral_tweets': row.viral_tweets,
                'growth_rate': float(row.growth_rate) if row.growth_rate else 0
            }
            for row in rows
        ]

