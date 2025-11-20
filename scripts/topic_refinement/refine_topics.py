#!/usr/bin/env python3
"""
Main script to refine topics using LLM analysis
"""
import argparse
import sys
import time
from typing import List, Dict
from database import TopicDatabase
from llm_analyzer import TopicAnalyzer
from config import MIN_TOPIC_SIZE, BATCH_SIZE, MAX_COST_PER_RUN, PROCESSING_MODES


def process_topics(mode: str = 'quick', topic_ids: List[int] = None,
                  limit: int = None, dry_run: bool = False):
    """
    Main function to process and refine topics

    Args:
        mode: Processing mode ('full', 'quick', 'test')
        topic_ids: Specific topic IDs to process (None for all)
        limit: Maximum number of topics to process
        dry_run: If True, don't save to database
    """

    print(f"Starting topic refinement in '{mode}' mode...")

    # Get processing configuration
    config = PROCESSING_MODES.get(mode, PROCESSING_MODES['quick'])
    batch_size = config['batch_size']
    model = config['model']

    # Initialize database and analyzer
    db = TopicDatabase()
    analyzer = TopicAnalyzer(model=model)

    try:
        # Get topics to process
        if topic_ids:
            # Process specific topics
            all_topics = []
            for topic_id in topic_ids:
                topic = db.get_topic_by_id(topic_id)
                if topic:
                    all_topics.append(topic)
        else:
            # Get unprocessed topics
            all_topics = db.get_unprocessed_topics(min_size=MIN_TOPIC_SIZE)

        if limit:
            all_topics = all_topics[:limit]

        print(f"Found {len(all_topics)} topics to process")

        if not all_topics:
            print("No topics to process")
            return

        # Get themes for context
        themes = db.get_all_themes()
        print(f"Using {len(themes)} themes for context")

        # Process topics
        processed_count = 0
        failed_count = 0

        # Process in batches
        for i in range(0, len(all_topics), batch_size):
            batch = all_topics[i:i + batch_size]

            print(f"\nProcessing batch {i//batch_size + 1} ({len(batch)} topics)...")

            # Check cost limit
            if analyzer.total_cost >= MAX_COST_PER_RUN:
                print(f"Cost limit reached (${MAX_COST_PER_RUN}). Stopping.")
                break

            # Analyze batch
            if len(batch) > 1 and batch_size > 1:
                # Batch processing
                refined_topics = analyzer.analyze_batch(batch, themes)
            else:
                # Single topic processing
                refined_topics = []
                for topic in batch:
                    print(f"  Analyzing topic {topic['topic_id']}: {topic['topic_name'][:50]}...")
                    refined = analyzer.analyze_single_topic(topic, themes)
                    refined_topics.append(refined)

            # Save results
            for refined in refined_topics:
                try:
                    # Debug print
                    if refined is None:
                        print(f"  WARNING: Got None response from LLM")
                        failed_count += 1
                        continue

                    if 'topic_id' not in refined:
                        print(f"  WARNING: Missing topic_id in response: {refined}")
                        failed_count += 1
                        continue

                    if not dry_run:
                        db.save_refined_topic(refined)
                        # Log processing
                        db.log_processing(
                            topic_id=refined['topic_id'],
                            processing_type=f"refinement_{mode}",
                            prompt="See analyzer for details",
                            response=refined,
                            tokens=refined['processing_metadata'].get('tokens_used', 0),
                            cost=refined['processing_metadata'].get('cost_usd', 0)
                        )

                    processed_count += 1

                    # Print summary
                    print(f"  ✓ Topic {refined['topic_id']}: {refined.get('refined_name', 'N/A')}")
                    print(f"    Category: {refined.get('category', 'N/A')}")
                    print(f"    Priority: {refined.get('monitoring_priority', 'N/A')}")
                    print(f"    Quality: {refined.get('quality_score', 0):.2f}")

                except Exception as e:
                    print(f"  ✗ Failed to save topic {refined.get('topic_id', 'UNKNOWN')}: {e}")
                    import traceback
                    traceback.print_exc()
                    failed_count += 1

            # Progress update
            print(f"\nProgress: {processed_count}/{len(all_topics)} processed, "
                  f"{failed_count} failed")
            print(f"Cost so far: ${analyzer.total_cost:.2f}")

            # Small delay between batches
            time.sleep(1)

        # Final statistics
        print("\n" + "="*50)
        print("REFINEMENT COMPLETE")
        print("="*50)

        stats = db.get_processing_stats()
        usage = analyzer.get_usage_stats()

        print(f"\nProcessing Summary:")
        print(f"  Topics processed: {processed_count}")
        print(f"  Topics failed: {failed_count}")
        print(f"  Total topics in DB: {stats['total_topics']}")
        print(f"  Total refined: {stats['processed_topics']}")
        print(f"  High priority: {stats['high_priority']}")
        print(f"  Ignored: {stats['ignored']}")
        print(f"  Average quality: {stats['avg_quality_score']:.2f}" if stats['avg_quality_score'] else "  Average quality: N/A")
        print(f"  Average relevance: {stats['avg_relevance']:.2f}" if stats['avg_relevance'] else "  Average relevance: N/A")

        print(f"\nLLM Usage:")
        print(f"  Model: {usage['model']}")
        print(f"  Total tokens: {usage['total_tokens']:,}")
        print(f"  Total cost: ${usage['total_cost_usd']:.2f}")

    except Exception as e:
        print(f"Error during processing: {e}")
        raise

    finally:
        db.close()


def view_refined_topics(category: str = None, priority: str = None):
    """View already refined topics"""

    db = TopicDatabase()

    query = """
    SELECT
        t.topic_id,
        t.topic_name as original_name,
        r.refined_name,
        r.category,
        r.monitoring_priority,
        r.quality_score,
        r.relevance_to_project,
        t.topic_size
    FROM topic_definitions t
    JOIN topic_definitions_refined r ON t.topic_id = r.topic_id
    WHERE 1=1
    """

    params = []

    if category:
        query += " AND r.category = %s"
        params.append(category)

    if priority:
        query += " AND r.monitoring_priority = %s"
        params.append(priority)

    query += " ORDER BY r.relevance_to_project DESC, t.topic_size DESC"

    from psycopg2.extras import RealDictCursor
    with db.conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(query, params)
        topics = cur.fetchall()

    print(f"\nFound {len(topics)} refined topics")
    print("="*100)

    for t in topics[:20]:  # Show top 20
        print(f"\nTopic {t['topic_id']}: {t['refined_name']}")
        print(f"  Original: {t['original_name'][:50]}...")
        print(f"  Category: {t['category']}")
        print(f"  Priority: {t['monitoring_priority']}")
        print(f"  Quality: {t['quality_score']:.2f}")
        print(f"  Relevance: {t['relevance_to_project']:.2f}")
        print(f"  Size: {t['topic_size']} tweets")

    db.close()


def main():
    """Main entry point"""

    parser = argparse.ArgumentParser(description="Refine topics using LLM analysis")

    subparsers = parser.add_subparsers(dest='command', help='Commands')

    # Process command
    process_parser = subparsers.add_parser('process', help='Process and refine topics')
    process_parser.add_argument('--mode', choices=['full', 'quick', 'test'],
                              default='quick', help='Processing mode')
    process_parser.add_argument('--topic-ids', type=int, nargs='+',
                              help='Specific topic IDs to process')
    process_parser.add_argument('--limit', type=int,
                              help='Maximum number of topics to process')
    process_parser.add_argument('--dry-run', action='store_true',
                              help="Don't save to database")

    # View command
    view_parser = subparsers.add_parser('view', help='View refined topics')
    view_parser.add_argument('--category', help='Filter by category')
    view_parser.add_argument('--priority',
                            choices=['high', 'medium', 'low', 'ignore'],
                            help='Filter by priority')

    # Stats command
    stats_parser = subparsers.add_parser('stats', help='Show processing statistics')

    args = parser.parse_args()

    if args.command == 'process':
        process_topics(
            mode=args.mode,
            topic_ids=args.topic_ids,
            limit=args.limit,
            dry_run=args.dry_run
        )
    elif args.command == 'view':
        view_refined_topics(
            category=args.category,
            priority=args.priority
        )
    elif args.command == 'stats':
        db = TopicDatabase()
        stats = db.get_processing_stats()
        print("\nTopic Processing Statistics:")
        print("="*40)
        for key, value in stats.items():
            if value is not None:
                if isinstance(value, float):
                    print(f"{key}: {value:.2f}")
                else:
                    print(f"{key}: {value}")
        db.close()
    else:
        parser.print_help()


if __name__ == "__main__":
    main()