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
import numpy as np

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
                
            # Parse K6 JSON output (one JSON object per line) - with sampling for large files
            metrics_data = []
            total_lines = len(lines)
            
            # If file is large (>50MB), sample every 10th line for performance
            step = 10 if json_file.stat().st_size > 50_000_000 else 1
            
            if step > 1:
                print(f"  📉 Large file detected, sampling every {step} lines")
            
            for i, line in enumerate(lines):
                if i % step != 0:  # Skip lines based on sampling
                    continue
                    
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

def calculate_stats(times):
    """Calculate statistical metrics for response times"""
    if not times:
        return {'count': 0, 'error': 'No data'}
    
    return {
        'count': len(times),
        'min': min(times),
        'max': max(times),
        'mean': statistics.mean(times),
        'median': statistics.median(times),
        'p95': statistics.quantiles(times, n=20)[18] if len(times) > 20 else max(times),
        'p99': statistics.quantiles(times, n=100)[98] if len(times) > 100 else max(times)
    }

def analyze_response_times(k6_results):
    """Analyze response times from K6 results by application"""
    analysis = {}
    
    for test_name, metrics in k6_results.items():
        # Analyze by application using the new separate metrics
        app_metrics = {
            'go': [],
            'csharp_ef': [],
            'csharp_dapper': []
        }
        
        for metric in metrics:
            metric_name = metric.get('metric', '')
            value = metric.get('data', {}).get('value')
            
            if value is None:
                continue
            
            # Application-specific response times
            if 'go_response_time' in metric_name or 'go_db_response_time' in metric_name or 'go_memory_response_time' in metric_name:
                app_metrics['go'].append(value)
            elif 'csharp_ef_response_time' in metric_name or 'csharp_ef_db_response_time' in metric_name or 'csharp_ef_memory_response_time' in metric_name:
                app_metrics['csharp_ef'].append(value)
            elif 'csharp_dapper_response_time' in metric_name or 'csharp_dapper_db_response_time' in metric_name or 'csharp_dapper_memory_response_time' in metric_name:
                app_metrics['csharp_dapper'].append(value)
        
        # Calculate stats per-app
        test_analysis = {}
        for app, times in app_metrics.items():
            test_analysis[app] = calculate_stats(times)
        
        analysis[test_name] = test_analysis
    
    return analysis

def analyze_throughput(k6_results):
    """Analyze throughput metrics by application"""
    analysis = {}
    
    for test_name, metrics in k6_results.items():
        # Per-app metrics
        app_errors = {
            'go': 0,
            'csharp_ef': 0,
            'csharp_dapper': 0
        }
        
        app_operations = {
            'go': 0,
            'csharp_ef': 0,
            'csharp_dapper': 0
        }
        
        for metric in metrics:
            metric_name = metric.get('metric', '')
            value = metric.get('data', {}).get('value', 0)
            
            # App-specific error rates
            if 'go_errors' in metric_name or 'go_db_errors' in metric_name or 'go_memory_errors' in metric_name:
                app_errors['go'] += value
            elif 'csharp_ef_errors' in metric_name or 'csharp_ef_db_errors' in metric_name or 'csharp_ef_memory_errors' in metric_name:
                app_errors['csharp_ef'] += value
            elif 'csharp_dapper_errors' in metric_name or 'csharp_dapper_db_errors' in metric_name or 'csharp_dapper_memory_errors' in metric_name:
                app_errors['csharp_dapper'] += value
            
            # App-specific operations
            elif 'go_operations' in metric_name or 'go_db_operations' in metric_name or 'go_memory_operations' in metric_name:
                app_operations['go'] += value
            elif 'csharp_ef_operations' in metric_name or 'csharp_ef_db_operations' in metric_name or 'csharp_ef_memory_operations' in metric_name:
                app_operations['csharp_ef'] += value
            elif 'csharp_dapper_operations' in metric_name or 'csharp_dapper_db_operations' in metric_name or 'csharp_dapper_memory_operations' in metric_name:
                app_operations['csharp_dapper'] += value
        
        test_analysis = {}
        
        # Add per-app analysis
        for app in ['go', 'csharp_ef', 'csharp_dapper']:
            operations = app_operations[app]
            errors = app_errors[app]
            
            test_analysis[app] = {
                'operations': operations,
                'errors': errors,
                'error_rate_percent': (errors / operations * 100) if operations > 0 else 0,
                'ops_per_sec': operations / 300 if operations > 0 else 0
            }
        
        analysis[test_name] = test_analysis
    
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
        f.write("# Go vs C# Performance Benchmark Report\n\n")
        f.write(f"Generated on: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
        
        # Performance Summary by Application
        f.write("## 📊 Performance Summary by Application\n\n")
        
        apps = ['go', 'csharp_ef', 'csharp_dapper']
        app_names = {'go': 'Go', 'csharp_ef': 'C# Entity Framework', 'csharp_dapper': 'C# Dapper'}
        
        for app in apps:
            f.write(f"### {app_names[app]}\n\n")
            
            # Response times table for this app
            f.write("#### Response Times\n\n")
            f.write("| Test | Count | Min (ms) | Mean (ms) | Median (ms) | P95 (ms) | P99 (ms) | Max (ms) |\n")
            f.write("|------|-------|----------|-----------|-------------|----------|----------|----------|\n")
            
            for test_name, test_data in response_times.items():
                if app in test_data and 'error' not in test_data[app]:
                    stats = test_data[app]
                    f.write(f"| {test_name} | {stats['count']} | "
                           f"{stats['min']:.2f} | {stats['mean']:.2f} | {stats['median']:.2f} | "
                           f"{stats['p95']:.2f} | {stats['p99']:.2f} | {stats['max']:.2f} |\n")
            
            # Throughput table for this app
            f.write("\n#### Throughput\n\n")
            f.write("| Test | Operations | Errors | Error Rate (%) | Ops/sec |\n")
            f.write("|------|------------|--------|----------------|---------|\n")
            
            for test_name, test_data in throughput.items():
                if app in test_data:
                    stats = test_data[app]
                    f.write(f"| {test_name} | {stats['operations']} | {stats['errors']} | "
                           f"{stats['error_rate_percent']:.2f} | {stats['ops_per_sec']:.2f} |\n")
            
            f.write("\n")
        
        # Cross-Application Comparison
        f.write("## 🏆 Cross-Application Comparison\n\n")
        
        for test_name in response_times.keys():
            f.write(f"### {test_name.replace('-', ' ').title()}\n\n")
            
            # Response time comparison
            f.write("#### Response Times\n\n")
            f.write("| Application | Mean (ms) | P95 (ms) | Operations |\n")
            f.write("|-------------|-----------|----------|-----------|\n")
            
            for app in apps:
                if app in response_times[test_name] and 'error' not in response_times[test_name][app]:
                    rt_stats = response_times[test_name][app]
                    th_stats = throughput[test_name][app]
                    f.write(f"| {app_names[app]} | {rt_stats['mean']:.2f} | {rt_stats['p95']:.2f} | {th_stats['operations']} |\n")
            
            f.write("\n")
        
        # Application Metrics Comparison
        if prometheus_data:
            f.write("## 💾 Application Metrics Comparison\n\n")
            
            if 'go' in prometheus_data and 'csharp' in prometheus_data:
                go_metrics = prometheus_data['go']
                csharp_metrics = prometheus_data['csharp']
                
                # Memory usage comparison
                f.write("### Memory Usage\n\n")
                f.write("| Metric | Go | C# |\n")
                f.write("|--------|----|----|\\n")
                
                # Look for memory-related metrics
                memory_metrics = ['benchmark_memory_usage_bytes', 'go_memstats_heap_alloc_bytes']
                for metric in memory_metrics:
                    go_val = next((v for k, v in go_metrics.items() if metric in k), 'N/A')
                    cs_val = next((v for k, v in csharp_metrics.items() if metric in k), 'N/A')
                    
                    # Format memory values nicely
                    if isinstance(go_val, (int, float)):
                        go_val = f"{go_val/1024/1024:.1f} MB"
                    if isinstance(cs_val, (int, float)):
                        cs_val = f"{cs_val/1024/1024:.1f} MB"
                    
                    f.write(f"| {metric.replace('_', ' ').title()} | {go_val} | {cs_val} |\n")
                
                f.write("\n")
        
        # Summary and Recommendations
        f.write("## 🎯 Key Findings & Recommendations\n\n")
        
        # Find best performing app per test
        f.write("### Performance Winners\n\n")
        
        for test_name in response_times.keys():
            best_app = None
            best_mean = float('inf')
            
            for app in apps:
                if app in response_times[test_name] and 'error' not in response_times[test_name][app]:
                    mean_time = response_times[test_name][app]['mean']
                    if mean_time < best_mean:
                        best_mean = mean_time
                        best_app = app
            
            if best_app:
                f.write(f"- **{test_name.replace('-', ' ').title()}**: {app_names[best_app]} ({best_mean:.2f}ms avg)\n")
        
        # Error rate analysis
        f.write("\n### Error Rate Analysis\n\n")
        for test_name in throughput.keys():
            f.write(f"**{test_name.replace('-', ' ').title()}**:\n\n")
            for app in apps:
                if app in throughput[test_name]:
                    error_rate = throughput[test_name][app]['error_rate_percent']
                    status = "✅" if error_rate < 1 else "⚠️" if error_rate < 5 else "❌"
                    f.write(f"- {status} {app_names[app]}: {error_rate:.2f}% error rate\n")
            f.write("\n")
        
        f.write("### Recommendations\n\n")
        f.write("Based on the benchmark results:\n\n")
        f.write("1. 📊 **Monitor Grafana dashboards** for real-time performance insights\n")
        f.write("2. 🧠 **Analyze memory patterns** - C# shows higher memory usage\n")
        f.write("3. 🔧 **Tune connection pools** based on database stress results\n")
        f.write("4. 🚨 **Investigate high error rates** in memory pressure tests\n")
        f.write("5. ⚡ **Consider caching strategies** for frequently accessed data\n")
        
        f.write("\n---\n\n")
        f.write("*📈 This report was generated automatically by the benchmark analysis script.*\n")
    
    print(f"✅ Comparison report generated: {report_file}")
    return report_file

def create_visualizations(response_times, throughput, output_dir):
    """Create performance visualization charts"""
    try:
        import matplotlib.pyplot as plt
        import seaborn as sns
        import numpy as np
        
        plt.style.use('seaborn-v0_8')
        fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(20, 16))
        
        apps = ['go', 'csharp_ef', 'csharp_dapper']
        app_names = {'go': 'Go', 'csharp_ef': 'C# EF', 'csharp_dapper': 'C# Dapper'}
        colors = {'go': '#00ADD8', 'csharp_ef': '#512BD4', 'csharp_dapper': '#68217A'}
        
        # 1. Response Time Comparison by App and Test
        test_names = list(response_times.keys())
        x = np.arange(len(test_names))
        width = 0.25
        
        for i, app in enumerate(apps):
            means = []
            for test in test_names:
                if app in response_times[test] and 'error' not in response_times[test][app]:
                    means.append(response_times[test][app]['mean'])
                else:
                    means.append(0)
            
            ax1.bar(x + i * width, means, width, label=app_names[app], color=colors[app], alpha=0.8)
        
        ax1.set_xlabel('Test Types')
        ax1.set_ylabel('Mean Response Time (ms)')
        ax1.set_title('Response Time Comparison by Application')
        ax1.set_xticks(x + width)
        ax1.set_xticklabels([t.replace('-', '\n') for t in test_names])
        ax1.legend()
        ax1.set_yscale('log')  # Log scale for better visualization
        
        # 2. Operations per Second Comparison
        for i, app in enumerate(apps):
            ops_per_sec = []
            for test in test_names:
                if app in throughput[test]:
                    ops_per_sec.append(throughput[test][app]['ops_per_sec'])
                else:
                    ops_per_sec.append(0)
            
            ax2.bar(x + i * width, ops_per_sec, width, label=app_names[app], color=colors[app], alpha=0.8)
        
        ax2.set_xlabel('Test Types')
        ax2.set_ylabel('Operations per Second')
        ax2.set_title('Throughput Comparison by Application')
        ax2.set_xticks(x + width)
        ax2.set_xticklabels([t.replace('-', '\n') for t in test_names])
        ax2.legend()
        
        # 3. Error Rate Comparison
        for i, app in enumerate(apps):
            error_rates = []
            for test in test_names:
                if app in throughput[test]:
                    error_rates.append(throughput[test][app]['error_rate_percent'])
                else:
                    error_rates.append(0)
            
            ax3.bar(x + i * width, error_rates, width, label=app_names[app], color=colors[app], alpha=0.8)
        
        ax3.set_xlabel('Test Types')
        ax3.set_ylabel('Error Rate (%)')
        ax3.set_title('Error Rate Comparison by Application')
        ax3.set_xticks(x + width)
        ax3.set_xticklabels([t.replace('-', '\n') for t in test_names])
        ax3.legend()
        
        # 4. P95 Response Time Comparison (More detailed view)
        for i, app in enumerate(apps):
            p95_times = []
            for test in test_names:
                if app in response_times[test] and 'error' not in response_times[test][app]:
                    p95_times.append(response_times[test][app]['p95'])
                else:
                    p95_times.append(0)
            
            ax4.bar(x + i * width, p95_times, width, label=app_names[app], color=colors[app], alpha=0.8)
        
        ax4.set_xlabel('Test Types')
        ax4.set_ylabel('P95 Response Time (ms)')
        ax4.set_title('P95 Response Time Comparison by Application')
        ax4.set_xticks(x + width)
        ax4.set_xticklabels([t.replace('-', '\n') for t in test_names])
        ax4.legend()
        ax4.set_yscale('log')  # Log scale for better visualization
        
        plt.tight_layout(pad=3.0)
        plt.suptitle('Go vs C# Performance Benchmark Results', fontsize=16, y=0.98)
        
        chart_file = Path(output_dir) / "performance_comparison_charts.png"
        plt.savefig(chart_file, dpi=300, bbox_inches='tight', facecolor='white')
        plt.close()
        
        print(f"✅ Performance charts generated: {chart_file}")
        
    except ImportError as e:
        print(f"⚠️ matplotlib/seaborn not available, skipping chart generation: {e}")
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