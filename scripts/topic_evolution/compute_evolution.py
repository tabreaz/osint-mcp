#!/usr/bin/env python3
"""
Compute topic evolution metrics from tweet_topics data
Populates the topic_evolution table with hourly/daily aggregations
"""

import psycopg2
from psycopg2.extras import RealDictCursor, execute_values
from datetime import datetime, timedelta
import json
import sys
import argparse
from typing import Dict, List, Optional
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv('../../.env')

DATABASE_CONFIG = {
    "host": os.getenv("POSTGRES_HOST", "localhost"),
    "port": int(os.getenv("POSTGRES_PORT", 5432)),
    "database": os.getenv("POSTGRES_DATABASE", "neuron"),
    "user": os.getenv("POSTGRES_USER", "tabreaz"),
    "password": os.getenv("POSTGRES_PASSWORD", "admin"),
    "schema": os.getenv("POSTGRES_SCHEMA", "osint")
}

class TopicEvolutionComputer:
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
            with self.conn.cursor() as cur:
                cur.execute(f"SET search_path TO {DATABASE_CONFIG['schema']}")
            self.conn.commit()
            print(f"Connected to database: {DATABASE_CONFIG['database']}")
        except Exception as e:
            print(f"Database connection failed: {e}")
            raise

    def get_date_range(self) -> tuple:
        """Get min and max dates from tweet data"""
        query = """
        SELECT
            MIN(created_at) as min_date,
            MAX(created_at) as max_date
        FROM tweets_deduplicated t
        WHERE EXISTS (
            SELECT 1 FROM tweet_topics tt
            WHERE tt.tweet_id = t.tweet_id
        )
        """

        with self.conn.cursor() as cur:
            cur.execute(query)
            result = cur.fetchone()
            return result[0], result[1]

    def get_last_processed_date(self) -> Optional[datetime]:
        """Get the last processed date from topic_evolution"""
        query = """
        SELECT MAX(date)
        FROM topic_evolution
        """

        with self.conn.cursor() as cur:
            cur.execute(query)
            result = cur.fetchone()
            return result[0] if result[0] else None

    def compute_hourly_evolution(self, start_date: datetime, end_date: datetime, batch_size: int = 24):
        """Compute topic evolution metrics hourly"""

        print(f"Computing evolution from {start_date} to {end_date}")

        # Process in daily batches
        current_date = start_date

        while current_date < end_date:
            batch_end = min(current_date + timedelta(days=1), end_date)

            print(f"Processing {current_date.date()}...")

            # Compute metrics for this batch
            query = """
            WITH hourly_stats AS (
                SELECT
                    tt.topic_id,
                    DATE_TRUNC('hour', t.created_at) as hour_bucket,
                    EXTRACT(HOUR FROM t.created_at)::integer as hour,
                    COUNT(DISTINCT tt.tweet_id) as tweet_count,
                    COUNT(DISTINCT t.author_id) as unique_authors,
                    AVG(tt.probability) as avg_probability,
                    SUM(t.total_engagement) as total_engagement,
                    COUNT(DISTINCT CASE WHEN t.total_engagement > 1000 THEN t.tweet_id END) as viral_tweets
                FROM tweet_topics tt
                JOIN tweets_deduplicated t ON tt.tweet_id = t.tweet_id
                WHERE tt.topic_id != -1
                AND t.created_at >= %s
                AND t.created_at < %s
                GROUP BY tt.topic_id, DATE_TRUNC('hour', t.created_at), EXTRACT(HOUR FROM t.created_at)
            ),
            new_authors AS (
                -- Count authors who posted about this topic for the first time
                SELECT
                    tt.topic_id,
                    DATE_TRUNC('hour', t.created_at) as hour_bucket,
                    COUNT(DISTINCT t.author_id) as new_author_count
                FROM tweet_topics tt
                JOIN tweets_deduplicated t ON tt.tweet_id = t.tweet_id
                WHERE tt.topic_id != -1
                AND t.created_at >= %s
                AND t.created_at < %s
                AND NOT EXISTS (
                    SELECT 1
                    FROM tweet_topics tt2
                    JOIN tweets_deduplicated t2 ON tt2.tweet_id = t2.tweet_id
                    WHERE tt2.topic_id = tt.topic_id
                    AND t2.author_id = t.author_id
                    AND t2.created_at < DATE_TRUNC('hour', t.created_at)
                )
                GROUP BY tt.topic_id, DATE_TRUNC('hour', t.created_at)
            ),
            keywords AS (
                -- Extract top keywords for this hour
                SELECT
                    tt.topic_id,
                    DATE_TRUNC('hour', t.created_at) as hour_bucket,
                    ARRAY_AGG(DISTINCT word ORDER BY word) FILTER (WHERE word IS NOT NULL) as top_words
                FROM tweet_topics tt
                JOIN tweets_deduplicated t ON tt.tweet_id = t.tweet_id
                CROSS JOIN LATERAL (
                    SELECT unnest(string_to_array(
                        regexp_replace(
                            lower(t.text),
                            '[^a-z0-9#@\\s]', '', 'g'
                        ), ' '
                    )) as word
                ) words
                WHERE tt.topic_id != -1
                AND t.created_at >= %s
                AND t.created_at < %s
                AND length(word) > 3
                AND word NOT IN ('http', 'https', 'that', 'this', 'with', 'from', 'have', 'will', 'been', 'they', 'their', 'what', 'when', 'where')
                GROUP BY tt.topic_id, DATE_TRUNC('hour', t.created_at)
            ),
            previous_hour AS (
                -- Get previous hour's tweet count for growth calculation
                SELECT
                    topic_id,
                    date + interval '1 hour' as next_hour,
                    tweet_count as prev_count
                FROM topic_evolution
                WHERE date >= %s - interval '1 hour'
                AND date < %s
            )
            SELECT
                hs.topic_id,
                hs.hour_bucket as date,
                hs.hour,
                hs.tweet_count,
                hs.unique_authors,
                COALESCE(na.new_author_count, 0) as new_authors,
                hs.avg_probability,
                CASE
                    WHEN array_length(k.top_words, 1) > 0
                    THEN jsonb_build_object('keywords', k.top_words[:10])
                    ELSE '{}'::jsonb
                END as top_keywords,
                hs.total_engagement,
                hs.viral_tweets,
                CASE
                    WHEN ph.prev_count > 0
                    THEN (hs.tweet_count - ph.prev_count)::float / ph.prev_count
                    ELSE 0
                END as growth_rate
            FROM hourly_stats hs
            LEFT JOIN new_authors na ON hs.topic_id = na.topic_id AND hs.hour_bucket = na.hour_bucket
            LEFT JOIN keywords k ON hs.topic_id = k.topic_id AND hs.hour_bucket = k.hour_bucket
            LEFT JOIN previous_hour ph ON hs.topic_id = ph.topic_id AND hs.hour_bucket = ph.next_hour
            """

            with self.conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(query, (
                    current_date, batch_end,
                    current_date, batch_end,
                    current_date, batch_end,
                    current_date, batch_end
                ))

                results = cur.fetchall()

                if results:
                    # Insert into topic_evolution
                    insert_query = """
                    INSERT INTO topic_evolution (
                        topic_id, date, hour, tweet_count, unique_authors,
                        new_authors, avg_probability, top_keywords,
                        total_engagement, viral_tweets, growth_rate
                    ) VALUES %s
                    ON CONFLICT (topic_id, date, hour) DO UPDATE SET
                        tweet_count = EXCLUDED.tweet_count,
                        unique_authors = EXCLUDED.unique_authors,
                        new_authors = EXCLUDED.new_authors,
                        avg_probability = EXCLUDED.avg_probability,
                        top_keywords = EXCLUDED.top_keywords,
                        total_engagement = EXCLUDED.total_engagement,
                        viral_tweets = EXCLUDED.viral_tweets,
                        growth_rate = EXCLUDED.growth_rate
                    """

                    values = [
                        (
                            r['topic_id'],
                            r['date'],
                            r['hour'],
                            r['tweet_count'],
                            r['unique_authors'],
                            r['new_authors'],
                            r['avg_probability'],
                            json.dumps(r['top_keywords']),
                            r['total_engagement'],
                            r['viral_tweets'],
                            r['growth_rate']
                        )
                        for r in results
                    ]

                    execute_values(cur, insert_query, values)
                    self.conn.commit()
                    print(f"  Inserted {len(results)} hourly records")

            current_date = batch_end

    def create_indexes(self):
        """Create necessary indexes for performance"""
        indexes = [
            "CREATE INDEX IF NOT EXISTS idx_topic_evolution_topic_date ON topic_evolution(topic_id, date DESC)",
            "CREATE INDEX IF NOT EXISTS idx_topic_evolution_date ON topic_evolution(date DESC)",
            "CREATE INDEX IF NOT EXISTS idx_topic_evolution_growth ON topic_evolution(growth_rate DESC) WHERE growth_rate > 0"
        ]

        with self.conn.cursor() as cur:
            for idx in indexes:
                cur.execute(idx)
        self.conn.commit()
        print("Indexes created")

    def get_evolution_summary(self):
        """Get summary of computed evolution data"""
        query = """
        WITH stats AS (
            SELECT
                COUNT(DISTINCT topic_id) as topics_tracked,
                COUNT(*) as total_records,
                MIN(date) as earliest_date,
                MAX(date) as latest_date,
                AVG(tweet_count) as avg_tweets_per_hour,
                MAX(growth_rate) as max_growth_rate,
                COUNT(DISTINCT CASE WHEN viral_tweets > 0 THEN topic_id END) as topics_with_viral
            FROM topic_evolution
        )
        SELECT * FROM stats
        """

        with self.conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(query)
            return cur.fetchone()

    def close(self):
        if self.conn:
            self.conn.close()

def main():
    parser = argparse.ArgumentParser(description='Compute topic evolution metrics')
    parser.add_argument('--days', type=int, default=30,
                       help='Number of days to process (default: 30)')
    parser.add_argument('--incremental', action='store_true',
                       help='Only process new data since last run')
    parser.add_argument('--from-date', type=str,
                       help='Start date (YYYY-MM-DD)')
    parser.add_argument('--to-date', type=str,
                       help='End date (YYYY-MM-DD)')

    args = parser.parse_args()

    computer = TopicEvolutionComputer()

    try:
        # First ensure we have the proper structure
        create_table = """
        ALTER TABLE topic_evolution
        ADD COLUMN IF NOT EXISTS id SERIAL PRIMARY KEY;

        -- Add unique constraint if not exists
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM pg_constraint
                WHERE conname = 'topic_evolution_unique'
            ) THEN
                ALTER TABLE topic_evolution
                ADD CONSTRAINT topic_evolution_unique
                UNIQUE (topic_id, date, hour);
            END IF;
        END $$;
        """

        with computer.conn.cursor() as cur:
            cur.execute(create_table)
        computer.conn.commit()

        # Determine date range
        if args.from_date and args.to_date:
            start_date = datetime.strptime(args.from_date, '%Y-%m-%d')
            end_date = datetime.strptime(args.to_date, '%Y-%m-%d')
        elif args.incremental:
            last_processed = computer.get_last_processed_date()
            if last_processed:
                start_date = last_processed
                print(f"Continuing from {start_date}")
            else:
                print("No previous data found, processing last 30 days")
                end_date = datetime.now()
                start_date = end_date - timedelta(days=30)
            _, end_date = computer.get_date_range()
        else:
            min_date, max_date = computer.get_date_range()
            end_date = max_date
            start_date = max(min_date, end_date - timedelta(days=args.days))

        # Compute evolution
        computer.compute_hourly_evolution(start_date, end_date)

        # Create indexes
        computer.create_indexes()

        # Show summary
        summary = computer.get_evolution_summary()
        print("\n=== Topic Evolution Summary ===")
        print(f"Topics tracked: {summary['topics_tracked']}")
        print(f"Total records: {summary['total_records']}")
        print(f"Date range: {summary['earliest_date']} to {summary['latest_date']}")
        print(f"Avg tweets/hour: {summary['avg_tweets_per_hour']:.2f}")
        print(f"Max growth rate: {summary['max_growth_rate']:.2%}" if summary['max_growth_rate'] else "Max growth rate: N/A")
        print(f"Topics with viral tweets: {summary['topics_with_viral']}")

    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)
    finally:
        computer.close()

if __name__ == "__main__":
    main()