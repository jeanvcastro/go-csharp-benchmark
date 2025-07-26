using System.Diagnostics;

namespace PerformanceBenchmark.Api.Middleware;

public class MetricsMiddleware
{
    private readonly RequestDelegate _next;
    
    private static readonly Prometheus.Histogram HttpRequestDuration = Prometheus.Metrics
        .CreateHistogram("http_request_duration_seconds", "Duration of HTTP requests in seconds",
            new Prometheus.HistogramConfiguration
            {
                LabelNames = new[] { "method", "endpoint", "status_code" }
            });

    private static readonly Prometheus.Counter HttpRequestsTotal = Prometheus.Metrics
        .CreateCounter("http_requests_total", "Total number of HTTP requests",
            new Prometheus.CounterConfiguration
            {
                LabelNames = new[] { "method", "endpoint", "status_code" }
            });

    private static readonly Prometheus.Gauge ActiveConnections = Prometheus.Metrics
        .CreateGauge("http_active_connections", "Number of active HTTP connections");

    public MetricsMiddleware(RequestDelegate next)
    {
        _next = next;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        var stopwatch = Stopwatch.StartNew();
        ActiveConnections.Inc();

        await _next(context);

        stopwatch.Stop();
        ActiveConnections.Dec();

        var endpoint = context.GetEndpoint()?.DisplayName ?? "unknown";
        var method = context.Request.Method;
        var statusCode = context.Response.StatusCode.ToString();

        HttpRequestDuration
            .WithLabels(method, endpoint, statusCode)
            .Observe(stopwatch.Elapsed.TotalSeconds);

        HttpRequestsTotal
            .WithLabels(method, endpoint, statusCode)
            .Inc();
    }
}