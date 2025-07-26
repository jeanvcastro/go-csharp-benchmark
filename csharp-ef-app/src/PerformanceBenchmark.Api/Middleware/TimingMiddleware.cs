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
        var timestamp = DateTime.Now.ToString("yyyy/MM/dd - HH:mm:ss");
        
        await _next(context);

        // Log format similar to Go's TimingMiddleware
        Console.WriteLine($"[{timestamp}] {context.Request.Method} {context.Request.Path} {context.Response.StatusCode} {context.Connection.RemoteIpAddress}");
    }
}