#!/bin/bash

RESULTS_DIR="./results"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BENCHMARK_SESSION="benchmark_${TIMESTAMP}"

echo "🚀 Starting Go vs C# Benchmark Suite - Session: ${BENCHMARK_SESSION}"
echo "============================================================"

check_prerequisites() {
    echo "🔍 Checking prerequisites..."
    
    if ! command -v k6 &> /dev/null; then
        echo "❌ k6 is not installed. Please install k6: https://k6.io/docs/getting-started/installation/"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        echo "❌ docker-compose is not installed"
        exit 1
    fi
    
    if ! command -v python3 &> /dev/null; then
        echo "❌ python3 is not installed"
        exit 1
    fi
    
    echo "✅ All prerequisites met"
}

setup_results_directory() {
    echo "📁 Setting up results directory..."
    mkdir -p "${RESULTS_DIR}/${BENCHMARK_SESSION}"
    
    # Create subdirectories for different test types
    mkdir -p "${RESULTS_DIR}/${BENCHMARK_SESSION}/k6-results"
    mkdir -p "${RESULTS_DIR}/${BENCHMARK_SESSION}/prometheus-metrics"
    mkdir -p "${RESULTS_DIR}/${BENCHMARK_SESSION}/reports"
    
    echo "✅ Results directory created: ${RESULTS_DIR}/${BENCHMARK_SESSION}"
}

check_services() {
    echo "🔍 Checking if services are running..."
    
    if ! curl -s http://localhost:8080/health > /dev/null; then
        echo "❌ Go application is not responding on port 8080"
        echo "Please run: docker-compose up -d"
        exit 1
    fi
    
    if ! curl -s http://localhost:8081/health > /dev/null; then
        echo "❌ C# application is not responding on port 8081"
        echo "Please run: docker-compose up -d"
        exit 1
    fi
    
    if ! curl -s http://localhost:9090/-/healthy > /dev/null; then
        echo "❌ Prometheus is not responding on port 9090"
        echo "Please run: docker-compose up -d"
        exit 1
    fi
    
    echo "✅ All services are running"
}

run_benchmark_test() {
    local test_name=$1
    local test_file=$2
    local description=$3
    
    echo ""
    echo "🧪 Running ${test_name}: ${description}"
    echo "=================================================="
    
    # Start metrics collection in background
    ./scripts/collect-metrics.sh "${BENCHMARK_SESSION}" "${test_name}" &
    local metrics_pid=$!
    
    # Run k6 test
    echo "Starting k6 test: ${test_file}"
    k6 run \
        --out json="${RESULTS_DIR}/${BENCHMARK_SESSION}/k6-results/${test_name}.json" \
        --out csv="${RESULTS_DIR}/${BENCHMARK_SESSION}/k6-results/${test_name}.csv" \
        "${test_file}"
    
    local k6_exit_code=$?
    
    # Stop metrics collection
    kill $metrics_pid 2>/dev/null || true
    wait $metrics_pid 2>/dev/null || true
    
    if [ $k6_exit_code -eq 0 ]; then
        echo "✅ ${test_name} completed successfully"
    else
        echo "⚠️  ${test_name} completed with warnings (exit code: ${k6_exit_code})"
    fi
    
    # Cool down period between tests
    echo "😴 Cooling down for 30 seconds..."
    sleep 30
}

run_all_benchmarks() {
    echo ""
    echo "🎯 Executing benchmark test suite..."
    echo "===================================="
    
    # Test 1: API Load Test
    run_benchmark_test \
        "api-load-test" \
        "./k6-scripts/api-load-test.js" \
        "1000 req/s load test with mixed operations (60% reads, 30% writes, 10% deletes)"
    
    # Test 2: Database Stress Test
    run_benchmark_test \
        "database-stress-test" \
        "./k6-scripts/database-stress-test.js" \
        "50 concurrent connections with intensive CRUD operations"
    
    # Test 3: Memory Pressure Test
    run_benchmark_test \
        "memory-pressure-test" \
        "./k6-scripts/memory-pressure-test.js" \
        "Memory pressure test with large payloads and GC stress"
}

collect_final_metrics() {
    echo ""
    echo "📊 Collecting final system metrics..."
    
    # Get current metrics from both applications
    curl -s http://localhost:8080/metrics > "${RESULTS_DIR}/${BENCHMARK_SESSION}/prometheus-metrics/go-final-metrics.txt"
    curl -s http://localhost:8081/metrics > "${RESULTS_DIR}/${BENCHMARK_SESSION}/prometheus-metrics/csharp-final-metrics.txt"
    
    # Get Prometheus metrics
    curl -s "http://localhost:9090/api/v1/query?query=up" > "${RESULTS_DIR}/${BENCHMARK_SESSION}/prometheus-metrics/prometheus-status.json"
    
    echo "✅ Final metrics collected"
}

generate_reports() {
    echo ""
    echo "📈 Generating analysis reports..."
    
    if [ -f "./scripts/analyze-results.py" ]; then
        python3 ./scripts/analyze-results.py "${RESULTS_DIR}/${BENCHMARK_SESSION}"
        echo "✅ Analysis report generated"
    else
        echo "⚠️  Analysis script not found, skipping detailed analysis"
    fi
}

print_summary() {
    echo ""
    echo "🎉 Benchmark Suite Completed!"
    echo "=============================="
    echo "Session ID: ${BENCHMARK_SESSION}"
    echo "Results location: ${RESULTS_DIR}/${BENCHMARK_SESSION}"
    echo ""
    echo "📂 Generated files:"
    echo "   • K6 Results: ${RESULTS_DIR}/${BENCHMARK_SESSION}/k6-results/"
    echo "   • Metrics: ${RESULTS_DIR}/${BENCHMARK_SESSION}/prometheus-metrics/"
    echo "   • Reports: ${RESULTS_DIR}/${BENCHMARK_SESSION}/reports/"
    echo ""
    echo "🔍 Next steps:"
    echo "   • Review results in ${RESULTS_DIR}/${BENCHMARK_SESSION}/reports/"
    echo "   • Check Grafana dashboard: http://localhost:3000"
    echo "   • Analyze metrics in Prometheus: http://localhost:9090"
    echo ""
    echo "🏁 Benchmark session ${BENCHMARK_SESSION} complete!"
}

cleanup_on_exit() {
    echo ""
    echo "🧹 Cleaning up background processes..."
    # Kill any remaining background processes
    jobs -p | xargs -r kill 2>/dev/null || true
}

# Set up cleanup trap
trap cleanup_on_exit EXIT

# Main execution
main() {
    echo "Go vs C# Performance Benchmark Suite"
    echo "Started at: $(date)"
    echo ""
    
    check_prerequisites
    setup_results_directory
    check_services
    run_all_benchmarks
    collect_final_metrics
    generate_reports
    print_summary
}

# Execute main function
main "$@"