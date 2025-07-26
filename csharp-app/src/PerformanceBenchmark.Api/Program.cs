using Microsoft.EntityFrameworkCore;
using PerformanceBenchmark.Api.Middleware;
using PerformanceBenchmark.Data;
using PerformanceBenchmark.Metrics;
using Prometheus;

var builder = WebApplication.CreateBuilder(args);

builder.Logging.ClearProviders();

builder.Services.AddControllers();

if (builder.Environment.IsDevelopment())
{
    builder.Services.AddEndpointsApiExplorer();
    builder.Services.AddSwaggerGen();
}

var connectionString = builder.Configuration.GetConnectionString("DefaultConnection") 
                       ?? throw new InvalidOperationException("Connection string 'DefaultConnection' not found.");

builder.Services.AddDbContextPool<BenchmarkDbContext>(options =>
    options.UseNpgsql(connectionString, npgsqlOptions =>
    {
        npgsqlOptions.CommandTimeout(30);
    })
    .EnableSensitiveDataLogging(false)
    .EnableServiceProviderCaching()
    .EnableThreadSafetyChecks(false));

builder.Services.AddScoped<IUserRepository, UserRepository>();
builder.Services.AddScoped<IOrderRepository, OrderRepository>();

builder.Services.AddSingleton<SystemMetricsCollector>();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

// Three middlewares like Go  
app.UseMiddleware<TimingMiddleware>();
app.UseMiddleware<MetricsMiddleware>();
app.UseMiddleware<RequestTimingMiddleware>();

app.UseMetricServer();

app.MapControllers();
app.MapGet("/health", () => new { status = "healthy", service = "benchmark-csharp" });

var systemMetrics = app.Services.GetRequiredService<SystemMetricsCollector>();
systemMetrics.StartCollection();

app.Run();