using System.Diagnostics;
using Microsoft.AspNetCore.Http;
using Prometheus;

namespace PerformanceBenchmark.Api.Middleware;

public class TimingMiddleware
{
    private readonly RequestDelegate _next;
    private static readonly Histogram RequestDuration = Prometheus.Metrics
        .CreateHistogram("http_request_duration_seconds", "Duration of HTTP requests in seconds",
            new HistogramConfiguration
            {
                LabelNames = new[] { "method", "endpoint", "status_code" }
            });

    private static readonly Counter RequestsTotal = Prometheus.Metrics
        .CreateCounter("http_requests_total", "Total number of HTTP requests",
            new CounterConfiguration
            {
                LabelNames = new[] { "method", "endpoint", "status_code" }
            });

    private static readonly Gauge ActiveConnections = Prometheus.Metrics
        .CreateGauge("http_active_connections", "Number of active HTTP connections");

    public TimingMiddleware(RequestDelegate next)
    {
        _next = next;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        var stopwatch = Stopwatch.StartNew();
        ActiveConnections.Inc();

        try
        {
            await _next(context);
        }
        finally
        {
            stopwatch.Stop();
            ActiveConnections.Dec();

            var endpoint = context.Request.Path.Value ?? "unknown";
            var method = context.Request.Method;
            var statusCode = context.Response.StatusCode.ToString();

            RequestDuration
                .WithLabels(method, endpoint, statusCode)
                .Observe(stopwatch.Elapsed.TotalSeconds);

            RequestsTotal
                .WithLabels(method, endpoint, statusCode)
                .Inc();

            Console.WriteLine($"Request: {method} {endpoint} | Status: {statusCode} | Duration: {stopwatch.ElapsedMilliseconds}ms");
        }
    }
}