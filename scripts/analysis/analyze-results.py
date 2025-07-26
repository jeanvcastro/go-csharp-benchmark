#!/usr/bin/env python3

import json
import csv
import os
import sys
import statistics
from pathlib import Path
from datetime import datetime
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

def load_k6_results(results_dir):
    """Load K6 JSON results from the benchmark session"""
    k6_results = {}
    k6_dir = Path(results_dir) / "k6-results"
    
    if not k6_dir.exists():
        print(f"❌ K6 results directory not found: {k6_dir}")
        return k6_results
    
    for json_file in k6_dir.glob("*.json"):
        test_name = json_file.stem
        print(f"📊 Loading K6 results for {test_name}...")
        
        try:
            with open(json_file, 'r') as f:
                lines = f.readlines()
                
            # Parse K6 JSON output (one JSON object per line)
            metrics_data = []
            for line in lines:
                if line.strip():
                    try:
                        data = json.loads(line)
                        if data.get('type') == 'Point':
                            metrics_data.append(data)
                    except json.JSONDecodeError:
                        continue
            
            k6_results[test_name] = metrics_data
            print(f"  ✅ Loaded {len(metrics_data)} metric points")
            
        except Exception as e:
            print(f"  ❌ Error loading {json_file}: {e}")
    
    return k6_results

def analyze_response_times(k6_results):
    """Analyze response times from K6 results"""
    analysis = {}
    
    for test_name, metrics in k6_results.items():
        response_times = []
        
        for metric in metrics:
            if (metric.get('metric') == 'http_req_duration' and 
                'data' in metric and 'value' in metric['data']):
                response_times.append(metric['data']['value'])
        
        if response_times:
            analysis[test_name] = {
                'count': len(response_times),
                'min': min(response_times),
                'max': max(response_times),
                'mean': statistics.mean(response_times),
                'median': statistics.median(response_times),
                'p95': statistics.quantiles(response_times, n=20)[18] if len(response_times) > 20 else max(response_times),
                'p99': statistics.quantiles(response_times, n=100)[98] if len(response_times) > 100 else max(response_times)
            }
        else:
            analysis[test_name] = {'count': 0, 'error': 'No response time data found'}
    
    return analysis

def analyze_throughput(k6_results):
    """Analyze throughput metrics"""
    analysis = {}
    
    for test_name, metrics in k6_results.items():
        requests = []
        errors = []
        
        for metric in metrics:
            if metric.get('metric') == 'http_reqs':
                requests.append(metric['data']['value'])
            elif metric.get('metric') == 'http_req_failed' and metric['data']['value'] > 0:
                errors.append(metric['data']['value'])
        
        total_requests = sum(requests) if requests else 0
        total_errors = len(errors)
        error_rate = (total_errors / total_requests * 100) if total_requests > 0 else 0
        
        analysis[test_name] = {
            'total_requests': total_requests,
            'total_errors': total_errors,
            'error_rate_percent': error_rate,
            'rps': total_requests / 300 if total_requests > 0 else 0  # Assuming ~5min tests
        }
    
    return analysis

def load_prometheus_metrics(results_dir):
    """Load and analyze Prometheus metrics"""
    metrics_dir = Path(results_dir) / "prometheus-metrics"
    prometheus_data = {}
    
    if not metrics_dir.exists():
        print(f"❌ Prometheus metrics directory not found: {metrics_dir}")
        return prometheus_data
    
    # Load Go metrics
    go_files = list(metrics_dir.glob("*go_metrics*.txt"))
    if go_files:
        print(f"📊 Found {len(go_files)} Go metrics files")
        prometheus_data['go'] = parse_prometheus_file(go_files[-1])  # Use latest
    
    # Load C# metrics
    csharp_files = list(metrics_dir.glob("*csharp_metrics*.txt"))
    if csharp_files:
        print(f"📊 Found {len(csharp_files)} C# metrics files")
        prometheus_data['csharp'] = parse_prometheus_file(csharp_files[-1])  # Use latest
    
    return prometheus_data

def parse_prometheus_file(file_path):
    """Parse Prometheus metrics file format"""
    metrics = {}
    
    try:
        with open(file_path, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#'):
                    if ' ' in line:
                        metric_name, value = line.rsplit(' ', 1)
                        try:
                            metrics[metric_name] = float(value)
                        except ValueError:
                            metrics[metric_name] = value
        
        print(f"  ✅ Parsed {len(metrics)} metrics from {file_path.name}")
        
    except Exception as e:
        print(f"  ❌ Error parsing {file_path}: {e}")
    
    return metrics

def generate_comparison_report(response_times, throughput, prometheus_data, output_dir):
    """Generate comprehensive comparison report"""
    report_file = Path(output_dir) / "benchmark_comparison_report.md"
    
    with open(report_file, 'w') as f:
        f.write("# Go vs C# Performance Benchmark Report\\n\\n")
        f.write(f"Generated on: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\\n\\n")
        
        # Response Times Analysis
        f.write("## Response Time Analysis\\n\\n")
        f.write("| Test | Count | Min (ms) | Mean (ms) | Median (ms) | P95 (ms) | P99 (ms) | Max (ms) |\\n")
        f.write("|------|-------|----------|-----------|-------------|----------|----------|----------|\\n")
        
        for test_name, stats in response_times.items():
            if 'error' not in stats:
                f.write(f"| {test_name} | {stats['count']} | "
                       f"{stats['min']:.2f} | {stats['mean']:.2f} | {stats['median']:.2f} | "
                       f"{stats['p95']:.2f} | {stats['p99']:.2f} | {stats['max']:.2f} |\\n")
        
        f.write("\\n")
        
        # Throughput Analysis
        f.write("## Throughput Analysis\\n\\n")
        f.write("| Test | Total Requests | Errors | Error Rate (%) | RPS |\\n")
        f.write("|------|----------------|--------|----------------|-----|\\n")
        
        for test_name, stats in throughput.items():
            f.write(f"| {test_name} | {stats['total_requests']} | {stats['total_errors']} | "
                   f"{stats['error_rate_percent']:.2f} | {stats['rps']:.2f} |\\n")
        
        f.write("\\n")
        
        # Application Metrics Comparison
        if prometheus_data:
            f.write("## Application Metrics Comparison\\n\\n")
            
            if 'go' in prometheus_data and 'csharp' in prometheus_data:
                go_metrics = prometheus_data['go']
                csharp_metrics = prometheus_data['csharp']
                
                # Memory usage comparison
                f.write("### Memory Usage\\n\\n")
                f.write("| Metric | Go | C# |\\n")
                f.write("|--------|----|----|\\n")
                
                # Look for memory-related metrics
                memory_metrics = ['benchmark_memory_usage_bytes', 'go_memstats_heap_alloc_bytes']
                for metric in memory_metrics:
                    go_val = next((v for k, v in go_metrics.items() if metric in k), 'N/A')
                    cs_val = next((v for k, v in csharp_metrics.items() if metric in k), 'N/A')
                    f.write(f"| {metric} | {go_val} | {cs_val} |\\n")
                
                f.write("\\n")
        
        # Summary and Recommendations
        f.write("## Summary and Recommendations\\n\\n")
        f.write("### Key Findings\\n\\n")
        
        # Calculate overall performance
        if response_times:
            avg_response_times = {test: stats.get('mean', 0) for test, stats in response_times.items() if 'error' not in stats}
            if avg_response_times:
                best_test = min(avg_response_times, key=avg_response_times.get)
                f.write(f"- **Fastest Response Time**: {best_test} ({avg_response_times[best_test]:.2f}ms average)\\n")
        
        if throughput:
            total_rps = {test: stats.get('rps', 0) for test, stats in throughput.items()}
            if total_rps:
                best_throughput = max(total_rps, key=total_rps.get)
                f.write(f"- **Highest Throughput**: {best_throughput} ({total_rps[best_throughput]:.2f} RPS)\\n")
        
        f.write("\\n### Recommendations\\n\\n")
        f.write("Based on the benchmark results:\\n\\n")
        f.write("1. Review application metrics in Grafana for detailed insights\\n")
        f.write("2. Analyze memory usage patterns and garbage collection behavior\\n")
        f.write("3. Consider connection pool tuning based on database stress test results\\n")
        f.write("4. Monitor error rates and investigate any performance degradation\\n")
        
        f.write("\\n---\\n\\n")
        f.write("*This report was generated automatically by the benchmark analysis script.*\\n")
    
    print(f"✅ Comparison report generated: {report_file}")
    return report_file

def create_visualizations(response_times, throughput, output_dir):
    """Create performance visualization charts"""
    try:
        import matplotlib.pyplot as plt
        import seaborn as sns
        
        plt.style.use('seaborn-v0_8')
        fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(15, 12))
        
        # Response Time Comparison
        if response_times:
            tests = list(response_times.keys())
            means = [stats.get('mean', 0) for stats in response_times.values() if 'error' not in stats]
            p95s = [stats.get('p95', 0) for stats in response_times.values() if 'error' not in stats]
            
            if means and p95s:
                x = range(len(tests))
                ax1.bar([i - 0.2 for i in x], means, 0.4, label='Mean', alpha=0.8)
                ax1.bar([i + 0.2 for i in x], p95s, 0.4, label='P95', alpha=0.8)
                ax1.set_xlabel('Test Cases')
                ax1.set_ylabel('Response Time (ms)')
                ax1.set_title('Response Time Comparison')
                ax1.set_xticks(x)
                ax1.set_xticklabels(tests, rotation=45)
                ax1.legend()
        
        # Throughput Comparison
        if throughput:
            tests = list(throughput.keys())
            rps_values = [stats.get('rps', 0) for stats in throughput.values()]
            
            if rps_values:
                ax2.bar(tests, rps_values, alpha=0.8, color='green')
                ax2.set_xlabel('Test Cases')
                ax2.set_ylabel('Requests per Second')
                ax2.set_title('Throughput Comparison')
                ax2.tick_params(axis='x', rotation=45)
        
        # Error Rate Comparison
        if throughput:
            tests = list(throughput.keys())
            error_rates = [stats.get('error_rate_percent', 0) for stats in throughput.values()]
            
            if error_rates:
                ax3.bar(tests, error_rates, alpha=0.8, color='red')
                ax3.set_xlabel('Test Cases')
                ax3.set_ylabel('Error Rate (%)')
                ax3.set_title('Error Rate Comparison')
                ax3.tick_params(axis='x', rotation=45)
        
        # Request Count Comparison
        if throughput:
            tests = list(throughput.keys())
            req_counts = [stats.get('total_requests', 0) for stats in throughput.values()]
            
            if req_counts:
                ax4.bar(tests, req_counts, alpha=0.8, color='blue')
                ax4.set_xlabel('Test Cases')
                ax4.set_ylabel('Total Requests')
                ax4.set_title('Total Requests Comparison')
                ax4.tick_params(axis='x', rotation=45)
        
        plt.tight_layout()
        chart_file = Path(output_dir) / "performance_comparison_charts.png"
        plt.savefig(chart_file, dpi=300, bbox_inches='tight')
        plt.close()
        
        print(f"✅ Performance charts generated: {chart_file}")
        
    except ImportError:
        print("⚠️  matplotlib/seaborn not available, skipping chart generation")
    except Exception as e:
        print(f"❌ Error generating charts: {e}")

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 analyze-results.py <results_directory>")
        sys.exit(1)
    
    results_dir = sys.argv[1]
    
    if not os.path.exists(results_dir):
        print(f"❌ Results directory does not exist: {results_dir}")
        sys.exit(1)
    
    print("🔍 Analyzing benchmark results...")
    print(f"Results directory: {results_dir}")
    print()
    
    # Create reports directory
    reports_dir = Path(results_dir) / "reports"
    reports_dir.mkdir(exist_ok=True)
    
    # Load and analyze K6 results
    k6_results = load_k6_results(results_dir)
    response_times = analyze_response_times(k6_results)
    throughput = analyze_throughput(k6_results)
    
    # Load Prometheus metrics
    prometheus_data = load_prometheus_metrics(results_dir)
    
    # Generate reports
    report_file = generate_comparison_report(response_times, throughput, prometheus_data, reports_dir)
    
    # Create visualizations
    create_visualizations(response_times, throughput, reports_dir)
    
    print()
    print("📊 Analysis Complete!")
    print(f"📂 Reports generated in: {reports_dir}")
    print(f"📈 Main report: {report_file}")
    print()

if __name__ == "__main__":
    main()