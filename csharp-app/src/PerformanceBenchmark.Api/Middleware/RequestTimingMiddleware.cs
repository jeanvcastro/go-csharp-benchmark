using System.Diagnostics;

namespace PerformanceBenchmark.Api.Middleware;

public class RequestTimingMiddleware
{
    private readonly RequestDelegate _next;

    public RequestTimingMiddleware(RequestDelegate next)
    {
        _next = next;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        var stopwatch = Stopwatch.StartNew();

        await _next(context);

        stopwatch.Stop();

        Console.WriteLine($"Request: {context.Request.Method} {context.Request.Path} | Status: {context.Response.StatusCode} | Latency: {stopwatch.ElapsedMilliseconds}ms");
    }
}