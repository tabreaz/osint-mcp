# Deprecated Author Metrics Scripts

**⚠️ DO NOT USE - PERFORMANCE ISSUES**

These scripts have been replaced with the new multi-tier architecture due to:

## Critical Issues Fixed:
1. **Cartesian Explosion**: LATERAL joins caused massive row multiplication
2. **O(N²) Complexity**: Coordination detection was extremely slow on large datasets
3. **Mixed Granularity**: 46 metrics daily caused storage bloat and performance issues

## Old System Problems:
- `compute_all_author_metrics.sql` - 46 metrics/author/day into intel_metrics
- `compute_author_activity_metrics.sql` - 21 activity metrics with performance issues
- `compute_author_coordination_metrics.sql` - O(N²) coordination detection
- `compute_author_influence_metrics.sql` - Heavy influence computation
- `compute_author_media_metrics.sql` - Media analysis (optional)
- `compute_author_semantic_metrics.sql` - Semantic analysis (optional)

## New System (Use Instead):
- `compute_author_daily_simple.sql` - Fast daily tracking (12 metrics)
- `compute_author_intelligence.sql` - Strategic analysis (10 metrics, configurable periods)
- `compute_author_metrics_new.sql` - Main wrapper with multi-tier approach
- `create_author_tables.sql` - New table schemas

## Performance Improvement:
- **Old**: 46 metrics/author/day → single table → 11,316 rows for 246 authors (1 day)
- **New**: 12 daily + 10 strategic → dedicated tables → ~75% storage reduction + ~99% speed improvement

---
*Moved to deprecated on: November 20, 2025*
*Replaced by: Multi-tier architecture with optimized queries*