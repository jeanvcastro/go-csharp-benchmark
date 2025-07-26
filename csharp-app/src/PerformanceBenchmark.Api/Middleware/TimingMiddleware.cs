using System.Diagnostics;

namespace PerformanceBenchmark.Api.Middleware;

public class TimingMiddleware
{
    private readonly RequestDelegate _next;

    public TimingMiddleware(RequestDelegate next)
    {
        _next = next;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        var stopwatch = Stopwatch.StartNew();

        await _next(context);

        stopwatch.Stop();

        // Simple timing log like Go's RequestTimingMiddleware
        Console.WriteLine($"Request: {context.Request.Method} {context.Request.Path} | Status: {context.Response.StatusCode} | Latency: {stopwatch.ElapsedMilliseconds}ms");
    }
}