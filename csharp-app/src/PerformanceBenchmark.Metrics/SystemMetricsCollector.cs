using System.Diagnostics;
using Prometheus;

namespace PerformanceBenchmark.Metrics;

public class SystemMetricsCollector
{
    private static readonly Gauge ThreadsGauge = Prometheus.Metrics
        .CreateGauge("benchmark_threads_active", "Number of active threads");

    private static readonly Gauge MemoryGauge = Prometheus.Metrics
        .CreateGauge("benchmark_memory_usage_bytes", "Memory usage in bytes", "type");

    private static readonly Histogram GcDurationHistogram = Prometheus.Metrics
        .CreateHistogram("benchmark_gc_duration_seconds", "Time spent in garbage collection");

    private static readonly Gauge DatabaseConnectionsGauge = Prometheus.Metrics
        .CreateGauge("database_connections_active", "Number of active database connections");

    private readonly Timer _timer;
    private readonly Process _currentProcess;

    public SystemMetricsCollector()
    {
        _currentProcess = Process.GetCurrentProcess();
        _timer = new Timer(CollectMetrics, null, TimeSpan.Zero, TimeSpan.FromSeconds(15));
    }

    public void StartCollection()
    {
    }

    private void CollectMetrics(object? state)
    {
        try
        {
            _currentProcess.Refresh();

            ThreadsGauge.Set(_currentProcess.Threads.Count);
            MemoryGauge.WithLabels("working_set").Set(_currentProcess.WorkingSet64);

            var totalMemory = GC.GetTotalMemory(false);
            MemoryGauge.WithLabels("gc_heap").Set(totalMemory);
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error collecting metrics: {ex.Message}");
        }
    }

    public void UpdateDatabaseConnectionMetrics(int activeConnections)
    {
        DatabaseConnectionsGauge.Set(activeConnections);
    }

    public void Dispose()
    {
        _timer?.Dispose();
        _currentProcess?.Dispose();
    }
}