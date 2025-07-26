#!/bin/bash

set -e

BENCHMARK_SESSION=$1
TEST_NAME=$2
RESULTS_DIR="./results"

if [ -z "$BENCHMARK_SESSION" ] || [ -z "$TEST_NAME" ]; then
    echo "Usage: $0 <benchmark_session> <test_name>"
    exit 1
fi

METRICS_DIR="${RESULTS_DIR}/${BENCHMARK_SESSION}/prometheus-metrics"
mkdir -p "$METRICS_DIR"

echo "📊 Starting metrics collection for ${TEST_NAME}..."

# Prometheus queries for Go vs C# comparison
QUERIES=(
    "http_requests_total"
    "http_request_duration_seconds"
    "http_active_connections"
    "benchmark_goroutines_active"
    "benchmark_threads_active"
    "benchmark_memory_usage_bytes"
    "database_connections"
    "up"
)

collect_prometheus_metrics() {
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local output_file="${METRICS_DIR}/${TEST_NAME}_metrics_${timestamp}.json"
    
    echo "{"\"timestamp\"": "\"$(date -Iseconds)\"", "\"metrics\"": {" > "$output_file"
    
    local first=true
    for query in "${QUERIES[@]}"; do
        if [ "$first" = false ]; then
            echo "," >> "$output_file"
        fi
        first=false
        
        echo -n "\"$query\": " >> "$output_file"
        curl -s "http://localhost:9090/api/v1/query?query=${query}" >> "$output_file" 2>/dev/null || echo "null" >> "$output_file"
    done
    
    echo "}}" >> "$output_file"
    echo "Metrics snapshot saved: $output_file"
}

collect_app_metrics() {
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    
    # Collect Go app metrics
    curl -s http://localhost:8080/metrics > "${METRICS_DIR}/${TEST_NAME}_go_metrics_${timestamp}.txt" 2>/dev/null || true
    
    # Collect C# app metrics  
    curl -s http://localhost:8081/metrics > "${METRICS_DIR}/${TEST_NAME}_csharp_metrics_${timestamp}.txt" 2>/dev/null || true
}

# Main collection loop
collect_metrics_continuously() {
    local interval=15  # Collect every 15 seconds
    local start_time=$(date +%s)
    
    echo "Collecting metrics every ${interval} seconds..."
    echo "Press Ctrl+C or send SIGTERM to stop collection"
    
    # Initial collection
    collect_prometheus_metrics
    collect_app_metrics
    
    while true; do
        sleep $interval
        
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        echo "📊 Collecting metrics... (${elapsed}s elapsed)"
        
        collect_prometheus_metrics
        collect_app_metrics
        
        # Also collect system-level metrics from containers
        collect_docker_stats
    done
}

collect_docker_stats() {
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local stats_file="${METRICS_DIR}/${TEST_NAME}_docker_stats_${timestamp}.json"
    
    # Get container stats for Go and C# apps
    docker stats --no-stream --format "table {{.Container}},{{.CPUPerc}},{{.MemUsage}},{{.NetIO}},{{.BlockIO}}" \
        benchmark_go_app benchmark_csharp_app > "${stats_file}" 2>/dev/null || true
}

collect_final_summary() {
    echo ""
    echo "📈 Collecting final metrics summary for ${TEST_NAME}..."
    
    local summary_file="${METRICS_DIR}/${TEST_NAME}_summary.json"
    local timestamp=$(date -Iseconds)
    
    # Create comprehensive summary
    cat > "$summary_file" << EOF
{
    "test_name": "$TEST_NAME",
    "benchmark_session": "$BENCHMARK_SESSION", 
    "collection_end_time": "$timestamp",
    "prometheus_queries": $(printf '%s\n' "${QUERIES[@]}" | jq -R . | jq -s .),
    "go_app_health": $(curl -s http://localhost:8080/health 2>/dev/null || echo '{"status": "unavailable"}'),
    "csharp_app_health": $(curl -s http://localhost:8081/health 2>/dev/null || echo '{"status": "unavailable"}'),
    "prometheus_health": $(curl -s http://localhost:9090/-/healthy 2>/dev/null && echo '{"status": "healthy"}' || echo '{"status": "unavailable"}')
}
EOF
    
    echo "✅ Final summary saved: $summary_file"
}

# Handle cleanup on script termination
cleanup() {
    echo ""
    echo "🛑 Stopping metrics collection for ${TEST_NAME}..."
    collect_final_summary
    echo "✅ Metrics collection stopped"
    exit 0
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT

# Start metrics collection
echo "🚀 Starting continuous metrics collection..."
echo "Test: $TEST_NAME"
echo "Session: $BENCHMARK_SESSION"
echo "Output directory: $METRICS_DIR"
echo ""

collect_metrics_continuously