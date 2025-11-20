#!/bin/bash

# OSINT New Multi-Tier Intelligence Metrics Computation Script
# Runs the optimized daily + strategic intelligence system
# Author: Generated for OSINT Intelligence Discovery System
# Usage: ./run_new_metrics_computation.sh [OPTIONS]

set -euo pipefail

# Configuration - Database Connection
export PGHOST=${POSTGRES_HOST:-localhost}
export PGPORT=${POSTGRES_PORT:-5432}
export PGDATABASE=${POSTGRES_DATABASE:-neuron}
export PGUSER=${POSTGRES_USER:-tabreaz}
export PGPASSWORD=${POSTGRES_PASSWORD:-admin}

# Script Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQL_DIR="${SCRIPT_DIR}/sql"

# Default Options
RUN_CORE_METRICS=true
RUN_DAILY_METRICS=true
RUN_INTELLIGENCE=false
INTELLIGENCE_PERIOD="7_days"
MIN_TWEET_THRESHOLD=1
TARGET_DATE=""
BATCH_START_DATE=""
BATCH_END_DATE=""
PERIODIC_ANALYSIS=false
QUIET=false
DRY_RUN=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    [[ "$QUIET" == "false" ]] && echo -e "${BLUE}[INFO]${NC} $1" >&2;
}
log_success() {
    [[ "$QUIET" == "false" ]] && echo -e "${GREEN}[SUCCESS]${NC} $1" >&2;
}
log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2;
}
log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2;
}
log_header() {
    [[ "$QUIET" == "false" ]] && echo -e "${CYAN}[HEADER]${NC} $1" >&2;
}

# Help function
show_help() {
    cat << EOF
OSINT New Multi-Tier Intelligence Metrics Computation Script

DESCRIPTION:
    Runs the optimized daily + strategic intelligence system with configurable options.

    Architecture:
    - Core Metrics: Project/theme daily tracking (fast)
    - Daily Metrics: Author daily activity (12 metrics, efficient)
    - Intelligence: Strategic analysis (10 metrics, periodic)

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --help                      Show this help message
    --date DATE                 Target date (YYYY-MM-DD, default: yesterday)
    --batch START END           Batch process date range (YYYY-MM-DD format)
    --periodic-from DATE        Run periodic intelligence from date onwards

    # Execution modes
    --daily-only                Run only daily metrics (fast, for automation)
    --intelligence-only         Run only strategic intelligence
    --core-only                 Run only core project/theme metrics
    --full                      Run everything (core + daily + intelligence)

    # Intelligence options
    --intelligence-period PERIOD    7_days, 30_days, or 90_days (default: 7_days)
    --min-threshold NUM         Minimum tweets for intelligence (default: 1)

    # Utility options
    --dry-run                   Show what would be executed without running
    --quiet                     Suppress informational output
    --check-tables              Verify table structure and data

EXAMPLES:
    # Daily automation (recommended)
    $0 --daily-only

    # Full metrics for specific date
    $0 --full --date 2025-11-16

    # Weekly intelligence analysis
    $0 --intelligence-only --intelligence-period 7_days

    # Batch process historical data
    $0 --batch 2025-08-01 2025-11-16 --daily-only

    # Complete periodic intelligence from August
    $0 --periodic-from 2025-08-01

    # Check system status
    $0 --check-tables

EOF
}

# Function to execute SQL and capture output
execute_sql() {
    local sql_command="$1"
    local description="$2"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would execute: $description"
        log_info "SQL: $sql_command"
        return 0
    fi

    log_info "Executing: $description"

    local result
    if result=$(psql -t -c "$sql_command" 2>&1); then
        log_success "$description completed"
        [[ "$QUIET" == "false" ]] && echo "$result" | grep -E "(rows?|authors?|metrics?|ms|SUCCESS)" || true
        return 0
    else
        log_error "$description failed: $result"
        return 1
    fi
}

# Function to check table structure and data
check_tables() {
    log_header "Checking table structure and data..."

    execute_sql "SELECT * FROM osint.compare_metrics_performance();" "Performance comparison"

    execute_sql "
    SELECT
        'Daily Metrics' as system,
        COUNT(*) as total_records,
        COUNT(DISTINCT author_id) as unique_authors,
        MIN(date) as earliest,
        MAX(date) as latest
    FROM osint.author_daily_metrics
    UNION ALL
    SELECT
        'Intelligence',
        COUNT(*),
        COUNT(DISTINCT author_id),
        MIN(analysis_date),
        MAX(analysis_date)
    FROM osint.author_intelligence;" "Table status check"
}

# Function to run core metrics (project/theme)
run_core_metrics() {
    local target_date="$1"
    log_header "Running core metrics for $target_date..."

    execute_sql "CALL osint.compute_timeseries_metrics('$target_date', 1);" "Core project/theme metrics"
}

# Function to run daily author metrics
run_daily_metrics() {
    local target_date="$1"
    log_header "Running daily author metrics for $target_date..."

    execute_sql "SELECT * FROM osint.compute_author_daily_simple('$target_date');" "Daily author metrics"
}

# Function to run intelligence analysis
run_intelligence() {
    local target_date="$1"
    local period="$2"
    local threshold="$3"
    log_header "Running intelligence analysis for $target_date (period: $period, threshold: $threshold)..."

    execute_sql "SELECT * FROM osint.compute_author_intelligence('$target_date', '$period', $threshold);" "Strategic intelligence"
}

# Function to run batch processing
run_batch() {
    local start_date="$1"
    local end_date="$2"
    log_header "Running batch processing from $start_date to $end_date..."

    execute_sql "SELECT * FROM osint.compute_author_daily_batch('$start_date', '$end_date');" "Batch daily metrics"
}

# Function to run periodic intelligence
run_periodic() {
    local start_date="$1"
    local threshold="$2"
    log_header "Running periodic intelligence analysis from $start_date..."

    execute_sql "SELECT * FROM osint.compute_periodic_intelligence('$start_date', 7, $threshold);" "Periodic intelligence"
}

# Function to get default date (yesterday)
get_default_date() {
    if command -v gdate >/dev/null 2>&1; then
        # macOS with GNU coreutils
        gdate -d "yesterday" '+%Y-%m-%d'
    else
        # Linux date
        date -d "yesterday" '+%Y-%m-%d' 2>/dev/null || date -v-1d '+%Y-%m-%d'
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            show_help
            exit 0
            ;;
        --date)
            TARGET_DATE="$2"
            shift 2
            ;;
        --batch)
            BATCH_START_DATE="$2"
            BATCH_END_DATE="$3"
            shift 3
            ;;
        --periodic-from)
            PERIODIC_ANALYSIS=true
            BATCH_START_DATE="$2"
            shift 2
            ;;
        --daily-only)
            RUN_CORE_METRICS=false
            RUN_DAILY_METRICS=true
            RUN_INTELLIGENCE=false
            shift
            ;;
        --intelligence-only)
            RUN_CORE_METRICS=false
            RUN_DAILY_METRICS=false
            RUN_INTELLIGENCE=true
            shift
            ;;
        --core-only)
            RUN_CORE_METRICS=true
            RUN_DAILY_METRICS=false
            RUN_INTELLIGENCE=false
            shift
            ;;
        --full)
            RUN_CORE_METRICS=true
            RUN_DAILY_METRICS=true
            RUN_INTELLIGENCE=true
            shift
            ;;
        --intelligence-period)
            INTELLIGENCE_PERIOD="$2"
            shift 2
            ;;
        --min-threshold)
            MIN_TWEET_THRESHOLD="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --quiet)
            QUIET=true
            shift
            ;;
        --check-tables)
            check_tables
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate database connection
if [[ "$DRY_RUN" == "false" ]]; then
    if ! psql -c "SELECT 1" >/dev/null 2>&1; then
        log_error "Cannot connect to database. Check connection parameters."
        exit 1
    fi
fi

# Set default target date if not provided
if [[ -z "$TARGET_DATE" && -z "$BATCH_START_DATE" && "$PERIODIC_ANALYSIS" == "false" ]]; then
    TARGET_DATE=$(get_default_date)
    log_info "Using default target date: $TARGET_DATE"
fi

# Validate intelligence period
case "$INTELLIGENCE_PERIOD" in
    7_days|30_days|90_days)
        ;;
    *)
        log_error "Invalid intelligence period: $INTELLIGENCE_PERIOD. Use 7_days, 30_days, or 90_days"
        exit 1
        ;;
esac

# Main execution
log_header "🚀 Starting OSINT New Multi-Tier Intelligence Computation"
log_info "Configuration:"
log_info "  - Database: $PGHOST:$PGPORT/$PGDATABASE"
log_info "  - Core Metrics: $RUN_CORE_METRICS"
log_info "  - Daily Metrics: $RUN_DAILY_METRICS"
log_info "  - Intelligence: $RUN_INTELLIGENCE ($INTELLIGENCE_PERIOD, threshold: $MIN_TWEET_THRESHOLD)"
log_info "  - Dry Run: $DRY_RUN"

start_time=$(date +%s)
error_count=0

# Execute based on mode
if [[ -n "$BATCH_START_DATE" && -n "$BATCH_END_DATE" ]]; then
    # Batch mode
    log_header "🔄 Batch Processing Mode"
    if ! run_batch "$BATCH_START_DATE" "$BATCH_END_DATE"; then
        ((error_count++))
    fi
elif [[ "$PERIODIC_ANALYSIS" == "true" ]]; then
    # Periodic intelligence mode
    log_header "📊 Periodic Intelligence Mode"
    if ! run_periodic "$BATCH_START_DATE" "$MIN_TWEET_THRESHOLD"; then
        ((error_count++))
    fi
else
    # Single date mode
    log_header "📅 Single Date Mode: $TARGET_DATE"

    # Run core metrics
    if [[ "$RUN_CORE_METRICS" == "true" ]]; then
        if ! run_core_metrics "$TARGET_DATE"; then
            ((error_count++))
        fi
    fi

    # Run daily metrics
    if [[ "$RUN_DAILY_METRICS" == "true" ]]; then
        if ! run_daily_metrics "$TARGET_DATE"; then
            ((error_count++))
        fi
    fi

    # Run intelligence
    if [[ "$RUN_INTELLIGENCE" == "true" ]]; then
        if ! run_intelligence "$TARGET_DATE" "$INTELLIGENCE_PERIOD" "$MIN_TWEET_THRESHOLD"; then
            ((error_count++))
        fi
    fi
fi

# Summary
end_time=$(date +%s)
duration=$((end_time - start_time))

log_header "📋 Execution Summary"
log_info "Duration: ${duration}s"

if [[ $error_count -eq 0 ]]; then
    log_success "✅ All operations completed successfully!"
    exit 0
else
    log_error "❌ Completed with $error_count errors"
    exit 1
fi