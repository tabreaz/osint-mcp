"""
Database connection and operations for topic refinement
"""
import psycopg2
from psycopg2.extras import RealDictCursor
import json
from typing import List, Dict, Optional
from datetime import datetime
from config import DATABASE_CONFIG

class TopicDatabase:
    def __init__(self):
        self.conn = None
        self.connect()

    def connect(self):
        """Establish database connection"""
        try:
            self.conn = psycopg2.connect(
                host=DATABASE_CONFIG["host"],
                port=DATABASE_CONFIG["port"],
                database=DATABASE_CONFIG["database"],
                user=DATABASE_CONFIG["user"],
                password=DATABASE_CONFIG["password"]
            )
            # Set schema
            with self.conn.cursor() as cur:
                cur.execute(f"SET search_path TO {DATABASE_CONFIG['schema']}")
            self.conn.commit()
            print(f"Connected to database: {DATABASE_CONFIG['database']}")
        except Exception as e:
            print(f"Database connection failed: {e}")
            raise

    def get_unprocessed_topics(self, min_size: int = 100) -> List[Dict]:
        """Get topics that haven't been refined yet"""

        # First check if refined table exists
        check_table = """
        SELECT EXISTS (
            SELECT FROM information_schema.tables
            WHERE table_schema = %s
            AND table_name = 'topic_definitions_refined'
        )
        """

        with self.conn.cursor() as cur:
            cur.execute(check_table, (DATABASE_CONFIG['schema'],))
            table_exists = cur.fetchone()[0]

        if table_exists:
            # Table exists, exclude already processed topics
            query = """
            SELECT
                td.topic_id,
                td.topic_name,
                td.topic_label,
                td.topic_size,
                td.keywords,
                td.top_words,
                td.representative_texts[:5] as sample_texts,
                td.coherence_score,
                td.diversity_score
            FROM topic_definitions td
            LEFT JOIN topic_definitions_refined tdr ON td.topic_id = tdr.topic_id
            WHERE tdr.topic_id IS NULL
            AND td.topic_id != -1  -- Skip outliers
            AND td.topic_size >= %s
            ORDER BY td.topic_size DESC
            """
        else:
            # Table doesn't exist yet, get all topics
            query = """
            SELECT
                td.topic_id,
                td.topic_name,
                td.topic_label,
                td.topic_size,
                td.keywords,
                td.top_words,
                td.representative_texts[:5] as sample_texts,
                td.coherence_score,
                td.diversity_score
            FROM topic_definitions td
            WHERE td.topic_id != -1  -- Skip outliers
            AND td.topic_size >= %s
            ORDER BY td.topic_size DESC
            """

        with self.conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(query, (min_size,))
            return cur.fetchall()

    def get_all_themes(self) -> List[Dict]:
        """Get all active themes for context"""
        query = """
        SELECT
            id as theme_id,
            name as theme_name,
            code as theme_code,
            description,
            priority
        FROM themes
        WHERE is_active = true
        ORDER BY priority, name
        """

        with self.conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(query)
            return cur.fetchall()

    def get_topic_by_id(self, topic_id: int) -> Optional[Dict]:
        """Get a single topic by ID"""
        query = """
        SELECT
            td.topic_id,
            td.topic_name,
            td.topic_label,
            td.topic_size,
            td.keywords,
            td.top_words,
            td.representative_texts[:5] as sample_texts,
            td.coherence_score,
            td.diversity_score
        FROM topic_definitions td
        WHERE td.topic_id = %s
        """

        with self.conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(query, (topic_id,))
            return cur.fetchone()

    def get_topic_tweet_samples(self, topic_id: int, limit: int = 10) -> List[Dict]:
        """Get sample tweets for a topic"""
        query = """
        SELECT
            t.tweet_id,
            t.text,
            t.author_username,
            t.total_engagement,
            tt.probability
        FROM tweets_deduplicated t
        JOIN tweet_topics tt ON t.tweet_id = tt.tweet_id
        WHERE tt.topic_id = %s
        ORDER BY tt.probability DESC, t.total_engagement DESC
        LIMIT %s
        """

        with self.conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(query, (topic_id, limit))
            return cur.fetchall()

    def save_refined_topic(self, refined_data: Dict):
        """Save LLM-refined topic data"""

        # First, create table if it doesn't exist
        create_table_query = """
        CREATE TABLE IF NOT EXISTS topic_definitions_refined (
            topic_id INTEGER PRIMARY KEY REFERENCES topic_definitions(topic_id),
            refined_name VARCHAR(255),
            refined_label VARCHAR(500),
            category VARCHAR(100),
            subcategory VARCHAR(100),
            aligned_theme_ids INTEGER[],
            suggested_new_theme VARCHAR(255),
            alignment_confidence FLOAT,
            clean_keywords TEXT[],
            entities JSONB,
            overall_sentiment VARCHAR(20),
            stance JSONB,
            quality_score FLOAT,
            relevance_to_project FLOAT,
            noise_level VARCHAR(20),
            llm_model VARCHAR(50),
            processed_at TIMESTAMP DEFAULT NOW(),
            processing_metadata JSONB,
            monitoring_priority VARCHAR(20),
            recommended_actions JSONB
        )
        """

        with self.conn.cursor() as cur:
            cur.execute(create_table_query)

            # Insert or update refined topic
            upsert_query = """
            INSERT INTO topic_definitions_refined (
                topic_id, refined_name, refined_label, category, subcategory,
                aligned_theme_ids, suggested_new_theme, alignment_confidence,
                clean_keywords, entities, overall_sentiment, stance,
                quality_score, relevance_to_project, noise_level,
                llm_model, processing_metadata, monitoring_priority, recommended_actions
            ) VALUES (
                %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
            )
            ON CONFLICT (topic_id)
            DO UPDATE SET
                refined_name = EXCLUDED.refined_name,
                refined_label = EXCLUDED.refined_label,
                category = EXCLUDED.category,
                subcategory = EXCLUDED.subcategory,
                aligned_theme_ids = EXCLUDED.aligned_theme_ids,
                suggested_new_theme = EXCLUDED.suggested_new_theme,
                alignment_confidence = EXCLUDED.alignment_confidence,
                clean_keywords = EXCLUDED.clean_keywords,
                entities = EXCLUDED.entities,
                overall_sentiment = EXCLUDED.overall_sentiment,
                stance = EXCLUDED.stance,
                quality_score = EXCLUDED.quality_score,
                relevance_to_project = EXCLUDED.relevance_to_project,
                noise_level = EXCLUDED.noise_level,
                llm_model = EXCLUDED.llm_model,
                processing_metadata = EXCLUDED.processing_metadata,
                monitoring_priority = EXCLUDED.monitoring_priority,
                recommended_actions = EXCLUDED.recommended_actions,
                processed_at = NOW()
            """

            cur.execute(upsert_query, (
                refined_data['topic_id'],
                refined_data.get('refined_name'),
                refined_data.get('refined_label'),
                refined_data.get('category'),
                refined_data.get('subcategory'),
                refined_data.get('aligned_theme_ids'),
                refined_data.get('suggested_new_theme'),
                refined_data.get('alignment_confidence'),
                refined_data.get('clean_keywords'),
                json.dumps(refined_data.get('entities', {})),
                refined_data.get('overall_sentiment'),
                json.dumps(refined_data.get('stance', {})),
                refined_data.get('quality_score'),
                refined_data.get('relevance_to_project'),
                refined_data.get('noise_level'),
                refined_data.get('llm_model'),
                json.dumps(refined_data.get('processing_metadata', {})),
                refined_data.get('monitoring_priority'),
                json.dumps(refined_data.get('recommended_actions', []))
            ))

        self.conn.commit()

    def log_processing(self, topic_id: int, processing_type: str,
                      prompt: str, response: Dict, tokens: int, cost: float):
        """Log LLM processing for audit and cost tracking"""

        # Create log table if doesn't exist
        create_log_table = """
        CREATE TABLE IF NOT EXISTS topic_llm_processing_log (
            id SERIAL PRIMARY KEY,
            topic_id INTEGER REFERENCES topic_definitions(topic_id),
            processing_type VARCHAR(50),
            prompt_template TEXT,
            llm_response JSONB,
            tokens_used INTEGER,
            cost_usd DECIMAL(10,4),
            created_at TIMESTAMP DEFAULT NOW()
        )
        """

        with self.conn.cursor() as cur:
            cur.execute(create_log_table)

            insert_log = """
            INSERT INTO topic_llm_processing_log
            (topic_id, processing_type, prompt_template, llm_response, tokens_used, cost_usd)
            VALUES (%s, %s, %s, %s, %s, %s)
            """

            cur.execute(insert_log, (
                topic_id,
                processing_type,
                prompt[:1000],  # Store first 1000 chars of prompt
                json.dumps(response),
                tokens,
                cost
            ))

        self.conn.commit()

    def get_processing_stats(self) -> Dict:
        """Get statistics about processed topics"""

        # Check if refined table exists
        check_table = """
        SELECT EXISTS (
            SELECT FROM information_schema.tables
            WHERE table_schema = %s
            AND table_name = 'topic_definitions_refined'
        )
        """

        with self.conn.cursor() as cur:
            cur.execute(check_table, (DATABASE_CONFIG['schema'],))
            table_exists = cur.fetchone()[0]

        if table_exists:
            query = """
            SELECT
                COUNT(DISTINCT td.topic_id) as total_topics,
                COUNT(DISTINCT tdr.topic_id) as processed_topics,
                COUNT(DISTINCT CASE WHEN tdr.monitoring_priority = 'high' THEN tdr.topic_id END) as high_priority,
                COUNT(DISTINCT CASE WHEN tdr.monitoring_priority = 'ignore' THEN tdr.topic_id END) as ignored,
                AVG(tdr.quality_score) as avg_quality_score,
                AVG(tdr.relevance_to_project) as avg_relevance
            FROM topic_definitions td
            LEFT JOIN topic_definitions_refined tdr ON td.topic_id = tdr.topic_id
            WHERE td.topic_id != -1
            """
        else:
            # Table doesn't exist, return basic stats
            query = """
            SELECT
                COUNT(DISTINCT td.topic_id) as total_topics,
                0 as processed_topics,
                0 as high_priority,
                0 as ignored,
                NULL as avg_quality_score,
                NULL as avg_relevance
            FROM topic_definitions td
            WHERE td.topic_id != -1
            """

        with self.conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(query)
            return cur.fetchone()

    def close(self):
        """Close database connection"""
        if self.conn:
            self.conn.close()
            print("Database connection closed")