FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS base
WORKDIR /app
EXPOSE 8080

FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

COPY ["src/PerformanceBenchmark.Api/PerformanceBenchmark.Api.csproj", "src/PerformanceBenchmark.Api/"]
COPY ["src/PerformanceBenchmark.Data/PerformanceBenchmark.Data.csproj", "src/PerformanceBenchmark.Data/"]
COPY ["src/PerformanceBenchmark.Metrics/PerformanceBenchmark.Metrics.csproj", "src/PerformanceBenchmark.Metrics/"]

RUN dotnet restore "src/PerformanceBenchmark.Api/PerformanceBenchmark.Api.csproj"

COPY . .
WORKDIR "/src/src/PerformanceBenchmark.Api"
RUN dotnet build "PerformanceBenchmark.Api.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "PerformanceBenchmark.Api.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .

ENV ASPNETCORE_URLS=http://+:8080

ENTRYPOINT ["dotnet", "PerformanceBenchmark.Api.dll"]