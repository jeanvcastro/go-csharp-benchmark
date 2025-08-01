﻿using PerformanceBenchmark.Api.Middleware;
using PerformanceBenchmark.Data;
using PerformanceBenchmark.Metrics;
using Prometheus;

var builder = WebApplication.CreateBuilder(args);

builder.Logging.ClearProviders();

builder.Services.AddControllers();

builder.Services.AddScoped<IUserRepository, SqlUserRepository>();
builder.Services.AddScoped<IOrderRepository, SqlOrderRepository>();

builder.Services.AddSingleton<SystemMetricsCollector>();

var app = builder.Build();


app.UseMiddleware<TimingMiddleware>();
app.UseMiddleware<MetricsMiddleware>();
app.UseMiddleware<RequestTimingMiddleware>();

app.UseMetricServer();

app.MapControllers();
app.MapGet("/health", () => new { status = "healthy", service = "benchmark-csharp" });

var systemMetrics = app.Services.GetRequiredService<SystemMetricsCollector>();
systemMetrics.StartCollection();

app.Run();